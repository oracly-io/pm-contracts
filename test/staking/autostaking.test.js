require('../common/init')

const { expect } = require('chai')
const { ethers } = require('hardhat')

const { deployStakingOraclyV1, initStakingOraclyV1 } = require('../common')
const { deployToken } = require('../common')

const { stake, unstake, withdraw } = require('../common/staking')
const { collectCommission, claimReward, setGatherer } = require('../common/staking')
const { depositId, forwardTimeToNextEpoch, ACTUAL_EPOCH_ID } = require('../common/staking')
const { init } = require('../common/staking')

const { BUY_4_STAKEPOOL, donateBuy4stake, buy4stake, setBuy4stakeERC20 } = require('../common/staking')
const { getDeposit, getStakeOf } = require('../common/staking')

const { approve, send, balanceOf } = require('../common/utils')
const { address, DEMO_INITIAL_SUPPLY } = require('../common/utils')
const { DEMO_DECIMALS } = require('../common/utils')

require('@openzeppelin/test-helpers/configure')({
  provider: process.env.LDE_URL
})

describe('Staking', () => {

  const TEST_DECIMALS = 6n
  const TEST_TOTAL_SUPPLY = 1_000n *10n**TEST_DECIMALS

  const TEST2_DECIMALS = 26n
  const TEST2_TOTAL_SUPPLY = 1_000n *10n**TEST2_DECIMALS

  const DEMO_DEC = 10n**DEMO_DECIMALS
  const TEST_DEC = 10n**TEST_DECIMALS
  const TEST2_DEC = 10n**TEST2_DECIMALS

  let StakingOraclyV1

  let DEMO
  let TEST
  let TEST2

  let owner
  let addr1
  let addr2
  let addrs // eslint-disable-line

  beforeEach(async () => {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners()

    DEMO = await deployToken('DEMO', address(address))
    TEST = await deployToken('TEST', address(address), [TEST_TOTAL_SUPPLY, TEST_DECIMALS]) // 6 decimals
    TEST2 = await deployToken('TEST', address(address), [TEST2_TOTAL_SUPPLY, TEST2_DECIMALS]) // 26 decimals

    StakingOraclyV1 = await deployStakingOraclyV1(DEMO.target)
    await initStakingOraclyV1(StakingOraclyV1, address(owner))
    init(StakingOraclyV1)

  })

  describe('StakingOraclyV1 Contract', () => {

    it('Access Control', async () => {
      await expect(setGatherer(addr1)).to.be.reverted
    })

    it('Can Stake/Unstake/Withdrow in the same Epoch in Not Created Epoch', async () => {

      await approve(owner, DEMO, StakingOraclyV1, 600n*DEMO_DEC)

      const epochid = await ACTUAL_EPOCH_ID()

      const depositid = depositId(owner, epochid)
      //Errors check
      await expect(unstake(owner, epochid, depositid)).to.be.revertedWith('CannotUnstakeUnexistDeposit')
      await expect(withdraw(owner, depositid)).to.be.revertedWith('CannotWithdrawUnexistDeposit')
      //

      await stake(owner, epochid, 100n*DEMO_DEC)
      await stake(owner, epochid, 200n*DEMO_DEC)
      await stake(owner, epochid, 300n*DEMO_DEC)

      //Errors check
      await expect(stake(owner, epochid, 100n*DEMO_DEC)).to.be.revertedWith('InsufficientAllowance')
      await expect(withdraw(owner, depositid)).to.be.revertedWith('CannotWithdrawStakedDeposit')
      await expect(unstake(addr1, epochid, depositid)).to.be.revertedWith('CannotUnstakeOtherStakerDeposit')
      //

      await unstake(owner, epochid, depositid)

      //Errors check
      await expect(unstake(owner, epochid, depositid)).to.be.revertedWith('CannotUnstakeUnstakedDeposit')
      await approve(owner, DEMO, StakingOraclyV1, 100n*DEMO_DEC)
      await expect(stake(owner, epochid, 100n*DEMO_DEC)).to.be.revertedWith('CannotUpdateUnstakedDeposit')
      await expect(withdraw(addr1, depositid)).to.be.revertedWith('CannotWithdrawOtherStakerDeposit')
      //

      await withdraw(owner, depositid)

      //Errors check
      await expect(withdraw(owner, depositid)).to.be.revertedWith('CannotWithdrawWithdrawnDeposit')
      await expect(stake(owner, epochid, 100n*DEMO_DEC)).to.be.revertedWith('CannotUpdateUnstakedDeposit')
      await expect(unstake(owner, epochid, depositid)).to.be.revertedWith('CannotUnstakeUnstakedDeposit')
      await expect(claimReward(owner, epochid, depositid, TEST)).to.be.revertedWith('CannotClaimRewardEpochEarlierStakeInEpochEnd')
      //

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(0n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

    })

    it('Collect Stake Unstake Withdrow', async () => {

      const epochid_0 = await ACTUAL_EPOCH_ID()
      expect(epochid_0).to.be.equal(0)

      //Errors check
      await expect(collectCommission(owner, TEST, 1n*TEST_DEC)).to.be.revertedWith('CannotCollectRewardsIntoUncreatedEpoch')
      //

      await approve(owner, DEMO, StakingOraclyV1, 500n*DEMO_DEC)
      await stake(owner, epochid_0, 500n*DEMO_DEC)
      const depositid_0 = depositId(owner, epochid_0)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(500n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 500n*DEMO_DEC)

      // creats epoch id 1
      await collectCommission(owner, TEST, 1n*TEST_DEC)
      const epochid_1 = await ACTUAL_EPOCH_ID()

      expect(epochid_1).to.be.equal(1)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(1n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - 1n*TEST_DEC)

      //Errors check
      await expect(stake(owner, epochid_0, 0n*DEMO_DEC)).to.be.revertedWith('CannotStakeZeroAmount')
      await expect(unstake(owner, epochid_0, depositid_0)).to.be.revertedWith('CannotUnstakeInUnactualEpoch')
      await expect(collectCommission(addr1, TEST, 1n*TEST_DEC)).to.be.revertedWith('RejectUnknownGathere')
      await expect(collectCommission(owner, TEST, 0n*TEST_DEC)).to.be.revertedWith('CannotCollectZeroAmount')
      //

      await unstake(owner, epochid_1, depositid_0)

      await approve(owner, DEMO, StakingOraclyV1, 500n*DEMO_DEC)
      await stake(owner, epochid_1, 500n*DEMO_DEC)
      const depositid_1 = depositId(owner, epochid_1)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(1000n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 1000n*DEMO_DEC)

      await forwardTimeToNextEpoch()

      // creats epoch id 2
      await collectCommission(owner, TEST, 1n*TEST_DEC)
      const epochid_2 = await ACTUAL_EPOCH_ID()
      expect(epochid_2).to.be.equal(2)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(2n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - 2n*TEST_DEC)

      await withdraw(owner, depositid_0)

      //Errors check
      await expect(claimReward(addr1, epochid_0, depositid_0, TEST)).to.be.revertedWith('CannotClaimRewardOnOtherStakerDeposit')
      await expect(claimReward(addr1, epochid_1, depositid_0, TEST)).to.be.revertedWith('CannotClaimRewardOnOtherStakerDeposit')
      await expect(claimReward(addr1, epochid_2, depositid_1, TEST)).to.be.revertedWith('CannotClaimRewardOnOtherStakerDeposit')
      await expect(claimReward(owner, epochid_0, depositid_0, TEST)).to.be.revertedWith('CannotClaimRewardEpochEarlierStakeInEpochEnd')
      await expect(claimReward(owner, epochid_0, depositid_1, TEST)).to.be.revertedWith('CannotClaimRewardEpochEarlierStakeInEpochEnd')
      await expect(claimReward(owner, epochid_2, depositid_0, TEST)).to.be.revertedWith('CannotClaimRewardEpochAfterStakeOutEpoch')
      //

      await claimReward(owner, epochid_1, depositid_0, TEST)

      //Errors check
      await expect(claimReward(owner, epochid_1, depositid_0, TEST)).to.be.revertedWith('CannotClaimAlreadyClaimedReward')
      //

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(1n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - 1n*TEST_DEC)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(500n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 500n*DEMO_DEC)

    })

    it('Multi User Collect Stake Unstake Withdrow', async () => {

      await send(owner, DEMO, addr1, 17n*DEMO_DEC)
      await send(owner, DEMO, addr2, 17n*DEMO_DEC)

      const epochid_0 = await ACTUAL_EPOCH_ID()
      expect(epochid_0).to.be.equal(0)

      await approve(owner, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await stake(owner, epochid_0, 1n*DEMO_DEC)
      await stake(owner, epochid_0, 6n*DEMO_DEC)
      await stake(owner, epochid_0, 10n*DEMO_DEC)
      const depositid_owner_0 = depositId(owner, epochid_0)

      await approve(addr1, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await stake(addr1, epochid_0, 7n*DEMO_DEC)
      await stake(addr1, epochid_0, 9n*DEMO_DEC)
      await stake(addr1, epochid_0, 1n*DEMO_DEC)
      const depositid_addr1_0 = depositId(addr1, epochid_0)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(34n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 51n*DEMO_DEC)

      // creates epoch id 1
      await collectCommission(owner, TEST, 1n*TEST_DEC)
      const epochid_1 = await ACTUAL_EPOCH_ID()
      expect(epochid_1).to.be.equal(1)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(1n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - 1n*TEST_DEC)

      //Errors check
      await expect(unstake(owner, epochid_1, depositid_addr1_0)).to.be.revertedWith('CannotUnstakeOtherStakerDeposit')
      await expect(unstake(addr1, epochid_1, depositid_owner_0)).to.be.revertedWith('CannotUnstakeOtherStakerDeposit')
      //

      await unstake(owner, epochid_1, depositid_owner_0)
      await unstake(addr1, epochid_1, depositid_addr1_0)

      await approve(addr2, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await stake(addr2, epochid_1, 1n*DEMO_DEC)
      await stake(addr2, epochid_1, 1n*DEMO_DEC)
      await stake(addr2, epochid_1, 1n*DEMO_DEC)
      await stake(addr2, epochid_1, 14n*DEMO_DEC)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(51n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 51n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(0n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0n*DEMO_DEC)

      await forwardTimeToNextEpoch()

      // creats epoch id 2
      await collectCommission(owner, TEST, 1n*TEST_DEC)
      const epochid_2 = await ACTUAL_EPOCH_ID()
      expect(epochid_2).to.be.equal(2)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(2n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - 2n*TEST_DEC)

      await withdraw(owner, depositid_owner_0)
      await withdraw(addr1, depositid_addr1_0)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 34n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(17n*DEMO_DEC)

      await claimReward(addr1, epochid_1, depositid_addr1_0, TEST)
      await claimReward(owner, epochid_1, depositid_owner_0, TEST)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(1n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - (1n*TEST_DEC + 1n*TEST_DEC/2n))
      expect(await balanceOf(TEST, addr1)).to.be.equal(1n*TEST_DEC/2n)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 34n*DEMO_DEC)

    })

    it('Multi User Collect Stake Unstake Withdrow in Actual phase many times', async () => {

      await send(owner, DEMO, addr1, 17n*DEMO_DEC)
      await send(owner, DEMO, addr2, 17n*DEMO_DEC)

      const epochid_0 = await ACTUAL_EPOCH_ID()
      expect(epochid_0).to.be.equal(0)

      await approve(owner, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await stake(owner, epochid_0, 1n*DEMO_DEC)
      await stake(owner, epochid_0, 6n*DEMO_DEC)
      await stake(owner, epochid_0, 10n*DEMO_DEC)
      const depositid_owner_0 = depositId(owner, epochid_0)

      await approve(addr1, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await stake(addr1, epochid_0, 7n*DEMO_DEC)
      await stake(addr1, epochid_0, 9n*DEMO_DEC)
      await stake(addr1, epochid_0, 1n*DEMO_DEC)
      const depositid_addr1_0 = depositId(addr1, epochid_0)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 17n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - (17n*DEMO_DEC + 17n*DEMO_DEC + 17n*DEMO_DEC))

      // creates epoch id 1
      await collectCommission(owner, TEST, 1n*TEST_DEC)
      const epochid_1 = await ACTUAL_EPOCH_ID()
      expect(epochid_1).to.be.equal(1)

      await claimReward(owner, epochid_1, depositid_owner_0, TEST)
      await claimReward(addr1, epochid_1, depositid_addr1_0, TEST)
      // doing nothing
      await claimReward(owner, epochid_1, depositid_owner_0, TEST)
      await claimReward(addr1, epochid_1, depositid_addr1_0, TEST)

      // IMPORTANT: undivadable amount of reward (1) makes claimed reward (0)
      // until rounding error handler kick of (when last staker claims last reward)
      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(0n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - 1n*TEST_DEC/2n)
      expect(await balanceOf(TEST, addr1)).to.be.equal(1n*TEST_DEC/2n)

      await collectCommission(owner, TEST, 2n*TEST_DEC)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(2n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - (2n*TEST_DEC + 1n*TEST_DEC/2n))
      expect(await balanceOf(TEST, addr1)).to.be.equal(1n*TEST_DEC/2n)

      await claimReward(owner, epochid_1, depositid_owner_0, TEST)
      await claimReward(addr1, epochid_1, depositid_addr1_0, TEST)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(0n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - (1n*TEST_DEC+1n*TEST_DEC/2n))
      expect(await balanceOf(TEST, addr1)).to.be.equal(1n*TEST_DEC+1n*TEST_DEC/2n)

      //Errors check
      await expect(unstake(owner, epochid_1, depositid_addr1_0)).to.be.revertedWith('CannotUnstakeOtherStakerDeposit')
      await expect(unstake(addr1, epochid_1, depositid_owner_0)).to.be.revertedWith('CannotUnstakeOtherStakerDeposit')
      //

      await unstake(owner, epochid_1, depositid_owner_0)
      await unstake(addr1, epochid_1, depositid_addr1_0)

      await approve(addr2, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await stake(addr2, epochid_1, 1n*DEMO_DEC)
      await stake(addr2, epochid_1, 1n*DEMO_DEC)
      await stake(addr2, epochid_1, 1n*DEMO_DEC)
      await stake(addr2, epochid_1, 14n*DEMO_DEC)
      const depositid_addr2_1 = depositId(addr2, epochid_1)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 17n*DEMO_DEC + 17n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - (17n*DEMO_DEC + 17n*DEMO_DEC + 17n*DEMO_DEC))
      expect(await balanceOf(DEMO, addr1)).to.be.equal(0n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0n*DEMO_DEC)

      await collectCommission(owner, TEST, 2n*TEST_DEC)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(2n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - (2n*TEST_DEC+1n*TEST_DEC+1n*TEST_DEC/2n))
      expect(await balanceOf(TEST, addr1)).to.be.equal(1n*TEST_DEC+1n*TEST_DEC/2n)

      await expect(claimReward(addr2, epochid_1, depositid_addr2_1, TEST)).revertedWith('CannotClaimRewardEpochEarlierStakeInEpochEnd')

      await forwardTimeToNextEpoch()

      // creats epoch id 2
      await collectCommission(owner, TEST, 10n*TEST_DEC)
      const epochid_2 = await ACTUAL_EPOCH_ID()
      expect(epochid_2).to.be.equal(2)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(10n*TEST_DEC+2n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - (10n*TEST_DEC+2n*TEST_DEC + 1n*TEST_DEC+1n*TEST_DEC/2n))
      expect(await balanceOf(TEST, addr1)).to.be.equal(1n*TEST_DEC+1n*TEST_DEC/2n)

      await withdraw(owner, depositid_owner_0)
      await withdraw(addr1, depositid_addr1_0)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - (17n*DEMO_DEC + 17n*DEMO_DEC))
      expect(await balanceOf(DEMO, addr1)).to.be.equal(17n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0n*DEMO_DEC)

      await claimReward(addr1, epochid_1, depositid_addr1_0, TEST)
      await claimReward(owner, epochid_1, depositid_owner_0, TEST)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(10n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - (10n*TEST_DEC + 1n*TEST_DEC + 1n*TEST_DEC+1n*TEST_DEC/2n))
      expect(await balanceOf(TEST, addr1)).to.be.equal(1n*TEST_DEC + 1n*TEST_DEC+1n*TEST_DEC/2n)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - (17n*DEMO_DEC + 17n*DEMO_DEC))

      await claimReward(addr2, epochid_2, depositid_addr2_1, TEST)

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(0n*TEST_DEC)
      expect(await balanceOf(TEST, owner)).to.be.equal(TEST_TOTAL_SUPPLY - (10n*TEST_DEC + 1n*TEST_DEC + 1n*TEST_DEC+1n*TEST_DEC/2n))
      expect(await balanceOf(TEST, addr1)).to.be.equal(1n*TEST_DEC + 1n*TEST_DEC+1n*TEST_DEC/2n)
      expect(await balanceOf(TEST, addr2)).to.be.equal(10n*TEST_DEC)

    })

  })

  describe('Buy 4 Stake', () => {

    it('ORCY holder donate thir ORCY token to Buy4Stake round', async () => {

      await send(owner, DEMO, addr1, 17n*DEMO_DEC)

      const epochid_0 = await ACTUAL_EPOCH_ID()
      expect(epochid_0).to.be.equal(0)

      //Errors check
      await expect(donateBuy4stake(owner, 0n*DEMO_DEC)).to.be.revertedWith('CannotCreateBuy4stakeZeroRound')
      await expect(donateBuy4stake(owner, 10n*DEMO_DEC)).to.be.revertedWith('InsufficientAllowance')
      await expect(donateBuy4stake(addr1, 18n*DEMO_DEC)).to.be.revertedWith('InsufficientFunds')
      //

      await approve(owner, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await donateBuy4stake(owner, 1n*DEMO_DEC)
      await donateBuy4stake(owner, 4n*DEMO_DEC)
      await donateBuy4stake(owner, 2n*DEMO_DEC)
      await donateBuy4stake(owner, 10n*DEMO_DEC)

      await approve(addr1, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await donateBuy4stake(addr1, 17n*DEMO_DEC)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(34n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(34n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - (17n*DEMO_DEC + 17n*DEMO_DEC))
      expect(await balanceOf(DEMO, addr1)).to.be.equal(0n*DEMO_DEC)

    })

    it('ORCY holder donate and buy4stake token TEST2 6 decimals', async () => {

      await send(owner, DEMO, addr1, 18n*DEMO_DEC)
      await send(owner, TEST, addr2, 2n*TEST_DEC)

      const epochid_0 = await ACTUAL_EPOCH_ID()
      expect(epochid_0).to.be.equal(0)

      await approve(addr1, DEMO, StakingOraclyV1, 1n*DEMO_DEC)
      await donateBuy4stake(addr1, 1n*DEMO_DEC)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(1n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(1n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 18n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(17n*DEMO_DEC)

      //Errors
      await expect(buy4stake(addr2, TEST, epochid_0, 2n*TEST_DEC)).to.be.revertedWith('CannotBuy4StakeUnsupportedERC20')
      await expect(buy4stake(addr2, DEMO, epochid_0, 2n*DEMO_DEC)).to.be.revertedWith('InsufficientFunds')
      //

      await send(owner, DEMO, addr2, 2n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(2n*DEMO_DEC)

      //Errors
      await expect(buy4stake(addr2, DEMO, epochid_0, 2n*DEMO_DEC)).to.be.revertedWith('InsufficientAllowance')
      //

      await approve(addr2, DEMO, StakingOraclyV1, 2n*DEMO_DEC)

      //Errors
      await expect(buy4stake(addr2, DEMO, epochid_0, 2n*DEMO_DEC)).to.be.revertedWith('InsufficientBuy4Stakepool')
      await expect(buy4stake(addr2, DEMO, epochid_0, 1n*DEMO_DEC)).to.be.revertedWith('CannotCollectRewardsIntoUncreatedEpoch')
      //

      await setBuy4stakeERC20(owner, TEST)

      //Errors
      await expect(buy4stake(addr2, DEMO, epochid_0, 2n*DEMO_DEC)).to.be.revertedWith('CannotBuy4StakeUnsupportedERC20')
      await expect(buy4stake(addr2, TEST, epochid_0, 0n*TEST_DEC)).to.be.revertedWith('CannotCollectZeroAmount')
      await expect(buy4stake(addr2, TEST, epochid_0, 1n*TEST_DEC)).to.be.revertedWith('InsufficientAllowance')
      //

      await approve(addr2, TEST, StakingOraclyV1, 2n*TEST_DEC)

      //Errors
      await expect(buy4stake(addr2, TEST, epochid_0, 2n*TEST_DEC)).to.be.revertedWith('InsufficientBuy4Stakepool')
      await expect(buy4stake(addr2, TEST, epochid_0, 1n*TEST_DEC)).to.be.revertedWith('CannotCollectRewardsIntoUncreatedEpoch')
      await expect(buy4stake(addr2, TEST, epochid_0 + 1n, 1n*TEST_DEC)).to.be.revertedWith('CannotBuy4stakeIntoUnactualEpoch')
      //

      // IMPORTANT
      // initial deposit cannot be made via buy4stake feature
      // so initial stake should be part of deployment
      await approve(addr1, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await stake(addr1, epochid_0, 1n*DEMO_DEC)
      await stake(addr1, epochid_0, 2n*DEMO_DEC)
      await stake(addr1, epochid_0, 14n*DEMO_DEC)
      const depositid_addr1_0 = depositId(addr1, epochid_0)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(1n*DEMO_DEC)
      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(0n*TEST_DEC)
      expect(await balanceOf(TEST, addr2)).to.be.equal(2n*TEST_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(2n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 1n*DEMO_DEC)

      // this starts and make deposit into first Epoch 1
      await buy4stake(addr2, TEST, epochid_0, 1n*TEST_DEC)
      const epochid_1 = await ACTUAL_EPOCH_ID()
      expect(epochid_1).to.be.equal(1)

      const depositid_addr2_1 = depositId(addr2, epochid_1)
      const deposit = await getDeposit(addr2, depositid_addr2_1)
      expect(deposit.depositid).to.be.equal(depositid_addr2_1)
      expect(deposit.staker).to.be.equal(address(addr2))
      expect(deposit.inEpochid).to.be.equal(1)
      expect(deposit.amount).to.be.equal(1n*DEMO_DEC)
      expect(deposit.outEpochid).to.be.equal(0)
      expect(deposit.unstaked).to.be.equal(false)
      expect(deposit.unstakedAt).to.be.equal(0)
      expect(deposit.withdrawn).to.be.equal(false)
      expect(deposit.withdrawnAt).to.be.equal(0)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(0n*DEMO_DEC)
      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(1n*TEST_DEC)
      expect(await balanceOf(TEST, addr2)).to.be.equal(1n*TEST_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(2n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 1n*DEMO_DEC)
      expect(await getStakeOf(addr1)).to.be.equal(17n*DEMO_DEC)
      expect(await getStakeOf(addr2)).to.be.equal(1n*DEMO_DEC)

      //Errors
      await expect(buy4stake(addr2, TEST, epochid_1, 1n*TEST_DEC)).to.be.revertedWith('InsufficientBuy4Stakepool')
      //

      await forwardTimeToNextEpoch()

      await approve(addr2, DEMO, StakingOraclyV1, 2n*DEMO_DEC)
      await donateBuy4stake(addr2, 2n*DEMO_DEC)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(2n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 1n*DEMO_DEC + 2n*DEMO_DEC) //+2
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0n*DEMO_DEC)
      expect(await getStakeOf(addr1)).to.be.equal(17n*DEMO_DEC)
      expect(await getStakeOf(addr2)).to.be.equal(1n*DEMO_DEC)

      // this starts and make deposit into second Epoch 2
      await approve(addr2, TEST, StakingOraclyV1, 1n*TEST_DEC)
      await buy4stake(addr2, TEST, epochid_1, 1n*TEST_DEC)
      const epochid_2 = await ACTUAL_EPOCH_ID()
      expect(epochid_2).to.be.equal(2)
      const depositid_addr2_2 = depositId(addr2, epochid_2)

      await unstake(addr2, epochid_2, depositid_addr2_1)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(1n*DEMO_DEC)
      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(2n*TEST_DEC)

      expect(await balanceOf(TEST, addr2)).to.be.equal(0n*TEST_DEC)
      await collectCommission(owner, TEST, 18n*TEST_DEC)
      await claimReward(addr2, epochid_2, depositid_addr2_1, TEST)
      expect(await balanceOf(TEST, addr2)).to.be.equal(
        ((1n*TEST_DEC + 18n*TEST_DEC) * 1n*DEMO_DEC) / (1n*DEMO_DEC + 17n*DEMO_DEC)
      )

      expect(await balanceOf(TEST, StakingOraclyV1)).to.be.equal(
        1n*TEST_DEC +
        ((1n*TEST_DEC + 18n*TEST_DEC) * 17n*DEMO_DEC) / (1n*DEMO_DEC + 17n*DEMO_DEC) +1n // +1n in rounding error
      )
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(
        17n*DEMO_DEC + 1n*DEMO_DEC + 2n*DEMO_DEC
      )
      expect(await BUY_4_STAKEPOOL()).to.be.equal(1n*DEMO_DEC)

      await forwardTimeToNextEpoch()

      // this starts and make deposit into second Epoch 3
      await collectCommission(owner, TEST, 1n*TEST_DEC)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 1n*DEMO_DEC + 2n*DEMO_DEC)

      await withdraw(addr2, depositid_addr2_1)

      // aquiered ORCY via Buy4Stake
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 2n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(1n*DEMO_DEC)

    })

    it('ORCY holder donate and buy4stake token TEST2 26 decimals', async () => {

      await send(owner, DEMO, addr1, 18n*DEMO_DEC)
      await send(owner, TEST2, addr2, 2n*TEST2_DEC)

      const epochid_0 = await ACTUAL_EPOCH_ID()
      expect(epochid_0).to.be.equal(0)

      await approve(addr1, DEMO, StakingOraclyV1, 1n*DEMO_DEC)
      await donateBuy4stake(addr1, 1n*DEMO_DEC)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(1n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(1n*DEMO_DEC)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 18n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(17n*DEMO_DEC)

      //Errors
      await expect(buy4stake(addr2, TEST2, epochid_0, 2n*TEST2_DEC)).to.be.revertedWith('CannotBuy4StakeUnsupportedERC20')
      await expect(buy4stake(addr2, DEMO, epochid_0, 2n*DEMO_DEC)).to.be.revertedWith('InsufficientFunds')
      //

      await send(owner, DEMO, addr2, 2n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(2n*DEMO_DEC)

      //Errors
      await expect(buy4stake(addr2, DEMO, epochid_0, 2n*DEMO_DEC)).to.be.revertedWith('InsufficientAllowance')
      //

      await approve(addr2, DEMO, StakingOraclyV1, 2n*DEMO_DEC)

      //Errors
      await expect(buy4stake(addr2, DEMO, epochid_0, 2n*DEMO_DEC)).to.be.revertedWith('InsufficientBuy4Stakepool')
      await expect(buy4stake(addr2, DEMO, epochid_0, 1n*DEMO_DEC)).to.be.revertedWith('CannotCollectRewardsIntoUncreatedEpoch')
      //

      await setBuy4stakeERC20(owner, TEST2)

      //Errors
      await expect(buy4stake(addr2, DEMO, epochid_0, 2n*DEMO_DEC)).to.be.revertedWith('CannotBuy4StakeUnsupportedERC20')
      await expect(buy4stake(addr2, TEST2, epochid_0, 0n*TEST2_DEC)).to.be.revertedWith('CannotCollectZeroAmount')
      await expect(buy4stake(addr2, TEST2, epochid_0, 1n*TEST2_DEC)).to.be.revertedWith('InsufficientAllowance')
      //

      await approve(addr2, TEST2, StakingOraclyV1, 2n*TEST2_DEC)

      //Errors
      await expect(buy4stake(addr2, TEST2, epochid_0, 2n*TEST2_DEC)).to.be.revertedWith('InsufficientBuy4Stakepool')
      await expect(buy4stake(addr2, TEST2, epochid_0, 1n*TEST2_DEC)).to.be.revertedWith('CannotCollectRewardsIntoUncreatedEpoch')
      await expect(buy4stake(addr2, TEST2, epochid_0 + 1n, 1n*TEST2_DEC)).to.be.revertedWith('CannotBuy4stakeIntoUnactualEpoch')
      //

      // IMPORTANT
      // initial deposit cannot be made via buy4stake feature
      // so initial stake should be part of deployment
      await approve(addr1, DEMO, StakingOraclyV1, 17n*DEMO_DEC)
      await stake(addr1, epochid_0, 1n*DEMO_DEC)
      await stake(addr1, epochid_0, 2n*DEMO_DEC)
      await stake(addr1, epochid_0, 14n*DEMO_DEC)
      const depositid_addr1_0 = depositId(addr1, epochid_0)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(1n*DEMO_DEC)
      expect(await balanceOf(TEST2, StakingOraclyV1)).to.be.equal(0n*TEST2_DEC)
      expect(await balanceOf(TEST2, addr2)).to.be.equal(2n*TEST2_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(2n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 1n*DEMO_DEC)

      // this starts and make deposit into first Epoch 1
      await buy4stake(addr2, TEST2, epochid_0, 1n*TEST2_DEC)
      const epochid_1 = await ACTUAL_EPOCH_ID()
      expect(epochid_1).to.be.equal(1)

      const depositid_addr2_1 = depositId(addr2, epochid_1)
      const deposit = await getDeposit(addr2, depositid_addr2_1)
      expect(deposit.depositid).to.be.equal(depositid_addr2_1)
      expect(deposit.staker).to.be.equal(address(addr2))
      expect(deposit.inEpochid).to.be.equal(1)
      expect(deposit.amount).to.be.equal(1n*DEMO_DEC)
      expect(deposit.outEpochid).to.be.equal(0)
      expect(deposit.unstaked).to.be.equal(false)
      expect(deposit.unstakedAt).to.be.equal(0)
      expect(deposit.withdrawn).to.be.equal(false)
      expect(deposit.withdrawnAt).to.be.equal(0)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(0n*DEMO_DEC)
      expect(await balanceOf(TEST2, StakingOraclyV1)).to.be.equal(1n*TEST2_DEC)
      expect(await balanceOf(TEST2, addr2)).to.be.equal(1n*TEST2_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(2n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 1n*DEMO_DEC)
      expect(await getStakeOf(addr1)).to.be.equal(17n*DEMO_DEC)
      expect(await getStakeOf(addr2)).to.be.equal(1n*DEMO_DEC)

      //Errors
      await expect(buy4stake(addr2, TEST2, epochid_1, 1n*TEST2_DEC)).to.be.revertedWith('InsufficientBuy4Stakepool')
      //

      await forwardTimeToNextEpoch()

      await approve(addr2, DEMO, StakingOraclyV1, 2n*DEMO_DEC)
      await donateBuy4stake(addr2, 2n*DEMO_DEC)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(2n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 1n*DEMO_DEC + 2n*DEMO_DEC) //+2
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0n*DEMO_DEC)
      expect(await getStakeOf(addr1)).to.be.equal(17n*DEMO_DEC)
      expect(await getStakeOf(addr2)).to.be.equal(1n*DEMO_DEC)

      // this starts and make deposit into second Epoch 2
      await approve(addr2, TEST2, StakingOraclyV1, 1n*TEST2_DEC)
      await buy4stake(addr2, TEST2, epochid_1, 1n*TEST2_DEC)
      const epochid_2 = await ACTUAL_EPOCH_ID()
      expect(epochid_2).to.be.equal(2)
      const depositid_addr2_2 = depositId(addr2, epochid_2)

      await unstake(addr2, epochid_2, depositid_addr2_1)

      expect(await BUY_4_STAKEPOOL()).to.be.equal(1n*DEMO_DEC)
      expect(await balanceOf(TEST2, StakingOraclyV1)).to.be.equal(2n*TEST2_DEC)

      expect(await balanceOf(TEST2, addr2)).to.be.equal(0n*TEST2_DEC)
      await collectCommission(owner, TEST2, 18n*TEST2_DEC)
      await claimReward(addr2, epochid_2, depositid_addr2_1, TEST2)
      expect(await balanceOf(TEST2, addr2)).to.be.equal(
        ((1n*TEST2_DEC + 18n*TEST2_DEC) * 1n*DEMO_DEC) / (1n*DEMO_DEC + 17n*DEMO_DEC)
      )

      expect(await balanceOf(TEST2, StakingOraclyV1)).to.be.equal(
        1n*TEST2_DEC +
        ((1n*TEST2_DEC + 18n*TEST2_DEC) * 17n*DEMO_DEC) / (1n*DEMO_DEC + 17n*DEMO_DEC) +1n // +1n in rounding error
      )
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0n*DEMO_DEC)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(
        17n*DEMO_DEC + 1n*DEMO_DEC + 2n*DEMO_DEC
      )
      expect(await BUY_4_STAKEPOOL()).to.be.equal(1n*DEMO_DEC)

      await forwardTimeToNextEpoch()

      // this starts and make deposit into second Epoch 3
      await collectCommission(owner, TEST2, 1n*TEST2_DEC)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 1n*DEMO_DEC + 2n*DEMO_DEC)

      await withdraw(addr2, depositid_addr2_1)

      // aquiered ORCY via Buy4Stake
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(17n*DEMO_DEC + 2n*DEMO_DEC)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(1n*DEMO_DEC)

    })

  })

})
