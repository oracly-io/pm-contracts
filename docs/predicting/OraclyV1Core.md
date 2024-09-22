# Solidity API

## OraclyV1Core

Core contract for handling prediction games, managing rounds, and calculating payouts.

_Provides essential logic for creating and managing prediction rounds, fetching price data, determining outcomes, and distributing prize pools.
     This contract is abstract and should be inherited by other contracts like OraclyV1, which will handle bettor interactions and protocol logic.
     Key functionalities:
     - Creation of new prediction rounds.
     - Fetching and validation of price data from oracles.
     - Determination of winners based on price movements.
     - Calculation and distribution of prize pools among winning participants.
     Note: This contract integrated with secure price oracles like Chainlink for price feeds._

### VIGORISH_PERCENT

```solidity
uint8 VIGORISH_PERCENT
```

The percentage taken as commission for stakers and mentors from the prize.

_Vigorish is a commission applied to the prize. It is set as a constant 1%._

### _predictions

```solidity
mapping(bytes32 => struct Prediction) _predictions
```

Mapping to store predictions for each round.

_Maps a round ID (bytes32) to a specific Prediction object. This stores the predictions made by bettors for a particular round._

### _rounds

```solidity
mapping(bytes32 => struct Round) _rounds
```

Mapping to store round information.

_Maps a round ID (bytes32) to a specific Round object that holds all the relevant information for the round, such as start time, end time, and other metadata._

### __FATAL_INSUFFICIENT_PRIZEPOOL_ERROR__

```solidity
mapping(address => bool) __FATAL_INSUFFICIENT_PRIZEPOOL_ERROR__
```

Tracks ERC20 tokens that have triggered a fatal error due to insufficient funds in the prize pool.

_This mapping stores a boolean flag for each ERC20 token address.
     When the flag is set to true, it indicates that the corresponding token's prize pool has insufficient funds, causing a fatal error.
     Mapping:
     - `address`: The address of the ERC20 token contract.
     - `bool`: A flag where `true` indicates a fatal insufficient prize pool error for that token._

### METAORACLY_CONTRACT

```solidity
address METAORACLY_CONTRACT
```

Immutable address of the MetaOracly contract, which serves as a registry of all games within the Oracly protocol.

_This immutable variable stores the address of the MetaOracly contract. Once set, it cannot be modified, ensuring the integrity of the contract registry across the protocol.
     This contract registry allows interaction with all possible games on the protocol._

### constructor

```solidity
constructor(address metaoracly_address) internal
```

Initializes the OraclyV1Core contract by setting the MetaOracly contract address.

_This constructor is essential as the MetaOracly contract acts as the source for retrieving game data, price feeds, and other relevant information critical to the OraclyV1Core functionality._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| metaoracly_address | address | The address of the MetaOracly contract that serves as the data provider for the game. |

### getPrediction

```solidity
function getPrediction(bytes32 predictionid) external view returns (struct Prediction prediction)
```

Fetches a specific `Prediction` based on the provided prediction ID.

_Returns a `Prediction` struct that contains details about the prediction.
     Useful for retrieving prediction information like the predicted outcome, amount deposited, and bettor details._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| predictionid | bytes32 | The unique ID of the prediction to retrieve. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| prediction | struct Prediction | A `Prediction` struct containing details such as the prediction position, bettor, and deposited amount. |

### getRound

```solidity
function getRound(bytes32 roundid) external view returns (struct Round round, uint256[4] prizepools, uint256[4] bettors, uint256[4] predictions)
```

Retrieves details about a specific prediction round.

_This function provides detailed information about a given round, including:
     - Round data (`Round` memory)
     - Total prize pools for the round and individual outcomes [Total, Down, Up, Zero] (`uint[4]`)
     - Total number of bettors for the round and individual outcomes [Total, Down, Up, Zero] (`uint[4]`)
     - Total number of predictions for the round and individual outcomes [Total, Down, Up, Zero] (`uint[4]`)
     Requirements:
     - The `roundid` must be valid and correspond to an existing round._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The unique identifier of the prediction round. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| round | struct Round | Information about the round as a `Round` struct. |
| prizepools | uint256[4] | Array of four `uint` values:        [0]: Total deposited amount in the ERC20 token.        [1]: Deposited amount for the Down outcome.        [2]: Deposited amount for the Up outcome.        [3]: Deposited amount for the Zero outcome. |
| bettors | uint256[4] | Array of four `uint` values:        [0]: Total number of participants in the round.        [1]: Number of participants who predicted Down.        [2]: Number of participants who predicted Up.        [3]: Number of participants who predicted Zero. |
| predictions | uint256[4] | Array of four `uint` values:        [0]: Total number of predictions made.        [1]: Number of predictions for Down.        [2]: Number of predictions for Up.        [3]: Number of predictions for Zero. |

