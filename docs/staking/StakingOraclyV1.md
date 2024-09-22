# Solidity API

## StakingOraclyV1

This contract manages multiple aspects of staking, including:
     - Epoch Management: Handles the creation and lifecycle of staking epochs, ensuring structured reward distribution cycles.
     - Deposit Tracking: Manages both pending and active staking deposits, providing transparency about stakers' locked amounts and statuses.
     - Reward Mechanics: Calculates staking rewards per epoch based on deposited ORCY token amounts automatically.
     - Buy4Stake: Allows stakers to acquire ORCY tokens directly for staking through the Buy4Stake process.

_This contract implements staking functionality for the Oracly Protocol, allowing ORCY token holders to lock tokens in return for staking rewards.
     Stakers can claim rewards for each epoch through which their deposit was `Staked` or in `Pending Unstake` status.
     The contract uses the Ownable pattern to restrict administrative functions and the ReentrancyGuard to protect against reentrancy attacks.
     It also implements the ICommissionCollector interface to manage reward distribution mechanisms.
     Stakers can stake ORCY tokens, claim rewards, and withdraw their stake._

### SCHEDULE

```solidity
uint32 SCHEDULE
```

The duration of one staking epoch in days.

_A staking epoch is fixed at 7 days. This constant used to calculate staking period durations._

### __FATAL_INSUFFICIENT_STAKEFUNDS_ERROR__

```solidity
bool __FATAL_INSUFFICIENT_STAKEFUNDS_ERROR__
```

Signals a fatal error caused by insufficient stake funds in the staking pool.

_This flag is set to true when the staking pool lacks sufficient funds to continue normal operations.
     Once active, it blocks new staking actions, although existing stakes will continue to accrue rewards.
     This is a critical safeguard to prevent the system from allowing additional stakes into a compromised stake pool._

### __FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__

```solidity
mapping(address => bool) __FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__
```

Tracks whether a fatal error has occurred for specific ERC20 tokens due to insufficient reward funds.

_This mapping records a boolean flag for each ERC20 token address, indicating if the reward pool has encountered a critical shortage of funds.
     The flag is set to `true` when the system detects that there are insufficient ERC20 tokens available to fulfill reward obligations.
     Once set, the system prevents the token from being used for reward accumulation by the contract to avoid further depletion and losses.
     The flag signals the necessity for manual intervention by an external authorized entity (EOA) to handle reward distribution.
     Existing rewards will still be distributed, but no new rewards can be accumulated for this token._

### STAKING_ERC20_CONTRACT

```solidity
address STAKING_ERC20_CONTRACT
```

The address of the ERC20 contract used as staking tokens. (ORCY)

_This is an immutable address, meaning it is set once at contract deployment and cannot be changed._

### AUTHORIZED_COMMISSION_GATHERER

```solidity
address AUTHORIZED_COMMISSION_GATHERER
```

The address of the authorized funds gatherer for the contract.

_This is the address responsible for gathering staking rewards from the bettor's prize on withdrawal and passing them to the contract for further distribution to stakers._

### BUY_4_STAKE_ERC20_CONTRACT

```solidity
address BUY_4_STAKE_ERC20_CONTRACT
```

The address of the ERC20 contract used in the Buy4Stake process, enabling participants to acquire ORCY tokens at a 1:1 exchange rate.

_The Buy4Stake mechanism uses this ERC20 token as a base for participants to purchase and stake ORCY tokens._

### ACTUAL_EPOCH_ID

```solidity
uint256 ACTUAL_EPOCH_ID
```

Tracks the current epoch ID used in the staking contract.

_This value increments with the beginning of each new staking epoch.
     It starts at a phantom epoch '0', meaning no staking epochs have been initiated yet.
     The epoch ID is used in various staking operations to identify the current staking epoch._

### BUY_4_STAKEPOOL

```solidity
uint256 BUY_4_STAKEPOOL
```

