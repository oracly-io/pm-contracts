// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IRewardCalculator
 * @dev Defines the interface for a contract responsible for calculating rewards in the Oracly Protocol.
 */
interface IRewardCalculator {

  /**
   * @notice Calculates the reward amount for a given bettor and commission.
   * @dev Implementations of this interface will define the specific reward calculation logic.
   * @param bettor The address of the bettor.
   * @param commission The commission amount collected.
   * @return reward The calculated reward amount.
   */
  function calculateReward(
    address bettor,
    uint commission
  ) external returns (uint);

}