### getGameRounds

```solidity
function getGameRounds(bytes32 gameid, uint256 offset) external view returns (bytes32[] roundids, uint256 size)
```

Retrieves a paginated list of Round IDs for a specified game.
        This function is useful for fetching game round IDs in batches.

_This function returns an array of round IDs and the total number of rounds associated with the given game.
     The returned array contains at most 20 round IDs starting from the specified offset to support pagination._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gameid | bytes32 | The unique identifier for the game. |
| offset | uint256 | The starting index from which round IDs will be fetched (for pagination). |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundids | bytes32[] | An array of up to 20 round IDs starting from the given offset. |
| size | uint256 | The total number of rounds in the game, which is helpful for paginating through all rounds. |

### getRoundPredictions

```solidity
function getRoundPredictions(bytes32 roundid, uint8 position, uint256 offset) external view returns (struct Prediction[] predictions, uint256 size)
```

Retrieves a paginated list of predictions for a specific round and position.

_Returns up to 20 `Prediction` structs starting from the specified `offset`.
     If `position` is set to 0, predictions for all positions are retrieved.
     Also returns the total number of predictions matching the criteria._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The unique identifier for the round to retrieve predictions from. |
| position | uint8 | The prediction position to filter by (1 for Down, 2 for Up, 3 for Zero). A value of 0 retrieves predictions for all positions. |
| offset | uint256 | The starting index for pagination. Use this to fetch predictions in batches. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| predictions | struct Prediction[] | An array of `Prediction` structs representing the matching predictions. |
| size | uint256 | The total number of predictions available for the specified round and position. |

### getBettorPredictions

```solidity
function getBettorPredictions(address bettor, uint8 position, uint256 offset) external view returns (struct Prediction[] predictions, uint256 size)
```

Retrieves a paginated list of a bettor's predictions for a specific position.

_Returns up to 20 `Prediction` structs starting from the specified `offset`.
     If `position` is set to 0, predictions for all positions are retrieved.
     Also returns the total number of predictions matching the criteria._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| bettor | address | The address of the bettor whose predictions are being queried. |
| position | uint8 | The predicted outcome (1 for Down, 2 for Up, 3 for Zero). A value of 0 retrieves predictions for all positions. |
| offset | uint256 | The starting index for pagination of the results. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| predictions | struct Prediction[] | An array of `Prediction` structs limited to 20 entries. |
| size | uint256 | The total number of predictions for the bettor and specified position. |

### isBettorInRound

```solidity
function isBettorInRound(address bettor, bytes32 roundid) external view returns (bool inround)
```

Checks whether a specific bettor has participated in a given round.
        This function is used to verify if the bettor has placed a prediction in the provided round.

_This function checks participation in a specific prediction round using the bettor's address and the unique round ID._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| bettor | address | The address of the bettor to check for participation. |
| roundid | bytes32 | The unique identifier of the round. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| inround | bool | `true` if the bettor participated in the round, `false` otherwise. |

### getBettor

```solidity
function getBettor(address bettor, address erc20) external view returns (address bettorid, uint256[4] predictions, uint256[4] deposits, uint256[4] payouts)
```

Retrieves information about a specific bettor's activity for a given ERC20 token.

_This function provides detailed information about the bettor's predictions, including:
     - Bettor's address (`bettorid`) if found.
     - Total number of predictions and individual outcomes [Total, Up, Down, Zero] (`uint[4]`).
     - Total deposited amounts for predictions and individual outcomes [Total, Up, Down, Zero] (`uint[4]`).
     - Total payouts received for predictions and individual outcomes [Total, Up, Down, Zero] (`uint[4]`).
     - If `bettor` have never interacted with the provided `erc20` token for predictions deposits and payouts returns zeros.
     - If `bettor` have never interacted with the cotract it returns zeros._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| bettor | address | The address of the bettor to query. |