Tracks the total amount of ORCY tokens available for the Buy4Stake pool.

_The Buy4Stake pool allows users to purchase ORCY tokens at a 1:1 rate and automatically stake them in a single transaction.
     This variable represents the total funds currently allocated in the Buy4Stake pool._

### constructor

```solidity
constructor(address erc20, address b4s_erc20) public
```

The provided addresses for the staking token (`erc20`) and Buy4Stake token (`b4s_erc20`) must be valid contract addresses and have non-zero total supplies.
        The contract deployer is assigned as the owner of this contract.

_Initializes the StakingOraclyV1 contract with the given ERC20 token addresses for staking and Buy4Stake mechanisms.
     This constructor ensures that both token addresses are valid and sets the deployer (Oracly Team) as the owner._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20 | address | The address of the ERC20 token to be used for staking. It must be a valid ERC20 token contract and have a non-zero total supply. |
| b4s_erc20 | address | The address of the Buy4Stake ERC20 token. It must be a valid ERC20 token contract and have a non-zero total supply. |

### getStakeOf

```solidity
function getStakeOf(address staker) external view returns (uint256 stakeof)
```

Retrieves the current active stake amount for a given staker.

_This function calculates the active stake of a staker by subtracting the total unstaked amount from the total staked amount._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| staker | address | The address of the staker whose active stake is being queried. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| stakeof | uint256 | The amount of active stake held by the staker. |

### getStakerDeposits

```solidity
function getStakerDeposits(address staker, uint256 offset) external view returns (struct Deposit[] deposits, uint256 size)
```

Retrieves a paginated list of deposits made by a specific staker.
        This function helps avoid gas limitations when querying large data sets by allowing the retrieval of deposits in smaller batches (up to 20 deposits per call).

_Implements pagination to efficiently retrieve a manageable number of deposits in each query.
     It returns a maximum of 20 deposits per call, starting from the specified `offset`._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| staker | address | The address of the staker whose deposits are being queried. |
| offset | uint256 | The starting index for pagination, allowing retrieval of deposits starting from that point. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| deposits | struct Deposit[] | An array of `Deposit` structs representing the staker's deposits within the specified range. |
| size | uint256 | The total number of deposits made by the staker, regardless of pagination. |

### getStakerPaidout

```solidity
function getStakerPaidout(address staker, address erc20) external view returns (uint256 paidout)
```

Returns the total amount that has been paid out to a specific staker for a given ERC20 token across all staking rewards.

_This function provides a read-only view of the total accumulated payouts for a staker across all deposits in the specified ERC20 token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| staker | address | The address of the staker whose accumulated payouts are being queried. |
| erc20 | address | The address of the ERC20 token contract for which the payout is being queried. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| paidout | uint256 | The total amount paid out to the staker in the specified ERC20 token. |

### getDepositPaidout

```solidity
function getDepositPaidout(bytes32 depositid, address erc20) external view returns (uint256 paidout)
```

Retrieves the total amount paid out for a specific deposit and ERC20 token.

_This function provides a view into the accumulated payouts for a specific deposit across all staking epochs for a given ERC20 token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositid | bytes32 | The unique identifier of the deposit for which the payout is being queried. |
| erc20 | address | The address of the ERC20 token corresponding to the payout. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| paidout | uint256 | The total amount that has been paid out for the specified deposit in the given ERC20 token. |

### getDepositEpochPaidout

```solidity
function getDepositEpochPaidout(bytes32 depositid, address erc20, uint256 epochid) external view returns (uint256 paidout)
```

Retrieves the total amount already paid out for a given deposit, ERC20 token, and epoch.

_This function provides a view into the accumulated payouts for a specific deposit in a particular epoch and for a specific ERC20 token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositid | bytes32 | The unique identifier of the deposit for which the payout is being queried. |
| erc20 | address | The address of the ERC20 token for which the payout is being queried. |
| epochid | uint256 | The identifier of the epoch for which the payout is being checked. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| paidout | uint256 | The total amount paid out for the specified deposit, ERC20 token, and epoch. |

