# Solidity API

## Price

Represents a price point from the Chainlink price feed, including the value, timestamp, and round ID.

_Each price point consists of the value, the timestamp when the price was updated, and the Chainlink round ID.
     - `value` This represents the price data from the Chainlink price feed.
     - `timestamp` Represents the time when the price was updated on the Chainlink feed.
     - `roundid` The round ID provides context on which round the price data was fetched from._

```solidity
struct Price {
  int256 value;
  uint256 timestamp;
  uint80 roundid;
}
```

