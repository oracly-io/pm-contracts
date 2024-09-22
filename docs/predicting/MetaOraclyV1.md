# Solidity API

## MetaOraclyV1

Serves as the main control point for creating and managing games within the Oracly Protocol.

_Provides the Oracly Team with the ability to block abused or manipulated games.
     Game Registry: Maintains a list of active games along with their parameters (schedule, price feed address).
     Game Creation: Allows authorized users (the Oracly Team) to create and configure new games.
     Game Blocking: Enables the Oracly Team to block specific games in case of suspected manipulation or technical issues.
     IMPORTANT: If a Game is blocked, any Rounds with Unverified Outcomes will automatically be treated as No Contest._

### SHORTEST_ROUND

```solidity
uint256 SHORTEST_ROUND
```

Defines the minimum duration a round can last.

_This constant represents the shortest possible round duration in the game, set to 1 minute._

### SHORTEST_POSITIONING

```solidity
uint256 SHORTEST_POSITIONING
```

Defines the minimum time required for the positioning phase within a round.

_This constant ensures the positioning phase lasts for at least 30 seconds._

### SHORTEST_EXPIRATION

```solidity
uint256 SHORTEST_EXPIRATION
```

Defines the minimum time before a round can expire after it ends.

_This constant enforces a minimum round expiration time of 1 hour._

### LONGEST_EXPIRATION

```solidity
uint256 LONGEST_EXPIRATION
```

Defines the maximum time before a round can expire after it ends.

_This constant enforces a maximum expiration time of 7 days for any round._

### constructor

```solidity
constructor() public
```

The deployer of this contract will automatically be assigned as the contract owner (Oracly Team), who has the privilege to manage game creation, blocking and unblocking the game.

_Initializes the contract by setting the deployer as the initial owner (Oracly Team)._

### addGame

```solidity
function addGame(address pricefeed, address erc20, uint16 version, uint256 schedule, uint256 positioning, uint256 expiration, uint256 minDeposit) external
```

Adds a new game to the Oracly Protocol, linking it to a Chainlink price feed and an ERC20 token for deposits and payouts.
        Can only be called by the contract owner (Oracly Team).

_This function registers a new game configuration with specified parameters, including the price feed, token, game logic version, and timing rules for rounds.
     Requirements:
     - Caller must be the contract owner (Oracly Team) (enforced via `onlyOwner` modifier).
     Emits a `GameAdded` event when a new game is successfully added._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pricefeed | address | The address of the Chainlink price feed used to provide pricing data feed for the game. |
| erc20 | address | The address of the ERC20 token used for both deposits and payouts in the game. |
| version | uint16 | The version of the Oracly game logic, useful for compatibility and updates. |
| schedule | uint256 | The interval in seconds between rounds of the game (e.g., 300 for 5 minutes). |
| positioning | uint256 | The duration in seconds for the positioning phase, where bettors place predictions. |
| expiration | uint256 | The duration in seconds after which the round expires, and only withdraw deposit actions are allowed. |
| minDeposit | uint256 | The minimum deposit required to participate in the round, denoted in the ERC20 token. |

### getActiveGames

```solidity
function getActiveGames(address erc20, uint256 offset) external view returns (struct Game[] games, uint256 size)
```

Retrieves a list of active games that use a specific ERC20 token.

_This function returns a paginated list of active `Game` structs that utilize the specified ERC20 token.
     The results can be fetched using the provided `offset` for pagination._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| erc20 | address | The address of the ERC20 token being used by the games. |
| offset | uint256 | The starting index for pagination of active games. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| games | struct Game[] | An array of `Game` structs representing the active games using the given ERC20 token. |
| size | uint256 | The total number of active games using the specified ERC20 token. |

### getGame

```solidity
function getGame(bytes32 gameid) external view returns (struct Game game)
```

Retrieves the details of a specific game based on its unique identifier.

_This function fetches the game details from internal storage using the provided game ID.
     The game details include all the relevant information about a specific prediction game._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gameid | bytes32 | The unique identifier for the game, represented as a bytes32 value. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| game | struct Game | A `Game` struct containing the metadata of the requested game. |

### unblockGame

```solidity
function unblockGame(bytes32 gameid) external
```

Unblocks a previously blocked game, allowing it to resume normal operation.

_Unblocking a game restores its availability for bettors and enables gameplay to continue.
Can only be called by the contract owner (Oracly Team).
     Emits a `GameUnblocked` event upon successful execution.
     Requirements:
     - The game must be in a blocked state.
     - Can only be called by the contract owner._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gameid | bytes32 | The unique identifier of the game to be unblocked. |

### blockGame

```solidity
function blockGame(bytes32 gameid) external
```

Blocks a game, preventing new prediction rounds from being initiated and marking unresolved rounds as impacted.

_Blocks the specified game, ensuring no new rounds are created and impacting any currently unresolved rounds.
     Emits a `GameBlocked` upon successful blocking.
     Requirements:
     - This function can only be called by the contract owner (Oracly Team).
     - The game must exist and not already be blocked._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gameid | bytes32 | The unique identifier of the game to block. |

### GameAdded

```solidity
event GameAdded(bytes32 gameid, address pricefeed, address erc20, uint16 version, uint256 schedule, uint256 positioning, uint256 expiration, uint256 minDeposit)
```

This event is emitted when a new game is added to the Oracly Protocol.

_Captures important parameters such as the Chainlink price feed, ERC20 token used, game version, and round timing details._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gameid | bytes32 | The unique identifier of the newly added game, used for tracking purposes. |
| pricefeed | address | The address of the Chainlink price feed used to provide external data for the game. |
| erc20 | address | The address of the ERC20 token used for both deposits and payouts in the game. |
| version | uint16 | The version of the Oracly game logic, useful for compatibility and updates. |
| schedule | uint256 | The interval in seconds between rounds of the game (e.g., 300 for 5 minutes). |
| positioning | uint256 | The duration in seconds for the positioning phase, where bettors place predictions. |
| expiration | uint256 | The duration in seconds after which the round expires, and only withdraw deposit actions are allowed. |
| minDeposit | uint256 | The minimum deposit required to participate in the round, denoted in the ERC20 token. |

### GameBlocked

```solidity
event GameBlocked(bytes32 gameid)
```

This event is emitted when a game is blocked by the Oracly team.
        It can signal to external systems or users that a game is no longer available for participation or prediction.

_Emitted when a game is blocked by the Oracly Team due to unforeseen issues, violations, or any other reasons defined within the protocol._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gameid | bytes32 | The unique identifier of the blocked game. |

### GameUnblocked

```solidity
event GameUnblocked(bytes32 gameid)
```

This event is emitted when a previously blocked game is unblocked by the Oracly Team.

_Emitted when a previously blocked game is unblocked._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| gameid | bytes32 | The unique identifier of the game that has been unblocked. |

