// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Deposit
 * @notice Represents a staking deposit of ORCY tokens in the Oracly Staking Contract.
 * @dev A staker's deposit is locked for a Staking Epoch, earns rewards, and grants voting power in governance processes.
 *      - `depositid` This is a hashed value representing the deposit ID.
 *      - `staker` This is the wallet address of the staker depositing ORCY tokens.
 *      - `inEpochid` Represents the epoch during which the deposit was created.
 *      - `createdAt` Records the time when the staker deposited ORCY tokens.
 *      - `amount` Specifies the quantity of ORCY tokens deposited into the staking contract.
 *      - `outEpochid` Defines the epoch during which the unstake process was initiated.
 *      - `unstaked` If true, the staker has requested to unlock their staked ORCY tokens.
 *      - `unstakedAt` Records the time when the staker unstake their ORCY tokens from the contract.
 *      - `withdrawn` If true, the staker has successfully withdrawn their tokens after unstaking.
 *      - `withdrawnAt` Records the time when the staker withdrew their ORCY tokens from the contract.
 */
struct Deposit {

  /**
   * @notice Unique identifier for the deposit.
   * @dev This is a hashed value representing the deposit ID.
   */
  bytes32 depositid;

  /**
   * @notice The address of the staker making the deposit.
   * @dev This is the wallet address of the staker depositing ORCY tokens.
   */
  address staker;

  /**
   * @notice The identifier of the Staking Epoch when the deposit was made.
   * @dev Represents the epoch during which the deposit was created.
   */
  uint inEpochid;

  /**
   * @notice The timestamp when the deposit was created.
   * @dev Records the time when the staker deposited ORCY tokens.
   */
  uint createdAt;

  /**
   * @notice The amount of ORCY tokens deposited by the staker.
   * @dev Specifies the quantity of ORCY tokens deposited into the staking contract.
   */
  uint amount;

  /**
   * @notice Identifier of the epoch when the deposit requested to unstake.
   * @dev Defines the epoch during which the unstake process is initiated.
   */
  uint outEpochid;

  /**
   * @notice Indicates whether the staker has initiated unstaking.
   * @dev If true, the staker has requested to unlock their staked ORCY tokens.
   */
  bool unstaked;

  /**
   * @notice The timestamp when the staker initiates unstaking.
   * @dev Records the time when the staker begins the process of unstaking their ORCY tokens from the contract.
   */
  uint unstakedAt;

  /**
   * @notice Indicates whether the staker has withdrawn their deposit.
   * @dev If true, the staker has successfully withdrawn their tokens after unstaking.
   */
  bool withdrawn;

  /**
   * @notice The timestamp when the deposit was withdrawn.
   * @dev Records the time when the staker withdrew their ORCY tokens from the contract.
   */
  uint withdrawnAt;

}

