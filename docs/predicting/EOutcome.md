# Solidity API

## EOutcome

Enum representing the possible outcomes of a prediction round in the game.

_Bettors predict whether the price of a selected asset will go Down, Up, or remain the same (Zero).
     `Undefined`: Value is the initial state when the outcome is unknown.
     `No Contest`:
      - All participants predicted the same outcome (either all Up, all Down, or all Zero), making it impossible to determine winners.
      - None of the participants correctly predicted the outcome.
      - The round was not resolved within the allowed time limit._

```solidity
enum EOutcome {
  Undefined,
  Down,
  Up,
  Zero,
  NoContest
}
```

