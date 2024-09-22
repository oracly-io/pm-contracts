// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Epoch
 * @notice Represents a recurring staking period (approximately 7 days) during which the staking pool remains unchanged.
 * @dev Staking rewards are distributed to stakers proportionally based on Oracly Commissions collected during the epoch.
 *      If no stakers register, the start of the epoch is delayed until participation occurs.
 *      - `epochid` This ID is used to track individual epochs.
 *      - `startDate` Indicates when the epoch is set to begin; however, the actual start may be delayed if no stakers participate.
 *      - `endDate` Defines when the staking epoch is expected to conclude, 7 days after the start date.
 *      - `startedAt` This records when the epoch started, which may differ from the scheduled start date due to a delayed start.
 *      - `endedAt` This captures the moment the epoch concluded, and no new staking reward commission is collected into the epoch.
 */
struct Epoch {

  /**
   * @notice Unique identifier for the staking epoch.
   * @dev This ID is used to track individual epochs.
   */
  uint epochid;

  /**
   * @notice The scheduled start date of the staking epoch.
   * @dev Indicates when the epoch is set to begin; however, the actual start may be delayed if no stakers participate.
   */
  uint startDate;

  /**
   * @notice The scheduled end date of the staking epoch.
   * @dev Defines when the staking epoch is expected to end, which is 7 days after the start date.
   */
  uint endDate;

  /**
   * @notice The actual timestamp when the staking epoch began.
   * @dev This records the exact time the epoch started, which may differ from the planned start date due to delays.
   */
  uint startedAt;

  /**
   * @notice The actual timestamp when the staking epoch ended.
   * @dev This captures the moment the epoch concluded, and no new staking reward commissions are collected for this epoch.
   */
  uint endedAt;

}
