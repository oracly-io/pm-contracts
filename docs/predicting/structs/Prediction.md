# Solidity API

## Prediction

Represents a bettor's choice of outcome (Down, Up, Zero) in a prediction game round.

_If the bettor's prediction aligns with the actual price change, they win a share of the prize pool.
     - `predictionid` This is a hashed value representing the prediction ID.
     - `roundid` Refers to the specific round within the game.
     - `gameid` Links the prediction to a specific game instance.
     - `bettor` Represents the bettor's wallet address.
     - `position` This is an `unit8` where (1 for Down, 2 for Up, 3 for Zero).
     - `deposit` This variable stores the value of the deposit for the prediction in the current round.
     - `claimed` This is true if the bettor has successfully claimed their payout after winning.
     - `createdAt` Records when the bettor made their prediction.
     - `payout` This is the amount the bettor receives from the prize pool upon winning.
     - `commission` The commission represents the amount deducted and allocated to stakers and mentors on a winning prediction.
     - `erc20` Bettors use this token for betting and receiving rewards in the game._

```solidity
struct Prediction {
  bytes32 predictionid;
  bytes32 roundid;
  bytes32 gameid;
  address bettor;
  uint8 position;
  uint256 deposit;
  bool claimed;
  uint256 createdAt;
  uint256 payout;
  uint256 commission;
  address erc20;
}
```

