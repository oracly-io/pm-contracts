# Solidity API

## MentoringOraclyV1

This contract establishes the mentorship structure, including mentor registration, reward distribution based on Proteges' success, and relationship tracking within the Oracly Protocol.

_Implements a mentorship system within the Oracly Protocol, allowing experienced bettors (Mentors) to guide less experienced bettors (Proteges) through prediction games.
     The contract manages mentor registrations, tracks mentor-protege relationships, and handles the distribution of Mentoring Rewards.
     Mentoring Rewards are calculated as a fixed percentage (0.25%) of the Proteges' winnings from prediction games, encouraging knowledge sharing within the ecosystem._

### MENTOR_COMMISSION_PERCENTAGE

```solidity
uint8 MENTOR_COMMISSION_PERCENTAGE
```

Percentage of the total Prediction Reward allocated to Mentoring Rewards, expressed in basis points.

_The value is set in basis points, where 1% equals 100 basis points.
     Constant is set to `25` (0.25%) of the commission is allocated to mentoring rewards._

### __FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__

```solidity
mapping(address => bool) __FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__
```

Tracks whether the contract is experiencing insufficient reward funds for distribution.

_This flag is set to prevent further operations when reward funds are insufficient._

### AUTHORIZED_COMMISSION_GATHERER

```solidity
address AUTHORIZED_COMMISSION_GATHERER
```

The address of the authorized funds gatherer for the contract.

_This is the address responsible for gathering mentoring rewards from the bettor's prize on withdrawal and passing them to the contract for further distribution to mentors._

### constructor

```solidity
constructor() public
```

The deployer will automatically be granted the required permissions to gather funds into the contract.

_Constructor that initializes the contract, setting the deployer as the owner (Oracly Team) and granting them the role of `AUTHORIZED_COMMISSION_GATHERER`.
     The contract deployer is automatically assigned as the owner (Oracly Team) of the contract through the `Ownable` constructor.
     Additionally, the deployer is designated as the `AUTHORIZED_COMMISSION_GATHERER`, a role required for gathering funds._

### getMentor

```solidity
function getMentor(address mentor, address erc20) external view returns (address mentorid, uint256 circle, uint256 rewards, uint256 payouts, uint256 createdAt, uint256 updatedAt)
```

Retrieves information about a mentor including proteges, rewards, and payout history for a given ERC20 token.

_Returns detailed mentor information for the specified ERC20 token, including associated proteges and financial data._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| mentor | address | The address of the mentor. |
| erc20 | address | The address of the ERC20 token. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| mentorid | address | the address of the mentor. |
| circle | uint256 | The number of proteges associated with the mentor. |
| rewards | uint256 | The total rewards earned by the mentor in the specified ERC20 token. |
| payouts | uint256 | The total payouts made to the mentor in the specified ERC20 token. |
| createdAt | uint256 | The timestamp when the mentor was created. |
| updatedAt | uint256 | The timestamp when the mentor's information was last updated. |

### getProtege

```solidity
function getProtege(address protege, address erc20) external view returns (address protegeid, address mentor, uint256 earned, uint256 earnedTotal, uint256 createdAt, uint256 updatedAt)
```

Retrieves detailed information about a specific Protege, including their mentor, earned rewards for a given ERC20 token, and timestamps for creation and updates.

_This function is a view function that returns the following information about the Protege:
     - Protege's address
     - Mentor's address
     - Earned rewards for the ERC20 token with the mentor
     - Total earned rewards for the ERC20 token across all mentors
     - Timestamps for creation and last update_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| protege | address | The address of the Protege whose information is being retrieved. |
| erc20 | address | The address of the ERC20 token for which reward details are queried. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| protegeid | address | The Protege's address, if found. |
| mentor | address | The address of the Protege's mentor. |
| earned | uint256 | The rewards earned by the Protege for the specified ERC20 token with their mentor. |
| earnedTotal | uint256 | The total rewards earned by the Protege for the specified ERC20 token. |
| createdAt | uint256 | The timestamp when the Protege was first created. |
| updatedAt | uint256 | The timestamp when the Protege's information was last updated. |

