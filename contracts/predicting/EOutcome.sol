// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title EOutcome
 * @notice Enum representing the possible outcomes of a prediction round in the game.
 * @dev Bettors predict whether the price of a selected asset will go Down, Up, or remain the same (Zero).
 *      `Undefined`: Value is the initial state when the outcome is unknown.
 *      `No Contest`:
 *       - All participants predicted the same outcome (either all Up, all Down, or all Zero), making it impossible to determine winners.
 *       - None of the participants correctly predicted the outcome.
 *       - The round was not resolved within the allowed time limit.
 */
enum EOutcome {

  /**
   * @notice The outcome is not yet defined.
   * @dev Used when the prediction round is in an early stage or hasn't been completed.
   */
  Undefined,

  /**
   * @notice The price of the asset has gone down.
   * @dev This outcome is reached if the price of the selected asset decreases during the round.
   */
  Down,

  /**
   * @notice The price of the asset has gone up.
   * @dev This outcome is reached if the price of the selected asset increases during the round.
   */
  Up,

  /**
   * @notice The price of the asset remained the same.
   * @dev This outcome is reached if there is no change in the asset's price between entry price and exit price.
   */
  Zero,

  /**
   * @notice The round resulted in no contest.
   * @dev Used when the round ends without a valid outcome due to external conditions.
   */
  NoContest
}
