// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Game } from "./structs/Game.sol";

/**
 * @title OraclyV1 Games Metadata Contract
 * @notice Serves as the main control point for creating and managing games within the Oracly Protocol.
 * @dev Provides the Oracly Team with the ability to block abused or manipulated games.
 *      Game Registry: Maintains a list of active games along with their parameters (schedule, price feed address).
 *      Game Creation: Allows authorized users (the Oracly Team) to create and configure new games.
 *      Game Blocking: Enables the Oracly Team to block specific games in case of suspected manipulation or technical issues.
 *      IMPORTANT: If a Game is blocked, any Rounds with Unverified Outcomes will automatically be treated as No Contest.
 */
contract MetaOraclyV1 is Ownable {

  using EnumerableSet for EnumerableSet.Bytes32Set;

  /**
   * @notice Defines the minimum duration a round can last.
   * @dev This constant represents the shortest possible round duration in the game, set to 1 minute.
   */
  uint constant internal SHORTEST_ROUND = 1 minutes;

  /**
   * @notice Defines the minimum time required for the positioning phase within a round.
   * @dev This constant ensures the positioning phase lasts for at least 30 seconds.
   */
  uint constant internal SHORTEST_POSITIONING = 30 seconds;

  /**
   * @notice Defines the minimum time before a round can expire after it ends.
   * @dev This constant enforces a minimum round expiration time of 1 hour.
   */
  uint constant internal SHORTEST_EXPIRATION = 1 hours;

  /**
   * @notice Defines the maximum time before a round can expire after it ends.
   * @dev This constant enforces a maximum expiration time of 7 days for any round.
   */
  uint constant internal LONGEST_EXPIRATION = 7 days;

  /**
   * @notice Tracks all games using a unique identifier.
   * @dev This mapping links each game (identified by a `bytes32` hash) to its corresponding `Game` struct.
   */
  mapping(bytes32 => Game) private _games;

  /**
   * @notice Tracks all active games associated with each ERC20 token address.
   * @dev This mapping links each ERC20 address to a set of active game identifiers (`bytes32`), allowing management of games related to different ERC20 token contracts.
   */
  mapping(address => EnumerableSet.Bytes32Set) private _activeGames;

  /**
   * @dev Initializes the contract by setting the deployer as the initial owner (Oracly Team).
   * @notice The deployer of this contract will automatically be assigned as the contract owner (Oracly Team), who has the privilege to manage game creation, blocking and unblocking the game.
   */
  constructor()
    Ownable(_msgSender())
  { }

  /**
   * @notice Adds a new game to the Oracly Protocol, linking it to a Chainlink price feed and an ERC20 token for deposits and payouts.
   *         Can only be called by the contract owner (Oracly Team).
   * @dev This function registers a new game configuration with specified parameters, including the price feed, token, game logic version, and timing rules for rounds.
   *      Requirements:
   *      - Caller must be the contract owner (Oracly Team) (enforced via `onlyOwner` modifier).
   *      Emits a `GameAdded` event when a new game is successfully added.
   * @param pricefeed The address of the Chainlink price feed used to provide pricing data feed for the game.
   * @param erc20 The address of the ERC20 token used for both deposits and payouts in the game.
   * @param version The version of the Oracly game logic, useful for compatibility and updates.
   * @param schedule The interval in seconds between rounds of the game (e.g., 300 for 5 minutes).
   * @param positioning The duration in seconds for the positioning phase, where bettors place predictions.
   * @param expiration The duration in seconds after which the round expires, and only withdraw deposit actions are allowed.
   * @param minDeposit The minimum deposit required to participate in the round, denoted in the ERC20 token.
   */
  function addGame(
    address pricefeed,
    address erc20,
    uint16 version,
    uint schedule,
    uint positioning,
    uint expiration,
    uint minDeposit

  )
    external
    onlyOwner
  {

    if (schedule < SHORTEST_ROUND) {
      revert("CannotAddGameScheduleTooShort");
    }

    if (positioning < SHORTEST_POSITIONING) {
      revert("CannotAddGamePositioningTooShort");
    }

    if (positioning > (schedule / 2)) {
      revert("CannotAddGamePositioningTooLarge");
    }

    if (expiration < SHORTEST_EXPIRATION) {
      revert("CannotAddGameExpirationTooShort");
    }

    if (expiration > LONGEST_EXPIRATION) {
      revert("CannotAddGameExpirationTooLarge");
    }

    if (minDeposit == 0) {
      revert("CannotAddGameMinDepositZero");
    }

    if (version == 0) {
      revert("CannotAddGameVersionZero");
    }

    if (AggregatorV3Interface(pricefeed).decimals() == 0) {
      revert("CannotAddGameWithInvalidFeedAddress");
    }

    if (IERC20(erc20).totalSupply() == 0) {
      revert("CannotAddGameERC20TotalSupplyCannotBeZero");
    }

    bytes32 gameid = keccak256(abi.encode(
      pricefeed,
      erc20,
      version,
      schedule,
      positioning
    ));

    if (_games[gameid].gameid != 0x0) {
      revert("CannotAddGameAlreadyExists");
    }

    _games[gameid] = Game({
      gameid: gameid,
      pricefeed: pricefeed,
      erc20: erc20,
      version: version,
      schedule: schedule,
      positioning: positioning,
      expiration: expiration,
      minDeposit: minDeposit,
      blocked: false
    });

    _activeGames[erc20].add(gameid);

    emit GameAdded(
      gameid,
      pricefeed,
      erc20,
      version,
      schedule,
      positioning,
      expiration,
      minDeposit
    );
  }

  /**
   * @notice Retrieves a list of active games that use a specific ERC20 token.
   * @dev This function returns a paginated list of active `Game` structs that utilize the specified ERC20 token.
   *      The results can be fetched using the provided `offset` for pagination.
   * @param erc20 The address of the ERC20 token being used by the games.
   * @param offset The starting index for pagination of active games.
   * @return games An array of `Game` structs representing the active games using the given ERC20 token.
   * @return size The total number of active games using the specified ERC20 token.
   */
  function getActiveGames(
    address erc20,
    uint256 offset
  )
    external
    view
    returns (
      Game[] memory games,
      uint size
    )
  {

    games = new Game[](0);
    size = _activeGames[erc20].length();

    if (size == 0) return (games, size);
    if (offset >= size) return (games, size);

    uint rest = size - offset;
    uint lastidx = 0;
    if (rest > 20) {
      lastidx = rest - 20;
    }
    uint resultSize = rest - lastidx;
    games = new Game[](resultSize);

    uint idx = 0;
    while (idx != resultSize) {
      bytes32 gameid = _activeGames[erc20].at(rest - 1 - idx);
      games[idx] = _games[gameid];
      idx++;
    }

  }

  /**
   * @notice Retrieves the details of a specific game based on its unique identifier.
   * @dev This function fetches the game details from internal storage using the provided game ID.
   *      The game details include all the relevant information about a specific prediction game.
   * @param gameid The unique identifier for the game, represented as a bytes32 value.
   * @return game A `Game` struct containing the metadata of the requested game.
   */
  function getGame(
    bytes32 gameid
  )
    external
    view
    returns (
      Game memory game
    )
  {

    game = _games[gameid];

  }

  /**
   * @notice Unblocks a previously blocked game, allowing it to resume normal operation.
   * @dev Unblocking a game restores its availability for bettors and enables gameplay to continue.
   * @param gameid The unique identifier of the game to be unblocked.
   * @dev Can only be called by the contract owner (Oracly Team).
   *      Emits a `GameUnblocked` event upon successful execution.
   *      Requirements:
   *      - The game must be in a blocked state.
   *      - Can only be called by the contract owner.
   */
  function unblockGame(
    bytes32 gameid
  )
    external
    onlyOwner
  {

    Game storage game = _games[gameid];
    if (game.gameid == 0x0) {
      revert("CannotUnblockGameDoNotExists");
    }
    if (!game.blocked) {
      revert("CannotUnblockGameIsNotBlocked");
    }

    game.blocked = false;

    _activeGames[game.erc20].add(gameid);

    emit GameUnblocked(gameid);

  }

  /**
   * @notice Blocks a game, preventing new prediction rounds from being initiated and marking unresolved rounds as impacted.
   * @dev Blocks the specified game, ensuring no new rounds are created and impacting any currently unresolved rounds.
   *      Emits a `GameBlocked` upon successful blocking.
   *      Requirements:
   *      - This function can only be called by the contract owner (Oracly Team).
   *      - The game must exist and not already be blocked.
   * @param gameid The unique identifier of the game to block.
   */
  function blockGame(
    bytes32 gameid
  )
    external
    onlyOwner
  {

    Game storage game = _games[gameid];
    if (game.gameid == 0x0) {
      revert("CannotBlockGameDoNotExists");
    }
    if (game.blocked) {
      revert("CannotBlockGameIsAlreadyBlocked");
    }

    game.blocked = true;

    _activeGames[game.erc20].remove(gameid);

    emit GameBlocked(gameid);
  }

  /**
   * @notice This event is emitted when a new game is added to the Oracly Protocol.
   * @dev Captures important parameters such as the Chainlink price feed, ERC20 token used, game version, and round timing details.
   * @param gameid The unique identifier of the newly added game, used for tracking purposes.
   * @param pricefeed The address of the Chainlink price feed used to provide external data for the game.
   * @param erc20 The address of the ERC20 token used for both deposits and payouts in the game.
   * @param version The version of the Oracly game logic, useful for compatibility and updates.
   * @param schedule The interval in seconds between rounds of the game (e.g., 300 for 5 minutes).
   * @param positioning The duration in seconds for the positioning phase, where bettors place predictions.
   * @param expiration The duration in seconds after which the round expires, and only withdraw deposit actions are allowed.
   * @param minDeposit The minimum deposit required to participate in the round, denoted in the ERC20 token.
   */
  event GameAdded(
    bytes32 indexed gameid,
    address pricefeed,
    address erc20,
    uint16 version,
    uint schedule,
    uint positioning,
    uint expiration,
    uint minDeposit
  );

  /**
   * @notice This event is emitted when a game is blocked by the Oracly team.
   *         It can signal to external systems or users that a game is no longer available for participation or prediction.
   * @dev Emitted when a game is blocked by the Oracly Team due to unforeseen issues, violations, or any other reasons defined within the protocol.
   * @param gameid The unique identifier of the blocked game.
   */
  event GameBlocked(bytes32 indexed gameid);

  /**
   * @notice This event is emitted when a previously blocked game is unblocked by the Oracly Team.
   * @dev Emitted when a previously blocked game is unblocked.
   * @param gameid The unique identifier of the game that has been unblocked.
   */
  event GameUnblocked(bytes32 indexed gameid);
}
