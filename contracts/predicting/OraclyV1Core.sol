// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { EOutcome } from "./EOutcome.sol";

import { Game } from "./structs/Game.sol";
import { Round } from "./structs/Round.sol";
import { Prediction } from "./structs/Prediction.sol";
import { Price } from "./structs/Price.sol";

import { MetaOraclyV1 } from "./MetaOraclyV1.sol";

/**
 * @title OraclyV1 Core Contract
 * @notice Core contract for handling prediction games, managing rounds, and calculating payouts.
 * @dev Provides essential logic for creating and managing prediction rounds, fetching price data, determining outcomes, and distributing prize pools.
 *      This contract is abstract and should be inherited by other contracts like OraclyV1, which will handle bettor interactions and protocol logic.
 *      Key functionalities:
 *      - Creation of new prediction rounds.
 *      - Fetching and validation of price data from oracles.
 *      - Determination of winners based on price movements.
 *      - Calculation and distribution of prize pools among winning participants.
 *      Note: This contract integrated with secure price oracles like Chainlink for price feeds.
 */
abstract contract OraclyV1Core is Context {

  using EnumerableSet for EnumerableSet.Bytes32Set;
  using EnumerableSet for EnumerableSet.AddressSet;
  using Address for address;

  /**
   * @notice The percentage taken as commission for stakers and mentors from the prize.
   * @dev Vigorish is a commission applied to the prize. It is set as a constant 1%.
   */
  uint8 constant public VIGORISH_PERCENT = 1;

  /**
   * @notice Mapping to store predictions for each round.
   * @dev Maps a round ID (bytes32) to a specific Prediction object. This stores the predictions made by bettors for a particular round.
   */
  mapping(bytes32 => Prediction) internal _predictions;

  /**
   * @notice Mapping to store round information.
   * @dev Maps a round ID (bytes32) to a specific Round object that holds all the relevant information for the round, such as start time, end time, and other metadata.
   */
  mapping(bytes32 => Round) internal _rounds;

  /**
   * @notice Mapping to track claimed predictions for each round.
   * @dev Maps a round ID (bytes32) to an array of EnumerableSet that tracks predictions claimed by bettors. Each set corresponds to different types of predictions, with the total being stored at index 0.
   */
  mapping(bytes32 => EnumerableSet.Bytes32Set[4]) private _claimedPredictions;

  /**
   * @notice Mapping to track all predictions for a round.
   * @dev Maps a round ID (bytes32) to an array of EnumerableSet that contains all predictions made for that round. Each set corresponds to different types of predictions, with the total being stored at index 0.
   */
  mapping(bytes32 => EnumerableSet.Bytes32Set[4]) private _roundPredictions;

  /**
   * @notice Mapping to track predictions placed by a specific bettor.
   * @dev Maps a bettor's address to an array of EnumerableSet that stores all of their predictions across rounds, Each set corresponds to different types of predictions, with the total being stored at index 0.
   */
  mapping(address => EnumerableSet.Bytes32Set[4]) private _bettorPredictions;

  /**
   * @notice Mapping to track all bettors for each round.
   * @dev Maps a round ID (bytes32) to an array of EnumerableSet that holds the addresses of all bettors participating in that round, Each set corresponds to different types of predictions, with the total being stored at index 0.
   */
  mapping(bytes32 => EnumerableSet.AddressSet[4]) private _roundBettors;

  /**
   * @notice Mapping to store funds deposited by each bettor in each ERC20 token.
   * @dev Maps a bettor's address and ERC20 token address to an array of four elements representing their funds deposited (in) total and across different prediction types.
   */
  mapping(address => mapping(address => uint[4])) private _bettorFundsIN;

  /**
   * @notice Mapping to store funds paid out to each bettor for each round.
   * @dev Maps a bettor's address and ERC20 token address to an array of four elements representing the funds paid out (out) total and across different prediction types.
   */
  mapping(address => mapping(address => uint[4])) private _bettorFundsOUT;

  /**
   * @notice Mapping to store all game rounds within a specific game.
   * @dev Maps a game ID (bytes32) to a set of round IDs that are part of the same game. This allows tracking of multiple rounds in the context of a single game.
   */
  mapping(bytes32 => EnumerableSet.Bytes32Set) private _gameRounds;

  /**
   * @notice Mapping to track the prize pool for each round.
   * @dev Maps a round ID (bytes32) to an array that represents the total prize pool and its distribution in that round, indexed by prediction outcome.
   */
  mapping(bytes32 => uint[2**8]) private _prizepool;

  /**
   * @notice Internal constant representing the ID used for tracking predictions in a round.
   * @dev Used as an index for arrays related to round predictions.
   */
  uint8 constant private ROUND_PREDICTIONS_ID = 0;

  /**
   * @notice Internal constant representing the ID used for tracking claimed predictions in a round.
   * @dev Used as an index for arrays related to claimed predictions in a round.
   */
  uint8 constant private ROUND_CLAIMED_PREDICTIONS_ID = 0;

  /**
   * @notice Internal constant representing the ID used for tracking bettors in a round.
   * @dev Used as an index for arrays related to round bettors.
   */
  uint8 constant private ROUND_BETTORS_ID = 0;

  /**
   * @notice Internal constant representing the ID used for tracking predictions placed by a bettor.
   * @dev Used as an index for arrays related to bettor predictions.
   */
  uint8 constant private BETTOR_PREDICTIONS_ID = 0;

  /**
   * @notice Internal constant representing the ID used for tracking the total amount deposited by a bettor.
   * @dev Used as an index for arrays related to bettor deposits.
   */
  uint8 constant private BETTOR_TOTAL_DEPOSIT_ID = 0;

  /**
   * @notice Internal constant representing the ID used for tracking the total amount paid out to a bettor.
   * @dev Used as an index for arrays related to bettor payouts.
   */
  uint8 constant private BETTOR_TOTAL_PAIDOUT_ID = 0;

  /**
   * @notice Internal constant representing the ID for the total prize pool in a round.
   * @dev Used as an index for arrays related to prize pool tracking.
   */
  uint8 constant private PRIZEPOOL_TOTAL_ID = 0;

  /**
   * @notice Internal constant representing the ID for the released prize pool in a round.
   * @dev Used as an index for arrays related to released funds from the prize pool.
   */
  uint8 constant private PRIZEPOOL_RELEASED_ID = 255;

  /**
   * @notice The constant that defines the bit offset for Chainlink's phase ID.
   * @dev This is used to extract the phase ID from the Chainlink round ID.
   *      Chainlink uses a combination of phase ID and aggregator round ID to distinguish between rounds in different phases of the same aggregator.
   *      The phase ID is stored in the most significant bits of the round ID, and this constant helps extract it.
   */
  uint256 constant private PRICE_FEED_PHASE_BIT_OFFSET = 64;

  /**
   * @notice Tracks ERC20 tokens that have triggered a fatal error due to insufficient funds in the prize pool.
   * @dev This mapping stores a boolean flag for each ERC20 token address.
   *      When the flag is set to true, it indicates that the corresponding token's prize pool has insufficient funds, causing a fatal error.
   *      Mapping:
   *      - `address`: The address of the ERC20 token contract.
   *      - `bool`: A flag where `true` indicates a fatal insufficient prize pool error for that token.
   */
  mapping(address => bool) public __FATAL_INSUFFICIENT_PRIZEPOOL_ERROR__;

  /**
   * @notice Immutable address of the MetaOracly contract, which serves as a registry of all games within the Oracly protocol.
   * @dev This immutable variable stores the address of the MetaOracly contract. Once set, it cannot be modified, ensuring the integrity of the contract registry across the protocol.
   *      This contract registry allows interaction with all possible games on the protocol.
   */
  address immutable public METAORACLY_CONTRACT;

  /**
   * @notice Initializes the OraclyV1Core contract by setting the MetaOracly contract address.
   * @dev This constructor is essential as the MetaOracly contract acts as the source for retrieving game data, price feeds, and other relevant information critical to the OraclyV1Core functionality.
   * @param metaoracly_address The address of the MetaOracly contract that serves as the data provider for the game.
   */
  constructor(
    address metaoracly_address
  )
  {
    if (!(metaoracly_address.code.length > 0)) {
      revert("CannotUseEOAAsMetaOraclyContract");
    }

    METAORACLY_CONTRACT = metaoracly_address;

  }

  /**
   * @notice Fetches a specific `Prediction` based on the provided prediction ID.
   * @dev Returns a `Prediction` struct that contains details about the prediction.
   *      Useful for retrieving prediction information like the predicted outcome, amount deposited, and bettor details.
   * @param predictionid The unique ID of the prediction to retrieve.
   * @return prediction A `Prediction` struct containing details such as the prediction position, bettor, and deposited amount.
   */
  function getPrediction(
    bytes32 predictionid
  )
    external
    view
    returns (
      Prediction memory prediction
    )
  {
    prediction = _predictions[predictionid];
  }

  /**
   * @notice Retrieves details about a specific prediction round.
   * @dev This function provides detailed information about a given round, including:
   *      - Round data (`Round` memory)
   *      - Total prize pools for the round and individual outcomes [Total, Down, Up, Zero] (`uint[4]`)
   *      - Total number of bettors for the round and individual outcomes [Total, Down, Up, Zero] (`uint[4]`)
   *      - Total number of predictions for the round and individual outcomes [Total, Down, Up, Zero] (`uint[4]`)
   *      Requirements:
   *      - The `roundid` must be valid and correspond to an existing round.
   * @param roundid The unique identifier of the prediction round.
   * @return round Information about the round as a `Round` struct.
   * @return prizepools Array of four `uint` values:
   *        [0]: Total deposited amount in the ERC20 token.
   *        [1]: Deposited amount for the Down outcome.
   *        [2]: Deposited amount for the Up outcome.
   *        [3]: Deposited amount for the Zero outcome.
   * @return bettors Array of four `uint` values:
   *        [0]: Total number of participants in the round.
   *        [1]: Number of participants who predicted Down.
   *        [2]: Number of participants who predicted Up.
   *        [3]: Number of participants who predicted Zero.
   * @return predictions Array of four `uint` values:
   *        [0]: Total number of predictions made.
   *        [1]: Number of predictions for Down.
   *        [2]: Number of predictions for Up.
   *        [3]: Number of predictions for Zero.
   */
  function getRound(
    bytes32 roundid
  )
    external
    view
    returns (
      Round memory round,
      uint[4] memory prizepools,
      uint[4] memory bettors,
      uint[4] memory predictions
    )
  {
    round = _rounds[roundid];
    prizepools = [
      _prizepool[roundid][PRIZEPOOL_TOTAL_ID],
      _prizepool[roundid][uint8(EOutcome.Down)],
      _prizepool[roundid][uint8(EOutcome.Up)],
      _prizepool[roundid][uint8(EOutcome.Zero)]
    ];
    bettors = [
      _roundBettors[roundid][ROUND_BETTORS_ID].length(),
      _roundBettors[roundid][uint8(EOutcome.Down)].length(),
      _roundBettors[roundid][uint8(EOutcome.Up)].length(),
      _roundBettors[roundid][uint8(EOutcome.Zero)].length()
    ];
    predictions = [
      _roundPredictions[roundid][ROUND_PREDICTIONS_ID].length(),
      _roundPredictions[roundid][uint8(EOutcome.Down)].length(),
      _roundPredictions[roundid][uint8(EOutcome.Up)].length(),
      _roundPredictions[roundid][uint8(EOutcome.Zero)].length()
    ];
  }

  /**
   * @notice Retrieves a paginated list of Round IDs for a specified game.
   *         This function is useful for fetching game round IDs in batches.
   * @dev This function returns an array of round IDs and the total number of rounds associated with the given game.
   *      The returned array contains at most 20 round IDs starting from the specified offset to support pagination.
   * @param gameid The unique identifier for the game.
   * @param offset The starting index from which round IDs will be fetched (for pagination).
   * @return roundids An array of up to 20 round IDs starting from the given offset.
   * @return size The total number of rounds in the game, which is helpful for paginating through all rounds.
   */
  function getGameRounds(
    bytes32 gameid,
    uint256 offset
  )
    external
    view
    returns (
      bytes32[] memory roundids,
      uint size
    )
  {

    roundids = new bytes32[](0);
    size = _gameRounds[gameid].length();

    if (size == 0) return (roundids, size);
    if (offset >= size) return (roundids, size);

    uint rest = size - offset;
    uint lastidx = 0;
    if (rest > 20) {
      lastidx = rest - 20;
    }
    uint resultSize = rest - lastidx;
    roundids = new bytes32[](resultSize);

    uint idx = 0;
    while (idx != resultSize) {
      roundids[idx] = _gameRounds[gameid].at(rest - 1 - idx);
      idx++;
    }

  }

  /**
   * @notice Retrieves a paginated list of predictions for a specific round and position.
   * @dev Returns up to 20 `Prediction` structs starting from the specified `offset`.
   *      If `position` is set to 0, predictions for all positions are retrieved.
   *      Also returns the total number of predictions matching the criteria.
   * @param roundid The unique identifier for the round to retrieve predictions from.
   * @param position The prediction position to filter by (1 for Down, 2 for Up, 3 for Zero). A value of 0 retrieves predictions for all positions.
   * @param offset The starting index for pagination. Use this to fetch predictions in batches.
   * @return predictions An array of `Prediction` structs representing the matching predictions.
   * @return size The total number of predictions available for the specified round and position.
   */
  function getRoundPredictions(
    bytes32 roundid,
    uint8 position,
    uint256 offset
  )
    external
    view
    returns (
      Prediction[] memory predictions,
      uint size
    )
  {

    predictions = new Prediction[](0);
    size = _roundPredictions[roundid][position].length();

    if (size == 0) return (predictions, size);
    if (offset >= size) return (predictions, size);

    uint rest = size - offset;
    uint lastidx = 0;
    if (rest > 20) {
      lastidx = rest - 20;
    }
    uint resultSize = rest - lastidx;
    predictions = new Prediction[](resultSize);

    uint idx = 0;
    while (idx != resultSize) {
      bytes32 predictionid = _roundPredictions[roundid][position].at(rest - 1 - idx);
      predictions[idx] = _predictions[predictionid];
      idx++;
    }

  }

  /**
   * @notice Retrieves a paginated list of a bettor's predictions for a specific position.
   * @dev Returns up to 20 `Prediction` structs starting from the specified `offset`.
   *      If `position` is set to 0, predictions for all positions are retrieved.
   *      Also returns the total number of predictions matching the criteria.
   * @param bettor The address of the bettor whose predictions are being queried.
   * @param position The predicted outcome (1 for Down, 2 for Up, 3 for Zero). A value of 0 retrieves predictions for all positions.
   * @param offset The starting index for pagination of the results.
   * @return predictions An array of `Prediction` structs limited to 20 entries.
   * @return size The total number of predictions for the bettor and specified position.
   */
  function getBettorPredictions(
    address bettor,
    uint8 position,
    uint256 offset
  )
    external
    view
    returns (
      Prediction[] memory predictions,
      uint size
    )
  {

    predictions = new Prediction[](0);
    size = _bettorPredictions[bettor][position].length();

    if (size == 0) return (predictions, size);
    if (offset >= size) return (predictions, size);

    uint rest = size - offset;
    uint lastidx = 0;
    if (rest > 20) {
      lastidx = rest - 20;
    }
    uint resultSize = rest - lastidx;
    predictions = new Prediction[](resultSize);

    uint idx = 0;
    while (idx != resultSize) {
      bytes32 predictionid = _bettorPredictions[bettor][position].at(rest - 1 - idx);
      predictions[idx] = _predictions[predictionid];
      idx++;
    }

  }

  /**
   * @notice Checks whether a specific bettor has participated in a given round.
   *         This function is used to verify if the bettor has placed a prediction in the provided round.
   * @dev This function checks participation in a specific prediction round using the bettor's address and the unique round ID.
   * @param bettor The address of the bettor to check for participation.
   * @param roundid The unique identifier of the round.
   * @return inround `true` if the bettor participated in the round, `false` otherwise.
   */
  function isBettorInRound(
    address bettor,
    bytes32 roundid
  )
    external
    view
    returns (
      bool inround
    )
  {

    inround = _roundBettors[roundid][ROUND_BETTORS_ID].contains(bettor);

  }

  /**
   * @notice Retrieves information about a specific bettor's activity for a given ERC20 token.
   * @dev This function provides detailed information about the bettor's predictions, including:
   *      - Bettor's address (`bettorid`) if found.
   *      - Total number of predictions and individual outcomes [Total, Up, Down, Zero] (`uint[4]`).
   *      - Total deposited amounts for predictions and individual outcomes [Total, Up, Down, Zero] (`uint[4]`).
   *      - Total payouts received for predictions and individual outcomes [Total, Up, Down, Zero] (`uint[4]`).
   *      - If `bettor` have never interacted with the provided `erc20` token for predictions deposits and payouts returns zeros.
   *      - If `bettor` have never interacted with the cotract it returns zeros.
   * @param bettor The address of the bettor to query.
   * @param erc20 The address of the ERC20 token used for the bettor's predictions.
   * @return bettorid The address of the bettor (or zero address if no predictions are found).
   * @return predictions Array of four `uint` values:
   *        [0]: Total number of predictions made.
   *        [1]: Number of predictions for Up.
   *        [2]: Number of predictions for Down.
   *        [3]: Number of predictions for Zero.
   * @return deposits Array of four `uint` values:
   *        [0]: Total amount deposited using the ERC20 token.
   *        [1]: Amount deposited for Up predictions.
   *        [2]: Amount deposited for Down predictions.
   *        [3]: Amount deposited for Zero predictions.
   * @return payouts Array of four `uint` values:
   *        [0]: Total payout amount received for the ERC20 token.
   *        [1]: Payout amount received for Up predictions.
   *        [2]: Payout amount received for Down predictions.
   *        [3]: Payout amount received for Zero predictions.
   */
  function getBettor(
    address bettor,
    address erc20
  )
    external
    view
    returns (
      address bettorid,
      uint[4] memory predictions,
      uint[4] memory deposits,
      uint[4] memory payouts
    )
  {

    uint size = _bettorPredictions[bettor][BETTOR_PREDICTIONS_ID].length();
    bettorid = size == 0 ? address(0) : bettor;
    predictions = [
      size,
      _bettorPredictions[bettor][uint8(EOutcome.Up)].length(),
      _bettorPredictions[bettor][uint8(EOutcome.Down)].length(),
      _bettorPredictions[bettor][uint8(EOutcome.Zero)].length()
    ];

    deposits = [
      _bettorFundsIN[bettor][erc20][BETTOR_TOTAL_DEPOSIT_ID],
      _bettorFundsIN[bettor][erc20][uint8(EOutcome.Up)],
      _bettorFundsIN[bettor][erc20][uint8(EOutcome.Down)],
      _bettorFundsIN[bettor][erc20][uint8(EOutcome.Zero)]
    ];

    payouts = [
      _bettorFundsOUT[bettor][erc20][BETTOR_TOTAL_PAIDOUT_ID],
      _bettorFundsOUT[bettor][erc20][uint8(EOutcome.Up)],
      _bettorFundsOUT[bettor][erc20][uint8(EOutcome.Down)],
      _bettorFundsOUT[bettor][erc20][uint8(EOutcome.Zero)]
    ];

  }

  /**
   * @notice Updates the bettor's prediction or creates a new one if it doesn't exist for the current game round.
   * @dev This function handles both creating new predictions and updating existing ones.
   *      It adjusts the bettor's token deposit for their prediction and ensures that internal mappings remain consistent.
   *      It also emits an event when a prediction is created or updated.
   *      Requirements:
   *      - The bettor's address must not be zero.
   *      - `amount` must be greater than zero.
   *      Emits:
   *      - `PredictionCreated` event if a new prediction is created.
   *      - `IncreasePredictionDeposit` event if the bettor's prediction is updated.
   * @param game The game structure associated with the prediction.
   * @param roundid The unique identifier of the round within the game.
   * @param position The predicted outcome for the round (1 for Down, 2 for Up, 3 for Zero).
   * @param amount The amount of tokens being deposited for the prediction.
   * @param bettor The address of the bettor making the prediction.
   */
  function _updatePrediction(
    Game memory game,
    bytes32 roundid,
    uint8 position,
    uint amount,
    address bettor
  )
    internal
  {

    bytes32 predictionid = keccak256(abi.encode(roundid, bettor, position));

    Prediction storage prediction = _predictions[predictionid];
    if (prediction.predictionid == 0x0) {
      prediction.predictionid = predictionid;
      prediction.roundid = roundid;
      prediction.gameid = game.gameid;
      prediction.bettor = bettor;
      prediction.position = position;
      prediction.createdAt = block.timestamp;
      prediction.erc20 = game.erc20;

      _roundPredictions[roundid][position].add(predictionid);
      _roundPredictions[roundid][ROUND_PREDICTIONS_ID].add(predictionid);

      _roundBettors[roundid][position].add(bettor);
      _roundBettors[roundid][ROUND_BETTORS_ID].add(bettor);

      _bettorPredictions[bettor][position].add(predictionid);
      _bettorPredictions[bettor][BETTOR_PREDICTIONS_ID].add(predictionid);

      emit PredictionCreated(
        predictionid,
        roundid,
        bettor,
        position,
        block.timestamp,
        game.erc20,
        game.gameid
      );
    }

    prediction.deposit = prediction.deposit + amount;

    _bettorFundsIN[bettor][game.erc20][BETTOR_TOTAL_DEPOSIT_ID] += amount;
    _bettorFundsIN[bettor][game.erc20][position] += amount;

    emit IncreasePredictionDeposit(predictionid, amount);
  }

  /**
   * @notice Updates a round's state by creating a new round if necessary and updating its prize pool.
   * @dev This function checks if the round already exists; if not, it initializes a new round.
   *      Then, based on the provided position and amount, it increments the respective prize pool.
   *      The position represents the bettor's predicted price movement direction (1 for Down, 2 for Up, 3 for Zero) within the round.
   *      The prize pool is updated accordingly based on the amount wagered for the specified position.
   *      Emits:
   *      - `RoundCreated` event upon successful creation of the round.
   *      - `RoundPrizepoolAdd` event to signal that the prize pool has been updated.
   * @param game The struct representing the game associated with the round.
   * @param roundid The unique identifier for the round to be updated.
   * @param position The prediction position chosen by the bettor (1 for Down, 2 for Up, 3 for Zero).
   * @param amount The amount of tokens being wagered on the position.
   */
  function _updateRound(
    Game memory game,
    bytes32 roundid,
    uint8 position,
    uint amount
  )
    internal
  {

    _createRound(game, roundid);
    _updatePrizepool(roundid, position, amount, game.erc20);

  }

  /**
   * @dev Creates a new prediction round within the specified game.
   *      This function initializes the parameters for a new round, fetches the entry price from the provided price feed, and validates the fetched price to ensure it meets the required timing constraints.
   *      Requirements:
   *      - The game must exist, be valid, and active.
   *      - The provided `roundid` must not have been used previously.
   *      - The fetched entry price must be valid and timestamped within the acceptable range defined by the game configuration.
   *      Emits a `RoundCreated` event upon successful creation of the round.
   * @param game The configuration parameters for the game.
   * @param roundid The unique identifier for the new prediction round.
   */
  function _createRound(
    Game memory game,
    bytes32 roundid
  )
    private
  {
    bytes32 gameid = game.gameid;
    address erc20 = game.erc20;

    Round storage round = _rounds[roundid];
    if (round.roundid == 0x0) {
      _gameRounds[game.gameid].add(roundid);

      uint sincestart = block.timestamp % game.schedule;
      uint startDate = block.timestamp - sincestart;

      address pricefeed = game.pricefeed;

      Price memory entryPrice = _getPriceLatest(pricefeed);

      if (!_isValidPrice(entryPrice)) {
        revert("RoundEntryPriceInInvalid");
      }

      if (entryPrice.timestamp < startDate) {
        revert("RoundEntryPriceTimestampTooEarly");
      }

      uint lockDate = startDate + game.positioning;
      if (entryPrice.timestamp >= lockDate) {
        revert("RoundEntryPriceTimestampTooLate");
      }

      uint endDate = startDate + game.schedule;
      uint expirationDate = endDate + game.expiration;

      round.roundid = roundid;
      round.gameid = gameid;
      round.entryPrice = entryPrice;
      round.startDate = startDate;
      round.lockDate = lockDate;
      round.endDate = endDate;
      round.expirationDate = expirationDate;
      round.openedAt = block.timestamp;
      round.erc20 = erc20;
      round.pricefeed = pricefeed;

      emit RoundCreated(
        roundid,
        gameid,
        _msgSender(),
        erc20,
        pricefeed,
        entryPrice,
        startDate,
        lockDate,
        endDate,
        expirationDate,
        block.timestamp
      );

    }

  }

  /**
   * @notice Checks whether a specific prediction round has been resolved.
   * @dev This function checks the status of a round using its unique ID.
   *      It is marked as `internal`, so it can only be accessed within this contract or derived contracts.
   *      The status of resolution implies that the round's outcome have been settled.
   * @param roundid The unique identifier (ID) of the round to check.
   * @return resolved Returns `true` if the round is resolved, meaning outcome have been settled, otherwise returns `false`.
   */
  function _isResolved(
    bytes32 roundid
  )
    internal
    view
    returns (
      bool resolved
    )
  {

    resolved = _rounds[roundid].resolved;

  }

  /**
   * @notice Resolves an round by determining the final outcome based on the provided exit price.
   * @dev This function calculates the outcome of a prediction round using the given `exitPriceid`, which must be fetched from an external oracle.
   *      Possible outcomes:
   *      - Down: The outcome is resolved as "Down" if the `Exit Price` is lower than the `Entry Price`. This indicates a price decrease during the round.
   *      - Up: The outcome is resolved as "Up" if the `Exit Price` is higher than the `Entry Price`, indicating a price increase during the round.
   *      - Zero: The outcome is resolved as "Zero" if the `Exit Price` is equal to the `Entry Price`
   *      - No Contest: All participants predicted the same outcome (either all Up, all Down, or all Zero), making it impossible to determine winners.
   *      - No Contest: None of the participants correctly predicted the outcome.
   *      - No Contest: The round was not resolved within the allowed time limit.
   *      This function permanently finalizes the state of the round and should only be called when the round is in settlement phase and unresolved.
   *      Requirements:
   *      - The round must be unresolved state.
   *      - The `exitPriceid` must be valid and `Exit Price` from the oracle.
   *      Emits:
   *      - `RoundResolvedNoContest`: If the round concludes with a "No Contest" outcome.
   *      - `RoundResolved`: If the round ends with a valid outcome: Down, Up, or Zero.
   * @param roundid The unique identifier of the round being resolved.
   * @param exitPriceid The ID representing the price used to determine the final outcome of the round.
   */
  function _resolve(
    bytes32 roundid,
    uint80 exitPriceid
  )
    internal
  {

    Round storage round = _rounds[roundid];
    if (round.resolved) {
      revert("CannotResolveResolvedRound");
    }

    if (round.openedAt == 0) {
      revert("CannotResolveUnopenedRound");
    }

    round.resolved = true;
    round.resolvedAt = block.timestamp;

    if (_isNoContestSingleOutcome(roundid)) {
      if (block.timestamp <= round.lockDate) {
        revert("CannotResolveRoundDuringPositioning");
      }

      round.resolution = uint8(EOutcome.NoContest);

      emit RoundResolvedNoContest(
        roundid,
        _msgSender(),
        block.timestamp,
        uint8(EOutcome.NoContest)
      );

      return;
    }

    if (block.timestamp <= round.endDate) {
      revert("CannotResolveRoundBeforeEndDate");
    }

    // Resolve to NoContest if round settlement period expired
    if (block.timestamp > round.expirationDate) {

      round.resolution = uint8(EOutcome.NoContest);

      emit RoundResolvedNoContest(
        roundid,
        _msgSender(),
        block.timestamp,
        uint8(EOutcome.NoContest)
      );

      return;
    }

    if (__FATAL_INSUFFICIENT_PRIZEPOOL_ERROR__[round.erc20]) {

      round.resolution = uint8(EOutcome.NoContest);

      emit RoundResolvedNoContest(
        roundid,
        _msgSender(),
        block.timestamp,
        uint8(EOutcome.NoContest)
      );

      return;
    }

    Game memory game = MetaOraclyV1(METAORACLY_CONTRACT).getGame(round.gameid);
    if (game.blocked) {

      round.resolution = uint8(EOutcome.NoContest);

      emit RoundResolvedNoContest(
        roundid,
        _msgSender(),
        block.timestamp,
        uint8(EOutcome.NoContest)
      );

      return;
    }

    if (exitPriceid == 0) {
      revert("CannotResolveRoundWithoutPrice");
    }

    Price memory exitPrice = _getPrice(round.pricefeed, exitPriceid);
    Price memory controlPrice = _getPrice(round.pricefeed, exitPriceid + 1);

    if (!_isValidResolution(
      round,
      exitPrice,
      controlPrice
    )) {
      revert("InvalidRoundResolution");
    }

    round.exitPrice = exitPrice;
    round.resolution = _calculateRoundResolution(roundid, round.entryPrice, exitPrice);

    emit RoundResolved(
      roundid,
      exitPrice,
      _msgSender(),
      block.timestamp,
      round.resolution
    );

  }

  /**
   * @notice Determines whether the given prediction round is a "No Contest" round.
   * @dev A round is considered a "No Contest" if all participants placed their predictions on the same outcome (Down, Up, or Zero), meaning no competition occurred.
   *      This function is useful for skipping payout or settlement logic when no competitive predictions are present.
   * @param roundid The unique identifier of the prediction round to check.
   * @return True if the round is a no contest or empty, false otherwise.
   */
  function _isNoContestSingleOutcome(bytes32 roundid)
    private
    view
    returns (
      bool
    )
  {
    uint prizepoolUp = _prizepool[roundid][uint8(EOutcome.Up)];
    uint prizepoolDown = _prizepool[roundid][uint8(EOutcome.Down)];
    uint prizepoolZero = _prizepool[roundid][uint8(EOutcome.Zero)];
    uint prizepoolTotal = _prizepool[roundid][PRIZEPOOL_TOTAL_ID];

    return (
      prizepoolUp == prizepoolTotal ||
      prizepoolDown == prizepoolTotal ||
      prizepoolZero == prizepoolTotal
    );
  }

  /**
   * @dev Retrieves price data for a specific round from a Chainlink price feed.
   *      Fetches price data for the specified round from the provided Chainlink price feed.
   *      Validates the returned data to ensure it corresponds to the requested round.
   *      Returns a `Price` struct containing the round ID, price value, and timestamp.
   *      Handles potential errors by returning a default `Price` struct with zero values.
   * @param pricefeed The address of the Chainlink price feed contract.
   * @param _roundid The ID of the desired price round.
   * @return price A `Price` struct containing the retrieved price data.
   */
  function _getPrice(
    address pricefeed,
    uint80 _roundid
  )
    private
    view
    returns (
      Price memory price
    )
  {

    try
      AggregatorV3Interface(pricefeed).getRoundData(_roundid)
      returns (
        uint80 roundid,
        int256 answer,
        uint256 /* startedAt */,
        uint256 updatedAt,
        uint80 answeredInRound
      )
    {
      if (
        roundid == _roundid &&
        roundid == answeredInRound
      ) {

        return Price({
          roundid: roundid,
          value: answer,
          timestamp: updatedAt
        });

      }

      return Price({
        roundid: 0,
        value: 0,
        timestamp: 0
      });

    } catch {

      return Price({
        roundid: 0,
        value: 0,
        timestamp: 0
      });

    }

  }

  /**
   * @notice Retrieves the latest price data from a specified Chainlink price feed.
   * @dev This function interacts with the Chainlink price feed contract to fetch the latest round data, including the round ID, price value, and timestamp.
   *      It returns a `Price` struct containing these values. If the round data is invalid, the function will return a `Price` struct with zero values.
   *      Make sure the specified price feed contract is a valid Chainlink price feed address to prevent unexpected results.
   * @param pricefeed The address of the Chainlink price feed contract.
   * @return price A `Price` struct containing the latest round ID, price value, and the timestamp of the price update.
   *               If the round is invalid, it returns a struct with zero values.
   */
  function _getPriceLatest(
    address pricefeed
  )
    private
    view
    returns (
      Price memory price
    )
  {

    (
      uint80 roundid,
      int256 answer,
      /* uint256 startedAt */,
      uint256 updatedAt,
      uint80 answeredInRound
    ) = AggregatorV3Interface(pricefeed).latestRoundData();

    if (roundid == answeredInRound) {

      return Price({
        roundid: roundid,
        value: answer,
        timestamp: updatedAt
      });

    }

    return Price({
      roundid: 0,
      value: 0,
      timestamp: 0
    });

  }

  /**
   * @notice Validates the prices provided for a round resolution to ensure correctness.
   *         Ensures that the exit price is valid, fits within the round's timeline, and meets the required phase and timing conditions.
   * @dev This function performs the following checks:
   *      - Ensures the exit price falls within the round's active period and is later than the entry price.
   *      - Ensures the control price is after the round's end date and comes from the same phase as the exit price.
   *      - Validates consistency in timestamps and phases between the provided prices.
   *      - Checks that the control price's phase and exit price's phase are aligned.
   * @param round The data of the round being validated.
   * @param exitPrice The price used for resolving the outcome of the round.
   * @param controlPrice The control price, used for comparison after the round's end.
   * @return valid `true` if all validations pass, `false` otherwise.
   */
  function _isValidResolution(
    Round memory round,
    Price memory exitPrice,
    Price memory controlPrice
  )
    private
    pure
    returns (
      bool valid
    )
  {
    // Ensure all prices are valid
    if (!_isValidPrice(exitPrice)) return false;
    if (!_isValidPrice(controlPrice)) return false;
    if (!_isValidPrice(round.entryPrice)) return false;

    // Avoid resolution if price difference is too hight
    if (!_isValidPriceDifference(exitPrice.value, controlPrice.value)) return false;
    if (!_isValidPriceDifference(exitPrice.value, round.entryPrice.value)) return false;

    // Ensure exit price is within the round's active period
    if (exitPrice.timestamp < round.lockDate) return false;
    if (exitPrice.timestamp >= round.endDate) return false;

    // Ensure control price is after the round's end date
    if (controlPrice.timestamp < round.endDate) return false;

    // The exit price must be newer than the round's entry price
    if (exitPrice.timestamp <= round.entryPrice.timestamp) return false;

    (uint16 opPhaseId, uint64 opAggrRoundId) = _parseRoundid(round.entryPrice.roundid);
    (uint16 rpPhaseId, uint64 rpAggrRoundId) = _parseRoundid(exitPrice.roundid);
    (uint16 cpPhaseId, uint64 cpAggrRoundId) = _parseRoundid(controlPrice.roundid);

    // Verify that all prices are from the same phase
    if (opPhaseId != rpPhaseId) return false;
    if (opPhaseId != cpPhaseId) return false;

    // Verify that entry price's round is earlier than exit price's round
    if (opAggrRoundId >= rpAggrRoundId) return false;

    // Ensure resolution and control price points are consecutive
    if ((rpAggrRoundId + 1) != cpAggrRoundId) return false;

    return true;

  }

  /**
   * @notice Validates the given Price struct to ensure its fields hold valid values.
   * @dev This function checks if the Price struct is properly populated with valid values.
   *      It verifies the following conditions:
   *      - The `timestamp` must not be the maximum or minimum value of `uint256`.
   *      - The `roundId` must not be the maximum or minimum value of `uint80`.
   *      - The `value` must be a positive number and must not be the maximum or minimum value of `int256`.
   * @param price The Price struct to validate, containing timestamp, roundId, and value fields.
   * @return valid Returns `true` if the `Price` struct contains valid values, otherwise `false`.
   */
  function _isValidPrice(Price memory price)
    private
    pure
    returns (
      bool valid
    )
  {

    return (
      price.timestamp != type(uint256).max &&
      price.timestamp != type(uint256).min &&

      price.roundid != type(uint80).max &&
      price.roundid != type(uint80).min &&

      price.value != type(int256).max &&
      price.value != type(int256).min &&

      price.value > 0
    );

  }

  /**
   * @notice Checks whether the absolute percentage difference between two positive integers is less than 100%.
   *         This is done by comparing the ratio of the larger number to the smaller one.
   *         If the ratio is exactly 1, the function returns `true`, indicating that the difference is within 100%.
   *         Returns `false` if the inputs are non-positive or the ratio exceeds 1.
   * @dev Assumes that the numbers are positive and non-zero.
   *      It calculates the ratio of the larger number to the smaller number.
   *      A ratio of 1 means there is an acceptable difference and the function returns `true`.
   *      Returns `false` if either number is non-positive.
   * @param x The first positive integer.
   * @param y The second positive integer.
   * @return True if the absolute percentage difference is less than or equal to 100%, false otherwise.
   */
  function _isValidPriceDifference(int256 x, int256 y)
    private
    pure
    returns (
      bool
    )
  {

    if (x <= 0 || y <= 0) return false;

    int256 ratio = y > x ? y / x : x / y;

    // less than 100% difference
    return (ratio == 1);

  }

  /**
   * @notice Parses a composite round ID into its constituent parts: phase ID and aggregator round ID.
   * @dev The round ID is a 80-bit composite value, where the upper 16 bits represent the phase ID,
   *      and the lower 64 bits represent the aggregator round ID. This function isolates and extracts
   *      both components from the given composite round ID.
   * @param roundId The 80-bit composite round ID to be parsed.
   * @return phaseId The 16-bit phase ID (upper 16 bits of roundId).
   * @return aggregatorRoundId The 64-bit aggregator round ID (lower 64 bits of roundId).
   */
  function _parseRoundid(
    uint80 roundId
  )
    private
    pure
    returns (
      uint16 phaseId,
      uint64 aggregatorRoundId
    )
  {
    phaseId = uint16(roundId >> PRICE_FEED_PHASE_BIT_OFFSET);
    aggregatorRoundId = uint64(roundId);
  }

  /**
   * @notice Computes a unique round ID by combining a phase ID with an aggregator round ID.
   *         This ensures that the round ID is unique across different phases of the price feed aggregator.
   * @dev The round ID is computed by shifting the 16-bit `phaseId` left by 64 bits and then adding the 64-bit `aggregatorRoundId`.
   *      This results in a single 80-bit value representing the unique round ID.
   *      The left shift ensures that the `phaseId` occupies the higher bits and does not overlap with the `aggregatorRoundId`.
   * @param phaseId The 16-bit ID representing the phase of the price feed aggregator. Each phase consists of multiple rounds.
   * @param aggregatorRoundId The 64-bit round ID provided by the underlying price feed aggregator for a specific phase.
   * @return roundId A unique 80-bit round ID that is a combination of the phase and aggregator round IDs.
   */
  function _computeRoundid(
    uint16 phaseId,
    uint64 aggregatorRoundId
  )
    internal
    pure
    returns (
      uint80 roundId
    )
  {
    roundId = uint80((uint256(phaseId) << PRICE_FEED_PHASE_BIT_OFFSET) | aggregatorRoundId);
  }

  /**
   * @notice Determines the outcome of a prediction round by comparing the entry and exit price values.
   * @dev This function calculates the outcome by comparing the exit price (`exitPrice`) to the entry price (`entryPrice`).
   *      It returns a `uint8` value corresponding to the round's outcome, which can be one of the following:
   *        - 1 for Down: If the exit price is lower than the entry price.
   *        - 2 for Up: If the exit price is higher than the entry price.
   *        - 3 for Zero: If the exit price equals the entry price.
   *        - 4 for No Contest: If the round ends without a clear winner or if settlement conditions fail, allowing participants to reclaim their funds.
   * @param roundid The unique identifier of the round being resolved.
   * @param entryPrice The price at the start of the round used as the reference.
   * @param exitPrice The price at the end of the round, compared to `entryPrice` to decide the outcome.
   * @return outcome The result of the round, as a `uint8` value (Refer to the `EOutcome` enum for possible values).
   */
  function _calculateRoundResolution(
    bytes32 roundid,
    Price memory entryPrice,
    Price memory exitPrice
  )
    private
    view
    returns (
      uint8 outcome
    )
  {

    outcome = uint8(EOutcome.Undefined);

    if (exitPrice.value > entryPrice.value) {

      outcome = uint8(EOutcome.Up);

    } else if (exitPrice.value < entryPrice.value) {

      outcome = uint8(EOutcome.Down);

    } else if (exitPrice.value == entryPrice.value) {

      outcome = uint8(EOutcome.Zero);

    }

    if (outcome == uint8(EOutcome.Undefined)) {

      outcome = uint8(EOutcome.NoContest);

    } else if (_isNoContestRound(roundid, outcome)) {

      outcome = uint8(EOutcome.NoContest);

    }

  }

  /**
   * @notice Determines if a round is considered a "No Contest" round.
   *         A round is considered a no contest if either:
   *         - No predictions were placed on the winning outcome (prize pool for winning position is 0).
   *         - All predictions were placed on the winning outcome (prize pool for winning position equals the total prize pool).
   *         "No Contest" logic ensures proper handling of edge cases in the prediction game.
   * @dev This function is called internally to assess if a specific round qualifies as a no contest.
   * @param roundid The unique identifier for the round.
   * @param winning The `uint8` representation of the winning outcome (1 for Down, 2 for Up, 3 for Zero).
   * @return True if the round is a no contest, false otherwise.
   */
  function _isNoContestRound(bytes32 roundid, uint8 winning)
    private
    view
    returns (
      bool
    )
  {
    uint prizepoolWin = _prizepool[roundid][winning];
    uint prizepoolTotal = _prizepool[roundid][PRIZEPOOL_TOTAL_ID];

    return prizepoolWin == 0 || prizepoolWin == prizepoolTotal;
  }

  /**
   * @notice Updates the prize pool for a specific round and prediction position.
   *         This function increments the prize pool for a selected position (Down, Up, Zero) in a specific round.
   *         The total prize pool for the round is also updated to reflect the new amount.
   * @dev This function updates both the prize pool for the given position in the specified round and the total prize pool for the entire round.
   *      Emits a `RoundPrizepoolAdd` event to signal that the prize pool has been updated.
   * @param roundid The unique identifier for the round. Each round has a unique ID for tracking prize pools and positions relations.
   * @param position The prediction position in the round: (1 for Down, 2 for Up, 3 for Zero)
   * @param amount The amount of tokens being added to the prize pool for the specified position.
   */
  function _updatePrizepool(
    bytes32 roundid,
    uint8 position,
    uint amount,
    address erc20
  )
    private
  {

    _prizepool[roundid][position] = _prizepool[roundid][position] + amount;
    _prizepool[roundid][PRIZEPOOL_TOTAL_ID] = _prizepool[roundid][PRIZEPOOL_TOTAL_ID] + amount;

    emit RoundPrizepoolAdd(
      roundid,
      erc20,
      position,
      amount
    );

  }

  /**
   * @notice Calculates the payout and commission for a specific prediction based on the outcome of the round.
   * @dev This function determines the payout and commission for a prediction based on whether:
   *      - The prediction was correct.
   *      - The prediction has already been claimed.
   *      The function also handles potential rounding errors for the last prediction in a round.
   * @param prediction The prediction made by the bettor, containing the prediction details.
   * @param round The round details, including the outcome and other round-specific data.
   * @return payout The calculated payout for the prediction based on its correctness and the round's result.
   * @return commission The commission deducted from the payout, if applicable.
   */
  function _calculatePayout(
    Prediction memory prediction,
    Round memory round
  )
    private
    view
    returns (
      uint payout,
      uint commission
    )
  {

    payout = 0;
    commission = 0;

    if (prediction.claimed || !round.resolved) return ( payout, commission );

    bool nocontest = round.resolution == uint8(EOutcome.NoContest);
    if (nocontest) {
      payout = prediction.deposit;
      return ( payout, commission );
    }

    bool win = round.resolution == prediction.position;
    if (win) {

      (payout, commission) = _calculatePrize(
        prediction.deposit,
        _prizepool[prediction.roundid][prediction.position],
        _prizepool[prediction.roundid][PRIZEPOOL_TOTAL_ID]
      );

      // Handle potential rounding error
      uint unclaimed = (
        _roundPredictions[prediction.roundid][prediction.position].length()
      -
        _claimedPredictions[prediction.roundid][prediction.position].length()
      );

      if (unclaimed == 1) {

        uint prizepool = (
          _prizepool[prediction.roundid][PRIZEPOOL_TOTAL_ID]
        -
          _prizepool[prediction.roundid][PRIZEPOOL_RELEASED_ID]
        );

        if (prizepool > (payout + commission)) {
          commission = prizepool - payout;
        }

      }

    }

  }

  /**
   * @notice Calculates the prize payout and commission for a given deposit based on the position and total pools.
   * @dev The prize is proportional to the deposit relative to the position pool.
   *      Commission is calculated as a percentage (VIGORISH_PERCENT) of the prize.
   *      The payout is the prize minus the commission.
   * @param deposit The amount of the bettor's deposit in the current round.
   * @param positionpool The total amount deposited by all bettors who chose the same position.
   * @param totalpool The total amount deposited by all bettors in the round.
   * @return payout The net amount after deducting the commission from the prize.
   * @return commission The commission amount based on the VIGORISH_PERCENT.
   */
  function _calculatePrize(
    uint deposit,
    uint positionpool,
    uint totalpool
  )
    private
    pure
    returns (
      uint payout,
      uint commission
    )
  {

    uint prize = (totalpool * deposit) / positionpool;

    commission = Math.ceilDiv(prize * VIGORISH_PERCENT, 100);
    payout = prize - commission;

  }

  /**
   * @notice Claims the payout for a bettor's prediction in a specific round with a given ERC20 token.
   * @dev This function ensures that all necessary checks are performed before allowing a claim:
   *      - Verifies that claimd ERC20 matches round ERC20 address.
   *      - Ensures the provided prediction ID related the round ID.
   *      - Checks that the prediction is associated with the round.
   *      - Confirms the caller is the original bettor who made the prediction.
   *      - Ensures the prediction hasn't already been claimed.
   *      - Validates that the round has been resolved.
   *      - Confirms that the prediction's position matches the final resolution of the round or handles a "No Contest" scenario.
   *      If all validations pass, the function calculates the payout and the commission, updates the prediction's status to claimed, and returns both the payout and commission values.
   *      Emits:
   *      - `PredictionClaimed` event emitted when a bettor claims the payout for prediction.
   *      - `RoundPrizepoolReleased` event on a successful prize pool release.
   *      - `RoundArchived` event once the round is archived.
   * @param roundid The unique identifier of the round to which the prediction belongs.
   * @param predictionid The unique identifier of the prediction for which the payout is claimed.
   * @param erc20 The address of the ERC20 token in which the payout is requested.
   * @return payout The amount awarded to the bettor based on the prediction.
   * @return commission The commission deducted from the payout for stakers and mentors.
   */
  function _claimPrediction(
    bytes32 roundid,
    bytes32 predictionid,
    address erc20
  )
    internal
    returns (
      uint payout,
      uint commission
    )
  {

    if (erc20 == address(0)) {
      revert("ERC20AddressZero");
    }

    Prediction memory prediction = _predictions[predictionid];
    if (prediction.roundid != roundid) {
      revert("PredictionRoundMismatch");
    }

    Round memory round = _rounds[roundid];
    if (round.erc20 != erc20) {
      revert("ERC20PredictionRoundMismatch");
    }

    if (!_roundPredictions[round.roundid][ROUND_PREDICTIONS_ID].contains(predictionid)) {
      revert("CannotClaimNonRoundPrediction");
    }

    address bettor = _msgSender();
    if (prediction.bettor != bettor) {
      revert("BettorPredictionMismatch");
    }

    if (prediction.claimed) {
      revert("CannotClaimClaimedPrediction");
    }

    if (_claimedPredictions[round.roundid][ROUND_CLAIMED_PREDICTIONS_ID].contains(prediction.predictionid)) {
      revert("CannotClaimClaimedPrediction");
    }

    if (!round.resolved) {
      revert("CannotClaimPredictionUnresolvedRound");
    }

    if (
      round.resolution != uint8(EOutcome.NoContest) &&
      round.resolution != prediction.position
    ) {
      revert("CannotClaimLostPrediction");
    }

    (payout, commission) = _calculatePayout(prediction, round);

    _updateClaimPrediction(predictionid, payout, commission);
    _releasePrizepool(roundid, payout, commission);

    _archiveRound(round);

  }

  /**
   * @dev Archives a prediction round if no further actions can be taken on it.
   *      This function checks whether the round has been resolved and if it has not yet been archived.
   *      It ensures that the round's outcome is one of the valid results (`NoContest`, `Down`, `Up`, `Zero`), and verifies that no unclaimed predictions remain.
   *      Once these conditions are met, the round is archived, marking the conclusion of the round's lifecycle.
   *      This is a private function that called as part of the round's lifecycle management.
   *      Emits a `RoundArchived` event once the round is archived.
   * @notice The round must be fully resolved, and no unclaimed predictions should remain for it to be archived.
   * @param round The `Round` struct representing the details of the prediction round being archived.
   */
  function _archiveRound(
    Round memory round
  )
    private
  {

    if (!round.resolved) return;
    if (round.archived) return;

    uint8 resolution = round.resolution;
    if (resolution == uint8(EOutcome.Undefined)) return;

    bool archived = false;
    if (resolution == uint8(EOutcome.NoContest)) {

      archived = (
        _roundPredictions[round.roundid][ROUND_PREDICTIONS_ID].length()
      ==
        _claimedPredictions[round.roundid][ROUND_CLAIMED_PREDICTIONS_ID].length()
      );

    }

    if (
      resolution == uint8(EOutcome.Down) ||
      resolution == uint8(EOutcome.Up) ||
      resolution == uint8(EOutcome.Zero)
    ) {

      archived = (
        _roundPredictions[round.roundid][resolution].length()
      ==
        _claimedPredictions[round.roundid][resolution].length()
      );

    }

    if (archived) {

      _rounds[round.roundid].archived = archived;
      _rounds[round.roundid].archivedAt = block.timestamp;

      emit RoundArchived(
        round.roundid,
        block.timestamp
      );

    }

  }

  /**
   * @notice Updates a prediction record with the payout, commission, and claimed status.
   *         This function processes a prediction's claim by assigning the payout, setting the commission, and marking the prediction as claimed.
   *         It also handles the updates for relevant tracking maps such as bettor statistics, round stats, and position-based tracking.
   * @dev This function modifies the internal state of the contract, specifically:
   *      Sets the `payout` and `commission` for a specific prediction.
   *      Marks the prediction as claimed.
   *      Updates round, position, and bettor maps for accurate tracking of statistics.
   *      Event `PredictionClaimed` emitted when a bettor claims the payout for prediction.
   * @param predictionid The unique identifier of the prediction being updated.
   * @param payout The calculated payout amount that will be distributed to the bettor.
   * @param commission The calculated commission amount deducted from the payout.
   */
  function _updateClaimPrediction(
    bytes32 predictionid,
    uint payout,
    uint commission
  )
    private
  {

    Prediction storage prediction = _predictions[predictionid];

    if (payout != 0) prediction.payout = payout;
    if (commission != 0) prediction.commission = commission;
    prediction.claimed = true;

    _claimedPredictions[prediction.roundid][ROUND_CLAIMED_PREDICTIONS_ID].add(predictionid);
    _claimedPredictions[prediction.roundid][prediction.position].add(predictionid);

    _bettorFundsOUT[prediction.bettor][prediction.erc20][BETTOR_TOTAL_PAIDOUT_ID] += payout;
    _bettorFundsOUT[prediction.bettor][prediction.erc20][prediction.position] += payout;

    emit PredictionClaimed(
      predictionid,
      prediction.bettor,
      prediction.erc20,
      payout,
      commission
    );
  }

  /**
   * @notice Releases the payout and commission from the prize pool for the specified round.
   *         Reverts if the total released amount exceeds the available prize pool.
   * @dev Releases the specified payout and commission amounts from the prize pool for a given round.
   *      Calculates the total amount to be released and updates the released portion of the prize pool.
   *      Reverts if the total released amount exceeds the total prize pool for the round.
   *      Emits a `RoundPrizepoolReleased` event on a successful prize pool release.
   * @param roundid The unique identifier of the round.
   * @param payout The payout amount to be released.
   * @param commission The commission amount to be released.
   */
  function _releasePrizepool(
    bytes32 roundid,
    uint payout,
    uint commission
  )
    private
  {

    uint prize = payout + commission;
    if (prize != 0) {
      _prizepool[roundid][PRIZEPOOL_RELEASED_ID] = _prizepool[roundid][PRIZEPOOL_RELEASED_ID] + prize;
    }

    if (_prizepool[roundid][PRIZEPOOL_RELEASED_ID] > _prizepool[roundid][PRIZEPOOL_TOTAL_ID]) {
      revert("InsufficientPrizepool");
    }

    emit RoundPrizepoolReleased(
      roundid,
      payout,
      commission
    );

  }

  /**
   * @notice Emitted when a round is resolved as a "No Contest", allowing participants to reclaim their funds.
   * @dev This event is triggered when the outcome of a round cannot be determined due to conditions that prevent a clear resolution.
   * @param roundid The unique identifier of the round that has been resolved as "No Contest".
   * @param resolvedBy The address of the EOA that initiated the resolution of the round.
   * @param resolvedAt The Unix timestamp at which the round was resolved.
   * @param resolution The constant value representing the "No Contest" outcome, a predefined value (4 for No Contest).
   */
  event RoundResolvedNoContest(
    bytes32 indexed roundid,
    address resolvedBy,
    uint resolvedAt,
    uint8 resolution
  );

  /**
   * @notice Emitted when a prediction round is resolved and its outcome is determined.
   * @dev This event logs important information about the resolution of a round, including the round ID, the exit price, the bettor who triggered the resolution, and the final outcome of the round.
   * @param roundid The unique identifier of the resolved prediction round.
   * @param exitPrice The price used to calculate the result of the round, fetched from Chainlink's price feed.
   * @param resolvedBy The address of the bettor that triggered the resolution of the round.
   * @param resolvedAt The timestamp (in seconds) when the round was resolved.
   * @param resolution The outcome of the round: (1 for Down, 2 for Up, 3 for Zero)
   */
  event RoundResolved(
    bytes32 indexed roundid,
    Price exitPrice,
    address resolvedBy,
    uint resolvedAt,
    uint8 resolution
  );

  /**
   * @dev Emitted when a round is archived.
   * @notice This event logs the archival of the round, marking the end of the round's lifecycle.
   * @param roundid The unique identifier of the archived round.
   * @param archivedAt The timestamp when the round was archived.
   */
  event RoundArchived(
    bytes32 indexed roundid,
    uint archivedAt
  );

  /**
   * @notice Emitted when a new prediction round is created.
   * @dev This event indicates the creation of a new prediction round within the ongoing game.
   *      It includes essential details such as the round ID, associated game, the ERC20 token for predictions, the price feed contract for asset price, and the timestamps defining round phases.
   * @param roundid The unique identifier of the created round.
   * @param gameid The unique identifier of the game to which the round is linked.
   * @param openedBy The address of the entity EOA that initiated the round creation.
   * @param erc20 The address of the ERC20 token contract used for placing predictions in the round.
   * @param pricefeed The address of the price feed contract used to retrieve the asset price for predictions.
   * @param entryPrice The initial price of the asset at the start of the round, retrieved from the price feed.
   * @param startDate The timestamp (in seconds since Unix epoch) when the round starts.
   * @param lockDate The timestamp when the prediction phase ends and no more entries can be placed.
   * @param endDate The timestamp when the round ends and the outcome of the price movement can be determined.
   * @param expirationDate The deadline timestamp by which the round must be settled, or else it defaults to 'No Contest'.
   * @param openedAt The timestamp when the round was created (when first prediction entered the round).
   */
  event RoundCreated(
    bytes32 indexed roundid,
    bytes32 gameid,
    address openedBy,
    address erc20,
    address pricefeed,
    Price entryPrice,
    uint startDate,
    uint lockDate,
    uint endDate,
    uint expirationDate,
    uint openedAt
  );

  /**
   * @notice Emitted when funds are added to a specific position's prize pool for a given round.
   *         This event tracks the addition of tokens to a prize pool, which is associated with a particular round and a specific position (Down, Up, Zero).
   * @dev The position can have three possible values: (1 for Down, 2 for Up, 3 for Zero)
   * @param roundid The ID of the round to which the prize pool is associated.
   * @param erc20 The address of the ERC20 token that is being added to the prize pool.
   * @param position The position (Down, Up, or Zero) in the prize pool where the tokens are added.
   * @param amount The amount of tokens being added to the prize pool for the given position.
   */
  event RoundPrizepoolAdd(
    bytes32 roundid,
    address erc20,
    uint8 position,
    uint amount
  );

  /**
   * @notice Emitted when funds are released to a bettor for a given round.
   *         This event tracks the release of tokens from the prize pool for a particular round, including the bettor's payout and any commission.
   * @dev The `payout` includes the bettor's share of the prize pool, which is calculated proportional to their contribution.
   *      The `commission` is a amount deducted from the prize, which is allocated to stakers and mentors.
   *      The event helps to audit the flow of funds for transparency and tracking of prize distribution.
   * @param roundid The ID of the round from which the funds are being released.
   * @param payout The total payout being released to the bettor, after deducting the commission.
   * @param commission The commission amount deducted from the prize, allocated to stakers and mentors.
   */
  event RoundPrizepoolReleased(
    bytes32 roundid,
    uint payout,
    uint commission
  );

  /**
   * @notice Emitted when a new prediction is created in the game.
   * @dev This event is triggered whenever a bettor makes a new prediction.
   *      It logs the details such as the round, bettor's address, and the prediction outcome.
   * @param predictionid The unique identifier of the created prediction.
   * @param roundid The ID of the round the prediction belongs to.
   * @param bettor The address of the bettor who created the prediction.
   * @param position The predicted outcome. (1 for Down, 2 for Up, 3 for Zero)
   * @param createdAt The timestamp (in seconds since the Unix epoch) when the prediction was created.
   * @param erc20 The address of the ERC20 token used as deposit for the prediction.
   * @param gameid The ID of the game instance that the prediction is associated with.
   */
  event PredictionCreated(
    bytes32 indexed predictionid,
    bytes32 roundid,
    address bettor,
    uint8 position,
    uint createdAt,
    address erc20,
    bytes32 gameid
  );

  /**
   * @notice Emitted when a bettor deposits tokens within the round.
   * @dev This event is emitted every time a bettor deposits tokens, either by creating a new prediction or increasing an existing one.
   * @param predictionid The unique identifier (ID) of the prediction being created or increased.
   * @param deposit The amount of tokens deposited.
   */
  event IncreasePredictionDeposit(
    bytes32 predictionid,
    uint deposit
  );

  /**
   * @notice Emitted when a bettor claims the payout for prediction.
   * @dev This event is triggered when a prediction is successfully claimed, detailing the bettor, payout, and commission.
   * @param predictionid The unique identifier of the claimed prediction.
   * @param bettor The address of the bettor who is claiming the prediction payout.
   * @param erc20 The ERC20 token used for both the payout and the commission.
   * @param payout The amount of tokens paid out to the bettor as a reward for the prediction.
   * @param commission The amount of tokens deducted from the payout as commission.
   */
  event PredictionClaimed(
    bytes32 predictionid,
    address bettor,
    address erc20,
    uint payout,
    uint commission
  );

}
