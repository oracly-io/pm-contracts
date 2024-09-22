# Solidity API

## Round

Represents a self-contained prediction contest where bettors predict whether the price of a selected asset will go Down, Up, or remain the same (Zero) within a short timeframe.

_Rounds progress through several distinct phases:
     - Entry (Positioning): Bettors can place predictions starting at `startDate` and ending at `lockDate`.
     - Round: Begins at `lockDate` and ends at `endDate`.
     - Settlement: Starts at `endDate` and ends either when the outcome is settled or at `expirationDate`. If not resolved by `expirationDate`, the round defaults to "No Contest".
     - Payout: Begins at `resolvedAt` and ends either when the last prediction is claimed at `archivedAt`.
     - Archive: Starts at `archivedAt` and is considered the final phase; no further actions can be taken on the round.
     Bettors with matching predictions share the prize pool proportionally to their deposit.
     - `roundid` This is a hashed value representing the round ID.
     - `gameid` Links the round to a specific game instance.
     - `resolution` This value reflects the round's outcome. (0 for Undefined, 1 for Down, 2 for Up, 3 for Zero, 4 for No Contest)
     - `entryPrice` The price of the selected asset at the round's opening, used for determining the outcome.
     - `exitPrice` The price of the selected asset by the round's end time to determine the actual price movement.
     - `startDate` Bettors can place predictions once the round has started.
     - `lockDate` Bettors must submit predictions before this time. After this, no new entries are allowed.
     - `endDate` The round ends at this time, and price movement can be evaluated.
     - `expirationDate` After this date, unresolved rounds default to "No Contest".
     - `resolved` This is true if the round outcome has been settled.
     - `resolvedAt` This indicates when the round's outcome was settled.
     - `openedAt` Indicates when first bettor entered the round.
     - `erc20` Bettors use this token for betting and receiving payouts.
     - `pricefeed` The price feed provides the entry and exit prices used to determine the outcome.
     - `archived` Once a round is archived, no further actions can be performed on the round.
     - `archivedAt` This timestamp is recorded when the `archived` status is set to true, marking the end of the round's lifecycle._

```solidity
struct Round {
  bytes32 roundid;
  bytes32 gameid;
  uint8 resolution;
  struct Price entryPrice;
  struct Price exitPrice;
  uint256 startDate;
  uint256 lockDate;
  uint256 endDate;
  uint256 expirationDate;
  bool resolved;
  uint256 resolvedAt;
  uint256 openedAt;
  address erc20;
  address pricefeed;
  bool archived;
  uint256 archivedAt;
}
```

