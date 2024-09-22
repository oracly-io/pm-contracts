// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Prediction
 * @notice Represents a bettor's choice of outcome (Down, Up, Zero) in a prediction game round.
 * @dev If the bettor's prediction aligns with the actual price change, they win a share of the prize pool.
 *      - `predictionid` This is a hashed value representing the prediction ID.
 *      - `roundid` Refers to the specific round within the game.
 *      - `gameid` Links the prediction to a specific game instance.
 *      - `bettor` Represents the bettor's wallet address.
 *      - `position` This is an `unit8` where (1 for Down, 2 for Up, 3 for Zero).
 *      - `deposit` This variable stores the value of the deposit for the prediction in the current round.
 *      - `claimed` This is true if the bettor has successfully claimed their payout after winning.
 *      - `createdAt` Records when the bettor made their prediction.
 *      - `payout` This is the amount the bettor receives from the prize pool upon winning.
 *      - `commission` The commission represents the amount deducted and allocated to stakers and mentors on a winning prediction.
 *      - `erc20` Bettors use this token for betting and receiving rewards in the game.
 */
struct Prediction {

  /**
   * @notice Unique identifier for the prediction.
   * @dev This is a hashed value representing the prediction ID.
   */
  bytes32 predictionid;

  /**
   * @notice Unique identifier for the round in which the prediction is made.
   * @dev Refers to the specific round within the game.
   */
  bytes32 roundid;

  /**
   * @notice Unique identifier for the game.
   * @dev Links the prediction to a specific game instance.
   */
  bytes32 gameid;

  /**
   * @notice The address of the bettor who made the prediction.
   * @dev Represents the bettor's wallet address.
   */
  address bettor;

  /**
   * @notice The position the bettor has taken in the prediction (Down, Up, Zero).
   * @dev This is an `unit8` where (1 for Down, 2 for Up, 3 for Zero).
   */
  uint8 position;

  /**
   * @notice The amount of ERC20 tokens deposited by the bettor for this prediction.
   * @dev This variable stores the value of the deposit for the prediction in the current round.
   */
  uint deposit;

  /**
   * @notice Indicates whether the bettor has claimed their winnings.
   * @dev This is true if the bettor has successfully claimed their payout after winning.
   */
  bool claimed;

  /**
   * @notice The timestamp when the prediction was created.
   * @dev Records when the bettor made their prediction.
   */
  uint createdAt;

  /**
   * @notice The payout awarded to the bettor if their prediction is correct.
   * @dev This is the amount the bettor receives from the prize pool upon winning.
   */
  uint payout;

  /**
   * @notice The commission amount deducted and allocated to stakers and mentors.
   * @dev The commission represents the amount deducted and allocated to stakers and mentors on a winning prediction.
   */
  uint commission;

  /**
   * @notice The ERC20 token used for the bettor's deposit and payout.
   * @dev Bettors use this token for betting and receiving rewards in the game.
   */
  address erc20;

}