| erc20 | address | The address of the ERC20 token used for the bettor's predictions. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| bettorid | address | The address of the bettor (or zero address if no predictions are found). |
| predictions | uint256[4] | Array of four `uint` values:        [0]: Total number of predictions made.        [1]: Number of predictions for Up.        [2]: Number of predictions for Down.        [3]: Number of predictions for Zero. |
| deposits | uint256[4] | Array of four `uint` values:        [0]: Total amount deposited using the ERC20 token.        [1]: Amount deposited for Up predictions.        [2]: Amount deposited for Down predictions.        [3]: Amount deposited for Zero predictions. |
| payouts | uint256[4] | Array of four `uint` values:        [0]: Total payout amount received for the ERC20 token.        [1]: Payout amount received for Up predictions.        [2]: Payout amount received for Down predictions.        [3]: Payout amount received for Zero predictions. |

### _updatePrediction

```solidity
function _updatePrediction(struct Game game, bytes32 roundid, uint8 position, uint256 amount, address bettor) internal
```

Updates the bettor's prediction or creates a new one if it doesn't exist for the current game round.

_This function handles both creating new predictions and updating existing ones.
     It adjusts the bettor's token deposit for their prediction and ensures that internal mappings remain consistent.
     It also emits an event when a prediction is created or updated.
     Requirements:
     - The bettor's address must not be zero.
     - `amount` must be greater than zero.
     Emits:
     - `PredictionCreated` event if a new prediction is created.
     - `IncreasePredictionDeposit` event if the bettor's prediction is updated._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| game | struct Game | The game structure associated with the prediction. |
| roundid | bytes32 | The unique identifier of the round within the game. |
| position | uint8 | The predicted outcome for the round (1 for Down, 2 for Up, 3 for Zero). |
| amount | uint256 | The amount of tokens being deposited for the prediction. |
| bettor | address | The address of the bettor making the prediction. |

### _updateRound

```solidity
function _updateRound(struct Game game, bytes32 roundid, uint8 position, uint256 amount) internal
```

Updates a round's state by creating a new round if necessary and updating its prize pool.

_This function checks if the round already exists; if not, it initializes a new round.
     Then, based on the provided position and amount, it increments the respective prize pool.
     The position represents the bettor's predicted price movement direction (1 for Down, 2 for Up, 3 for Zero) within the round.
     The prize pool is updated accordingly based on the amount wagered for the specified position.
     Emits:
     - `RoundCreated` event upon successful creation of the round.
     - `RoundPrizepoolAdd` event to signal that the prize pool has been updated._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| game | struct Game | The struct representing the game associated with the round. |
| roundid | bytes32 | The unique identifier for the round to be updated. |
| position | uint8 | The prediction position chosen by the bettor (1 for Down, 2 for Up, 3 for Zero). |
| amount | uint256 | The amount of tokens being wagered on the position. |

### _isResolved

```solidity
function _isResolved(bytes32 roundid) internal view returns (bool resolved)
```

Checks whether a specific prediction round has been resolved.

_This function checks the status of a round using its unique ID.
     It is marked as `internal`, so it can only be accessed within this contract or derived contracts.
     The status of resolution implies that the round's outcome have been settled._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The unique identifier (ID) of the round to check. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| resolved | bool | Returns `true` if the round is resolved, meaning outcome have been settled, otherwise returns `false`. |

### _resolve

```solidity
function _resolve(bytes32 roundid, uint80 exitPriceid) internal
```

Resolves an round by determining the final outcome based on the provided exit price.

_This function calculates the outcome of a prediction round using the given `exitPriceid`, which must be fetched from an external oracle.
     Possible outcomes:
     - Down: The outcome is resolved as "Down" if the `Exit Price` is lower than the `Entry Price`. This indicates a price decrease during the round.
     - Up: The outcome is resolved as "Up" if the `Exit Price` is higher than the `Entry Price`, indicating a price increase during the round.
     - Zero: The outcome is resolved as "Zero" if the `Exit Price` is equal to the `Entry Price`
     - No Contest: All participants predicted the same outcome (either all Up, all Down, or all Zero), making it impossible to determine winners.
     - No Contest: None of the participants correctly predicted the outcome.
     - No Contest: The round was not resolved within the allowed time limit.
     This function permanently finalizes the state of the round and should only be called when the round is in settlement phase and unresolved.
     Requirements:
     - The round must be unresolved state.
     - The `exitPriceid` must be valid and `Exit Price` from the oracle.
     Emits:
     - `RoundResolvedNoContest`: If the round concludes with a "No Contest" outcome.
     - `RoundResolved`: If the round ends with a valid outcome: Down, Up, or Zero._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The unique identifier of the round being resolved. |
| exitPriceid | uint80 | The ID representing the price used to determine the final outcome of the round. |

### _computeRoundid

```solidity
function _computeRoundid(uint16 phaseId, uint64 aggregatorRoundId) internal pure returns (uint80 roundId)
```

