// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ICommissionCollector } from "../interfaces/ICommissionCollector.sol";
import { IRewardCalculator } from "../interfaces/IRewardCalculator.sol";

/**
 * @title OraclyV1 Mentoring Protocol
 * @notice This contract establishes the mentorship structure, including mentor registration, reward distribution based on Proteges' success, and relationship tracking within the Oracly Protocol.
 * @dev Implements a mentorship system within the Oracly Protocol, allowing experienced bettors (Mentors) to guide less experienced bettors (Proteges) through prediction games.
 *      The contract manages mentor registrations, tracks mentor-protege relationships, and handles the distribution of Mentoring Rewards.
 *      Mentoring Rewards are calculated as a fixed percentage (0.25%) of the Proteges' winnings from prediction games, encouraging knowledge sharing within the ecosystem.
 */
contract MentoringOraclyV1 is Ownable, ReentrancyGuard, ICommissionCollector, IRewardCalculator {

  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  /**
   * @notice Percentage of the total Prediction Reward allocated to Mentoring Rewards, expressed in basis points.
   * @dev The value is set in basis points, where 1% equals 100 basis points.
   *      Constant is set to `25` (0.25%) of the commission is allocated to mentoring rewards.
   */
  uint8 constant public MENTOR_COMMISSION_PERCENTAGE = 25;

  /**
   * @notice Maps a participant's address to an array tracking the historical timestamps of their mentorship activities.
   * @dev [0] - Protege creation timestamp, [1] - Protege update timestamp, [2] - Mentor creation timestamp, [3] - Mentor update timestamp.
   */
  mapping(address => uint[4]) private _history;

  /**
   * @notice Maps a Protege's address to their assigned Mentor's address.
   * @dev Used to establish the mentor-protege relationship.
   */
  mapping(address => address) private _registry;

  /**
   * @notice Maps a Mentor's address to a set of their Proteges' addresses.
   * @dev Tracks active relationships between Mentors and their Proteges.
   */
  mapping(address => EnumerableSet.AddressSet) private _circle;

  /**
   * @notice Stores Mentoring Rewards accrued by a Mentor from a specific ERC20 token.
   * @dev The first address is the Mentor, the second address is the ERC20 token, and the result is the accumulated rewards.
   */
  mapping(address => mapping(address => uint)) private _mentorRewards;

  /**
   * @notice Tracks payouts already received by Mentors from a specific ERC20 token.
   * @dev The first address is the Mentor, the second address is the ERC20 token, and the result is the accumulated payouts.
   */
  mapping(address => mapping(address => uint)) private _mentorPayouts;

  /**
   * @notice Tracks the total Prediction Rewards earned by a Protege under a specific Mentor.
   * @dev The first address represents the Mentor, the second represents the Protege, and the third represents the ERC20 token in which the earnings are tracked. The result is the amount of the token earned by the Protege under the Mentor.
   */
  mapping(address => mapping(address => mapping(address => uint))) private _protegeEarned;

  /**
   * @notice Tracks the total earnings accumulated by a Protege in ERC20 tokens.
   * @dev The first address is the Protege, the second is the ERC20 token contract address, and the result is the amount of the token earned by this Protege across all mentors.
   */
  mapping(address => mapping(address => uint)) private _protegeEarnedTOTAL;

  /**
   * @notice Tracks whether the contract is experiencing insufficient reward funds for distribution.
   * @dev This flag is set to prevent further operations when reward funds are insufficient.
   */
  mapping(address => bool) public __FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__;

  /**
   * @notice The address of the authorized funds gatherer for the contract.
   * @dev This is the address responsible for gathering mentoring rewards from the bettor's prize on withdrawal and passing them to the contract for further distribution to mentors.
   */
  address public AUTHORIZED_COMMISSION_GATHERER = address(0);

  /**
   * @notice Index for tracking the protege's creation timestamp.
   * @dev This constant is used to store the timestamp when the protege was first created in the `_history` mapping.
   */
  uint8 constant private PROTEGE_CREATED_AT_ID = 0;

  /**
   * @notice Index for tracking the protege's last update timestamp.
   * @dev This constant is used to store the timestamp when the protege was last updated in the `_history` mapping.
   */
  uint8 constant private PROTEGE_UPDATED_AT_ID = 1;

  /**
   * @notice Index for tracking the mentor's creation timestamp.
   * @dev This constant is used to store the timestamp when the mentor was first created in the `_history` mapping.
   */
  uint8 constant private MENTOR_CREATED_AT_ID = 2;

  /**
   * @notice Index for tracking the mentor's last update timestamp.
   * @dev This constant is used to store the timestamp when the mentor was last updated in the `_history` mapping.
   */
  uint8 constant private MENTOR_UPDATED_AT_ID = 3;

  /**
   * @dev Constructor that initializes the contract, setting the deployer as the owner (Oracly Team) and granting them the role of `AUTHORIZED_COMMISSION_GATHERER`.
   *      The contract deployer is automatically assigned as the owner (Oracly Team) of the contract through the `Ownable` constructor.
   *      Additionally, the deployer is designated as the `AUTHORIZED_COMMISSION_GATHERER`, a role required for gathering funds.
   * @notice The deployer will automatically be granted the required permissions to gather funds into the contract.
   */
  constructor()
    Ownable(_msgSender())
  {
    AUTHORIZED_COMMISSION_GATHERER = _msgSender();
  }

  /**
   * @notice Retrieves information about a mentor including proteges, rewards, and payout history for a given ERC20 token.
   * @dev Returns detailed mentor information for the specified ERC20 token, including associated proteges and financial data.
   * @param mentor The address of the mentor.
   * @param erc20 The address of the ERC20 token.
   * @return mentorid the address of the mentor.
   * @return circle The number of proteges associated with the mentor.
   * @return rewards The total rewards earned by the mentor in the specified ERC20 token.
   * @return payouts The total payouts made to the mentor in the specified ERC20 token.
   * @return createdAt The timestamp when the mentor was created.
   * @return updatedAt The timestamp when the mentor's information was last updated.
   */
  function getMentor(
    address mentor,
    address erc20
  )
    external
    view
    returns (
      address mentorid,
      uint circle,
      uint rewards,
      uint payouts,
      uint createdAt,
      uint updatedAt
    )
  {

    if (_history[mentor][MENTOR_CREATED_AT_ID] != 0) mentorid = mentor;

    circle = _circle[mentorid].length();
    rewards = _mentorRewards[mentorid][erc20];
    payouts = _mentorPayouts[mentorid][erc20];
    createdAt = _history[mentorid][MENTOR_CREATED_AT_ID];
    updatedAt = _history[mentorid][MENTOR_UPDATED_AT_ID];

  }

  /**
   * @notice Retrieves detailed information about a specific Protege, including their mentor, earned rewards for a given ERC20 token, and timestamps for creation and updates.
   * @dev This function is a view function that returns the following information about the Protege:
   *      - Protege's address
   *      - Mentor's address
   *      - Earned rewards for the ERC20 token with the mentor
   *      - Total earned rewards for the ERC20 token across all mentors
   *      - Timestamps for creation and last update
   * @param protege The address of the Protege whose information is being retrieved.
   * @param erc20 The address of the ERC20 token for which reward details are queried.
   * @return protegeid The Protege's address, if found.
   * @return mentor The address of the Protege's mentor.
   * @return earned The rewards earned by the Protege for the specified ERC20 token with their mentor.
   * @return earnedTotal The total rewards earned by the Protege for the specified ERC20 token.
   * @return createdAt The timestamp when the Protege was first created.
   * @return updatedAt The timestamp when the Protege's information was last updated.
   */
  function getProtege(
    address protege,
    address erc20
  )
    external
    view
    returns (
      address protegeid,
      address mentor,
      uint earned,
      uint earnedTotal,
      uint createdAt,
      uint updatedAt
    )
  {

    if (_history[protege][PROTEGE_CREATED_AT_ID] != 0) protegeid = protege;

    mentor = _registry[protegeid];
    earned = _protegeEarned[protegeid][erc20][mentor];
    earnedTotal = _protegeEarnedTOTAL[protegeid][erc20];
    createdAt = _history[protegeid][PROTEGE_CREATED_AT_ID];
    updatedAt = _history[protegeid][PROTEGE_UPDATED_AT_ID];

  }

  /**
   * @notice Retrieves a paginated list of Proteges associated with a specific Mentor.
   * @dev This function returns a list of Protege addresses along with the total number of Proteges linked to the given Mentor.
   *      The results can be paginated by specifying an offset.
   * @param mentor The address of the Mentor whose Proteges are being queried.
   * @param offset The starting index for the pagination of the Protege list.
   * @return proteges An array of addresses representing the Proteges.
   * @return size The total number of Proteges associated with the Mentor.
   */
  function getMentorProteges(
    address mentor,
    uint offset
  )
    external
    view
    returns (
      address[] memory proteges,
      uint size
    )
  {

    proteges = new address[](0);
    size = _circle[mentor].length();

    if (size == 0) return (proteges, size);
    if (offset >= size) return (proteges, size);

    uint rest = size - offset;
    uint lastidx = 0;
    if (rest > 20) {
      lastidx = rest - 20;
    }
    uint resultSize = rest - lastidx;
    proteges = new address[](resultSize);

    uint idx = 0;
    while (idx != resultSize) {
      proteges[idx] = _circle[mentor].at(rest - 1 - idx);
      idx++;
    }

  }

  /**
   * @notice Returns the amount of ERC20 tokens earned by a mentor from a specified protege.
   * @dev This function retrieves the accumulated earnings a mentor has gained from their protege in the specified ERC20 token.
   * @param protege The address of the protege whose earnings are being queried.
   * @param erc20 The address of the ERC20 token for which the earnings are being checked.
   * @param mentor The address of the mentor who has earned the tokens.
   * @return earned The total amount of ERC20 tokens earned by the mentor from the protege.
   */
  function getProtegeMentorEarned(
    address protege,
    address erc20,
    address mentor
  )
    external
    view
    returns (
      uint earned
    )
  {

    earned = _protegeEarned[protege][erc20][mentor];

  }

  /**
   * @notice Sets the authorized funds gatherer address.
   *         Only callable by the contract owner (Oracly Team).
   * @dev Updates the address authorized to gather funds. This function can only be executed by the contract owner (Oracly Team).
   *      It ensures that the new gatherer is valid contract address.
   *      Emits `AuthorizedGathererSet` event upon successful update of the gatherer address.
   *      This function is protected by `onlyOwner` to ensure that only the contract owner can change the gatherer.
   * @param gatherer The new address to be set as the gatherer.
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
   * @notice Allows a proteges to join a mentor-protege relationship.
   * @dev This function is external and non-reentrant, ensuring it can only be called from outside the contract and preventing re-entrancy attacks.
   *      The `onlyOffChainCallable` modifier restricts access to off-chain EOA to prevent internal or contract-based invocation.
   *      Emits an `JoinedMentor` event upon successful join.
   * @param mentor The address of the mentor that the protege wants to join.
   */
  function joinMentor(
    address mentor
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    address protege = _msgSender();
    _joinMentor(mentor, protege);

  }

  /**
   * @notice Establishes a mentor-protege relationship between two addresses.
   *         This function is used internally to manage and enforce the rules around mentoring relationships.
   * @dev Internal helper function that validates both mentor and protege addresses, ensuring:
   *      - The mentor and protege are valid addresses.
   *      - The mentor and protege are not the same address.
   *      - Circular mentoring relationships are not allowed (i.e., the protege cannot mentor the mentor).
   *      The function then updates the contract's internal state to reflect the newly established relationship.
   *      Emits an `JoinedMentor` event upon successful join.
   * @param mentor The address of the mentor to be linked in the relationship.
   * @param protege The address of the protege who will be under the mentorship of the mentor.
   */
  function _joinMentor(
    address mentor,
    address protege
  )
    private
  {

    if (mentor == address(0)) {
      revert("MentorAddressCannotBeZero");
    }

    if (protege == address(0)) {
      revert("ProtegeAddressCannotBeZero");
    }

    if (_registry[protege] != address(0)) {
      revert("CannotRejoinProtege");
    }

    if (mentor == protege) {
      revert("CannotJoinToSelf");
    }

    // Block circular mentoring
    // By not allowing mentors to become proteges
    if (_circle[protege].length() != 0) {
      revert("MentorCannotBecomeProtege");
    }

    _registry[protege] = mentor;
    if (_history[protege][PROTEGE_CREATED_AT_ID] == 0) _history[protege][PROTEGE_CREATED_AT_ID] = block.timestamp;
    _history[protege][PROTEGE_UPDATED_AT_ID] = block.timestamp;

    _circle[mentor].add(protege);
    if (_history[mentor][MENTOR_CREATED_AT_ID] == 0) _history[mentor][MENTOR_CREATED_AT_ID] = block.timestamp;
    _history[mentor][MENTOR_UPDATED_AT_ID] = block.timestamp;

    emit JoinedMentor(
      protege,
      mentor
    );

  }

  /**
   * @notice Removes a Protege from the Mentor's circle.
   *         This function can only be called by the Mentor who currently mentors the Protege.
   * @dev Requirements:
   *      - The caller of the function (the `mentor`) must be the current mentor of the `protege`.
   *      - `protege` must be currently associated with the calling `mentor`.
   *      Emits an `ProtegeExpelled` event upon successful removal.
   * @param protege The address of the Protege to be expelled from the Mentor's circle.
   */
  function expelProtege(
    address protege
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    address mentor = _msgSender();
    _expelProtege(protege, mentor);

  }

  /**
   * @notice Removes a Protege from a Mentor's circle.
   * @dev Internal helper function to remove a Protege from a Mentor's circle.
   *      This function handles the core logic of removing the Protege, updating relevant storage.
   *      It ensures that the specified Protege is no longer associated with the Mentor.
   *      Emits an `ProtegeExpelled` event upon successful removal.
   * @param protege The address of the Protege to be removed from the Mentor's circle.
   * @param mentor The address of the Mentor removing the Protege from their circle.
   */
  function _expelProtege(
    address protege,
    address mentor
  )
    private
  {

    if (protege == address(0)) {
      revert("ProtegeAddressCannotBeZero");
    }

    if (mentor == address(0)) {
      revert("MentorAddressCannotBeZero");
    }

    if (_registry[protege] != mentor) {
      revert("CannotRemoveUnmentoredProtege");
    }

    if (!_circle[mentor].contains(protege)) {
      revert("CannotRemoveUnmentoredProtege");
    }

    _registry[protege] = address(0);
    if (_history[protege][PROTEGE_CREATED_AT_ID] == 0) _history[protege][PROTEGE_CREATED_AT_ID] = block.timestamp;
    _history[protege][PROTEGE_UPDATED_AT_ID] = block.timestamp;

    _circle[mentor].remove(protege);
    if (_history[mentor][MENTOR_CREATED_AT_ID] == 0) _history[mentor][MENTOR_CREATED_AT_ID] = block.timestamp;
    _history[mentor][MENTOR_UPDATED_AT_ID] = block.timestamp;

    emit ProtegeExpelled(
      protege,
      mentor
    );

  }

  /**
   * @notice Transfers a protege from one mentor to another.
   *         The caller must be the current mentor of the protege.
   * @dev This function ensures that a protege's mentorship is updated by transferring them from one mentor to another.
   *      The transaction is protected against reentrancy attacks and can only be called from an off-chain context.
   *      Emits an `ProtegeExpelled` event upon successful removal from an old mentor.
   *      Emits an `JoinedMentor` event upon successful join to a new mentor.
   * @param protege The address of the protege being transferred.
   * @param mentor The address of the new mentor to which the protege is assigned.
   */
  function transferProtege(
    address protege,
    address mentor
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    address sender = _msgSender();
    _expelProtege(protege, sender);
    _joinMentor(mentor, protege);

  }

  /**
   * @notice Calculates the Mentoring Reward for a specific protege based on a provided amount.
   * @dev This function is an external view override, meaning it can be called externally to view the calculated reward for a protege without any gas fees for state changes.
   * @param protege The address of the protege whose reward is being calculated.
   * @param amount The amount used as the base for the reward calculation.
   * @return reward The calculated Mentoring Reward for the given protege and amount.
   */
  function calculateReward(
    address protege,
    uint amount
  )
    external
    view
    override
    returns (
      uint reward
    )
  {

    (, reward) = _calculateReward(protege, amount);

  }

  /**
   * @notice Calculates the Mentoring Reward for a given protege and commission, and retrieves the mentor's address.
   * @dev This is an internal function that calculates the reward for a mentor based on the protege's paid commission.
   *      The function returns the mentor's address and the calculated reward.
   * @param protege The address of the protege whose mentor will receive the reward.
   * @param commission The amount based on which the reward will be calculated.
   * @return mentor The address of the mentor who is associated with the protege.
   * @return reward The calculated reward for the mentor.
   */
  function _calculateReward(
    address protege,
    uint commission
  )
    private
    view
    returns (
      address mentor,
      uint reward
    )
  {

    reward = 0;

    mentor = _registry[protege];
    if (mentor != address(0)) {

      reward = Math.ceilDiv(commission * MENTOR_COMMISSION_PERCENTAGE, 100);

    }

  }

  /**
   * @notice Collects a reward from commission of a protege's prize and distributes it to the corresponding Mentoring Reward pool.
   *         The function facilitates the transfer of rewards from the protege to the mentor's reward pool using the specified ERC20 token.
   * @dev Collects a reward from commission of a protege's prize and distributes it to the associated mentor.
   *      Requirements:
   *      - `protege` and `sender` must be valid.
   *      - `commission` must be greater than zero.
   *      - The specified ERC20 token must not be blocked for reward collection.
   *      - The caller must have sufficient ERC20 token balance and allowance.
   *      - The function ensures reentrancy protection and restricts access using the `onlyGathereCallable` modifier.
   *      Emits a `MentorfundsAdded` event upon successful reward distribution to the mentor.
   * @param protege The address of the protege, who is receiving mentorship.
   * @param erc20 The address of the ERC20 token used for the reward distribution.
   * @param commission The amount of the ERC20 token to collect and distribute as the reward.
   */
  function collectCommission(
    address protege,
    address erc20,
    uint commission
  )
    external
    override
    nonReentrant
    onlyGathereCallable
  {
    if (commission == 0) {
      revert("CannotCollectZeroAmount");
    }

    if (protege == address(0)) {
      revert("CannotCollectFromZeroProtege");
    }

    address sender = _msgSender();
    if (sender == address(0)) {
      revert("CannotCollectFromZeroGatherer");
    }

    if (__FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__[erc20]) {
      revert("CannotCollectRewardERC20TokenIsBlocked");
    }

    (address mentor, uint reward) = _calculateReward(protege, commission);
    if (protege == mentor) {
      revert("CannotCollectFromZeroProtege");
    }

    if (reward != 0) {
      _mentorRewards[mentor][erc20] = _mentorRewards[mentor][erc20] + reward;

      _protegeEarned[protege][erc20][mentor] = _protegeEarned[protege][erc20][mentor] + reward;
      _protegeEarnedTOTAL[protege][erc20] = _protegeEarnedTOTAL[protege][erc20] + reward;

      if (IERC20(erc20).balanceOf(sender) < reward) {
        revert("InsufficientFunds");
      }
      if (IERC20(erc20).allowance(sender, address(this)) < reward) {
        revert("InsufficientAllowance");
      }

      IERC20(erc20).safeTransferFrom(sender, address(this), reward);

      emit MentorfundsAdded(
        protege,
        mentor,
        erc20,
        reward
      );
    }
  }

  /**
   * @notice Allows the Mentor (caller) to claim their accumulated Mentoring Reward for a specified ERC20 token.
   * @dev This function transfers the accumulated Mentoring Reward for the specified ERC20 token to the caller.
   *      Requirements:
   *       - `erc20` must be a valid ERC20 token address.
   *       - The caller must have accumulated Mentoring Rewards for the specified ERC20 token.
   *       - The contract must hold enough balance of the specified ERC20 token to cover the reward payout.
   *      Emits:
   *       - `MentorRewardPayout` event upon a successful claim.
   *       - `FATAL_EVENT_INSUFFICIENT_REWARDFUNDS` event if the contract lacks sufficient funds.
   * @param erc20 The address of the ERC20 token for which the reward is being claimed.
   */
  function claimReward(
    address erc20
  )
    external
    nonReentrant
    onlyOffChainCallable
  {

    if (erc20 == address(0)) {
      revert("InvalidErc20Address");
    }

    address mentor = _msgSender();
    uint payout = _mentorRewards[mentor][erc20] - _mentorPayouts[mentor][erc20];
    if (payout == 0) {
      revert("NothingToWithdraw");
    }

    if (IERC20(erc20).balanceOf(address(this)) < payout) {
      __FATAL_INSUFFICIENT_REWARDFUNDS_ERROR__[erc20] = true;
      emit FATAL_EVENT_INSUFFICIENT_REWARDFUNDS(
        mentor,
        erc20,
        IERC20(erc20).balanceOf(address(this)),
        payout
      );
      return;
    }

    _mentorPayouts[mentor][erc20] = _mentorPayouts[mentor][erc20] + payout;

    IERC20(erc20).safeTransfer(mentor, payout);

    emit MentorRewardPayout(
      mentor,
      erc20,
      payout
    );

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
    if (_msgSender() != AUTHORIZED_COMMISSION_GATHERER) {
        revert("RejectUnknownGathere");
    }
    _;
  }

  /**
   * @notice Emitted when the reward pool does not have sufficient funds to cover a mentor's earnings payout.
   *         This signals a critical issue as the reward pool is depleted, preventing a successful distribution of rewards.
   * @dev This event provides transparency on the failure to payout a mentor due to insufficient reward funds.
   *      It includes information on the affected mentor, the ERC20 token involved, the current reward fund balance, and the attempted payout amount.
   *      It acts as an important signal for mentors to know that the contract is blocked from collecting specific ERC20 tokens and that a manual EOA distribution is required.
   * @param mentor The address of the mentor who should have received the payout.
   * @param erc20 The address of the ERC20 token representing the reward currency.
   * @param balance The current balance of the reward pool for the given ERC20 token.
   * @param payout The intended amount to be paid to the mentor.
   */
  event FATAL_EVENT_INSUFFICIENT_REWARDFUNDS(
    address mentor,
    address erc20,
    uint balance,
    uint payout
  );

  /**
   * @notice Emitted when a protege successfully joins a mentor.
   * @dev This event is triggered when a protege is associated with a mentor in the Oracly Protocol.
   * @param protege The address of the protege who joins the mentor.
   * @param mentor The address of the mentor that the protege is joining.
   */
  event JoinedMentor(
    address indexed protege,
    address indexed mentor
  );

  /**
   * @notice Emitted when a mentor expels a protege.
   * @dev This event is triggered when a mentor decides to disassociate a protege from their mentorship.
   * @param protege The address of the protege being expelled.
   * @param mentor The address of the mentor performing the expulsion.
   */
  event ProtegeExpelled(
    address indexed protege,
    address indexed mentor
  );

  /**
   * @notice Emitted when a Protege withdraws their prize and 0.25% is assigned to the Mentor's reward.
   * @dev This event is triggered whenever a Protege contributes funds to their Mentor.
   * @param protege The address of the Protege who earned the funds.
   * @param mentor The address of the Mentor receiving the reward.
   * @param erc20 The ERC20 token contract address used for the reward transaction.
   * @param reward The amount of Mentor's reward in ERC20 tokens.
   */
  event MentorfundsAdded(
    address indexed protege,
    address indexed mentor,
    address indexed erc20,
    uint reward
  );

  /**
   * @notice Emitted when a Mentor claims and receives a payout of their accumulated Mentoring Rewards.
   * @dev This event provides details about the Mentor, the ERC20 token used for the payout, and the payout amount.
   * @param mentor The address of the Mentor who is receiving the payout.
   * @param erc20 The address of the ERC20 token contract used for the payout.
   * @param payout The amount of ERC20 tokens paid to the Mentor.
   */
  event MentorRewardPayout(
    address indexed mentor,
    address indexed erc20,
    uint payout
  );

  /**
   * @notice Emitted when a new gatherer is authorized for the contract.
   * @dev This event is triggered whenever the contract owner (Oracly Team) assigns a new gatherer.
   * @param gatherer The address of the authorized gatherer.
   */
  event AuthorizedGathererSet(
      address indexed gatherer
  );

}

