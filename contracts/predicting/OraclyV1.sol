// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Game } from "./structs/Game.sol";
import { EOutcome } from "./EOutcome.sol";
import { OraclyV1Core } from "./OraclyV1Core.sol";

import { ICommissionCollector } from "../interfaces/ICommissionCollector.sol";
import { IRewardCalculator } from "../interfaces/IRewardCalculator.sol";

import { MetaOraclyV1 } from "./MetaOraclyV1.sol";

/**
 * @title OraclyV1 Contract
 * @notice This contract implements the erc20 related functionality for the Oracly Protocol's decentralized prediction game.
 *         It allows bettors to participate in prediction rounds, manages the lifecycle of each round, integrates with Chainlink to obtain price data, and determines round outcomes based on price movements.
 *         The contract also handles bettor payouts, refunds, and manages reward distributions via external contracts.
 * @dev Contract for the Oracly Protocol's decentralized prediction game.
 *      Manages prediction rounds, integrates with Chainlink for price data, determines round outcomes, and handles bettor payouts and refunds.
 */
contract OraclyV1 is Context, ReentrancyGuard, OraclyV1Core {

  using SafeERC20 for IERC20;

  /**
   * @notice Address of the staking contract used for distributing staking rewards.
   * @dev This address should point to a valid smart contract.
   *      It is used to manage staking rewards in the Oracly protocol.
   *      The contract must implement the expected staking interface to ensure proper reward distribution.
   */
  address immutable public STAKING_CONTRACT;

  /**
   * @notice Address of the mentoring contract used for distributing mentor rewards.
   * @dev This address must be a smart contract. It handles the distribution of mentor rewards, and interacts with the core protocol to facilitate appropriate rewards based on mentoring actions.
   */
  address immutable public MENTORING_CONTRACT;

  /**
   * @notice Externally Owned Account (EOA) address used as a backup for reward distribution in case the main contracts encounter issues.
   * @dev This address must be an EOA (not a contract).
   *      It serves as a backup to handle reward distributions manually if either the staking or mentoring contract fails and is bypassed.
   */
  address immutable public DISTRIBUTOR_EOA;

  /**
   * @notice Constructor to initialize the reward distributors and related contracts.
   * @dev Validates the addresses for staking and mentoring contracts to ensure they are contracts and not EOAs.
   *      Also validates that the `distributorEOA_address` is an EOA and not a contract.
   * @param distributorEOA_address Address of the EOA used as a backup for reward distribution.
   * @param stakingContract_address Address of the staking contract for staking rewards.
   * @param mentoringContract_address Address of the mentoring contract for mentor rewards.
   * @param metaoraclyContract_address Address of the MetaOracly contract that handles oracle game data.
   */
  constructor(
    address distributorEOA_address,
    address stakingContract_address,
    address mentoringContract_address,
    address metaoraclyContract_address
  )
    OraclyV1Core(metaoraclyContract_address)
  {

    if (!(stakingContract_address.code.length > 0)) {
      revert("CannotUseEOAAsStakingRewardDistributorContract");
    }

    if (!(mentoringContract_address.code.length > 0)) {
      revert("CannotUseEOAAsMentoringRewardDistributorContract");
    }

    if (distributorEOA_address.code.length > 0) {
      revert("CannotUseContractAsEOADistributor");
    }

    STAKING_CONTRACT = stakingContract_address;
    MENTORING_CONTRACT = mentoringContract_address;
    DISTRIBUTOR_EOA = distributorEOA_address;

  }

  /**
   * @notice Resolves a prediction round by validating the Exit Price ID and determining the outcome.
   * @dev This function resolves a prediction round, ensuring that the provided priceid corresponds to a valid Exit Price from the price feed.
   *      - The function is protected against re-entrancy attacks via `nonReentrant` modifier.
   *      - It is restricted to off-chain callers EOA using the `onlyOffChainCallable` modifier.
   *      Emits:
   *      - `RoundResolvedNoContest`: If the round concludes with a "No Contest" outcome.
   *      - `RoundResolved`: If the round ends with a valid outcome: Down, Up, or Zero.
   * @param roundid The ID of the round that needs to be resolved.
   * @param exitPriceid The ID of the Exit Price that is used to determine the final outcome of the round.
   */
  function resolve(
    bytes32 roundid,
    uint80 exitPriceid
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    _resolve(roundid, exitPriceid);

  }

  /**
   * @notice Resolves a prediction round and processes the withdrawal of the payout.
   * @dev This function first resolves the specified round and prediction, based on the provided Exit Price.
   *      It then facilitates the withdrawal of the payout in the specified ERC20 token.
   *      - The function is protected against re-entrancy attacks via `nonReentrant` modifier.
   *      - It is restricted to off-chain callers EOA using the `onlyOffChainCallable` modifier.
   *      Emits:
   *      - `RoundResolvedNoContest`: If the round concludes with a "No Contest" outcome.
   *      - `RoundResolved`: If the round ends with a valid outcome: Down, Up, or Zero.
   *      - `FATAL_EVENT_INSUFFICIENT_PRIZEPOOL` if there are insufficient funds in the prize pool.
   *      - `PredictionClaimed` event emitted when a bettor claims the payout for prediction.
   *      - `RoundPrizepoolReleased` event on a successful prize pool release.
   *      - `RoundArchived` event once the round is archived.
   *      - `MentorsRewardDistributedViaContract` when mentor commission is successfully distributed via contract.
   *      - `MentorsRewardDistributedViaEOA` when mentor commission is distributed via EOA due to a fallback.
   *      - `StakersRewardDistributedViaContract` when staker commission is successfully distributed via contract.
   *      - `StakersRewardDistributedViaEOA` when staker commission is distributed via EOA due to a fallback.
   * @param roundid The ID of the prediction round to resolve.
   * @param predictionid The ID of the specific prediction within the round.
   * @param erc20 The address of the ERC20 token contract used for the withdrawal.
   * @param exitPriceid The ID of the price point (exit price) used to resolve the prediction.
   */
  function resolve4withdraw(
    bytes32 roundid,
    bytes32 predictionid,
    address erc20,
    uint80 exitPriceid
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    if (!_isResolved(roundid)) {
      _resolve(roundid, exitPriceid);
    }

    _withdraw(roundid, predictionid, erc20);

  }

  /**
   * @notice Claims a payout based on the result of a prediction in a specific round, using the specified ERC20 token for withdrawal.
   * @dev This function allows off-chain callers EOA to withdraw winnings from a prediction in a specific round, denominated in a given ERC20 token.
   *      - The function is protected against re-entrancy attacks via `nonReentrant` modifier.
   *      - It is restricted to off-chain callers EOA using the `onlyOffChainCallable` modifier.
   *      Emits:
   *      - `FATAL_EVENT_INSUFFICIENT_PRIZEPOOL` if there are insufficient funds in the prize pool.
   *      - `MentorsRewardDistributedViaContract` when mentor commission is successfully distributed via contract.
   *      - `MentorsRewardDistributedViaEOA` when mentor commission is distributed via EOA due to a fallback.
   *      - `StakersRewardDistributedViaContract` when staker commission is successfully distributed via contract.
   *      - `StakersRewardDistributedViaEOA` when staker commission is distributed via EOA due to a fallback.
   *      - `PredictionClaimed` event emitted when a bettor claims the payout for prediction.
   *      - `RoundPrizepoolReleased` event on a successful prize pool release.
   *      - `RoundArchived` event once the round is archived.
   * @param roundid The ID of the round in which the prediction was made.
   * @param predictionid The ID of the specific prediction to claim the payout for.
   * @param erc20 The address of the ERC20 token to be used for the payout withdrawal.
   */
  function withdraw(
    bytes32 roundid,
    bytes32 predictionid,
    address erc20
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    _withdraw(roundid, predictionid, erc20);

  }

  /**
   * @notice Withdraws funds based on a bettor's prediction result.
   * @dev This internal function handles the core logic for withdrawing funds from a prediction round.
   *      It calculates the payout and applicable commission based on the prediction's outcome, distributes funds accordingly, and updates the internal contract state.
   *      Emits:
   *      - `FATAL_EVENT_INSUFFICIENT_PRIZEPOOL` if there are insufficient funds in the prize pool.
   *      - `MentorsRewardDistributedViaContract` when mentor commission is successfully distributed via contract.
   *      - `MentorsRewardDistributedViaEOA` when mentor commission is distributed via EOA due to a fallback.
   *      - `StakersRewardDistributedViaContract` when staker commission is successfully distributed via contract.
   *      - `StakersRewardDistributedViaEOA` when staker commission is distributed via EOA due to a fallback.
   *      - `PredictionClaimed` event emitted when a bettor claims the payout for prediction.
   *      - `RoundPrizepoolReleased` event on a successful prize pool release.
   *      - `RoundArchived` event once the round is archived.
   * @param roundid The unique identifier for the prediction round.
   * @param predictionid The unique identifier for the bettor's prediction within the round.
   * @param erc20 The address of the ERC20 token contract used for the withdrawal.
   */
  function _withdraw(
    bytes32 roundid,
    bytes32 predictionid,
    address erc20
  )
    private
  {

    (uint payout, uint commission) = _claimPrediction(roundid, predictionid, erc20);

    _distributeERC20(
      erc20,
      payout,
      commission
    );

  }

  /**
   * @notice Distributes ERC20 tokens to the bettor and relevant reward contracts.
   * @dev This function handles the distribution of winnings (payout) to the bettor and commissions to mentors and stakers.
   *      It includes error handling and fallback mechanisms for unexpected issues during reward distribution.
   *      The distribution process includes:
   *      - Payout to the bettor.
   *      - Commissions to relevant parties (mentors, stakers).
   *      - Error handling for token transfer failures (with potential fallback to EOA).
   *      Requirements:
   *      - The contract must hold a sufficient balance of the specified ERC20 token.
   *      - Reward contracts must be properly configured and valid.
   *      Emits:
   *      - `FATAL_EVENT_INSUFFICIENT_PRIZEPOOL` if there are insufficient funds in the prize pool.
   *      - `MentorsRewardDistributedViaContract` when mentor commission is successfully distributed via contract.
   *      - `MentorsRewardDistributedViaEOA` when mentor commission is distributed via EOA due to a fallback.
   *      - `StakersRewardDistributedViaContract` when staker commission is successfully distributed via contract.
   *      - `StakersRewardDistributedViaEOA` when staker commission is distributed via EOA due to a fallback.
   * @param erc20 The address of the ERC20 token to distribute.
   * @param payout The amount to be paid to the bettor.
   * @param commission The total commission amount to be distributed among relevant parties.
   */
  function _distributeERC20(
    address erc20,
    uint payout,
    uint commission
  )
    private
  {

    address bettor = _msgSender();

    if (IERC20(erc20).balanceOf(address(this)) < (payout + commission)) {
      __FATAL_INSUFFICIENT_PRIZEPOOL_ERROR__[erc20] = true;
      emit FATAL_EVENT_INSUFFICIENT_PRIZEPOOL(
        bettor,
        erc20,
        IERC20(erc20).balanceOf(address(this)),
        payout,
        commission
      );
      return;
    }

    if (commission != 0) {

      uint stakersReward = commission;

      try
        IRewardCalculator(MENTORING_CONTRACT).calculateReward(
          bettor,
          commission
        )
        returns (
          uint metorsReward
        )
      {

        if (metorsReward != 0 && metorsReward <= commission) {

          stakersReward = commission - metorsReward;

          IERC20(erc20).approve(MENTORING_CONTRACT, metorsReward);
          try
            ICommissionCollector(MENTORING_CONTRACT).collectCommission(
              bettor,
              erc20,
              commission
            )
          {

            emit MentorsRewardDistributedViaContract(
              MENTORING_CONTRACT,
              bettor,
              erc20,
              metorsReward
            );

          } catch {

            IERC20(erc20).safeTransfer(DISTRIBUTOR_EOA, metorsReward);

            emit MentorsRewardDistributedViaEOA(
              DISTRIBUTOR_EOA,
              bettor,
              erc20,
              metorsReward
            );

          }

        }

      } catch { } // solhint-disable-line

      if (stakersReward != 0) {

        IERC20(erc20).approve(STAKING_CONTRACT, stakersReward);
        try
          ICommissionCollector(STAKING_CONTRACT).collectCommission(
            bettor,
            erc20,
            stakersReward
          )
        {

          emit StakersRewardDistributedViaContract(
            STAKING_CONTRACT,
            bettor,
            erc20,
            stakersReward
          );

        } catch {

          IERC20(erc20).safeTransfer(DISTRIBUTOR_EOA, stakersReward);

          emit StakersRewardDistributedViaEOA(
            DISTRIBUTOR_EOA,
            bettor,
            erc20,
            stakersReward
          );

        }

      }

    }

    if (payout != 0) {

      IERC20(erc20).safeTransfer(bettor, payout);

    }

  }

  /**
   * @notice Places a prediction on the specified game and round.
   * @dev This function allows off-chain callers EOA to place a prediction on a game round by depositing a certain amount of ERC20 tokens.
   *      The bettor predicts an outcome (Down, Up, or Zero) for the given game and round.
   *      Requirements:
   *      - The `amount` must be greater than zero.
   *      - The `position` must be one of the valid values (1 for Down, 2 for Up, 3 for Zero).
   *      - The function is protected against re-entrancy attacks via `nonReentrant` modifier.
   *      - It is restricted to off-chain callers EOA using the `onlyOffChainCallable` modifier.
   *      Emits:
   *      - `RoundCreated` event upon successful creation of the round.
   *      - `RoundPrizepoolAdd` event to signal that the prize pool has been updated.
   *      - `PredictionCreated` event if a new prediction is created.
   *      - `IncreasePredictionDeposit` event if the bettor's prediction is updated.
   * @param amount The amount of ERC20 tokens the bettor deposits to place the prediction.
   * @param position The predicted outcome for the game round. Valid values: (1 for Down, 2 for Up, 3 for Zero)
   * @param gameid The ID of the game where the prediction is being placed.
   * @param roundid The ID of the specific round within the game.
   */
  function placePrediction(
    uint amount,
    uint8 position,
    bytes32 gameid,
    bytes32 roundid
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    Game memory game = MetaOraclyV1(METAORACLY_CONTRACT).getGame(gameid);
    if (gameid == 0x0 || gameid != game.gameid) {
      revert("NotSupportedGame");
    }
    if (game.blocked) {
      revert("CannotPlacePredictionGameIsBlocked");
    }

    if (__FATAL_INSUFFICIENT_PRIZEPOOL_ERROR__[game.erc20]) {
      revert("CannotPlacePredictionERC20TokenIsBlocked");
    }

    if (
      position != uint8(EOutcome.Up) &&
      position != uint8(EOutcome.Down) &&
      position != uint8(EOutcome.Zero)
    ) {
      revert("NotSupportedPosition");
    }

    if (amount < game.minDeposit) {
      revert("UnacceptableDepositAmount");
    }

    address bettor = _msgSender();
    if (IERC20(game.erc20).balanceOf(bettor) < amount) {
      revert("InsufficientFunds");
    }
    if (IERC20(game.erc20).allowance(bettor, address(this)) < amount) {
      revert("InsufficientAllowance");
    }

    uint sinceStart = block.timestamp % game.schedule;
    uint startDate = block.timestamp - sinceStart;
    bytes32 actualroundid = keccak256(abi.encode(game.gameid, startDate));
    if (actualroundid != roundid) {
      revert("CannotPlacePredictionIntoUnactualRound");
    }

    if (sinceStart >= game.positioning) {
      revert("CannotPlacePredictionOutOfPositioningPeriod");
    }

    _updateRound(game, roundid, position, amount);
    _updatePrediction(game, roundid, position, amount, bettor);

    IERC20(game.erc20).safeTransferFrom(bettor, address(this), amount);

  }

  /**
   * @notice Restricts function execution to external accounts (EOA) only.
   * @dev This modifier ensures that only EOAs (Externally Owned Accounts) can call functions protected by this modifier, preventing contracts from executing such functions.
   *      The check is performed by verifying that the caller has no code associated with it (not a contract) and by comparing `tx.origin` with `_msgSender()`.
   */
  modifier onlyOffChainCallable() {
    address sender = _msgSender();
    if (sender.code.length > 0) {
      revert("OnlyEOASendersAllowed");
    }
    if (tx.origin != sender) {
      revert("OnlyEOASendersAllowed");
    }
    _;
  }

  /**
   * @notice Emitted when the contract's prize pool is insufficient to cover both a bettor's payout and the commission.
   *         This event signals a critical failure that effectively prevents the specified ERC20 token from being used as the deposit token for further predictions.
   * @dev This is a fatal event that indicates the current prize pool cannot satisfy the requested payout and commission amounts.
   * @param bettor The address of the bettor attempting to withdraw the funds.
   * @param erc20 The ERC20 token involved in the payout and commission transaction.
   * @param balance The current balance of the ERC20 token held in the contract.
   * @param payout The payout amount requested by the bettor.
   * @param commission The commission amount that is due to the contract.
  */
  event FATAL_EVENT_INSUFFICIENT_PRIZEPOOL(
    address bettor,
    address erc20,
    uint balance,
    uint payout,
    uint commission
  );

  /**
   * @notice This event is emitted when a mentor's reward is distributed via a smart contract.
   * @dev This event captures the distribution of rewards to mentors based on the bettor's activity.
   *      It logs the distributor (the smart contract handling the distribution), the bettor (the bettor whose activity triggered the reward), the ERC20 token used, and the reward amount.
   * @param distributor The address of the contract that is distributing the reward.
   * @param bettor The address of the bettor who generated the mentor's reward.
   * @param erc20 The address of the ERC20 token contract used for distributing the reward.
   * @param amount The amount of the reward in the ERC20 token.
   */
  event MentorsRewardDistributedViaContract(
    address distributor,
    address bettor,
    address erc20,
    uint amount
  );

  /**
   * @notice Emitted when a mentor's reward is distributed using an Externally Owned Account (EOA).
   *         This happens as a fallback mechanism when direct distribution through smart contracts is not possible.
   * @dev This event is triggered whenever the mentor's reward is sent via an EOA, in scenarios where automated reward distribution through the smart contract system fails and is bypassed.
   *      The mentor's reward is distributed using an ERC20 token.
   * @param distributor The address of the EOA responsible for distributing the reward to the mentor.
   * @param bettor The address of the bettor whose activity generated the reward for the mentor.
   * @param erc20 The address of the ERC20 token contract used to transfer the reward.
   * @param amount The amount of ERC20 tokens that are distributed as the reward.
   */
  event MentorsRewardDistributedViaEOA(
    address distributor,
    address bettor,
    address erc20,
    uint amount
  );

  /**
   * @notice Emitted when a staker's reward is distributed through a contract.
   * @dev This event logs the details of a reward distribution to stakers initiated by a contract.
   * @param distributor The address of the contract responsible for distributing the reward.
   * @param bettor The address of the bettor whose actions generated the reward for the stakers.
   * @param erc20 The ERC20 token used for the reward distribution.
   * @param amount The total amount of the ERC20 reward distributed.
   */
  event StakersRewardDistributedViaContract(
    address distributor,
    address bettor,
    address erc20,
    uint amount
  );

  /**
   * @notice Emitted when a staker's reward is distributed via an Externally Owned Account (EOA).
   *         This event acts as a fallback mechanism when the reward distribution does not go through
   *         the primary method, triggering the involvement of an EOA.
   * @dev This event provides a backup solution in cases where a direct reward transfer to the staking contract fails and is bypassed, allowing the reward to be manually handled by the EOA.
   * @param distributor The address of the EOA responsible for distributing the reward.
   * @param bettor The address of the bettor whose actions resulted in the reward.
   * @param erc20 The address of the ERC20 token used to pay out the reward.
   * @param amount The amount of tokens (in the ERC20 standard) distributed as the reward.
   */
  event StakersRewardDistributedViaEOA(
    address distributor,
    address bettor,
    address erc20,
    uint amount
  );

}

