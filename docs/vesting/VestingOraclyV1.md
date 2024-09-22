# Solidity API

## VestingOraclyV1

This contract is designed to handle the vesting of ORCY tokens, aligning token release with long-term project goals and incentivizing continued participation.

_A vesting contract for ORCY tokens within the Oracly Protocol ecosystem. This contract ensures a gradual and controlled release of ORCY tokens to a designated beneficiary over a 26-month period with a 6-month cliff.
     The contract overrides the `release` and `receive` functions to prevent direct token release or receipt of native tokens._

### DURATION

```solidity
uint64 DURATION
```

The duration of the vesting period after the cliff, spanning 20 months.

_This constant defines the length of time over which the tokens are gradually released after the cliff period._

### CLIFF

```solidity
uint64 CLIFF
```

The cliff period for the vesting, which lasts 6 months.

_No tokens are released during the cliff period. Tokens start releasing only after this period ends._

### constructor

```solidity
constructor(address beneficiary) public
```

Constructor for VestingOraclyV1 contract.

_Initializes the vesting wallet with a predefined cliff period and total duration. Tokens begin vesting after the cliff, and are released gradually over the 20-month duration._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| beneficiary | address | The address of the beneficiary who will receive the vested ORCY tokens. |

### release

```solidity
function release() public virtual
```

Prevents the direct release of native tokens.

_Overrides the `release` function to disable native token release. Only ORCY tokens are managed by this contract._

### receive

```solidity
receive() external payable virtual
```

Prevents the contract from receiving native tokens.

_Overrides the `receive` function to reject incoming native token transfers._

