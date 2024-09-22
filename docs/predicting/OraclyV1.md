# Solidity API

## OraclyV1

This contract implements the erc20 related functionality for the Oracly Protocol's decentralized prediction game.
        It allows bettors to participate in prediction rounds, manages the lifecycle of each round, integrates with Chainlink to obtain price data, and determines round outcomes based on price movements.
        The contract also handles bettor payouts, refunds, and manages reward distributions via external contracts.

_Contract for the Oracly Protocol's decentralized prediction game.
     Manages prediction rounds, integrates with Chainlink for price data, determines round outcomes, and handles bettor payouts and refunds._

### STAKING_CONTRACT

```solidity
address STAKING_CONTRACT
```

Address of the staking contract used for distributing staking rewards.

_This address should point to a valid smart contract.
     It is used to manage staking rewards in the Oracly protocol.
     The contract must implement the expected staking interface to ensure proper reward distribution._

### MENTORING_CONTRACT

```solidity
address MENTORING_CONTRACT
```

Address of the mentoring contract used for distributing mentor rewards.

_This address must be a smart contract. It handles the distribution of mentor rewards, and interacts with the core protocol to facilitate appropriate rewards based on mentoring actions._

### DISTRIBUTOR_EOA

```solidity
address DISTRIBUTOR_EOA
```

Externally Owned Account (EOA) address used as a backup for reward distribution in case the main contracts encounter issues.

_This address must be an EOA (not a contract).
     It serves as a backup to handle reward distributions manually if either the staking or mentoring contract fails and is bypassed._

### constructor

```solidity
constructor(address distributorEOA_address, address stakingContract_address, address mentoringContract_address, address metaoraclyContract_address) public
```

Constructor to initialize the reward distributors and related contracts.

_Validates the addresses for staking and mentoring contracts to ensure they are contracts and not EOAs.
     Also validates that the `distributorEOA_address` is an EOA and not a contract._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| distributorEOA_address | address | Address of the EOA used as a backup for reward distribution. |
| stakingContract_address | address | Address of the staking contract for staking rewards. |
| mentoringContract_address | address | Address of the mentoring contract for mentor rewards. |
| metaoraclyContract_address | address | Address of the MetaOracly contract that handles oracle game data. |

### resolve

```solidity
function resolve(bytes32 roundid, uint80 exitPriceid) external
```

Resolves a prediction round by validating the Exit Price ID and determining the outcome.

_This function resolves a prediction round, ensuring that the provided priceid corresponds to a valid Exit Price from the price feed.
     - The function is protected against re-entrancy attacks via `nonReentrant` modifier.
     - It is restricted to off-chain callers EOA using the `onlyOffChainCallable` modifier.
     Emits:
     - `RoundResolvedNoContest`: If the round concludes with a "No Contest" outcome.
     - `RoundResolved`: If the round ends with a valid outcome: Down, Up, or Zero._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The ID of the round that needs to be resolved. |
| exitPriceid | uint80 | The ID of the Exit Price that is used to determine the final outcome of the round. |

### resolve4withdraw

```solidity
function resolve4withdraw(bytes32 roundid, bytes32 predictionid, address erc20, uint80 exitPriceid) external
```

Resolves a prediction round and processes the withdrawal of the payout.

_This function first resolves the specified round and prediction, based on the provided Exit Price.
     It then facilitates the withdrawal of the payout in the specified ERC20 token.
     - The function is protected against re-entrancy attacks via `nonReentrant` modifier.
     - It is restricted to off-chain callers EOA using the `onlyOffChainCallable` modifier.
     Emits:
     - `RoundResolvedNoContest`: If the round concludes with a "No Contest" outcome.
     - `RoundResolved`: If the round ends with a valid outcome: Down, Up, or Zero.
     - `FATAL_EVENT_INSUFFICIENT_PRIZEPOOL` if there are insufficient funds in the prize pool.
     - `PredictionClaimed` event emitted when a bettor claims the payout for prediction.
     - `RoundPrizepoolReleased` event on a successful prize pool release.
     - `RoundArchived` event once the round is archived.
     - `MentorsRewardDistributedViaContract` when mentor commission is successfully distributed via contract.
     - `MentorsRewardDistributedViaEOA` when mentor commission is distributed via EOA due to a fallback.
     - `StakersRewardDistributedViaContract` when staker commission is successfully distributed via contract.
     - `StakersRewardDistributedViaEOA` when staker commission is distributed via EOA due to a fallback._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The ID of the prediction round to resolve. |
