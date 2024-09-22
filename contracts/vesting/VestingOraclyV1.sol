// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { VestingWallet } from "@openzeppelin/contracts/finance/VestingWallet.sol";

/**
 * @title VestingOraclyV1
 * @dev A vesting contract for ORCY tokens within the Oracly Protocol ecosystem. This contract ensures a gradual and controlled release of ORCY tokens to a designated beneficiary over a 26-month period with a 6-month cliff.
 *      The contract overrides the `release` and `receive` functions to prevent direct token release or receipt of native tokens.
 * @notice This contract is designed to handle the vesting of ORCY tokens, aligning token release with long-term project goals and incentivizing continued participation.
 */
contract VestingOraclyV1 is VestingWallet {

  /**
   * @notice The duration of the vesting period after the cliff, spanning 20 months.
   * @dev This constant defines the length of time over which the tokens are gradually released after the cliff period.
   */
  uint64 public constant DURATION = uint64(30 days * 20); // 20 months

  /**
   * @notice The cliff period for the vesting, which lasts 6 months.
   * @dev No tokens are released during the cliff period. Tokens start releasing only after this period ends.
   */
  uint64 public constant CLIFF = uint64(30 days * 6); // 6 months

  /**
   * @notice Constructor for VestingOraclyV1 contract.
   * @param beneficiary The address of the beneficiary who will receive the vested ORCY tokens.
   * @dev Initializes the vesting wallet with a predefined cliff period and total duration. Tokens begin vesting after the cliff, and are released gradually over the 20-month duration.
   */
  constructor(address beneficiary)
    VestingWallet(beneficiary, uint64(block.timestamp + CLIFF), DURATION)
  { }

  /**
   * @notice Prevents the direct release of native tokens.
   * @dev Overrides the `release` function to disable native token release. Only ORCY tokens are managed by this contract.
   * @custom:throws Reverts with "NativeTokenReleaseIsNOOP" if attempted.
   */
  function release()
    public
    virtual
    override
  {
    revert("NativeTokenReleaseIsNOOP");
  }

  /**
   * @notice Prevents the contract from receiving native tokens.
   * @dev Overrides the `receive` function to reject incoming native token transfers.
   * @custom:throws Reverts with "NativeTokenReceiveIsNOOP" if attempted.
   */
  receive()
    external
    payable
    virtual
    override
  {
    revert("NativeTokenReceiveIsNOOP");
  }

}
