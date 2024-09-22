// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { EnumerableSet } from  "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ICommissionCollector } from "../interfaces/ICommissionCollector.sol";

import { Epoch } from "./structs/Epoch.sol";
import { Deposit } from "./structs/Deposit.sol";

/**
 * @title OraclyV1 Staking Contract
 * @dev This contract implements staking functionality for the Oracly Protocol, allowing ORCY token holders to lock tokens in return for staking rewards.
 *      Stakers can claim rewards for each epoch through which their deposit was `Staked` or in `Pending Unstake` status.
 *      The contract uses the Ownable pattern to restrict administrative functions and the ReentrancyGuard to protect against reentrancy attacks.
 *      It also implements the ICommissionCollector interface to manage reward distribution mechanisms.
 *      Stakers can stake ORCY tokens, claim rewards, and withdraw their stake.
 * @notice This contract manages multiple aspects of staking, including:
 *      - Epoch Management: Handles the creation and lifecycle of staking epochs, ensuring structured reward distribution cycles.
 *      - Deposit Tracking: Manages both pending and active staking deposits, providing transparency about stakers' locked amounts and statuses.
 *      - Reward Mechanics: Calculates staking rewards per epoch based on deposited ORCY token amounts automatically.
 *      - Buy4Stake: Allows stakers to acquire ORCY tokens directly for staking through the Buy4Stake process.
 */
