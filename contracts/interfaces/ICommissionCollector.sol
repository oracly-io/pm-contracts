// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title ICommissionCollector
 * @dev Interface for collecting commission within the Oracly Protocol.
 */
interface ICommissionCollector {

  /**
   * @notice Collects a commission from a bettor for gerther rewards distributes.
   * @dev Implementations of this interface will handle the actual commission collection and reward distribution logic.
   * @param bettor The address of the bettor from who commission was collected.
   * @param erc20 The address of the ERC20 token used for the reward.
   * @param commission The commission to be collected.
   */
  function collectCommission(
    address bettor,
    address erc20,
    uint commission
  ) external;

}