Computes a unique round ID by combining a phase ID with an aggregator round ID.
        This ensures that the round ID is unique across different phases of the price feed aggregator.

_The round ID is computed by shifting the 16-bit `phaseId` left by 64 bits and then adding the 64-bit `aggregatorRoundId`.
     This results in a single 80-bit value representing the unique round ID.
     The left shift ensures that the `phaseId` occupies the higher bits and does not overlap with the `aggregatorRoundId`._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| phaseId | uint16 | The 16-bit ID representing the phase of the price feed aggregator. Each phase consists of multiple rounds. |
| aggregatorRoundId | uint64 | The 64-bit round ID provided by the underlying price feed aggregator for a specific phase. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundId | uint80 | A unique 80-bit round ID that is a combination of the phase and aggregator round IDs. |

### _claimPrediction

```solidity
function _claimPrediction(bytes32 roundid, bytes32 predictionid, address erc20) internal returns (uint256 payout, uint256 commission)
```

Claims the payout for a bettor's prediction in a specific round with a given ERC20 token.

_This function ensures that all necessary checks are performed before allowing a claim:
     - Verifies that claimd ERC20 matches round ERC20 address.
     - Ensures the provided prediction ID related the round ID.
     - Checks that the prediction is associated with the round.
     - Confirms the caller is the original bettor who made the prediction.
     - Ensures the prediction hasn't already been claimed.
     - Validates that the round has been resolved.
     - Confirms that the prediction's position matches the final resolution of the round or handles a "No Contest" scenario.
     If all validations pass, the function calculates the payout and the commission, updates the prediction's status to claimed, and returns both the payout and commission values.
     Emits:
     - `PredictionClaimed` event emitted when a bettor claims the payout for prediction.
     - `RoundPrizepoolReleased` event on a successful prize pool release.
     - `RoundArchived` event once the round is archived._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The unique identifier of the round to which the prediction belongs. |
| predictionid | bytes32 | The unique identifier of the prediction for which the payout is claimed. |
| erc20 | address | The address of the ERC20 token in which the payout is requested. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| payout | uint256 | The amount awarded to the bettor based on the prediction. |
| commission | uint256 | The commission deducted from the payout for stakers and mentors. |

### RoundResolvedNoContest

```solidity
event RoundResolvedNoContest(bytes32 roundid, address resolvedBy, uint256 resolvedAt, uint8 resolution)
```

Emitted when a round is resolved as a "No Contest", allowing participants to reclaim their funds.

_This event is triggered when the outcome of a round cannot be determined due to conditions that prevent a clear resolution._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The unique identifier of the round that has been resolved as "No Contest". |
| resolvedBy | address | The address of the EOA that initiated the resolution of the round. |
| resolvedAt | uint256 | The Unix timestamp at which the round was resolved. |
| resolution | uint8 | The constant value representing the "No Contest" outcome, a predefined value (4 for No Contest). |

### RoundResolved

```solidity
event RoundResolved(bytes32 roundid, struct Price exitPrice, address resolvedBy, uint256 resolvedAt, uint8 resolution)
```

Emitted when a prediction round is resolved and its outcome is determined.

_This event logs important information about the resolution of a round, including the round ID, the exit price, the bettor who triggered the resolution, and the final outcome of the round._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The unique identifier of the resolved prediction round. |
| exitPrice | struct Price | The price used to calculate the result of the round, fetched from Chainlink's price feed. |
| resolvedBy | address | The address of the bettor that triggered the resolution of the round. |
| resolvedAt | uint256 | The timestamp (in seconds) when the round was resolved. |
| resolution | uint8 | The outcome of the round: (1 for Down, 2 for Up, 3 for Zero) |

### RoundArchived

```solidity
event RoundArchived(bytes32 roundid, uint256 archivedAt)
```

This event logs the archival of the round, marking the end of the round's lifecycle.

_Emitted when a round is archived._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The unique identifier of the archived round. |
| archivedAt | uint256 | The timestamp when the round was archived. |

### RoundCreated

```solidity
event RoundCreated(bytes32 roundid, bytes32 gameid, address openedBy, address erc20, address pricefeed, struct Price entryPrice, uint256 startDate, uint256 lockDate, uint256 endDate, uint256 expirationDate, uint256 openedAt)
```

Emitted when a new prediction round is created.

_This event indicates the creation of a new prediction round within the ongoing game.
     It includes essential details such as the round ID, associated game, the ERC20 token for predictions, the price feed contract for asset price, and the timestamps defining round phases._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The unique identifier of the created round. |