| predictionid | bytes32 | The ID of the specific prediction within the round. |
| erc20 | address | The address of the ERC20 token contract used for the withdrawal. |
| exitPriceid | uint80 | The ID of the price point (exit price) used to resolve the prediction. |

### withdraw

```solidity
function withdraw(bytes32 roundid, bytes32 predictionid, address erc20) external
```

Claims a payout based on the result of a prediction in a specific round, using the specified ERC20 token for withdrawal.

_This function allows off-chain callers EOA to withdraw winnings from a prediction in a specific round, denominated in a given ERC20 token.
     - The function is protected against re-entrancy attacks via `nonReentrant` modifier.
     - It is restricted to off-chain callers EOA using the `onlyOffChainCallable` modifier.
     Emits:
     - `FATAL_EVENT_INSUFFICIENT_PRIZEPOOL` if there are insufficient funds in the prize pool.
     - `MentorsRewardDistributedViaContract` when mentor commission is successfully distributed via contract.
     - `MentorsRewardDistributedViaEOA` when mentor commission is distributed via EOA due to a fallback.
     - `StakersRewardDistributedViaContract` when staker commission is successfully distributed via contract.
     - `StakersRewardDistributedViaEOA` when staker commission is distributed via EOA due to a fallback.
     - `PredictionClaimed` event emitted when a bettor claims the payout for prediction.
     - `RoundPrizepoolReleased` event on a successful prize pool release.
     - `RoundArchived` event once the round is archived._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The ID of the round in which the prediction was made. |
| predictionid | bytes32 | The ID of the specific prediction to claim the payout for. |
| erc20 | address | The address of the ERC20 token to be used for the payout withdrawal. |

### placePrediction

```solidity
function placePrediction(uint256 amount, uint8 position, bytes32 gameid, bytes32 roundid) external
```

Places a prediction on the specified game and round.

_This function allows off-chain callers EOA to place a prediction on a game round by depositing a certain amount of ERC20 tokens.
     The bettor predicts an outcome (Down, Up, or Zero) for the given game and round.
     Requirements:
     - The `amount` must be greater than zero.
     - The `position` must be one of the valid values (1 for Down, 2 for Up, 3 for Zero).
     - The function is protected against re-entrancy attacks via `nonReentrant` modifier.
     - It is restricted to off-chain callers EOA using the `onlyOffChainCallable` modifier.
     Emits:
     - `RoundCreated` event upon successful creation of the round.
     - `RoundPrizepoolAdd` event to signal that the prize pool has been updated.
     - `PredictionCreated` event if a new prediction is created.
     - `IncreasePredictionDeposit` event if the bettor's prediction is updated._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | The amount of ERC20 tokens the bettor deposits to place the prediction. |
| position | uint8 | The predicted outcome for the game round. Valid values: (1 for Down, 2 for Up, 3 for Zero) |
| gameid | bytes32 | The ID of the game where the prediction is being placed. |
| roundid | bytes32 | The ID of the specific round within the game. |

### onlyOffChainCallable

```solidity
modifier onlyOffChainCallable()
```

Restricts function execution to external accounts (EOA) only.

_This modifier ensures that only EOAs (Externally Owned Accounts) can call functions protected by this modifier, preventing contracts from executing such functions.
     The check is performed by verifying that the caller has no code associated with it (not a contract) and by comparing `tx.origin` with `_msgSender()`._