### getDeposit

```solidity
function getDeposit(bytes32 depositid) external view returns (struct Deposit deposit)
```

Retrieves the details of a specific deposit identified by `depositid`.

_Fetches a `Deposit` struct containing details about the deposit, such as the staker's address, the amount deposited, entry epoch._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositid | bytes32 | The unique identifier of the deposit. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| deposit | struct Deposit | The `Deposit` struct containing the relevant information associated with the given `depositid`. |

### getEpoch

```solidity
function getEpoch(uint256 epochid, address erc20) external view returns (struct Epoch epoch, uint256[3] stakes, uint256[3] stakepool, uint256[2] rewards)
```

Retrieves full information about a specific staking epoch.

_This function provides a view into the current state of a specific staking epoch, including details about stakes, stakepool, and rewards for a given ERC20 token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| epochid | uint256 | The unique identifier of the staking epoch. |
| erc20 | address | The address of the ERC20 token associated with the epoch (optional for rewards stats). |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| epoch | struct Epoch | The Epoch struct containing details such as epochid, start and end dates, and timestamps. |
| stakes | uint256[3] | An array containing the total staked amount, pending incoming stakes, and pending outgoing stakes for the epoch. |
| stakepool | uint256[3] | An array containing the total stakepool amount, pending incoming stakepool, and pending outgoing stakepool for the epoch. |
| rewards | uint256[2] | An array containing the collected and released reward amounts for the epoch with respect to the provided ERC20 token. |

### buy4stake

```solidity
function buy4stake(address erc20, uint256 epochid, uint256 amount) external
```

Allows stakers to purchase ORCY tokens using a specific ERC20 token and automatically stake them in the current epoch.

_Validates the ERC20 contract, the staker's balance, allowance, and ensures the epoch is correct.
     Releases the ORCY tokens from the `BUY_4_STAKEPOOL`,
     Distributes the collected tokens among current stakers and stakes the ORCY tokens on staker's behalf for the current epoch.
     Requirements
     - The `erc20` must be the `BUY_4_STAKE_ERC20_CONTRACT`.
     - The staker must have sufficient balance and allowance for the ERC20 token.
     - The `epochid` must match the current epoch (`ACTUAL_EPOCH_ID`).
     - The `BUY_4_STAKEPOOL` must have enough ORCY tokens to cover the purchase.
     - The staking contract must hold enough ORCY tokens.
     - Only externally-owned accounts (EOAs) can call this function via the `onlyOffChainCallable` modifier.
     Emits:
     - `FATAL_EVENT_INSUFFICIENT_STAKEFUNDS` if the staking contract has insufficient ORCY tokens.
     - `Buy4StakepoolReleased` event for off-chain tracking.
     - `NewEpochStarted` event to indicate the start of a new epoch.
     - `RewardCollected` event when the reward is successfully collected and transferred to the contract.
     - `DepositCreated` event upon successful creation of a new deposit.
     - `IncreaseDepositAmount` event upon successful staking of tokens._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20 | address | The address of the ERC20 token used for the purchase (must match the designated `BUY_4_STAKE_ERC20_CONTRACT`). |
| epochid | uint256 | The ID of the epoch in which the purchased tokens will be staked (must match the current epoch `ACTUAL_EPOCH_ID`). |
| amount | uint256 | The amount of ERC20 tokens the staker wishes to spend on purchasing ORCY tokens. |

### donateBuy4stake

```solidity
function donateBuy4stake(uint256 amount) external
```

Allows stakers to donate ORCY tokens to the buy4stake pool.

