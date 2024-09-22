// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Price
 * @notice Represents a price point from the Chainlink price feed, including the value, timestamp, and round ID.
 * @dev Each price point consists of the value, the timestamp when the price was updated, and the Chainlink round ID.
 *      - `value` This represents the price data from the Chainlink price feed.
 *      - `timestamp` Represents the time when the price was updated on the Chainlink feed.
 *      - `roundid` The round ID provides context on which round the price data was fetched from.
 */
struct Price {

  /**
   * @notice The value of the price at the specified timestamp.
   * @dev This represents the price data from the Chainlink price feed.
   */
  int value;

  /**
   * @notice The timestamp when the price was last updated.
   * @dev Represents the time when the price was updated on the Chainlink feed.
   */
  uint timestamp;

  /**
   * @notice The round ID from the Chainlink price feed.
   * @dev The round ID provides context on which round the price data was fetched from.
   */
  uint80 roundid;

}

