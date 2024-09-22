# Solidity API

## ORCY

The ORCY token is the native token of the Oracly Protocol, enabling staking, governance, and facilitating reward distribution.

_This contract implements the standard ERC-20 functionality for the ORCY token, allowing users to transfer ORCY, check balances, and participate in staking and governance.
      It controls the minting process according to the OraclyV1 Economy, distributing tokens for growth, team, seed, and buy4stake addresses._

### TOTAL_SUPPLY

```solidity
uint256 TOTAL_SUPPLY
```

Fixed total supply of ORCY tokens, permanently set to 10 million tokens.

_The supply is scaled to 18 decimal places (10 million * 1e18)._

### TOKEN_NAME

```solidity
string TOKEN_NAME
```

Official name of the ORCY token, represented as 'Oracly Glyph'.

_This is the full name used in the ERC-20 standard._

### TOKEN_SYMBOL

```solidity
string TOKEN_SYMBOL
```

The symbol of the ORCY token, denoted as 'ORCY'.

_This symbol will be displayed on exchanges and wallets._

### GROWTH_PERCENTAGE

```solidity
uint8 GROWTH_PERCENTAGE
```

Percentage of the total token supply allocated for the growth fund.

_Set at 10%, this portion is reserved for initiatives that promote ecosystem growth._

### TEAM_PERCENTAGE

```solidity
uint8 TEAM_PERCENTAGE
```

Percentage of the total token supply allocated for the team.

_Set at 10%, this portion is reserved for team members as compensation._

### SEED_PERCENTAGE

```solidity
uint8 SEED_PERCENTAGE
```

Percentage of the total token supply allocated for seed investors.

_Set at 5%, this portion is reserved for early-stage investors who funded the project._

### BUY4STAKE_PERCENTAGE

```solidity
uint8 BUY4STAKE_PERCENTAGE
```

Percentage of the total token supply allocated for the buy4stake program.

_Set at 50%, this portion is reserved for the buy4stake mechanism to incentivize staking._

### GROWTH_VESTING_PERCENTAGE

```solidity
uint8 GROWTH_VESTING_PERCENTAGE
```

Percentage of the total token supply allocated for growth-related vesting.

_Set at 10%, this portion will be unlocked over time to sustain long-term growth initiatives._

### TEAM_VESTING_PERCENTAGE

```solidity
uint8 TEAM_VESTING_PERCENTAGE
```

Percentage of the total token supply allocated for team vesting.

_Set at 10%, this portion will be unlocked gradually for team members as part of their vesting schedule._

### SEED_VESTING_PERCENTAGE

```solidity
uint8 SEED_VESTING_PERCENTAGE
```

Percentage of the total token supply allocated for seed investors' vesting.

_Set at 5%, this portion will be released over time to early investors in accordance with the vesting schedule._

### constructor

```solidity
constructor(address growth_address, address team_address, address seed_address, address buy4stake_address, address growth_vesting_address, address team_vesting_address, address seed_vesting_address) public
```

Initializes the ORCY token contract by minting the total supply and distributing it according to the ORCY economy's token allocation plan.

_The total supply of ORCY tokens is minted and allocated across various addresses based on predefined percentages for growth, team, seed investors, and buy4stake mechanisms._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| growth_address | address | Address that receives the portion allocated for growth initiatives (10%). |
| team_address | address | Address that receives the portion allocated for the team (10%). |
| seed_address | address | Address that receives the portion allocated for seed investors (5%). |
| buy4stake_address | address | Address that receives the portion allocated for the buy4stake program (50%). |
| growth_vesting_address | address | Address that receives the vesting portion for long-term growth initiatives (10%). |
| team_vesting_address | address | Address that receives the vesting portion for team members (10%). |
| seed_vesting_address | address | Address that receives the vesting portion for seed investors (5%). |