_Transfers ORCY tokens from the donator's wallet to the contract, increasing the buy4stake pool.
     The transfer will revert if the staker's balance is insufficient or the allowance granted to this contract is not enough.
     This function can only be called by off-chain EOA, and it uses a non-reentrant modifier to prevent re-entrancy attacks.
     Requirements:
     - The caller must have approved the contract to spend at least `amount` tokens.
     - Only externally-owned accounts (EOAs) can call this function via the `onlyOffChainCallable` modifier.
     - The function is protected against re-entrancy through the `nonReentrant` modifier.
     Emits the `Buy4StakepoolIncreased` event after successfully increasing the pool._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| amount | uint256 | The amount of ORCY tokens the staker wishes to donate. |

### setBuy4stakeERC20

```solidity
function setBuy4stakeERC20(address erc20) external
```

Sets the accepted ERC20 token contract address for the Buy4Stake functionality.
        The specified ERC20 token will be used to purchase staking tokens (ORCY) in the Buy4Stake process.

_This function ensures that the token contract has a non-zero total supply, confirming it is a valid ERC20 token.
     It also enforces that only the contract owner (Oracly Team) can invoke this function.
     The function updates the state variable `BUY_4_STAKE_ERC20_CONTRACT` with the provided ERC20 contract address.
     Emits the `Buy4StakeAcceptedERC20Set` event upon successful execution._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20 | address | The address of the ERC20 token contract that will be accepted for Buy4Stake staking operations. |

### setGatherer

```solidity
function setGatherer(address gatherer) external
```

Updates the authorized gatherer address responsible for collecting staking rewards from bettors' prizes.

_This function can only be called by the contract owner (Oracly Team).
     It checks that the new gatherer is valid contract address.
     This function is protected by `onlyOwner` to ensure that only the contract owner can change the gatherer.
     Emits `AuthorizedGathererSet` event upon successful update of the gatherer address._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gatherer | address | The address to be set as the authorized reward gatherer. |

### stake

```solidity
function stake(uint256 epochid, uint256 amount) external
```

Allows a staker to stake a specified amount of ORCY tokens for a given epoch.

_The staker must have a sufficient ORCY token balance and must approve the contract to transfer the specified `amount` of tokens on their behalf.
     The function uses the `nonReentrant` modifier to prevent re-entrancy attacks.
     Only externally-owned accounts (EOAs) can call this function via the `onlyOffChainCallable` modifier.
     Emits:
     - `DepositCreated` event upon successful creation of a new deposit.
     - `IncreaseDepositAmount` event upon successful staking of tokens._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| epochid | uint256 | The ID of the staking epoch for which the tokens are being staked. |
| amount | uint256 | The number of ORCY tokens the staker wishes to stake. |

### unstake

```solidity
function unstake(uint256 epochid, bytes32 depositid) external
```

Initiates the unstaking process for a specific deposit during the current staking epoch.
        The unstaking process will unlock the staked ORCY tokens in the following epoch.
        During the current epoch, the stake will continue generating rewards until the next epoch starts.

_Implements the unstaking mechanism, ensuring:
     - The staked deposit exists and is owned by the caller.
     - The caller is unstaking within the correct epoch.
     - Prevents reentrancy attacks using the `nonReentrant` modifier.
     - Only externally-owned accounts (EOAs) can call this function via the `onlyOffChainCallable` modifier.
     Emits a `DepositUnstaked` event upon successful unstaking, indicating the deposit ID and the staker who unstaked it._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| epochid | uint256 | The ID of the epoch in which the unstaking is initiated. |
| depositid | bytes32 | The unique identifier of the deposit to be unstaked. |

### withdraw

```solidity
function withdraw(bytes32 depositid) external
```

Allows a staker to withdraw a previously unstaked deposit.

_The function reverts under the following conditions:
     - The deposit does not exist.
     - The caller is not the owner of the deposit.
     - The deposit is still actively staked.
     - The deposit has already been withdrawn.
     - The withdrawal is attempted before the deposit's associated out epoch has ended.
     Requirements:
     - Only externally-owned accounts (EOAs) can invoke this function, enforced by the `onlyOffChainCallable` modifier.
     - The `nonReentrant` modifier ensures that the function cannot be called again until the first execution is complete.
     Emits:
     - `DepositWithdrawn` on successful withdrawal of the deposit.
     - `FATAL_EVENT_INSUFFICIENT_STAKEFUNDS` if the contract lacks sufficient funds to cover the withdrawal._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositid | bytes32 | The unique identifier of the deposit to be withdrawn. |