contract StakingOraclyV1 is Ownable, ReentrancyGuard, ICommissionCollector {

  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  /**
   * @notice Mapping of epochs by epoch ID.
   * @dev Each epoch tracks staking and reward details, including start time and end time.
   */
  mapping(uint => Epoch) private _epochs;

  /**
   * @notice Mapping of deposits by a unique deposit ID.
   * @dev Tracks individual stakers' deposits. Each deposit ID links to a deposit record that includes staked amount, entry epoch, exit epoch, and current status.
   */
  mapping(bytes32 => Deposit) private _deposits;

  /**
   * @notice Keeps track of the stake deposits for each staking epoch, categorized by staking status.
   * @dev The mapping associates an epoch ID with an array of three `uint` values, representing amount of stake deposits in various stages:
   *      - [0]: Total stake deposits locked in the epoch and actively earning rewards.
   *      - [1]: Stake deposits locked, but will only activate in the next epoch. (`Pending Stake`)
   *      - [2]: Stake deposits locked and earning rewards, but will be unstaked and unlocked in the next epoch. (`Pending Unstake`)
   */
  mapping(uint => uint[3]) private _stakes;

  /**
   * @notice Represents the total amount of ORCY tokens locked per epoch, categorized by staking status.
   * @dev The mapping associates each epoch ID with an array of three `uint` values, representing amount of ORCY tokens in various stages:
   *      - [0]: Total ORCY tokens locked in the epoch and actively earning rewards.
   *      - [1]: ORCY tokens locked, but not yet active, will be staked in the next epoch ("Pending Stake").
   *      - [2]: ORCY tokens locked in the epoch and earning rewards, but will be unstaked and unlocked in the next epoch ("Pending Unstake").
   *      This structure complements `_stakes` by representing the actual token amounts in different staking states.
   */
  mapping(uint => uint[3]) private _stakepool;

  /**
   * @notice Tracks the total amount of ERC20 tokens collected by the staking contract for each epoch.
   *         These tokens are available to be distributed as staking rewards in the respective epoch.
   * @dev The mapping associates each epoch ID with the amount of collected staking rewards.
   *      - The first key in the mapping is the `epochId`, identifying the staking epoch.
   *      - The second key is the ERC20 token's contract address, allowing multiple token types to be tracked per epoch.
   *      - The value is the total amount of that ERC20 token collected for rewards during the given epoch.
   */
  mapping(uint => mapping(address => uint)) private _rewardpool;

  /**
   * @notice Tracks the total amount of ERC20 rewards that have been released per epoch.
   *         This is the amount that has already been distributed to the users as rewards.
   * @dev The mapping associates each epoch ID with the amount of released staking rewards.
   *      - The first key in the mapping is the `epochId`, identifying the staking epoch.
   *      - The second key is the ERC20 token's contract address, allowing multiple token types to be tracked per epoch.
   *      - The value is the total amount of that ERC20 token that has been released as rewards for the given epoch.
   */
  mapping(uint => mapping(address => uint)) private _releasedReward;

  /**
   * @notice Set of all staker deposits by staker address.
   * @dev Uses an enumerable set to ensure uniqueness of deposit IDs and allows enumeration of each deposit made by a staker.
   *      Each deposit ID is represented by a unique identifier (bytes32 hash), which can be mapped to a `Deposit` struct.
   */
  mapping(address => EnumerableSet.Bytes32Set) private _stakerDeposits;

  /**
   * @notice Mapping of total payouts received by each staker, tracked by their address and the corresponding reward ERC20 token.
   * @dev Tracks payouts for stakers across different reward tokens.
   *      - The first mapping key is the staker's address.
   *      - The second is the reward token (ERC20) address.
   *      - The `uint256` value represents the total amount paid out in the respective token.
   */
  mapping(address => mapping(address => uint)) private _stakerPayouts;

  /**
   * @notice Tracks which deposits have been claimed by users for a specific staking epoch and ERC20 token.
   * @dev This is a double mapping where:
   *      - The first key (`uint`) represents the staking epoch ID.
   *      - The second key (`address`) represents the ERC20 token address.
   *      - The value is an EnumerableSet of `bytes32`, which contains the unique IDs of the deposits that have been claimed by the staker.
   */
  mapping(uint => mapping(address => EnumerableSet.Bytes32Set)) private _claimed;

  /**
   * @notice Tracks payout amounts for a given deposit across multiple epochs and ERC20 tokens.
   * @dev This is a triple mapping where:
   *      - The first key (`bytes32`) represents the deposit ID.
   *      - The second key (`address`) represents the ERC20 token address.
   *      - The third key (`uint`) represents the staking epoch ID.
   *      - The value is the amount of the payout corresponding to the deposit, token, and epoch.
   */
  mapping(bytes32 => mapping(address => mapping(uint => uint))) private _payouts;

  /**
   * @notice Tracks the total payout amounts accrued for each deposit ID and ERC20 token.
   *         This mapping helps track payouts for multiple tokens across various deposits, ensuring each deposit's total earnings can be easily retrieved.
   * @dev This is a double mapping where:
   *      - The first key (`bytes32`) represents the unique deposit ID.
   *      - The second key (`address`) represents the ERC20 token address.
   *      - The value is a `uint` representing the total payout amount accumulated over all staking epochs for the specified deposit and ERC20 token.
   */
  mapping(bytes32 => mapping(address => uint)) private _depositPayouts;

  /**
   * @notice Tracks the total staked and unstaked amounts for each staker.
   * @dev This mapping stores an array of two values per staker address:
   *      - [0] The total amount of tokens staked by the staker.
   *      - [1] The total amount of tokens unstaked by the staker.
   */
  mapping(address => uint[2]) private _staked;

  /**
   * @notice Constant to represent index of the total ORCY tokens currently staked in an epoch.
   * @dev This index is used to access the total amount of ORCY tokens locked and actively earning rewards in the current epoch.
   */
  uint8 constant private STAKEPOOL_TOTAL_ID = 0;

  /**
   * @notice Constant to represent index of ORCY tokens that are pending to be staked.
   * @dev This index is used to access the amount of ORCY tokens locked but not yet active, which will be staked in the next epoch ("Pending Stake").
   */
  uint8 constant private STAKEPOOL_PENDING_IN_ID = 1;

  /**
   * @notice Constant to represent index of ORCY tokens that are pending to be unstaked.
   * @dev This index is used to access the amount of ORCY tokens still earning rewards in the current epoch but will be unlocked in the next epoch ("Pending Unstake").
   */
  uint8 constant private STAKEPOOL_PENDING_OUT_ID = 2;

  /**
   * @notice Constant to represent index of the total stake deposits currently locked in an epoch.
   * @dev This index is used to access the total amount of stake deposits locked and actively earning rewards during the current staking epoch.
   */
  uint8 constant private STAKES_TOTAL_ID = 0;

  /**
   * @notice Constant to represent index of stake deposits that are pending to be activated in the next epoch.
   * @dev This index is used to access the amount of stake deposits that are locked but will only become active and start earning rewards in the next epoch ("Pending Stake").
   */
  uint8 constant private STAKES_PENDING_IN_ID = 1;

  /**
   * @notice Constant to represent index of stake deposits that are pending to be unlocked in the next epoch.
   * @dev This index is used to access the amount of stake deposits that are still earning rewards during the current epoch but will be unlocked in the next epoch ("Pending Unstake").
   */
  uint8 constant private STAKES_PENDING_OUT_ID = 2;

  /**
   * @notice Constant to represent the index for the total amount of tokens staked by a staker.
   * @dev This constant is used to access the staked total in the `_staked` mapping for each staker.
   */
  uint8 constant private STAKED_TOTAL_ID = 0;

  /**
   * @notice Constant to represent the index for the total amount of tokens unstaked by a staker.
   * @dev This constant is used to access the unstaked total in the `_staked` mapping for each staker.
   */
  uint8 constant private UNSTAKED_TOTAL_ID = 1;

  /**
   * @notice The duration of one staking epoch in days.
   * @dev A staking epoch is fixed at 7 days. This constant used to calculate staking period durations.
   */
  uint32 constant public SCHEDULE = 7 days;

  /**
   * @notice Signals a fatal error caused by insufficient stake funds in the staking pool.
   * @dev This flag is set to true when the staking pool lacks sufficient funds to continue normal operations.
   *      Once active, it blocks new staking actions, although existing stakes will continue to accrue rewards.
   *      This is a critical safeguard to prevent the system from allowing additional stakes into a compromised stake pool.
   */
  bool public __FATAL_INSUFFICIENT_STAKEFUNDS_ERROR__;

  /**
   * @notice Tracks whether a fatal error has occurred for specific ERC20 tokens due to insufficient reward funds.
   * @dev This mapping records a boolean flag for each ERC20 token address, indicating if the reward pool has encountered a critical shortage of funds.
   *      The flag is set to `true` when the system detects that there are insufficient ERC20 tokens available to fulfill reward obligations.
   *      Once set, the system prevents the token from being used for reward accumulation by the contract to avoid further depletion and losses.
   *      The flag signals the necessity for manual intervention by an external authorized entity (EOA) to handle reward distribution.
   *      Existing rewards will still be distributed, but no new rewards can be accumulated for this token.
   */
  mapping(address => bool) public __FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__;

  /**
   * @notice The address of the ERC20 contract used as staking tokens. (ORCY)
   * @dev This is an immutable address, meaning it is set once at contract deployment and cannot be changed.
   */
  address immutable public STAKING_ERC20_CONTRACT;

  /**
   * @notice The address of the authorized funds gatherer for the contract.
   * @dev This is the address responsible for gathering staking rewards from the bettor's prize on withdrawal and passing them to the contract for further distribution to stakers.
   */
  address public AUTHORIZED_COMMISSION_GATHERER;

  /**
   * @notice The address of the ERC20 contract used in the Buy4Stake process, enabling participants to acquire ORCY tokens at a 1:1 exchange rate.
   * @dev The Buy4Stake mechanism uses this ERC20 token as a base for participants to purchase and stake ORCY tokens.
   */
  address public BUY_4_STAKE_ERC20_CONTRACT;

  /**
   * @notice Tracks the current epoch ID used in the staking contract.
   * @dev This value increments with the beginning of each new staking epoch.
   *      It starts at a phantom epoch '0', meaning no staking epochs have been initiated yet.
   *      The epoch ID is used in various staking operations to identify the current staking epoch.
   */
  uint public ACTUAL_EPOCH_ID = 0;

  /**
   * @notice Tracks the total amount of ORCY tokens available for the Buy4Stake pool.
   * @dev The Buy4Stake pool allows users to purchase ORCY tokens at a 1:1 rate and automatically stake them in a single transaction.
   *      This variable represents the total funds currently allocated in the Buy4Stake pool.
   */
  uint public BUY_4_STAKEPOOL = 0;

  /**
   * @dev Initializes the StakingOraclyV1 contract with the given ERC20 token addresses for staking and Buy4Stake mechanisms.
   *      This constructor ensures that both token addresses are valid and sets the deployer (Oracly Team) as the owner.
   * @notice The provided addresses for the staking token (`erc20`) and Buy4Stake token (`b4s_erc20`) must be valid contract addresses and have non-zero total supplies.
   *         The contract deployer is assigned as the owner of this contract.
   * @param erc20 The address of the ERC20 token to be used for staking. It must be a valid ERC20 token contract and have a non-zero total supply.
   * @param b4s_erc20 The address of the Buy4Stake ERC20 token. It must be a valid ERC20 token contract and have a non-zero total supply.
   */
  constructor(
    address erc20,
    address b4s_erc20
  )
    Ownable(_msgSender())
  {
    if (IERC20(erc20).totalSupply() == 0) {
      revert("StakingERC20TotalSupplyCannotBeZero");
    }

    if (IERC20(b4s_erc20).totalSupply() == 0) {
      revert("Buy4StakeERC20TotalSupplyCannotBeZero");
    }

    STAKING_ERC20_CONTRACT = erc20;
    AUTHORIZED_COMMISSION_GATHERER = _msgSender();
    BUY_4_STAKE_ERC20_CONTRACT = b4s_erc20;
  }

  /**
   * @notice Retrieves the current active stake amount for a given staker.
   * @dev This function calculates the active stake of a staker by subtracting the total unstaked amount from the total staked amount.
   * @param staker The address of the staker whose active stake is being queried.
   * @return stakeof The amount of active stake held by the staker.
   */
  function getStakeOf(
    address staker
  )
    external
    view
    returns (
      uint stakeof
    )
  {

    stakeof = _staked[staker][STAKED_TOTAL_ID] - _staked[staker][UNSTAKED_TOTAL_ID];

  }

  /**
   * @dev Implements pagination to efficiently retrieve a manageable number of deposits in each query.
   *      It returns a maximum of 20 deposits per call, starting from the specified `offset`.
   * @notice Retrieves a paginated list of deposits made by a specific staker.
   *         This function helps avoid gas limitations when querying large data sets by allowing the retrieval of deposits in smaller batches (up to 20 deposits per call).
   * @param staker The address of the staker whose deposits are being queried.
   * @param offset The starting index for pagination, allowing retrieval of deposits starting from that point.
   * @return deposits An array of `Deposit` structs representing the staker's deposits within the specified range.
   * @return size The total number of deposits made by the staker, regardless of pagination.
   */
  function getStakerDeposits(
    address staker,
    uint offset
  )
    external
    view
    returns (
      Deposit[] memory deposits,
      uint size
    )
  {

    deposits = new Deposit[](0);
    size = _stakerDeposits[staker].length();

    if (size == 0) return (deposits, size);
    if (offset >= size) return (deposits, size);

    uint rest = size - offset;
    uint lastidx = 0;
    if (rest > 20) {
      lastidx = rest - 20;
    }
    uint resultSize = rest - lastidx;
    deposits = new Deposit[](resultSize);

    uint idx = 0;
    while (idx != resultSize) {
      bytes32 predictionid = _stakerDeposits[staker].at(rest - 1 - idx);
      deposits[idx] = _deposits[predictionid];
      idx++;
    }

  }

  /**
   * @dev This function provides a read-only view of the total accumulated payouts for a staker across all deposits in the specified ERC20 token.
   * @notice Returns the total amount that has been paid out to a specific staker for a given ERC20 token across all staking rewards.
   * @param staker The address of the staker whose accumulated payouts are being queried.
   * @param erc20 The address of the ERC20 token contract for which the payout is being queried.
   * @return paidout The total amount paid out to the staker in the specified ERC20 token.
   */
  function getStakerPaidout(
    address staker,
    address erc20
  )
    external
    view
    returns (
      uint paidout
    )
  {

    paidout = _stakerPayouts[staker][erc20];

  }

  /**
   * @notice Retrieves the total amount paid out for a specific deposit and ERC20 token.
   * @dev This function provides a view into the accumulated payouts for a specific deposit across all staking epochs for a given ERC20 token.
   * @param depositid The unique identifier of the deposit for which the payout is being queried.
   * @param erc20 The address of the ERC20 token corresponding to the payout.
   * @return paidout The total amount that has been paid out for the specified deposit in the given ERC20 token.
   */
  function getDepositPaidout(
    bytes32 depositid,
    address erc20
  )
    external
    view
    returns (
      uint paidout
    )
  {

    paidout = _depositPayouts[depositid][erc20];

  }

  /**
   * @dev This function provides a view into the accumulated payouts for a specific deposit in a particular epoch and for a specific ERC20 token.
   * @notice Retrieves the total amount already paid out for a given deposit, ERC20 token, and epoch.
   * @param depositid The unique identifier of the deposit for which the payout is being queried.
   * @param erc20 The address of the ERC20 token for which the payout is being queried.
   * @param epochid The identifier of the epoch for which the payout is being checked.
   * @return paidout The total amount paid out for the specified deposit, ERC20 token, and epoch.
   */
  function getDepositEpochPaidout(
    bytes32 depositid,
    address erc20,
    uint epochid
  )
    external
    view
    returns (
      uint paidout
    )
  {

    paidout = _payouts[depositid][erc20][epochid];

  }

  /**
   * @notice Retrieves the details of a specific deposit identified by `depositid`.
   * @dev Fetches a `Deposit` struct containing details about the deposit, such as the staker's address, the amount deposited, entry epoch.
   * @param depositid The unique identifier of the deposit.
   * @return deposit The `Deposit` struct containing the relevant information associated with the given `depositid`.
   */
  function getDeposit(
    bytes32 depositid
  )
    external
    view
    returns (
      Deposit memory deposit
    )
  {

    deposit = _deposits[depositid];

  }

  /**
   * @notice Retrieves full information about a specific staking epoch.
   * @dev This function provides a view into the current state of a specific staking epoch, including details about stakes, stakepool, and rewards for a given ERC20 token.
   * @param epochid The unique identifier of the staking epoch.
   * @param erc20 The address of the ERC20 token associated with the epoch (optional for rewards stats).
   * @return epoch The Epoch struct containing details such as epochid, start and end dates, and timestamps.
   * @return stakes An array containing the total staked amount, pending incoming stakes, and pending outgoing stakes for the epoch.
   * @return stakepool An array containing the total stakepool amount, pending incoming stakepool, and pending outgoing stakepool for the epoch.
   * @return rewards An array containing the collected and released reward amounts for the epoch with respect to the provided ERC20 token.
   */
  function getEpoch(
    uint epochid,
    address erc20
  )
    external
    view
    returns (
      Epoch memory epoch,
      uint[3] memory stakes,
      uint[3] memory stakepool,
      uint[2] memory rewards
    )
  {

    epoch = _epochs[epochid];

    stakes = [
      _stakes[epochid][STAKES_TOTAL_ID],
      _stakes[epochid][STAKES_PENDING_IN_ID],
      _stakes[epochid][STAKES_PENDING_OUT_ID]
    ];

    stakepool = [
      _stakepool[epochid][STAKEPOOL_TOTAL_ID],
      _stakepool[epochid][STAKEPOOL_PENDING_IN_ID],
      _stakepool[epochid][STAKEPOOL_PENDING_OUT_ID]
    ];

    rewards = [
      _rewardpool[epochid][erc20],
      _releasedReward[epochid][erc20]
    ];

  }

  /**
   * @notice Allows stakers to purchase ORCY tokens using a specific ERC20 token and automatically stake them in the current epoch.
   * @dev Validates the ERC20 contract, the staker's balance, allowance, and ensures the epoch is correct.
   *      Releases the ORCY tokens from the `BUY_4_STAKEPOOL`,
   *      Distributes the collected tokens among current stakers and stakes the ORCY tokens on staker's behalf for the current epoch.
   *      Requirements
   *      - The `erc20` must be the `BUY_4_STAKE_ERC20_CONTRACT`.
   *      - The staker must have sufficient balance and allowance for the ERC20 token.
   *      - The `epochid` must match the current epoch (`ACTUAL_EPOCH_ID`).
   *      - The `BUY_4_STAKEPOOL` must have enough ORCY tokens to cover the purchase.
   *      - The staking contract must hold enough ORCY tokens.
   *      - Only externally-owned accounts (EOAs) can call this function via the `onlyOffChainCallable` modifier.
   *      Emits:
   *      - `FATAL_EVENT_INSUFFICIENT_STAKEFUNDS` if the staking contract has insufficient ORCY tokens.
   *      - `Buy4StakepoolReleased` event for off-chain tracking.
   *      - `NewEpochStarted` event to indicate the start of a new epoch.
   *      - `RewardCollected` event when the reward is successfully collected and transferred to the contract.
   *      - `DepositCreated` event upon successful creation of a new deposit.
   *      - `IncreaseDepositAmount` event upon successful staking of tokens.
   * @param erc20 The address of the ERC20 token used for the purchase (must match the designated `BUY_4_STAKE_ERC20_CONTRACT`).
   * @param epochid The ID of the epoch in which the purchased tokens will be staked (must match the current epoch `ACTUAL_EPOCH_ID`).
   * @param amount The amount of ERC20 tokens the staker wishes to spend on purchasing ORCY tokens.
   */
  function buy4stake(
    address erc20,
    uint epochid,
    uint amount
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    if (BUY_4_STAKE_ERC20_CONTRACT != erc20) {
      revert("CannotBuy4StakeUnsupportedERC20");
    }

    address staker = _msgSender();
    if (IERC20(erc20).balanceOf(staker) < amount) {
      revert("InsufficientFunds");
    }
    if (IERC20(erc20).allowance(staker, address(this)) < amount) {
      revert("InsufficientAllowance");
    }

    if (ACTUAL_EPOCH_ID != epochid) {
      revert("CannotBuy4stakeIntoUnactualEpoch");
    }

    uint deposit = _exchangeQuote(erc20, amount);
    if (BUY_4_STAKEPOOL < deposit) {
      revert("InsufficientBuy4Stakepool");
    }

    if (IERC20(STAKING_ERC20_CONTRACT).balanceOf(address(this)) < deposit) {
      __FATAL_INSUFFICIENT_STAKEFUNDS_ERROR__ = true;
      emit FATAL_EVENT_INSUFFICIENT_STAKEFUNDS(
        staker,
        STAKING_ERC20_CONTRACT,
        IERC20(STAKING_ERC20_CONTRACT).balanceOf(address(this)),
        deposit
      );
      return;
    }

    _releaseBuy4Stakepool(deposit);
    _collectCommission(staker, erc20, amount);
    _stake(staker, ACTUAL_EPOCH_ID, deposit);

    IERC20(erc20).safeTransferFrom(staker, address(this), amount);

  }

  /**
   * @dev Internal utility function to get a 1:1 quote for exchanging an ERC20 token to the equivalent staking token (ORCY).
   * @notice This function calculates the corresponding staking token amount for the given ERC20 amount.
   * @param erc20 The address of the ERC20 token being exchanged.
   * @param amount The amount of the ERC20 token to be exchanged.
   * @return value The equivalent amount in the staking token, adjusted for the decimal differences.
   */
  function _exchangeQuote(
    address erc20,
    uint amount
  )
    private
    view
    returns (
      uint value
    )
  {

    value = amount;

    uint8 decimalsIN = IERC20Metadata(erc20).decimals();
    uint8 decimalsOUT = IERC20Metadata(STAKING_ERC20_CONTRACT).decimals();

    if (decimalsIN < decimalsOUT) {
      value = amount * 10**(decimalsOUT - decimalsIN);
    }

    if (decimalsIN > decimalsOUT) {
      value = Math.ceilDiv(amount, 10**(decimalsIN - decimalsOUT));
    }

  }

  /**
   * @notice Releases a specified amount from the Buy4Stake pool.
   * @dev This function subtracts the specified `amount` from the `BUY_4_STAKEPOOL`.
   *      Emits the `Buy4StakepoolReleased` event for off-chain tracking.
   * @param amount The amount of tokens to be released from the Buy4Stake pool.
   */
  function _releaseBuy4Stakepool(
    uint amount
  )
    private
  {

    BUY_4_STAKEPOOL = BUY_4_STAKEPOOL - amount;

    emit Buy4StakepoolReleased(
      STAKING_ERC20_CONTRACT,
      BUY_4_STAKEPOOL,
      amount
    );

  }

  /**
   * @notice Allows stakers to donate ORCY tokens to the buy4stake pool.
   * @dev Transfers ORCY tokens from the donator's wallet to the contract, increasing the buy4stake pool.
   *      The transfer will revert if the staker's balance is insufficient or the allowance granted to this contract is not enough.
   *      This function can only be called by off-chain EOA, and it uses a non-reentrant modifier to prevent re-entrancy attacks.
   *      Requirements:
   *      - The caller must have approved the contract to spend at least `amount` tokens.
   *      - Only externally-owned accounts (EOAs) can call this function via the `onlyOffChainCallable` modifier.
   *      - The function is protected against re-entrancy through the `nonReentrant` modifier.
   *      Emits the `Buy4StakepoolIncreased` event after successfully increasing the pool.
   * @param amount The amount of ORCY tokens the staker wishes to donate.
   */
  function donateBuy4stake(
    uint amount
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    if (amount == 0) {
      revert("CannotCreateBuy4stakeZeroRound");
    }

    address donator = _msgSender();
    if (IERC20(STAKING_ERC20_CONTRACT).balanceOf(donator) < amount) {
      revert("InsufficientFunds");
    }
    if (IERC20(STAKING_ERC20_CONTRACT).allowance(donator, address(this)) < amount) {
      revert("InsufficientAllowance");
    }

    _increaseBuy4Stakepool(amount);

    IERC20(STAKING_ERC20_CONTRACT).safeTransferFrom(donator, address(this), amount);

  }

  /**
   * @notice Increases the buy4stake pool by the specified amount.
   *         This function is used internally to update the buy4stake pool.
   * @dev Increases the buy4stake pool by the specified amount.
   *      Emits the `Buy4StakepoolIncreased` event after successfully increasing the pool.
   * @param amount The amount of ORCY to increase the buy4stake pool.
   */
  function _increaseBuy4Stakepool(
    uint amount
  )
    private
  {

    BUY_4_STAKEPOOL = BUY_4_STAKEPOOL + amount;

    emit Buy4StakepoolIncreased(
      STAKING_ERC20_CONTRACT,
      BUY_4_STAKEPOOL,
      amount
    );

  }

  /**
   * @notice Sets the accepted ERC20 token contract address for the Buy4Stake functionality.
   *         The specified ERC20 token will be used to purchase staking tokens (ORCY) in the Buy4Stake process.
   * @dev This function ensures that the token contract has a non-zero total supply, confirming it is a valid ERC20 token.
   *      It also enforces that only the contract owner (Oracly Team) can invoke this function.
   *      The function updates the state variable `BUY_4_STAKE_ERC20_CONTRACT` with the provided ERC20 contract address.
   *      Emits the `Buy4StakeAcceptedERC20Set` event upon successful execution.
   * @param erc20 The address of the ERC20 token contract that will be accepted for Buy4Stake staking operations.
   */
  function setBuy4stakeERC20(
    address erc20
  )
    external
    onlyOwner
  {

    if (IERC20(erc20).totalSupply() == 0) {
      revert("Buy4stakeERC20TotalSupplyCannotBeZero");
    }

    BUY_4_STAKE_ERC20_CONTRACT = erc20;

    emit Buy4StakeAcceptedERC20Set(erc20);

  }

  /**
   * @notice Updates the authorized gatherer address responsible for collecting staking rewards from bettors' prizes.
   * @dev This function can only be called by the contract owner (Oracly Team).
   *      It checks that the new gatherer is valid contract address.
   *      This function is protected by `onlyOwner` to ensure that only the contract owner can change the gatherer.
   *      Emits `AuthorizedGathererSet` event upon successful update of the gatherer address.
   * @param gatherer The address to be set as the authorized reward gatherer.
   */
  function setGatherer(
    address gatherer
  )
    external
    onlyOwner
  {
    if (gatherer == address(0)) {
      revert("GathereCannotBeZeroAddress");
    }

    if (gatherer == address(this)) {
      revert("GathereCannotBeSelfAddress");
    }

    AUTHORIZED_COMMISSION_GATHERER = gatherer;

    emit AuthorizedGathererSet(gatherer);

  }

  /**
   * @notice Allows a staker to stake a specified amount of ORCY tokens for a given epoch.
   * @dev The staker must have a sufficient ORCY token balance and must approve the contract to transfer the specified `amount` of tokens on their behalf.
   *      The function uses the `nonReentrant` modifier to prevent re-entrancy attacks.
   *      Only externally-owned accounts (EOAs) can call this function via the `onlyOffChainCallable` modifier.
   *      Emits:
   *      - `DepositCreated` event upon successful creation of a new deposit.
   *      - `IncreaseDepositAmount` event upon successful staking of tokens.
   * @param epochid The ID of the staking epoch for which the tokens are being staked.
   * @param amount The number of ORCY tokens the staker wishes to stake.
   */
  function stake(
    uint epochid,
    uint amount
  )
    external
    nonReentrant
    onlyOffChainCallable
  {
    address staker = _msgSender();
    if (IERC20(STAKING_ERC20_CONTRACT).balanceOf(staker) < amount) {
      revert("InsufficientFunds");
    }
    if (IERC20(STAKING_ERC20_CONTRACT).allowance(staker, address(this)) < amount) {
      revert("InsufficientAllowance");
    }

    _stake(staker, epochid, amount);

    IERC20(STAKING_ERC20_CONTRACT).safeTransferFrom(staker, address(this), amount);

  }

  /**
   * @notice Internal function to handle the staking process for a staker into a specified epoch.
   * @dev This function checks for valid staking conditions:
   *      - The `amount` of tokens must be greater than zero.
   *      - The staking contract must not be blocked due to insufficient stake funds.
   *      - The `epochid` must be the current epoch to prevent staking into outdated or future epochs.
   *      Emits:
   *      - `DepositCreated` event upon successful creation of a new deposit.
   *      - `IncreaseDepositAmount` event upon successful staking of tokens.
   * @param staker The address of the staker.
   * @param epochid The ID of the epoch for which the staker is staking tokens.
   * @param amount The amount of ORCY tokens to be staked by the staker.
   */
  function _stake(
    address staker,
    uint epochid,
    uint amount
  )
    private
  {

    if (amount == 0) {
      revert("CannotStakeZeroAmount");
    }

    if (__FATAL_INSUFFICIENT_STAKEFUNDS_ERROR__) {
      revert("CannotStakeDepositContractIsBlocked");
    }

    if (epochid != ACTUAL_EPOCH_ID) {
      revert("CannotStakeIntoUnactualEpoch");
    }

    _stakeDeposit(staker, epochid, amount);

  }

  /**
   * @notice Creates or updates a stake deposit for a staker in a specific epoch.
   *         If the deposit already exists, it increases the staked amount.
   *         If the deposit is new, it creates a new entry. Reverts if the deposit was previously unstaked.
   * @dev Handles the creation or update of a deposit, including storage changes and event emissions.
   *      Ensures no updates are made to deposits that have been previously unstaked.
   *      Emits:
   *      - `DepositCreated` event upon successful creation of a new deposit.
   *      - `IncreaseDepositAmount` event upon successful staking of tokens.
   * @param staker The address of the staker.
   * @param epochid The ID of the epoch the staker is staking in.
   * @param amount The amount of tokens to stake.
   */
  function _stakeDeposit(
    address staker,
    uint epochid,
    uint amount
  )
    private
  {

    bytes32 depositid = keccak256(abi.encode(epochid, staker));

    Deposit storage deposit = _deposits[depositid];
    if (deposit.unstaked) {
      revert("CannotUpdateUnstakedDeposit");
    }

    if (deposit.depositid == 0x0) {
      deposit.depositid = depositid;
      deposit.inEpochid = epochid;
      deposit.staker = staker;
      deposit.createdAt = block.timestamp;

      _stakes[epochid][STAKES_PENDING_IN_ID] = _stakes[epochid][STAKES_PENDING_IN_ID] + 1;
      _stakerDeposits[staker].add(depositid);

      emit DepositCreated(
        depositid,
        epochid,
        staker,
        block.timestamp,
        STAKING_ERC20_CONTRACT
      );
    }

    deposit.amount = deposit.amount + amount;

    _staked[staker][STAKED_TOTAL_ID] = _staked[staker][STAKED_TOTAL_ID] + amount;

    _stakepool[epochid][STAKEPOOL_PENDING_IN_ID] = _stakepool[epochid][STAKEPOOL_PENDING_IN_ID] + amount;

    emit IncreaseDepositAmount(depositid, staker, amount);

  }

  /**
   * @notice Initiates the unstaking process for a specific deposit during the current staking epoch.
   *         The unstaking process will unlock the staked ORCY tokens in the following epoch.
   *         During the current epoch, the stake will continue generating rewards until the next epoch starts.
   * @dev Implements the unstaking mechanism, ensuring:
   *      - The staked deposit exists and is owned by the caller.
   *      - The caller is unstaking within the correct epoch.
   *      - Prevents reentrancy attacks using the `nonReentrant` modifier.
   *      - Only externally-owned accounts (EOAs) can call this function via the `onlyOffChainCallable` modifier.
   *      Emits a `DepositUnstaked` event upon successful unstaking, indicating the deposit ID and the staker who unstaked it.
   * @param epochid The ID of the epoch in which the unstaking is initiated.
   * @param depositid The unique identifier of the deposit to be unstaked.
   */
  function unstake(
    uint epochid,
    bytes32 depositid
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    Deposit memory deposit = _deposits[depositid];
    if (deposit.depositid == 0x0) {
      revert("CannotUnstakeUnexistDeposit");
    }

    address staker = _msgSender();
    if (deposit.staker != staker) {
      revert("CannotUnstakeOtherStakerDeposit");
    }

    if (deposit.unstaked) {
      revert("CannotUnstakeUnstakedDeposit");
    }

    if (epochid != ACTUAL_EPOCH_ID) {
      revert("CannotUnstakeInUnactualEpoch");
    }

    if (epochid < deposit.inEpochid) {
      revert("CannotUnstakeEpochEarlierStakeEpoch");
    }

    _unstakeDeposit(epochid, depositid);

    emit DepositUnstaked(
      depositid,
      staker,
      epochid
    );

  }

  /**
   * @notice Updates the deposit's state and associated staking data when a staker requests to unstake.
   * @dev Internal function to handle unstaking, modifying the deposit and the epoch state.
          The deposit is marked as unstaked, and it is added to the pending unstaked.
   * @param epochid The ID of the epoch in which the unstaking is initiated.
   * @param depositid The unique identifier of the deposit.
   */
  function _unstakeDeposit(
    uint epochid,
    bytes32 depositid
  )
    private
  {

    Deposit storage deposit = _deposits[depositid];

    deposit.outEpochid = epochid;

    deposit.unstaked = true;
    deposit.unstakedAt = block.timestamp;

    uint amount = deposit.amount;
    address staker = deposit.staker;

    _staked[staker][UNSTAKED_TOTAL_ID] = _staked[staker][UNSTAKED_TOTAL_ID] + amount;

    _stakes[epochid][STAKES_PENDING_OUT_ID] = _stakes[epochid][STAKES_PENDING_OUT_ID] + 1;
    _stakepool[epochid][STAKEPOOL_PENDING_OUT_ID] = _stakepool[epochid][STAKEPOOL_PENDING_OUT_ID] + amount;

  }

  /**
   * @notice Allows a staker to withdraw a previously unstaked deposit.
   * @dev The function reverts under the following conditions:
   *      - The deposit does not exist.
   *      - The caller is not the owner of the deposit.
   *      - The deposit is still actively staked.
   *      - The deposit has already been withdrawn.
   *      - The withdrawal is attempted before the deposit's associated out epoch has ended.
   *      Requirements:
   *      - Only externally-owned accounts (EOAs) can invoke this function, enforced by the `onlyOffChainCallable` modifier.
   *      - The `nonReentrant` modifier ensures that the function cannot be called again until the first execution is complete.
   *      Emits:
   *      - `DepositWithdrawn` on successful withdrawal of the deposit.
   *      - `FATAL_EVENT_INSUFFICIENT_STAKEFUNDS` if the contract lacks sufficient funds to cover the withdrawal.
   * @param depositid The unique identifier of the deposit to be withdrawn.
   */
  function withdraw(
    bytes32 depositid
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    Deposit memory deposit = _deposits[depositid];
    if (deposit.depositid == 0x0) {
      revert("CannotWithdrawUnexistDeposit");
    }

    if (deposit.depositid != depositid) {
      revert("CannotWithdrawDamangedDeposit");
    }

    address staker = _msgSender();
    if (deposit.staker != staker) {
      revert("CannotWithdrawOtherStakerDeposit");
    }

    if (!deposit.unstaked) {
      revert("CannotWithdrawStakedDeposit");
    }

    if (deposit.withdrawn) {
      revert("CannotWithdrawWithdrawnDeposit");
    }

    if (
      deposit.inEpochid != deposit.outEpochid &&
      deposit.outEpochid >= ACTUAL_EPOCH_ID
    ) {
      revert("CannotWithdrawUntilOutEpochEnd");
    }

    if (IERC20(STAKING_ERC20_CONTRACT).balanceOf(address(this)) < deposit.amount) {
      __FATAL_INSUFFICIENT_STAKEFUNDS_ERROR__ = true;
      emit FATAL_EVENT_INSUFFICIENT_STAKEFUNDS(
        staker,
        STAKING_ERC20_CONTRACT,
        IERC20(STAKING_ERC20_CONTRACT).balanceOf(address(this)),
        deposit.amount
      );
      return;
    }

    _withdrawDeposit(depositid);

    emit DepositWithdrawn(
      depositid,
      staker
    );

    IERC20(STAKING_ERC20_CONTRACT).safeTransfer(staker, deposit.amount);

  }

  /**
   * @notice Marks the deposit as withdrawn.
   * @dev Internal function to handle the withdrawal of a specific deposit.
   *      It updates the internal state to reflect that the deposit has been withdrawn.
   * @param depositid The unique identifier of the deposit to be withdrawn.
   */
  function _withdrawDeposit(
    bytes32 depositid
  )
    private
  {

    Deposit storage deposit = _deposits[depositid];

    deposit.withdrawnAt = block.timestamp;
    deposit.withdrawn = true;

  }

  /**
   * @notice Claims the staking reward for a specific deposit within a given epoch.
   * @dev This function ensures that the reward claim process is secure and valid by performing several checks:
   *      - Validates that the provided ERC20 token address corresponds to an allowed reward token.
   *      - Ensures that the deposit exists and is owned by the caller.
   *      - Verifies that the provided epoch ID is within the valid range and associated with the deposit.
   *      - Checks that the reward for this deposit and epoch has not been fully claimed previously.
   *      - Confirms that the epoch exists and has been initialized correctly.
   *      - Ensures that the contract has sufficient funds to distribute the reward; otherwise, it emits a fatal error event.
   *      If all checks pass, the reward is calculated, the deposit is marked as rewarded, and the ERC20 tokens are transferred to the caller.
   *      Requirements:
   *      - The caller must own the deposit.
   *      - The epoch ID must be valid and associated with the deposit.
   *      - The epoch must be initialized before claiming rewards.
   *      - Can only be called by off-chain EOA (using `onlyOffChainCallable`).
   *      Emits:
   *      - `RewardClaimed` Event emitted when the reward is successfully claimed.
   *      - `FATAL_EVENT_INSUFFICIENT_REWARDFUNDS` Event emitted when the contract lacks sufficient funds to pay the reward.
   * @param epochid The ID of the staking epoch for which the reward is being claimed.
   * @param depositid The unique identifier of the deposit associated with the staker.
   * @param erc20 The address of the ERC20 token that represents the reward.
   */
  function claimReward(
    uint epochid,
    bytes32 depositid,
    address erc20
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    if (erc20 == address(0)) {
      revert("InvalidErc20Address");
    }

    Deposit memory deposit = _deposits[depositid];
    if (deposit.depositid == 0x0) {
      revert("CannotClaimRewardUnexistDeposit");
    }

    address staker = _msgSender();
    if (deposit.staker != staker) {
      revert("CannotClaimRewardOnOtherStakerDeposit");
    }

    if (epochid <= deposit.inEpochid) {
      revert("CannotClaimRewardEpochEarlierStakeInEpochEnd");
    }

    if (epochid > ACTUAL_EPOCH_ID) {
      revert("CannotClaimRewardEpochNewerActualEpoch");
    }

    if (epochid > deposit.outEpochid && deposit.unstaked) {
      revert("CannotClaimRewardEpochAfterStakeOutEpoch");
    }

    if (_claimed[epochid][erc20].contains(depositid)) {
      revert("CannotClaimAlreadyClaimedReward");
    }

    if (_epochs[epochid].epochid == 0) {
      revert("CannotClaimRewardForUncreatedEpoch");
    }

    uint payout = _calculatePayout(depositid, epochid, erc20, deposit.amount);

    if (IERC20(erc20).balanceOf(address(this)) < payout) {
      __FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__[erc20] = true;
      emit FATAL_EVENT_INSUFFICIENT_REWARDFUNDS(
        staker,
        depositid,
        erc20,
        epochid,
        payout
      );
      return;
    }

    _rewardDeposit(depositid, epochid, erc20, staker, payout);

    emit RewardClaimed(
      depositid,
      staker,
      erc20,
      epochid,
      payout
    );

    if (payout != 0) {
      IERC20(erc20).safeTransfer(staker, payout);
    }

  }

  /**
   * @notice Calculates the payout for a staker's deposit in a given epoch, specific to an ERC20 token.
   * @dev This function determines the payout by calculating the staker's proportionate share of the total collected ERC20 tokens for the specified epoch.
   *      It uses the formula: `Deposit Amount * Collected Amount / Stake Pool - Paiedout Amount`.
   *      It ensures no leftover balances in the pool by distributing the entire collected amount for the epoch.
   * @param depositid The unique identifier of the deposit.
   * @param epochid The ID of the epoch for which the payout is being calculated.
   * @param erc20 The address of the ERC20 token associated with the payout.
   * @param amount The amount of the deposit in the specified ERC20 token.
   * @return payout The calculated payout amount for the specified deposit, based on the token and epoch rules.
   */
  function _calculatePayout(
    bytes32 depositid,
    uint epochid,
    address erc20,
    uint amount
  )
    private
    view
    returns (
      uint payout
    )
  {

    payout = 0;

    if (_claimed[epochid][erc20].contains(depositid)) return ( payout );

    uint epochStakepool = _stakepool[epochid][STAKEPOOL_TOTAL_ID];
    uint epochRewardfunds = _rewardpool[epochid][erc20];

    uint totalpayout = (epochRewardfunds * amount) / epochStakepool;
    uint paidout = _payouts[depositid][erc20][epochid];

    if (paidout >= totalpayout) return ( payout );

    payout = totalpayout - paidout;

    if (ACTUAL_EPOCH_ID == epochid) return ( payout );

    // Handle potential rounding error
    uint remainingStakes = _stakes[epochid][STAKES_TOTAL_ID] - _claimed[epochid][erc20].length();

    if (remainingStakes == 1) {
      uint remainingReward = _rewardpool[epochid][erc20] - _releasedReward[epochid][erc20];
      if (remainingReward > payout) {

        payout = remainingReward;

      }
    }

  }

  /**
   * @notice Distributes rewards to a staker for a specific deposit in the given epoch.
   * @dev Rewards a staker's deposit for a specific epoch by:
   *      - Marking the deposit as claimed for the epoch (if the epoch is not the current one).
   *      - Updating payout tracking for the deposit, staker, and global epoch rewards.
   *      - Ensuring that sufficient rewards are available before distributing the payout.
   *      - Reverting the transaction if the distributed rewards exceed the collected rewards.
   * @param depositid Unique identifier of the deposit.
   * @param epochid The epoch during which the reward is being distributed.
   * @param erc20 The address of the ERC20 token used for the reward payout.
   * @param staker The address of the staker who owns the deposit.
   * @param payout The amount of the reward to be distributed.
   */
  function _rewardDeposit(
    bytes32 depositid,
    uint epochid,
    address erc20,
    address staker,
    uint payout
  )
    private
  {

    if (ACTUAL_EPOCH_ID != epochid) {
      _claimed[epochid][erc20].add(depositid);
    }

    if (payout != 0) {
      _depositPayouts[depositid][erc20] = _depositPayouts[depositid][erc20] + payout;
      _stakerPayouts[staker][erc20] = _stakerPayouts[staker][erc20] + payout;
      _payouts[depositid][erc20][epochid] = _payouts[depositid][erc20][epochid] + payout;

      _releasedReward[epochid][erc20] = _releasedReward[epochid][erc20] + payout;
    }

    if (_releasedReward[epochid][erc20] > _rewardpool[epochid][erc20]) {
      revert("InsufficientRewardfunds");
    }

  }

  /**
   * @notice Allows a designated gatherer to collect staking rewards from a bettor's prize.
   *         This function facilitates the transfer of ERC20 tokens from the gatherer's balance to the contract and processes the reward distribution.
   * @dev This function performs several important checks to ensure secure commission collection:
   *      - Ensures that the gatherer has a sufficient balance of ERC20 tokens to cover the request for commission collection.
   *      - Verifies that the gatherer has approved the contract to transfer at least `commission` of ERC20 tokens.
   *      Requirements:
   *      - The caller must be an authorized gatherer (`onlyGathererCallable`).
   *      - The gatherer must have a sufficient balance and allowance for the ERC20 token.
   *      - The function is protected against reentrancy attacks using the `nonReentrant` modifier.
   *      Emits:
   *      - `NewEpochStarted` event to indicate the start of a new epoch.
   *      - `RewardCollected` event when the commission is successfully collected and transferred to the contract.
   * @param bettor The address of the bettor who paid the commission.
   * @param erc20 The address of the ERC20 token contract from which tokens will be collected.
   * @param commission The amount of ERC20 tokens to collect for reward distribution.
   */
  function collectCommission(
    address bettor,
    address erc20,
    uint commission
  )
    external
    override
    nonReentrant
    onlyGathereCallable
  {
    address sender = _msgSender();
    if (IERC20(erc20).balanceOf(sender) < commission) {
      revert("InsufficientFunds");
    }
    if (IERC20(erc20).allowance(sender, address(this)) < commission) {
      revert("InsufficientAllowance");
    }

    _collectCommission(bettor, erc20, commission);

    IERC20(erc20).safeTransferFrom(sender, address(this), commission);

  }

  /**
   * @notice Handles the collection of staking rewards by a designated gatherer from a bettor's prize.
   *         This function registers the collected rewards for future distribution.
   * @dev Key validations and operations include:
   *      - Verifying the gathered `commission` is greater than zero.
   *      - Checking that the ERC20 token is not flagged as blocked.
   *      - Automatically starting a new epoch if the current one has ended.
   *      Requirements:
   *      - `bettor` must be valid address.
   *      - `commission` must be greater than zero.
   *      - The selected ERC20 token must not be blocked.
   *      - The epoch must exist.
   *      Emits:
   *      - `NewEpochStarted` event to indicate the start of a new epoch.
   *      - `RewardCollected` event when the reward is successfully collected and transferred to the contract.
   * @param bettor The address of the bettor who paid the commission.
   * @param erc20 The address of the ERC20 token contract from which tokens will be collected.
   * @param commission The amount of ERC20 tokens to collect and transfer for reward distribution.
   */
  function _collectCommission(
    address bettor,
    address erc20,
    uint commission
  )
    private
  {

    if (bettor == address(0)) {
      revert("CannotCollectFromZeroAccount");
    }

    if (commission == 0) {
      revert("CannotCollectZeroAmount");
    }

    address sender = _msgSender();
    if (sender == address(0)) {
      revert("CannotCollectFromZeroGatherer");
    }

    if (__FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__[erc20]) {
      revert("CannotCollectRewardERC20TokenIsBlocked");
    }

    if (_epochs[ACTUAL_EPOCH_ID].endDate <= block.timestamp) {
      _startEpoch(ACTUAL_EPOCH_ID + 1);
    }

    if (_epochs[ACTUAL_EPOCH_ID].epochid == 0) {
      revert("CannotCollectRewardsIntoUncreatedEpoch");
    }

    _updateRewardpool(erc20, commission);

    emit CommissionCollected(
      ACTUAL_EPOCH_ID,
      erc20,
      bettor,
      commission
    );

  }

  /**
   * @notice Updates the total collected reward for the current epoch and the specified ERC20 token.
   *         This function increments the collected reward for the current epoch by the specified amount.
   * @dev Internal function to update the collected reward mapping for the current epoch.
   * @param erc20 The address of the ERC20 token for which the reward is being added.
   * @param commission The amount of the reward to be added to the total collected reward.
   */
  function _updateRewardpool(
    address erc20,
    uint commission
  )
    private
  {

    _rewardpool[ACTUAL_EPOCH_ID][erc20] = _rewardpool[ACTUAL_EPOCH_ID][erc20] + commission;

  }

  /**
   * @notice Initiates a new staking epoch, creating a stakepool for the given epoch and marking the previous epoch as ended.
   * @dev This function is used to handle the transition between staking epochs.
   *      It creates a new stakepool for the specified epoch and updates the internal tracking for the current epoch.
   *      The previous epoch is marked as ended, and the current epoch ID is updated.
   *      Emits the `NewEpochStarted` event to indicate the start of a new epoch.
   * @param epochid The ID of the epoch to start.
   */
  function _startEpoch(
    uint epochid
  )
    private
  {

    bool created = _createStakepool(epochid);
    if (created) {
      _createEpoch(epochid);
      _epochs[ACTUAL_EPOCH_ID].endedAt = block.timestamp;
      ACTUAL_EPOCH_ID = epochid;
    }

  }

  /**
   * @notice Creates a new stakepool for the specified epoch.
   *         If a stakepool and stakes exist for the current epoch, they will be transferred to the new epoch.
   * @dev The function calculates the total stakepool and stakes for the current epoch and transfers them to the specified new epoch, provided they are non-zero.
   * @param epochid The ID of the epoch for which to create the stakepool.
   * @return created A boolean indicating whether the stakepool was successfully created.
   */
  function _createStakepool(
    uint epochid
  )
    private
    returns (
      bool created
    )
  {

    created = false;

    uint stakepool = (
      (
        _stakepool[ACTUAL_EPOCH_ID][STAKEPOOL_TOTAL_ID]
      +
        _stakepool[ACTUAL_EPOCH_ID][STAKEPOOL_PENDING_IN_ID]
      )
    -
      _stakepool[ACTUAL_EPOCH_ID][STAKEPOOL_PENDING_OUT_ID]
    );

    uint stakes = (
      (
        _stakes[ACTUAL_EPOCH_ID][STAKES_TOTAL_ID]
      +
        _stakes[ACTUAL_EPOCH_ID][STAKES_PENDING_IN_ID]
      )
    -
      _stakes[ACTUAL_EPOCH_ID][STAKES_PENDING_OUT_ID]
    );

    if (stakepool != 0 && stakes != 0) {
      _stakepool[epochid][STAKEPOOL_TOTAL_ID] = stakepool;
      _stakes[epochid][STAKES_TOTAL_ID] = stakes;
      created = true;
    }

  }

  /**
   * @notice Creates a new staking epoch if it does not already exist.
   * @dev Initializes a new epoch by setting its ID, start date, and end date.
   *      This function also records the current block timestamp as the epoch's start time.
   *      Emits the `NewEpochStarted` event to indicate the start of a new epoch.
   * @param epochid The unique ID of the epoch to be created.
   */
  function _createEpoch(
    uint epochid
  )
    private
  {

    Epoch storage epoch = _epochs[epochid];
    if (epoch.epochid == 0 && epochid != 0) {

      epoch.epochid = epochid;

      uint sincestart = block.timestamp % SCHEDULE;
      uint startDate = block.timestamp - sincestart;
      uint endDate = startDate + SCHEDULE;

      epoch.startDate = startDate;
      epoch.endDate = endDate;
      epoch.startedAt = block.timestamp;

      emit NewEpochStarted(
        epoch.epochid,
        ACTUAL_EPOCH_ID,
        STAKING_ERC20_CONTRACT,
        block.timestamp,
        startDate,
        endDate,
        _stakes[epochid][STAKES_TOTAL_ID],
        _stakepool[epochid][STAKEPOOL_TOTAL_ID]
      );

    }

  }

  /**
   * @notice Restricts function execution to external accounts (EOA) only.
   * @dev This modifier ensures that only EOAs (Externally Owned Accounts) can call functions protected by this modifier, preventing contracts from executing such functions.
   *      The check is performed by verifying that the caller has no code associated with it (not a contract) and by comparing `tx.origin` with `_msgSender()`.
   */
  modifier onlyOffChainCallable() {
    address sender = _msgSender();
    if (sender.code.length > 0) {
      revert("OnlyEOASendersAllowed");
    }
    if (tx.origin != sender) {
      revert("OnlyEOASendersAllowed");
    }
    _;
  }

  /**
   * @notice Restricts function execution to the authorized funds gatherer.
   * @dev This modifier ensures that only the authorized entity, defined by the `AUTHORIZED_COMMISSION_GATHERER` address, can call functions protected by this modifier.
   *      If an unauthorized entity tries to invoke the function, the transaction is reverted.
   */
  modifier onlyGathereCallable() {
    address sender = _msgSender();
    if (sender != AUTHORIZED_COMMISSION_GATHERER) {
        revert("RejectUnknownGathere");
    }
    _;
  }

  /**
   * @notice Emitted when there are insufficient reward funds available to fulfill a staker's reward claim.
   * @dev Acts as an important signal for stakers, indicating that the contract cannot collect the specific ERC20 token and that a manual EOA (Externally Owned Account) distribution is required.
   * @param staker The address of the staker attempting to claim the reward.
   * @param depositid The unique identifier of the staker's deposit.
   * @param erc20 The address of the ERC20 token associated with the reward being claimed.
   * @param epochid The ID of the staking epoch in which the reward being claimed.
   * @param payout The amount of the reward that could not be fulfilled due to insufficient funds.
   */
  event FATAL_EVENT_INSUFFICIENT_REWARDFUNDS(
    address staker,
    bytes32 depositid,
    address erc20,
    uint epochid,
    uint payout
  );

  /**
   * @notice Emitted when a staker attempts to withdraw an unstaked deposit, but the contract does not have sufficient balance of the staking token (ORCY) to complete the withdrawal.
   * @dev This serves as a crucial signal for stakers to know that the contract is blocked, and a manual EOA distribution is required.
   * @param staker The address of the staker attempting to withdraw funds.
   * @param erc20 The address of the ERC20 token in which the staked funds are held.
   * @param balance The current ERC20 token balance held by the contract.
   * @param amount The amount of ERC20 tokens the staker attempted to withdraw, which the contract could not fulfill.
   */
  event FATAL_EVENT_INSUFFICIENT_STAKEFUNDS(
    address staker,
    address erc20,
    uint balance,
    uint amount
  );

  /**
   * @notice Emitted when a staker unstakes a deposit.
   * @dev This event is triggered when a staker initiates the process of unstaking their deposit from a specific epoch.
   * @param depositid The unique identifier of the unstaked deposit.
   * @param staker The address of the staker who unstaked the deposit.
   * @param epochid The identifier of the epoch during which the deposit was unstaked.
   */
  event DepositUnstaked(
    bytes32 indexed depositid,
    address indexed staker,
    uint indexed epochid
  );

  /**
   * @notice Emitted when a staker successfully withdraws their stake deposit.
   * @dev This event indicates the complete removal of deposited funds by a staker from the contract.
   * @param depositid The unique identifier of the withdrawn deposit.
   * @param staker The address of the staker who initiated the withdrawal.
   */
  event DepositWithdrawn(
    bytes32 indexed depositid,
    address indexed staker
  );

  /**
   * @notice Emitted when a staker claims their staking reward for a specific deposit during a particular epoch.
   * @dev This event is triggered after a successful reward claim by a staker.
   *      The event parameters provide detailed information about the deposit, staker, reward token, epoch, and payout amount.
   * @param depositid The unique identifier of the deposit for which the reward is claimed.
   * @param staker The address of the staker who claimed the reward.
   * @param erc20 The address of the ERC20 token representing the reward.
   * @param epochid The ID of the epoch in which the reward was earned.
   * @param payout The amount of reward claimed by the staker.
   */
  event RewardClaimed(
    bytes32 indexed depositid,
    address indexed staker,
    address indexed erc20,
    uint epochid,
    uint payout
  );

  /**
   * @notice Emitted when staking rewards are collected from a bettor's paid commission.
   * @dev This event logs the commission collection for a specific epoch and bettor.
   * @param epochid The identifier of the staking epoch during which the commission is collected.
   * @param erc20 The address of the ERC20 token contract from which tokens are collected.
   * @param bettor The address of the bettor who paid the commission.
   * @param commission The amount of ERC20 tokens collected as commission for reward distribution.
   */
  event CommissionCollected(
    uint indexed epochid,
    address indexed erc20,
    address indexed bettor,
    uint commission
  );

  /**
   * @notice Emitted when a new staking epoch is initiated, signaling the transition between epochs.
   * @dev This event provides details about the newly started staking epoch, including its unique identifiers, the ERC20 token being staked, the staking period timestamps, and information about the stakes and stakepool.
   * @param epochid The unique identifier of the newly started staking epoch.
   * @param prevepochid The unique identifier of the epoch that directly preceded the new one.
   * @param erc20 The address of the staking token (ORCY) used for stakepool of the epoch.
   * @param startedAt The timestamp when the new epoch was started.
   * @param startDate The timestamp representing the start of the new epoch's staking period.
   * @param endDate The timestamp representing the end of the new epoch's staking period.
   * @param stakes The total amount of deposits staked in new epoch.
   * @param stakepool The total amount of tokens staked in the new epoch.
   */
  event NewEpochStarted(
    uint indexed epochid,
    uint indexed prevepochid,
    address erc20,
    uint startedAt,
    uint startDate,
    uint endDate,
    uint stakes,
    uint stakepool
  );

  /**
   * @notice Emitted when a staker deposits ORCY tokens into the contract, either by creating a new deposit or increasing an existing one.
   * @dev This event is emitted every time a staker deposits ORCY tokens into the contract, whether it is a new deposit or an increase to an existing one.
   * @param depositid The unique identifier of the deposit being created or increased.
   * @param staker The address of the staker making the deposit.
   * @param amount The amount of ORCY tokens deposited.
   */
  event IncreaseDepositAmount(
      bytes32 indexed depositid,
      address indexed staker,
      uint amount
  );

  /**
   * @notice Emitted when a new stake deposit is created in the contract.
   * @dev This event is triggered whenever a staker successfully creates a new deposit.
   *      It provides details about the deposit including the unique deposit ID, epoch ID, staker's address, timestamp of creation, and the ERC20 token being staked.
   * @param depositid Unique identifier for the deposit.
   * @param epochid The ID of the staking epoch in which the deposit is created.
   * @param staker The address of the staker who made the deposit.
   * @param createdAt The timestamp when the deposit is created.
   * @param erc20 The address of the staking token (ORCY) being staked in the deposit.
   */
  event DepositCreated(
      bytes32 indexed depositid,
      uint indexed epochid,
      address indexed staker,
      uint createdAt,
      address erc20
  );

  /**
   * @notice Emitted when a new gatherer is authorized for the contract.
   * @dev This event is triggered whenever the contract owner (Oracly Team) assigns a new gatherer.
   * @param gatherer The address of the authorized gatherer.
   */
  event AuthorizedGathererSet(
      address indexed gatherer
  );

  /**
   * @notice This event is emitted when the ERC20 token accepted for the Buy4Stake functionality is changed.
   *         It indicates that a new ERC20 token will now be used for acquiring ORCY tokens via staking.
   * @dev This event is critical for tracking updates to the ERC20 token used in Buy4Stake operations.
   * @param erc20 The address of the new ERC20 token that is now accepted for Buy4Stake.
   */
  event Buy4StakeAcceptedERC20Set(
    address indexed erc20
  );

  /**
   * @notice Emitted when the Buy4Stake pool balance is increased.
   * @dev This event signals that more funds have been added to the Buy4Stake pool.
   *      The new total balance of the Buy4Stake pool and the amount that was added.
   * @param erc20 The address of the staking token (ORCY) being added to the Buy4Stake pool.
   * @param stakepool The new balance of the Buy4Stake pool after the increase.
   * @param amount The amount added to the Buy4Stake pool.
   */
  event Buy4StakepoolIncreased(
    address indexed erc20,
    uint stakepool,
    uint amount
  );

  /**
   * @notice Emitted when funds are released from the Buy4Stake pool.
   * @dev This event logs the details of funds being released from the Buy4Stake pool, including the updated stake pool balance and the amount released.
   * @param erc20 The address of the staking token (ORCY) associated with the release.
   * @param stakepool The updated balance of the stake pool after the funds are released.
   * @param amount The amount of ERC20 tokens that were released from the pool.
   */
  event Buy4StakepoolReleased(
    address indexed erc20,
    uint stakepool,
    uint amount
  );

}