### getMentorProteges

```solidity
function getMentorProteges(address mentor, uint256 offset) external view returns (address[] proteges, uint256 size)
```

Retrieves a paginated list of Proteges associated with a specific Mentor.

_This function returns a list of Protege addresses along with the total number of Proteges linked to the given Mentor.
     The results can be paginated by specifying an offset._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| mentor | address | The address of the Mentor whose Proteges are being queried. |
| offset | uint256 | The starting index for the pagination of the Protege list. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| proteges | address[] | An array of addresses representing the Proteges. |
| size | uint256 | The total number of Proteges associated with the Mentor. |

### getProtegeMentorEarned

```solidity
function getProtegeMentorEarned(address protege, address erc20, address mentor) external view returns (uint256 earned)
```

Returns the amount of ERC20 tokens earned by a mentor from a specified protege.

_This function retrieves the accumulated earnings a mentor has gained from their protege in the specified ERC20 token._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| protege | address | The address of the protege whose earnings are being queried. |
| erc20 | address | The address of the ERC20 token for which the earnings are being checked. |
| mentor | address | The address of the mentor who has earned the tokens. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| earned | uint256 | The total amount of ERC20 tokens earned by the mentor from the protege. |

### setGatherer

```solidity
function setGatherer(address gatherer) external
```

Sets the authorized funds gatherer address.
        Only callable by the contract owner (Oracly Team).

_Updates the address authorized to gather funds. This function can only be executed by the contract owner (Oracly Team).
     It ensures that the new gatherer is valid contract address.
     Emits `AuthorizedGathererSet` event upon successful update of the gatherer address.
     This function is protected by `onlyOwner` to ensure that only the contract owner can change the gatherer._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gatherer | address | The new address to be set as the gatherer. |

### joinMentor

```solidity
function joinMentor(address mentor) external
```

Allows a proteges to join a mentor-protege relationship.

_This function is external and non-reentrant, ensuring it can only be called from outside the contract and preventing re-entrancy attacks.
     The `onlyOffChainCallable` modifier restricts access to off-chain EOA to prevent internal or contract-based invocation.
     Emits an `JoinedMentor` event upon successful join._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| mentor | address | The address of the mentor that the protege wants to join. |

### expelProtege

```solidity
function expelProtege(address protege) external
```

Removes a Protege from the Mentor's circle.
        This function can only be called by the Mentor who currently mentors the Protege.

_Requirements:
     - The caller of the function (the `mentor`) must be the current mentor of the `protege`.
     - `protege` must be currently associated with the calling `mentor`.
     Emits an `ProtegeExpelled` event upon successful removal._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| protege | address | The address of the Protege to be expelled from the Mentor's circle. |

### transferProtege

```solidity
function transferProtege(address protege, address mentor) external
```

Transfers a protege from one mentor to another.
        The caller must be the current mentor of the protege.

_This function ensures that a protege's mentorship is updated by transferring them from one mentor to another.
     The transaction is protected against reentrancy attacks and can only be called from an off-chain context.
     Emits an `ProtegeExpelled` event upon successful removal from an old mentor.
     Emits an `JoinedMentor` event upon successful join to a new mentor._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| protege | address | The address of the protege being transferred. |
| mentor | address | The address of the new mentor to which the protege is assigned. |

### calculateReward

```solidity
function calculateReward(address protege, uint256 amount) external view returns (uint256 reward)
```

Calculates the Mentoring Reward for a specific protege based on a provided amount.

_This function is an external view override, meaning it can be called externally to view the calculated reward for a protege without any gas fees for state changes._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| protege | address | The address of the protege whose reward is being calculated. |
| amount | uint256 | The amount used as the base for the reward calculation. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| reward | uint256 | The calculated Mentoring Reward for the given protege and amount. |

### collectCommission

```solidity
function collectCommission(address protege, address erc20, uint256 commission) external
```

Collects a reward from commission of a protege's prize and distributes it to the corresponding Mentoring Reward pool.
        The function facilitates the transfer of rewards from the protege to the mentor's reward pool using the specified ERC20 token.

