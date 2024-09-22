# Solidity API

## Deposit

Represents a staking deposit of ORCY tokens in the Oracly Staking Contract.

_A staker's deposit is locked for a Staking Epoch, earns rewards, and grants voting power in governance processes.
     - `depositid` This is a hashed value representing the deposit ID.
     - `staker` This is the wallet address of the staker depositing ORCY tokens.
     - `inEpochid` Represents the epoch during which the deposit was created.
     - `createdAt` Records the time when the staker deposited ORCY tokens.
     - `amount` Specifies the quantity of ORCY tokens deposited into the staking contract.
     - `outEpochid` Defines the epoch during which the unstake process was initiated.
     - `unstaked` If true, the staker has requested to unlock their staked ORCY tokens.
     - `unstakedAt` Records the time when the staker unstake their ORCY tokens from the contract.
     - `withdrawn` If true, the staker has successfully withdrawn their tokens after unstaking.
     - `withdrawnAt` Records the time when the staker withdrew their ORCY tokens from the contract._

```solidity
struct Deposit {
  bytes32 depositid;
  address staker;
  uint256 inEpochid;
  uint256 createdAt;
  uint256 amount;
  uint256 outEpochid;
  bool unstaked;
  uint256 unstakedAt;
  bool withdrawn;
  uint256 withdrawnAt;
}
```

