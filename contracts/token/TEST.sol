// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TEST
 * @notice A test ERC20 token used only in unit tests to emulate various decimal points for ERC20 tokens.
 * @dev This contract is designed to test different decimal configurations for ERC20 tokens.
 * It inherits from OpenZeppelin's ERC20 implementation.
 */
contract TEST is ERC20 {

  /**
   * @notice The name of the test token.
   * @dev This constant defines the token name as "OraclyV1 TEST Token".
   */
  string constant internal TOKEN_NAME = "OraclyV1 TEST Token";

  /**
   * @notice The symbol for the test token.
   * @dev This constant defines the token symbol as "TEST".
   */
  string constant internal TOKEN_SYMBOL = "TEST";

  /**
   * @notice The decimal places used by the token.
   * @dev This value is set during contract construction and represents the number of decimals for the token.
   */
  uint8 immutable internal DECIMALS;

  /**
   * @notice The total supply of the test token.
   * @dev This value is set during contract construction and represents the initial token supply.
   */
  uint immutable internal TOTAL_SUPPLY;

  /**
   * @notice Constructor to initialize the TEST token with a specific supply and decimal points.
   * @param _supply The total supply of tokens to be minted.
   * @param _decimals The number of decimal places for the token.
   * @dev Mints the total supply to the deployer of the contract and sets the decimals.
   */
  constructor(
    uint _supply,
    uint8 _decimals
  )
    ERC20(TOKEN_NAME, TOKEN_SYMBOL)
  {
    TOTAL_SUPPLY = _supply;
    DECIMALS = _decimals;

    // Mints the total supply to the contract deployer (msg.sender)
    _mint(_msgSender(), TOTAL_SUPPLY);
  }

  /**
   * @notice Returns the number of decimal places the token uses.
   * @dev Overrides the decimals function from the ERC20 base contract.
   * @return uint8 The number of decimal places set for this token.
   */
  function decimals()
    public
    view
    virtual
    override
    returns (uint8)
  {
    return DECIMALS;
  }

}