_Collects a reward from commission of a protege's prize and distributes it to the associated mentor.
     Requirements:
     - `protege` and `sender` must be valid.
     - `commission` must be greater than zero.
     - The specified ERC20 token must not be blocked for reward collection.
     - The caller must have sufficient ERC20 token balance and allowance.
     - The function ensures reentrancy protection and restricts access using the `onlyGathereCallable` modifier.
     Emits a `MentorfundsAdded` event upon successful reward distribution to the mentor._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| protege | address | The address of the protege, who is receiving mentorship. |
| erc20 | address | The address of the ERC20 token used for the reward distribution. |
| commission | uint256 | The amount of the ERC20 token to collect and distribute as the reward. |

### claimReward

```solidity
function claimReward(address erc20) external
```

Allows the Mentor (caller) to claim their accumulated Mentoring Reward for a specified ERC20 token.

_This function transfers the accumulated Mentoring Reward for the specified ERC20 token to the caller.
     Requirements:
      - `erc20` must be a valid ERC20 token address.
      - The caller must have accumulated Mentoring Rewards for the specified ERC20 token.
      - The contract must hold enough balance of the specified ERC20 token to cover the reward payout.
     Emits:
      - `MentorRewardPayout` event upon a successful claim.
      - `FATAL_EVENT_INSUFFICIENT_REWARDFUNDS` event if the contract lacks sufficient funds._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20 | address | The address of the ERC20 token for which the reward is being claimed. |

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
event FATAL_EVENT_INSUFFICIENT_REWARDFUNDS(address mentor, address erc20, uint256 balance, uint256 payout)
```

Emitted when the reward pool does not have sufficient funds to cover a mentor's earnings payout.
        This signals a critical issue as the reward pool is depleted, preventing a successful distribution of rewards.

_This event provides transparency on the failure to payout a mentor due to insufficient reward funds.
     It includes information on the affected mentor, the ERC20 token involved, the current reward fund balance, and the attempted payout amount.
     It acts as an important signal for mentors to know that the contract is blocked from collecting specific ERC20 tokens and that a manual EOA distribution is required._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| mentor | address | The address of the mentor who should have received the payout. |
| erc20 | address | The address of the ERC20 token representing the reward currency. |
| balance | uint256 | The current balance of the reward pool for the given ERC20 token. |
| payout | uint256 | The intended amount to be paid to the mentor. |

### JoinedMentor

```solidity
event JoinedMentor(address protege, address mentor)
```

Emitted when a protege successfully joins a mentor.

_This event is triggered when a protege is associated with a mentor in the Oracly Protocol._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| protege | address | The address of the protege who joins the mentor. |
| mentor | address | The address of the mentor that the protege is joining. |

### ProtegeExpelled

```solidity
event ProtegeExpelled(address protege, address mentor)
```

Emitted when a mentor expels a protege.

_This event is triggered when a mentor decides to disassociate a protege from their mentorship._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| protege | address | The address of the protege being expelled. |
| mentor | address | The address of the mentor performing the expulsion. |

### MentorfundsAdded

```solidity
event MentorfundsAdded(address protege, address mentor, address erc20, uint256 reward)
```

Emitted when a Protege withdraws their prize and 0.25% is assigned to the Mentor's reward.

_This event is triggered whenever a Protege contributes funds to their Mentor._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| protege | address | The address of the Protege who earned the funds. |
| mentor | address | The address of the Mentor receiving the reward. |
| erc20 | address | The ERC20 token contract address used for the reward transaction. |
| reward | uint256 | The amount of Mentor's reward in ERC20 tokens. |

### MentorRewardPayout

```solidity
event MentorRewardPayout(address mentor, address erc20, uint256 payout)
```

Emitted when a Mentor claims and receives a payout of their accumulated Mentoring Rewards.

_This event provides details about the Mentor, the ERC20 token used for the payout, and the payout amount._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| mentor | address | The address of the Mentor who is receiving the payout. |
| erc20 | address | The address of the ERC20 token contract used for the payout. |
| payout | uint256 | The amount of ERC20 tokens paid to the Mentor. |

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

