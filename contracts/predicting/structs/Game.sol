// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Game
 * @notice Represents a series of prediction rounds where bettors predict cryptocurrency price movements for a chance to win rewards.
 * @dev The struct defines key parameters for a game instance, including the price feed, token used for rewards, and schedule details.
 *      - `gameid` This is a hashed value of main properites representing the game ID.
 *      - `pricefeed` The price feed provides cryptocurrency price data for bettors to make predictions.
 *      - `erc20` Participants deposit this token to join the game, and rewards are distributed in the same token.
 *      - `version` Tracks the version of the game to differentiate between various game variants.
 *      - `scheduled` Specifies the start time of the game, which is set during initialization.
 *      - `positioning` Defines the time period before the game locks in which bettors can position their predictions.
 *      - `expiration` The time at which the round expires after it ends, and only withdraw deposit actions are allowed.
 *      - `minDeposit` Specifies the smallest amount of ERC20 tokens that a bettor must deposit to enter the game.
 *      - `blocked` If set to true, the game is blocked and no new actions (such as placing predictions) can be taken.
 */
struct Game {

  /**
   * @notice Unique identifier for the game.
   * @dev This is a hashed value of main properites representing the game ID.
   */
  bytes32 gameid;

  /**
   * @notice The address of the price feed contract.
   * @dev The price feed provides cryptocurrency price data for bettors to make predictions.
   */
  address pricefeed;

  /**
   * @notice The address of the ERC20 token contract used for deposits and rewards.
   * @dev Participants deposit this token to join the game, and rewards are distributed in the same token.
   */
  address erc20;

  /**
   * @notice Indicates the version number of the game.
   * @dev Tracks the version of the game to differentiate between various game variants.
   */
  uint16 version;

  /**
   * @notice The timestamp when the game is scheduled to start.
   * @dev Specifies the start time of the game, which is set during initialization.
   */
  uint schedule;

  /**
   * @notice Time window for bettors to submit their predictions.
   * @dev Defines the time period before the game locks in which bettors can position their predictions.
   */
  uint positioning;

  /**
   * @notice The expiration time for the game.
   * @dev The time at which the round expires after it ends, and only withdraw deposit actions are allowed.
   */
  uint expiration;

  /**
   * @notice The minimum deposit required to participate in the game.
   * @dev Specifies the smallest amount of ERC20 tokens that a bettor must deposit to enter the game.
   */
  uint minDeposit;

  /**
   * @notice A flag indicating whether the game is blocked.
   * @dev If set to true, the game is blocked and no new actions (such as placing predictions) can be taken.
   */
  bool blocked;

}
