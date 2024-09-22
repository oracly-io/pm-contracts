// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ORCY Token
 * @notice The ORCY token is the native token of the Oracly Protocol, enabling staking, governance, and facilitating reward distribution.
 * @dev This contract implements the standard ERC-20 functionality for the ORCY token, allowing users to transfer ORCY, check balances, and participate in staking and governance.
 *       It controls the minting process according to the OraclyV1 Economy, distributing tokens for growth, team, seed, and buy4stake addresses.
 */
contract ORCY is ERC20 {

  /**
   * @notice Fixed total supply of ORCY tokens, permanently set to 10 million tokens.
   * @dev The supply is scaled to 18 decimal places (10 million * 1e18).
   */
  uint constant internal TOTAL_SUPPLY = 10_000_000 * 1e18;

  /**
   * @notice Official name of the ORCY token, represented as 'Oracly Glyph'.
   * @dev This is the full name used in the ERC-20 standard.
   */
  string constant internal TOKEN_NAME = "Oracly Glyph";

  /**
   * @notice The symbol of the ORCY token, denoted as 'ORCY'.
   * @dev This symbol will be displayed on exchanges and wallets.
   */
  string constant internal TOKEN_SYMBOL = "ORCY";

  /**
   * @notice Percentage of the total token supply allocated for the growth fund.
   * @dev Set at 10%, this portion is reserved for initiatives that promote ecosystem growth.
   */
  uint8 constant internal GROWTH_PERCENTAGE = 10;

  /**
   * @notice Percentage of the total token supply allocated for the team.
   * @dev Set at 10%, this portion is reserved for team members as compensation.
   */
  uint8 constant internal TEAM_PERCENTAGE = 10;

  /**
   * @notice Percentage of the total token supply allocated for seed investors.
   * @dev Set at 5%, this portion is reserved for early-stage investors who funded the project.
   */
  uint8 constant internal SEED_PERCENTAGE = 5;

  /**
   * @notice Percentage of the total token supply allocated for the buy4stake program.
   * @dev Set at 50%, this portion is reserved for the buy4stake mechanism to incentivize staking.
   */
  uint8 constant internal BUY4STAKE_PERCENTAGE = 50;

  /**
   * @notice Percentage of the total token supply allocated for growth-related vesting.
   * @dev Set at 10%, this portion will be unlocked over time to sustain long-term growth initiatives.
   */
  uint8 constant internal GROWTH_VESTING_PERCENTAGE = 10;

  /**
   * @notice Percentage of the total token supply allocated for team vesting.
   * @dev Set at 10%, this portion will be unlocked gradually for team members as part of their vesting schedule.
   */
  uint8 constant internal TEAM_VESTING_PERCENTAGE = 10;

  /**
   * @notice Percentage of the total token supply allocated for seed investors' vesting.
   * @dev Set at 5%, this portion will be released over time to early investors in accordance with the vesting schedule.
   */
  uint8 constant internal SEED_VESTING_PERCENTAGE = 5;

  /**
   * @notice Initializes the ORCY token contract by minting the total supply and distributing it according to the ORCY economy's token allocation plan.
   * @dev The total supply of ORCY tokens is minted and allocated across various addresses based on predefined percentages for growth, team, seed investors, and buy4stake mechanisms.
   * @param growth_address Address that receives the portion allocated for growth initiatives (10%).
   * @param team_address Address that receives the portion allocated for the team (10%).
   * @param seed_address Address that receives the portion allocated for seed investors (5%).
   * @param buy4stake_address Address that receives the portion allocated for the buy4stake program (50%).
   * @param growth_vesting_address Address that receives the vesting portion for long-term growth initiatives (10%).
   * @param team_vesting_address Address that receives the vesting portion for team members (10%).
   * @param seed_vesting_address Address that receives the vesting portion for seed investors (5%).
   */
  constructor(
    address growth_address,
    address team_address,
    address seed_address,
    address buy4stake_address,
    address growth_vesting_address,
    address team_vesting_address,
    address seed_vesting_address
  )
    ERC20(TOKEN_NAME, TOKEN_SYMBOL)
  {
    if (growth_address == address(0)) revert("GrowthAddressCannotBeZero");
    if (team_address == address(0)) revert("TeamAddressCannotBeZero");
    if (seed_address == address(0)) revert("SeedAddressCannotBeZero");
    if (buy4stake_address == address(0)) revert("Buy4StakeAddressCannotBeZero");
    if (growth_vesting_address == address(0)) revert("GrowthVestingAddressCannotBeZero");
    if (team_vesting_address == address(0)) revert("TeamVestingAddressCannotBeZero");
    if (seed_vesting_address == address(0)) revert("SeedVestingAddressCannotBeZero");

    // Mint tokens to the specified addresses
    _mint(growth_address, TOTAL_SUPPLY * GROWTH_PERCENTAGE / 100);
    _mint(team_address, TOTAL_SUPPLY * TEAM_PERCENTAGE / 100);
    _mint(seed_address, TOTAL_SUPPLY * SEED_PERCENTAGE / 100);
    _mint(buy4stake_address, TOTAL_SUPPLY * BUY4STAKE_PERCENTAGE / 100);

    // Mint tokens for vesting purposes
    _mint(growth_vesting_address, TOTAL_SUPPLY * GROWTH_VESTING_PERCENTAGE / 100);
    _mint(team_vesting_address, TOTAL_SUPPLY * TEAM_VESTING_PERCENTAGE / 100);
    _mint(seed_vesting_address, TOTAL_SUPPLY * SEED_VESTING_PERCENTAGE / 100);
  }

}
