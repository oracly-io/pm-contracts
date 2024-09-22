# Solidity API

## DEMO

Provides a free allocation of DEMO tokens for demonstrating OraclyV1 gameplay.

_This contract acts as a faucet, dispensing a controlled amount of DEMO tokens to bettors.
     Token Allocation: Each eligible request grants 1,000 DEMO tokens.
     Wallet Limits: No wallet address can request more than 10,000 DEMO tokens in total.
     ERC-20: Implements basic ERC-20 token functionality for DEMO, allowing transfers and balance checks._

### INIT_SUPPLY

```solidity
uint256 INIT_SUPPLY
```

Initial supply of DEMO tokens distributed upon contract deployment.

_This constant defines the total initial supply of the DEMO tokens (1,000 tokens)_

### DEMO_SUPPLY

```solidity
uint256 DEMO_SUPPLY
```

Amount of DEMO tokens dispensed per mint request

_Defines the fixed number of DEMO tokens (1,000 tokens) that can be minted for each minting request._

### MAX_ADDRESS_MINT

```solidity
uint256 MAX_ADDRESS_MINT
```

Maximum amount of DEMO tokens that a single wallet can mint.

_This constant caps the amount of tokens a single wallet can mint (10,000 tokens), ensuring no wallet can exceed this limit._

### TOKEN_NAME

```solidity
string TOKEN_NAME
```

Official name of the DEMO token, represented as "Oracly Demo".

_This is the full name used in the ERC-20 standard._

### TOKEN_SYMBOL

```solidity
string TOKEN_SYMBOL
```

The symbol of the DEMO token, denoted as "DEMO".

_This symbol will be displayed on exchanges and wallets._

### minted

```solidity
mapping(address => uint256) minted
```

Tracks the number of DEMO tokens minted by each bettor.

_Maps a bettor's wallet address to the total number of DEMO tokens they have minted.
     This mapping is used to enforce minting limits._

### constructor

```solidity
constructor() public
```

Initializes the contract by minting the initial supply of DEMO tokens to the deployer's address.

_Mints 1,000 DEMO tokens to the deployer's address upon contract deployment.
     The `ERC20` constructor is called with `TOKEN_NAME` and `TOKEN_SYMBOL` as parameters._

### mint

```solidity
function mint() external
```

Mints 1,000 DEMO tokens to the caller, ensuring the wallet does not exceed the 10,000 DEMO cap.

_This function allows the caller to mint 1,000 DEMO tokens at a time, provided they have not reached the maximum cap of 10,000 DEMO tokens per wallet.
     If minting the tokens would cause the caller's minted token amount to exceed the cap, the transaction is reverted with `MintLimitExceeded`.
     Requirements:
     - The caller must be an EOA (Externally Owned Account), enforced by the `onlyOffChainCallable` modifier.
     - The contract tracks the balance and limits the total mintable tokens to a maximum of 10,000 DEMO per address._

### onlyOffChainCallable

```solidity
modifier onlyOffChainCallable()
```

Restricts function execution to external accounts (EOA) only.

_This modifier ensures that only EOAs (Externally Owned Accounts) can call functions protected by this modifier, preventing contracts from executing such functions.
     The check is performed by verifying that the caller has no code associated with it (not a contract) and by comparing `tx.origin` with `_msgSender()`._