### claimReward

```solidity
function claimReward(uint256 epochid, bytes32 depositid, address erc20) external
```

Claims the staking reward for a specific deposit within a given epoch.

_This function ensures that the reward claim process is secure and valid by performing several checks:
     - Validates that the provided ERC20 token address corresponds to an allowed reward token.
     - Ensures that the deposit exists and is owned by the caller.
     - Verifies that the provided epoch ID is within the valid range and associated with the deposit.
     - Checks that the reward for this deposit and epoch has not been fully claimed previously.
     - Confirms that the epoch exists and has been initialized correctly.
     - Ensures that the contract has sufficient funds to distribute the reward; otherwise, it emits a fatal error event.
     If all checks pass, the reward is calculated, the deposit is marked as rewarded, and the ERC20 tokens are transferred to the caller.
     Requirements:
     - The caller must own the deposit.
     - The epoch ID must be valid and associated with the deposit.
     - The epoch must be initialized before claiming rewards.
     - Can only be called by off-chain EOA (using `onlyOffChainCallable`).
     Emits:
     - `RewardClaimed` Event emitted when the reward is successfully claimed.
     - `FATAL_EVENT_INSUFFICIENT_REWARDFUNDS` Event emitted when the contract lacks sufficient funds to pay the reward._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| epochid | uint256 | The ID of the staking epoch for which the reward is being claimed. |
| depositid | bytes32 | The unique identifier of the deposit associated with the staker. |
| erc20 | address | The address of the ERC20 token that represents the reward. |

### collectCommission

```solidity
function collectCommission(address bettor, address erc20, uint256 commission) external
```

Allows a designated gatherer to collect staking rewards from a bettor's prize.
        This function facilitates the transfer of ERC20 tokens from the gatherer's balance to the contract and processes the reward distribution.

_This function performs several important checks to ensure secure commission collection:
     - Ensures that the gatherer has a sufficient balance of ERC20 tokens to cover the request for commission collection.
     - Verifies that the gatherer has approved the contract to transfer at least `commission` of ERC20 tokens.
     Requirements:
     - The caller must be an authorized gatherer (`onlyGathererCallable`).
     - The gatherer must have a sufficient balance and allowance for the ERC20 token.
     - The function is protected against reentrancy attacks using the `nonReentrant` modifier.
     Emits:
     - `NewEpochStarted` event to indicate the start of a new epoch.
     - `RewardCollected` event when the commission is successfully collected and transferred to the contract._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| bettor | address | The address of the bettor who paid the commission. |
| erc20 | address | The address of the ERC20 token contract from which tokens will be collected. |
| commission | uint256 | The amount of ERC20 tokens to collect for reward distribution. |

### onlyOffChainCallable

```solidity
modifier onlyOffChainCallable()
```

Restricts function execution to external accounts (EOA) only.

_This modifier ensures that only EOAs (Externally Owned Accounts) can call functions protected by this modifier, preventing contracts from executing such functions.
     The check is performed by verifying that the caller has no code associated with it (not a contract) and by comparing `tx.origin` with `_msgSender()`._

### onlyGathereCallable

```solidity
modifier onlyGathereCallable()
```

Restricts function execution to the authorized funds gatherer.

_This modifier ensures that only the authorized entity, defined by the `AUTHORIZED_COMMISSION_GATHERER` address, can call functions protected by this modifier.
     If an unauthorized entity tries to invoke the function, the transaction is reverted._

### FATAL_EVENT_INSUFFICIENT_REWARDFUNDS

