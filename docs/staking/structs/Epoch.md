# Solidity API

## Epoch

Represents a recurring staking period (approximately 7 days) during which the staking pool remains unchanged.

_Staking rewards are distributed to stakers proportionally based on Oracly Commissions collected during the epoch.
     If no stakers register, the start of the epoch is delayed until participation occurs.
     - `epochid` This ID is used to track individual epochs.
     - `startDate` Indicates when the epoch is set to begin; however, the actual start may be delayed if no stakers participate.
     - `endDate` Defines when the staking epoch is expected to conclude, 7 days after the start date.
     - `startedAt` This records when the epoch started, which may differ from the scheduled start date due to a delayed start.
     - `endedAt` This captures the moment the epoch concluded, and no new staking reward commission is collected into the epoch._

```solidity
struct Epoch {
  uint256 epochid;
  uint256 startDate;
  uint256 endDate;
  uint256 startedAt;
  uint256 endedAt;
}
```