### FATAL_EVENT_INSUFFICIENT_PRIZEPOOL

```solidity
event FATAL_EVENT_INSUFFICIENT_PRIZEPOOL(address bettor, address erc20, uint256 balance, uint256 payout, uint256 commission)
```

Emitted when the contract's prize pool is insufficient to cover both a bettor's payout and the commission.
        This event signals a critical failure that effectively prevents the specified ERC20 token from being used as the deposit token for further predictions.

_This is a fatal event that indicates the current prize pool cannot satisfy the requested payout and commission amounts._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| bettor | address | The address of the bettor attempting to withdraw the funds. |
| erc20 | address | The ERC20 token involved in the payout and commission transaction. |
| balance | uint256 | The current balance of the ERC20 token held in the contract. |
| payout | uint256 | The payout amount requested by the bettor. |
| commission | uint256 | The commission amount that is due to the contract. |

### MentorsRewardDistributedViaContract

```solidity
event MentorsRewardDistributedViaContract(address distributor, address bettor, address erc20, uint256 amount)
```

This event is emitted when a mentor's reward is distributed via a smart contract.

_This event captures the distribution of rewards to mentors based on the bettor's activity.
     It logs the distributor (the smart contract handling the distribution), the bettor (the bettor whose activity triggered the reward), the ERC20 token used, and the reward amount._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| distributor | address | The address of the contract that is distributing the reward. |
| bettor | address | The address of the bettor who generated the mentor's reward. |
| erc20 | address | The address of the ERC20 token contract used for distributing the reward. |
| amount | uint256 | The amount of the reward in the ERC20 token. |

### MentorsRewardDistributedViaEOA

```solidity
event MentorsRewardDistributedViaEOA(address distributor, address bettor, address erc20, uint256 amount)
```

Emitted when a mentor's reward is distributed using an Externally Owned Account (EOA).
        This happens as a fallback mechanism when direct distribution through smart contracts is not possible.

_This event is triggered whenever the mentor's reward is sent via an EOA, in scenarios where automated reward distribution through the smart contract system fails and is bypassed.
     The mentor's reward is distributed using an ERC20 token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| distributor | address | The address of the EOA responsible for distributing the reward to the mentor. |
| bettor | address | The address of the bettor whose activity generated the reward for the mentor. |
| erc20 | address | The address of the ERC20 token contract used to transfer the reward. |
| amount | uint256 | The amount of ERC20 tokens that are distributed as the reward. |

### StakersRewardDistributedViaContract

```solidity
event StakersRewardDistributedViaContract(address distributor, address bettor, address erc20, uint256 amount)
```

Emitted when a staker's reward is distributed through a contract.

_This event logs the details of a reward distribution to stakers initiated by a contract._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| distributor | address | The address of the contract responsible for distributing the reward. |
| bettor | address | The address of the bettor whose actions generated the reward for the stakers. |
| erc20 | address | The ERC20 token used for the reward distribution. |
| amount | uint256 | The total amount of the ERC20 reward distributed. |

### StakersRewardDistributedViaEOA

```solidity
event StakersRewardDistributedViaEOA(address distributor, address bettor, address erc20, uint256 amount)
```

Emitted when a staker's reward is distributed via an Externally Owned Account (EOA).
        This event acts as a fallback mechanism when the reward distribution does not go through
        the primary method, triggering the involvement of an EOA.

_This event provides a backup solution in cases where a direct reward transfer to the staking contract fails and is bypassed, allowing the reward to be manually handled by the EOA._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| distributor | address | The address of the EOA responsible for distributing the reward. |
| bettor | address | The address of the bettor whose actions resulted in the reward. |
| erc20 | address | The address of the ERC20 token used to pay out the reward. |
| amount | uint256 | The amount of tokens (in the ERC20 standard) distributed as the reward. |

