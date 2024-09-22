# Solidity API

## Game

Represents a series of prediction rounds where bettors predict cryptocurrency price movements for a chance to win rewards.

_The struct defines key parameters for a game instance, including the price feed, token used for rewards, and schedule details.
     - `gameid` This is a hashed value of main properites representing the game ID.
     - `pricefeed` The price feed provides cryptocurrency price data for bettors to make predictions.
     - `erc20` Participants deposit this token to join the game, and rewards are distributed in the same token.
     - `version` Tracks the version of the game to differentiate between various game variants.
     - `scheduled` Specifies the start time of the game, which is set during initialization.
     - `positioning` Defines the time period before the game locks in which bettors can position their predictions.
     - `expiration` The time at which the round expires after it ends, and only withdraw deposit actions are allowed.
     - `minDeposit` Specifies the smallest amount of ERC20 tokens that a bettor must deposit to enter the game.
     - `blocked` If set to true, the game is blocked and no new actions (such as placing predictions) can be taken._

```solidity
struct Game {
  bytes32 gameid;
  address pricefeed;
  address erc20;
  uint16 version;
  uint256 schedule;
  uint256 positioning;
  uint256 expiration;
  uint256 minDeposit;
  bool blocked;
}
```