| gameid | bytes32 | The unique identifier of the game to which the round is linked. |
| openedBy | address | The address of the entity EOA that initiated the round creation. |
| erc20 | address | The address of the ERC20 token contract used for placing predictions in the round. |
| pricefeed | address | The address of the price feed contract used to retrieve the asset price for predictions. |
| entryPrice | struct Price | The initial price of the asset at the start of the round, retrieved from the price feed. |
| startDate | uint256 | The timestamp (in seconds since Unix epoch) when the round starts. |
| lockDate | uint256 | The timestamp when the prediction phase ends and no more entries can be placed. |
| endDate | uint256 | The timestamp when the round ends and the outcome of the price movement can be determined. |
| expirationDate | uint256 | The deadline timestamp by which the round must be settled, or else it defaults to 'No Contest'. |
| openedAt | uint256 | The timestamp when the round was created (when first prediction entered the round). |

### RoundPrizepoolAdd

```solidity
event RoundPrizepoolAdd(bytes32 roundid, address erc20, uint8 position, uint256 amount)
```

Emitted when funds are added to a specific position's prize pool for a given round.
        This event tracks the addition of tokens to a prize pool, which is associated with a particular round and a specific position (Down, Up, Zero).

_The position can have three possible values: (1 for Down, 2 for Up, 3 for Zero)_

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The ID of the round to which the prize pool is associated. |
| erc20 | address | The address of the ERC20 token that is being added to the prize pool. |
| position | uint8 | The position (Down, Up, or Zero) in the prize pool where the tokens are added. |
| amount | uint256 | The amount of tokens being added to the prize pool for the given position. |

### RoundPrizepoolReleased

```solidity
event RoundPrizepoolReleased(bytes32 roundid, uint256 payout, uint256 commission)
```

Emitted when funds are released to a bettor for a given round.
        This event tracks the release of tokens from the prize pool for a particular round, including the bettor's payout and any commission.

_The `payout` includes the bettor's share of the prize pool, which is calculated proportional to their contribution.
     The `commission` is a amount deducted from the prize, which is allocated to stakers and mentors.
     The event helps to audit the flow of funds for transparency and tracking of prize distribution._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| roundid | bytes32 | The ID of the round from which the funds are being released. |
| payout | uint256 | The total payout being released to the bettor, after deducting the commission. |
| commission | uint256 | The commission amount deducted from the prize, allocated to stakers and mentors. |

### PredictionCreated

```solidity
event PredictionCreated(bytes32 predictionid, bytes32 roundid, address bettor, uint8 position, uint256 createdAt, address erc20, bytes32 gameid)
```

Emitted when a new prediction is created in the game.

_This event is triggered whenever a bettor makes a new prediction.
     It logs the details such as the round, bettor's address, and the prediction outcome._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| predictionid | bytes32 | The unique identifier of the created prediction. |
| roundid | bytes32 | The ID of the round the prediction belongs to. |
| bettor | address | The address of the bettor who created the prediction. |
| position | uint8 | The predicted outcome. (1 for Down, 2 for Up, 3 for Zero) |
| createdAt | uint256 | The timestamp (in seconds since the Unix epoch) when the prediction was created. |
| erc20 | address | The address of the ERC20 token used as deposit for the prediction. |
| gameid | bytes32 | The ID of the game instance that the prediction is associated with. |

### IncreasePredictionDeposit

```solidity
event IncreasePredictionDeposit(bytes32 predictionid, uint256 deposit)
```

Emitted when a bettor deposits tokens within the round.

_This event is emitted every time a bettor deposits tokens, either by creating a new prediction or increasing an existing one._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| predictionid | bytes32 | The unique identifier (ID) of the prediction being created or increased. |
| deposit | uint256 | The amount of tokens deposited. |

### PredictionClaimed

```solidity
event PredictionClaimed(bytes32 predictionid, address bettor, address erc20, uint256 payout, uint256 commission)
```

Emitted when a bettor claims the payout for prediction.

_This event is triggered when a prediction is successfully claimed, detailing the bettor, payout, and commission._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| predictionid | bytes32 | The unique identifier of the claimed prediction. |
| bettor | address | The address of the bettor who is claiming the prediction payout. |
| erc20 | address | The ERC20 token used for both the payout and the commission. |
| payout | uint256 | The amount of tokens paid out to the bettor as a reward for the prediction. |
| commission | uint256 | The amount of tokens deducted from the payout as commission. |

