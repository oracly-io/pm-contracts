// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Price } from "./Price.sol";

/**
 * @title Round
 * @notice Represents a self-contained prediction contest where bettors predict whether the price of a selected asset will go Down, Up, or remain the same (Zero) within a short timeframe.
 * @dev Rounds progress through several distinct phases:
 *      - Entry (Positioning): Bettors can place predictions starting at `startDate` and ending at `lockDate`.
 *      - Round: Begins at `lockDate` and ends at `endDate`.
 *      - Settlement: Starts at `endDate` and ends either when the outcome is settled or at `expirationDate`. If not resolved by `expirationDate`, the round defaults to "No Contest".
 *      - Payout: Begins at `resolvedAt` and ends either when the last prediction is claimed at `archivedAt`.
 *      - Archive: Starts at `archivedAt` and is considered the final phase; no further actions can be taken on the round.
 *      Bettors with matching predictions share the prize pool proportionally to their deposit.
 *      - `roundid` This is a hashed value representing the round ID.
 *      - `gameid` Links the round to a specific game instance.
 *      - `resolution` This value reflects the round's outcome. (0 for Undefined, 1 for Down, 2 for Up, 3 for Zero, 4 for No Contest)
 *      - `entryPrice` The price of the selected asset at the round's opening, used for determining the outcome.
 *      - `exitPrice` The price of the selected asset by the round's end time to determine the actual price movement.
 *      - `startDate` Bettors can place predictions once the round has started.
 *      - `lockDate` Bettors must submit predictions before this time. After this, no new entries are allowed.
 *      - `endDate` The round ends at this time, and price movement can be evaluated.
 *      - `expirationDate` After this date, unresolved rounds default to "No Contest".
 *      - `resolved` This is true if the round outcome has been settled.
 *      - `resolvedAt` This indicates when the round's outcome was settled.
 *      - `openedAt` Indicates when first bettor entered the round.
 *      - `erc20` Bettors use this token for betting and receiving payouts.
 *      - `pricefeed` The price feed provides the entry and exit prices used to determine the outcome.
 *      - `archived` Once a round is archived, no further actions can be performed on the round.
 *      - `archivedAt` This timestamp is recorded when the `archived` status is set to true, marking the end of the round's lifecycle.
 */
struct Round {

  /**
   * @notice Unique identifier for the round.
   * @dev This is a hashed value representing the round ID.
   */
  bytes32 roundid;

  /**
   * @notice Unique identifier for the game this round belongs to.
   * @dev Links the round to a specific game instance.
   */
  bytes32 gameid;

  /**
   * @notice The outcome of the round (Undefined, Down, Up, Zero, No Contest).
   * @dev This value reflects the round's outcome. (0 for Undefined, 1 for Down, 2 for Up, 3 for Zero, 4 for No Contest)
   */
  uint8 resolution;

  /**
   * @notice The price at the start of the round.
   * @dev The price of the selected asset at the round's opening, used for determining the outcome.
   */
  Price entryPrice;

  /**
   * @notice The price at the end of the round used for resolution.
   * @dev The price of the selected asset by the round's end time to determine the actual price movement.
   */
  Price exitPrice;

  /**
   * @notice The timestamp when the round starts.
   * @dev Bettors can place predictions once the round has started.
   */
  uint startDate;

  /**
   * @notice The timestamp when predictions are locked for the round.
   * @dev Bettors must submit predictions before this time. After this, no new entries are allowed.
   */
  uint lockDate;

  /**
   * @notice The timestamp when the round ends.
   * @dev The round ends at this time, and price movement can be evaluated.
   */
  uint endDate;

  /**
   * @notice The expiration date of the round.
   * @dev After this date, unresolved rounds default to "No Contest".
   */
  uint expirationDate;

  /**
   * @notice Indicates whether the round has been resolved.
   * @dev This is true if the round outcome has been settled.
   */
  bool resolved;

  /**
   * @notice The timestamp when the round was resolved.
   * @dev This indicates when the round's outcome was settled.
   */
  uint resolvedAt;

  /**
   * @notice Timestamp indicating when the round was opened by the first prediction.
   * @dev Indicates when first bettor entered the round.
   */
  uint openedAt;

  /**
   * @notice The ERC20 token used for deposits and rewards in this round.
   * @dev Bettors use this token for betting and receiving payouts.
   */
  address erc20;

  /**
   * @notice The address of the price feed contract used for price data in the round.
   * @dev The price feed provides the entry and exit prices used to determine the outcome.
   */
  address pricefeed;

  /**
   * @notice Indicates whether the round has been archived.
   * @dev Once a round is archived, no further actions can be performed on the round.
   */
  bool archived;

  /**
   * @notice The timestamp when the round was archived.
   * @dev This timestamp is recorded when the `archived` status is set to true, marking the end of the round's lifecycle.
   */
  uint archivedAt;

}