```solidity
event FATAL_EVENT_INSUFFICIENT_REWARDFUNDS(address staker, bytes32 depositid, address erc20, uint256 epochid, uint256 payout)
```

Emitted when there are insufficient reward funds available to fulfill a staker's reward claim.

_Acts as an important signal for stakers, indicating that the contract cannot collect the specific ERC20 token and that a manual EOA (Externally Owned Account) distribution is required._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| staker | address | The address of the staker attempting to claim the reward. |
| depositid | bytes32 | The unique identifier of the staker's deposit. |
| erc20 | address | The address of the ERC20 token associated with the reward being claimed. |
| epochid | uint256 | The ID of the staking epoch in which the reward being claimed. |
| payout | uint256 | The amount of the reward that could not be fulfilled due to insufficient funds. |

### FATAL_EVENT_INSUFFICIENT_STAKEFUNDS

```solidity
event FATAL_EVENT_INSUFFICIENT_STAKEFUNDS(address staker, address erc20, uint256 balance, uint256 amount)
```

Emitted when a staker attempts to withdraw an unstaked deposit, but the contract does not have sufficient balance of the staking token (ORCY) to complete the withdrawal.

_This serves as a crucial signal for stakers to know that the contract is blocked, and a manual EOA distribution is required._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| staker | address | The address of the staker attempting to withdraw funds. |
| erc20 | address | The address of the ERC20 token in which the staked funds are held. |
| balance | uint256 | The current ERC20 token balance held by the contract. |
| amount | uint256 | The amount of ERC20 tokens the staker attempted to withdraw, which the contract could not fulfill. |

### DepositUnstaked

```solidity
event DepositUnstaked(bytes32 depositid, address staker, uint256 epochid)
```

Emitted when a staker unstakes a deposit.

_This event is triggered when a staker initiates the process of unstaking their deposit from a specific epoch._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositid | bytes32 | The unique identifier of the unstaked deposit. |
| staker | address | The address of the staker who unstaked the deposit. |
| epochid | uint256 | The identifier of the epoch during which the deposit was unstaked. |

### DepositWithdrawn

```solidity
event DepositWithdrawn(bytes32 depositid, address staker)
```

Emitted when a staker successfully withdraws their stake deposit.

_This event indicates the complete removal of deposited funds by a staker from the contract._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositid | bytes32 | The unique identifier of the withdrawn deposit. |
| staker | address | The address of the staker who initiated the withdrawal. |

### RewardClaimed

```solidity
event RewardClaimed(bytes32 depositid, address staker, address erc20, uint256 epochid, uint256 payout)
```

Emitted when a staker claims their staking reward for a specific deposit during a particular epoch.

_This event is triggered after a successful reward claim by a staker.
     The event parameters provide detailed information about the deposit, staker, reward token, epoch, and payout amount._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositid | bytes32 | The unique identifier of the deposit for which the reward is claimed. |
| staker | address | The address of the staker who claimed the reward. |
| erc20 | address | The address of the ERC20 token representing the reward. |
| epochid | uint256 | The ID of the epoch in which the reward was earned. |
| payout | uint256 | The amount of reward claimed by the staker. |

### CommissionCollected

```solidity
event CommissionCollected(uint256 epochid, address erc20, address bettor, uint256 commission)
```

Emitted when staking rewards are collected from a bettor's paid commission.

_This event logs the commission collection for a specific epoch and bettor._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| epochid | uint256 | The identifier of the staking epoch during which the commission is collected. |
| erc20 | address | The address of the ERC20 token contract from which tokens are collected. |
| bettor | address | The address of the bettor who paid the commission. |
| commission | uint256 | The amount of ERC20 tokens collected as commission for reward distribution. |

### NewEpochStarted

```solidity
event NewEpochStarted(uint256 epochid, uint256 prevepochid, address erc20, uint256 startedAt, uint256 startDate, uint256 endDate, uint256 stakes, uint256 stakepool)
```

Emitted when a new staking epoch is initiated, signaling the transition between epochs.

