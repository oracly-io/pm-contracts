// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title DEMO Token - OraclyV1 Faucet
 * @notice Provides a free allocation of DEMO tokens for demonstrating OraclyV1 gameplay.
 * @dev This contract acts as a faucet, dispensing a controlled amount of DEMO tokens to bettors.
 *      Token Allocation: Each eligible request grants 1,000 DEMO tokens.
 *      Wallet Limits: No wallet address can request more than 10,000 DEMO tokens in total.
 *      ERC-20: Implements basic ERC-20 token functionality for DEMO, allowing transfers and balance checks.
 */
contract DEMO is ERC20 {

  /**
   * @notice Initial supply of DEMO tokens distributed upon contract deployment.
   * @dev This constant defines the total initial supply of the DEMO tokens (1,000 tokens)
   */
  uint256 constant internal INIT_SUPPLY = 1_000 * 1e18;

  /**
   * @notice Amount of DEMO tokens dispensed per mint request
   * @dev Defines the fixed number of DEMO tokens (1,000 tokens) that can be minted for each minting request.
   */
  uint256 constant internal DEMO_SUPPLY = 1_000 * 1e18;

  /**
   * @notice Maximum amount of DEMO tokens that a single wallet can mint.
   * @dev This constant caps the amount of tokens a single wallet can mint (10,000 tokens), ensuring no wallet can exceed this limit.
   */
  uint256 constant internal MAX_ADDRESS_MINT = 10_000 * 1e18;

  /**
   * @notice Official name of the DEMO token, represented as "Oracly Demo".
   * @dev This is the full name used in the ERC-20 standard.
   */
  string constant internal TOKEN_NAME = "Oracly Demo";

  /**
   * @notice The symbol of the DEMO token, denoted as "DEMO".
   * @dev This symbol will be displayed on exchanges and wallets.
   */
  string constant internal TOKEN_SYMBOL = "DEMO";

  /**
   * @notice Tracks the number of DEMO tokens minted by each bettor.
   * @dev Maps a bettor's wallet address to the total number of DEMO tokens they have minted.
   *      This mapping is used to enforce minting limits.
   */
  mapping(address => uint256) public minted;

  /**
   * @notice Initializes the contract by minting the initial supply of DEMO tokens to the deployer's address.
   * @dev Mints 1,000 DEMO tokens to the deployer's address upon contract deployment.
   *      The `ERC20` constructor is called with `TOKEN_NAME` and `TOKEN_SYMBOL` as parameters.
   */
  constructor()
    ERC20(TOKEN_NAME, TOKEN_SYMBOL)
  {
    address sender = _msgSender();
    _mint(sender, INIT_SUPPLY);
  }

  /**
   * @notice Mints 1,000 DEMO tokens to the caller, ensuring the wallet does not exceed the 10,000 DEMO cap.
   * @dev This function allows the caller to mint 1,000 DEMO tokens at a time, provided they have not reached the maximum cap of 10,000 DEMO tokens per wallet.
   *      If minting the tokens would cause the caller's minted token amount to exceed the cap, the transaction is reverted with `MintLimitExceeded`.
   *      Requirements:
   *      - The caller must be an EOA (Externally Owned Account), enforced by the `onlyOffChainCallable` modifier.
   *      - The contract tracks the balance and limits the total mintable tokens to a maximum of 10,000 DEMO per address.
   */
  function mint()
    external
    onlyOffChainCallable
  {
    address sender = _msgSender();

    if ((minted[sender] + DEMO_SUPPLY) > MAX_ADDRESS_MINT) {
      revert("MintLimitExceeded");
    }

    minted[sender] = minted[sender] + DEMO_SUPPLY;
    _mint(sender, DEMO_SUPPLY);

  }

  /**
   * @notice Restricts function execution to external accounts (EOA) only.
   * @dev This modifier ensures that only EOAs (Externally Owned Accounts) can call functions protected by this modifier, preventing contracts from executing such functions.
   *      The check is performed by verifying that the caller has no code associated with it (not a contract) and by comparing `tx.origin` with `_msgSender()`.
   */
  modifier onlyOffChainCallable() {
    address sender = _msgSender();
    if (sender.code.length > 0) {
      revert("OnlyEOASendersAllowed");
    }
    if (tx.origin != sender) {
      revert("OnlyEOASendersAllowed");
    }
    _;
  }
}