_This event provides details about the newly started staking epoch, including its unique identifiers, the ERC20 token being staked, the staking period timestamps, and information about the stakes and stakepool._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| epochid | uint256 | The unique identifier of the newly started staking epoch. |
| prevepochid | uint256 | The unique identifier of the epoch that directly preceded the new one. |
| erc20 | address | The address of the staking token (ORCY) used for stakepool of the epoch. |
| startedAt | uint256 | The timestamp when the new epoch was started. |
| startDate | uint256 | The timestamp representing the start of the new epoch's staking period. |
| endDate | uint256 | The timestamp representing the end of the new epoch's staking period. |
| stakes | uint256 | The total amount of deposits staked in new epoch. |
| stakepool | uint256 | The total amount of tokens staked in the new epoch. |

### IncreaseDepositAmount

```solidity
event IncreaseDepositAmount(bytes32 depositid, address staker, uint256 amount)
```

Emitted when a staker deposits ORCY tokens into the contract, either by creating a new deposit or increasing an existing one.

_This event is emitted every time a staker deposits ORCY tokens into the contract, whether it is a new deposit or an increase to an existing one._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositid | bytes32 | The unique identifier of the deposit being created or increased. |
| staker | address | The address of the staker making the deposit. |
| amount | uint256 | The amount of ORCY tokens deposited. |

### DepositCreated

```solidity
event DepositCreated(bytes32 depositid, uint256 epochid, address staker, uint256 createdAt, address erc20)
```

Emitted when a new stake deposit is created in the contract.

_This event is triggered whenever a staker successfully creates a new deposit.
     It provides details about the deposit including the unique deposit ID, epoch ID, staker's address, timestamp of creation, and the ERC20 token being staked._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| depositid | bytes32 | Unique identifier for the deposit. |
| epochid | uint256 | The ID of the staking epoch in which the deposit is created. |
| staker | address | The address of the staker who made the deposit. |
| createdAt | uint256 | The timestamp when the deposit is created. |
| erc20 | address | The address of the staking token (ORCY) being staked in the deposit. |

### AuthorizedGathererSet

```solidity
event AuthorizedGathererSet(address gatherer)
```

Emitted when a new gatherer is authorized for the contract.

_This event is triggered whenever the contract owner (Oracly Team) assigns a new gatherer._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gatherer | address | The address of the authorized gatherer. |

### Buy4StakeAcceptedERC20Set

```solidity
event Buy4StakeAcceptedERC20Set(address erc20)
```

This event is emitted when the ERC20 token accepted for the Buy4Stake functionality is changed.
        It indicates that a new ERC20 token will now be used for acquiring ORCY tokens via staking.

_This event is critical for tracking updates to the ERC20 token used in Buy4Stake operations._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20 | address | The address of the new ERC20 token that is now accepted for Buy4Stake. |

### Buy4StakepoolIncreased

```solidity
event Buy4StakepoolIncreased(address erc20, uint256 stakepool, uint256 amount)
```

Emitted when the Buy4Stake pool balance is increased.

_This event signals that more funds have been added to the Buy4Stake pool.
     The new total balance of the Buy4Stake pool and the amount that was added._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20 | address | The address of the staking token (ORCY) being added to the Buy4Stake pool. |
| stakepool | uint256 | The new balance of the Buy4Stake pool after the increase. |
| amount | uint256 | The amount added to the Buy4Stake pool. |

### Buy4StakepoolReleased

```solidity
event Buy4StakepoolReleased(address erc20, uint256 stakepool, uint256 amount)
```

Emitted when funds are released from the Buy4Stake pool.

_This event logs the details of funds being released from the Buy4Stake pool, including the updated stake pool balance and the amount released._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20 | address | The address of the staking token (ORCY) associated with the release. |
| stakepool | uint256 | The updated balance of the stake pool after the funds are released. |
| amount | uint256 | The amount of ERC20 tokens that were released from the pool. |

