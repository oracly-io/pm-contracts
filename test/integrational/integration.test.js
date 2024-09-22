require('../common/init')

const { expect } = require('chai')
const { ethers } = require('hardhat')

const { deployToken, deployAggregatorProxyMock } = require('../common')
const { deployMeta, deployOraclyV1 } = require('../common')
const { deployStakingOraclyV1, initStakingOraclyV1 } = require('../common')
const { deployMentoring, initMentoring } = require('../common')

const { approve, send, balanceOf, forwardTime } = require('../common/utils')
const { DEMO_INITIAL_SUPPLY } = require('../common/utils')

const { RESOLUTION } = require('../common/oraclyv1')

const staking = require('../common/staking')
const mentoring = require('../common/mentoring')
const oraclyv1 = require('../common/oraclyv1')
const meta = require('../common/meta')

require('@openzeppelin/test-helpers/configure')({
  provider: process.env.LDE_URL
})

describe('Integration', () => {

  let MetaOraclyV1
  let MentoringOraclyV1
  let MockAggregatorProxy
  let StakingOraclyV1
  let OraclyV1

  let DEMO
  let DEMO2

  let owner
  let addr1
  let addr2
  let addr3
  let addr4
  let addr5
  let addrs // eslint-disable-line

  beforeEach(async () => {
    [owner, addr1, addr2, addr3, addr4, addr5, ...addrs] = await ethers.getSigners()

    DEMO = await deployToken('DEMO', owner.address)
    DEMO2 = await deployToken('DEMO', owner.address)
    MockAggregatorProxy = await deployAggregatorProxyMock()

    MetaOraclyV1 = await deployMeta()
    meta.init(MetaOraclyV1)

    StakingOraclyV1 = await deployStakingOraclyV1(DEMO.target)
    staking.init(StakingOraclyV1)

    MentoringOraclyV1 = await deployMentoring()
    mentoring.init(MentoringOraclyV1)

    OraclyV1 = await deployOraclyV1(
      // Destributor EOA
      owner.address,
      StakingOraclyV1.target,
      MentoringOraclyV1.target,
      MetaOraclyV1.target,
    )
    oraclyv1.init(OraclyV1)

    await initStakingOraclyV1(StakingOraclyV1, OraclyV1.target)
    await initMentoring(MentoringOraclyV1, OraclyV1.target)

  })

  describe('Palce Prediction before register Mentors and Stakers', () => {

    it('Palce Prediction and Round resolution Withdraw NO Staking and Mentoring (DistributorEOA)', async () => {

      const game = await meta.addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        schedule: 120,
        positioning: 60,
        expiration: 3600,
        version: 1,
        minDeposit: 1
      })

      const roundid = await oraclyv1.forwardTimeToRoundOpen(game)
      await send(owner, DEMO, addr1, 3)
      await approve(addr1, DEMO, OraclyV1, 3)

      expect(await oraclyv1.isBettorInRound(addr1, roundid)).to.be.equal(false)

      const predictionid_zero = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.ZERO, game.gameid, roundid)
      const predictionid_down = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.DOWN, game.gameid, roundid)
      const predictionid_up = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.UP, game.gameid, roundid)

      expect(await oraclyv1.isBettorInRound(addr1, roundid)).to.be.equal(true)

      await forwardTime(game.schedule)

      await oraclyv1.resolve(addr1, roundid)

      const round = await oraclyv1.getRound(addr1, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.UP)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(0)

      await oraclyv1.withdraw(addr1, roundid, predictionid_up, DEMO)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 2n)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(2)

      expect(await oraclyv1.isBettorInRound(owner, roundid)).to.be.equal(false)

    })

    it('Palce Prediction and Round resolution Withdraw WITN Mentoring NO Staking', async () => {

      const game = await meta.addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        schedule: 120,
        positioning: 60,
        expiration: 3600,
        version: 1,
        minDeposit: 1
      })

      const roundid = await oraclyv1.forwardTimeToRoundOpen(game)
      await send(owner, DEMO, addr1, 3)
      await approve(addr1, DEMO, OraclyV1, 3)

      const predictionid_zero = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.ZERO, game.gameid, roundid)
      const predictionid_down = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.DOWN, game.gameid, roundid)
      const predictionid_up = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.UP, game.gameid, roundid)

      await forwardTime(game.schedule)

      await oraclyv1.resolve(addr1, roundid)

      const round = await oraclyv1.getRound(addr1, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.UP)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(0)

      await mentoring.joinMentor(addr1, addr2)

      await oraclyv1.withdraw(addr1, roundid, predictionid_up, DEMO)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(2)

      await mentoring.claimReward(addr2, DEMO)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(1)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 3n)
    })

    it('Palce Prediction and Round resolution Withdraw NO Mentoring WITH Staking', async () => {

      const game = await meta.addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        schedule: 120,
        positioning: 60,
        expiration: 3600,
        version: 1,
        minDeposit: 1
      })

      await send(owner, DEMO, addr1, 3)
      await send(owner, DEMO, addr2, 1)
      await approve(addr1, DEMO, OraclyV1, 5)

      const roundid_1 = await oraclyv1.forwardTimeToRoundOpen(game)

      const predictionid_zero_1 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.ZERO, game.gameid, roundid_1)
      const predictionid_down_1 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.DOWN, game.gameid, roundid_1)
      const predictionid_up_1 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.UP, game.gameid, roundid_1)

      await forwardTime(game.schedule)

      await oraclyv1.resolve(addr1, roundid_1)

      const round_1 = await oraclyv1.getRound(addr1, roundid_1)
      expect(round_1.resolution).to.be.equal(RESOLUTION.UP)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(0)

      const epochid_0 = await staking.ACTUAL_EPOCH_ID()
      expect(epochid_0).to.be.equal(0)
      await approve(addr2, DEMO, StakingOraclyV1, 1)
      await staking.stake(addr2, epochid_0, 1)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(1)

      // creates initial staking epoch epochid=1
      await oraclyv1.withdraw(addr1, roundid_1, predictionid_up_1, DEMO)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(2)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(2)

      const epochid_1 = await staking.ACTUAL_EPOCH_ID()
      expect(epochid_1).to.be.equal(1)

      const roundid_2 = await oraclyv1.forwardTimeToRoundOpen(game)

      const predictionid_down_2 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.DOWN, game.gameid, roundid_2)
      const predictionid_up_2 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.UP, game.gameid, roundid_2)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(0)

      await forwardTime(game.schedule)

      await oraclyv1.resolve(addr1, roundid_2)

      const round_2 = await oraclyv1.getRound(addr1, roundid_2)
      expect(round_2.resolution).to.be.equal(RESOLUTION.UP)

      await staking.forwardTimeToNextEpoch()

      // creates next staking epoch epochid=2
      await oraclyv1.withdraw(addr1, roundid_2, predictionid_up_2, DEMO)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(1)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(3)

      const depositid = staking.depositId(addr2, epochid_0)
      await staking.claimReward(addr2, epochid_1, depositid, DEMO)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(2)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(1)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(1)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 4n)
    })

    it('Palce Prediction and Round resolution Withdraw WITH Mentoring WITH Staking Only Mentors Rewarded', async () => {

      const game = await meta.addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        schedule: 120,
        positioning: 60,
        expiration: 3600,
        version: 1,
        minDeposit: 1
      })

      await send(owner, DEMO, addr1, 3)
      await send(owner, DEMO, addr2, 1)

      const roundid_1 = await oraclyv1.forwardTimeToRoundOpen(game)

      await approve(addr1, DEMO, OraclyV1, 3)
      const predictionid_zero_1 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.ZERO, game.gameid, roundid_1)
      const predictionid_down_1 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.DOWN, game.gameid, roundid_1)
      const predictionid_up_1 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.UP, game.gameid, roundid_1)

      await forwardTime(game.schedule)

      await oraclyv1.resolve(addr1, roundid_1)

      const round_1 = await oraclyv1.getRound(addr1, roundid_1)
      expect(round_1.resolution).to.be.equal(RESOLUTION.UP)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(0)

      // staking
      const epochid_0 = await staking.ACTUAL_EPOCH_ID()
      expect(epochid_0).to.be.equal(0)
      await approve(addr2, DEMO, StakingOraclyV1, 1)
      await staking.stake(addr2, epochid_0, 1)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(1)

      // mentoring
      await mentoring.joinMentor(addr1, addr3)

      // not creates initial staking epoch epochid=1 (nothing collected)
      await oraclyv1.withdraw(addr1, roundid_1, predictionid_up_1, DEMO)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(2)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(1)
      expect(await balanceOf(DEMO, MentoringOraclyV1)).to.be.equal(1)
      expect(await staking.ACTUAL_EPOCH_ID()).to.be.equal(0)

      const roundid_2 = await oraclyv1.forwardTimeToRoundOpen(game)

      await approve(addr1, DEMO, OraclyV1, 2)
      const predictionid_down_2 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.DOWN, game.gameid, roundid_2)
      const predictionid_up_2 = await oraclyv1.placePrediction(addr1, 1, RESOLUTION.UP, game.gameid, roundid_2)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(0)

      await forwardTime(game.schedule)

      await oraclyv1.resolve(addr1, roundid_2)

      const round_2 = await oraclyv1.getRound(addr1, roundid_2)
      expect(round_2.resolution).to.be.equal(RESOLUTION.UP)

      await staking.forwardTimeToNextEpoch()

      // creates next staking epoch epochid=2
      await oraclyv1.withdraw(addr1, roundid_2, predictionid_up_2, DEMO)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(1)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(1)
      expect(await balanceOf(DEMO, MentoringOraclyV1)).to.be.equal(2)

      const depositid = staking.depositId(addr2, epochid_0)
      await expect(staking.claimReward(addr2, epochid_0, depositid, DEMO)).to.be.revertedWith('CannotClaimRewardEpochEarlierStakeInEpochEnd')

      await mentoring.claimReward(addr3, DEMO)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(1)
      expect(await balanceOf(DEMO, MentoringOraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO, addr3)).to.be.equal(2)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(1)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 4n)
    })

    it('Palce Prediction and Round resolution Withdraw WITH Mentoring WITH Staking All Rewarded', async () => {

      const game = await meta.addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO2.target,
        schedule: 120,
        positioning: 60,
        expiration: 3600,
        version: 1,
        minDeposit: 1
      })

      const player = addr1
      const staker1 = addr2
      const staker2 = addr3
      const mentor1 = addr4
      const mentor2 = addr5

      await send(owner, DEMO2, player, 1000)
      await send(owner, DEMO, staker1, 20)
      await send(owner, DEMO, staker2, 100)

      // staking
      const epochid_0 = await staking.ACTUAL_EPOCH_ID()
      expect(epochid_0).to.be.equal(0)

      await approve(staker1, DEMO, StakingOraclyV1, 20)
      await staking.stake(staker1, epochid_0, 20)
      const depositid_1 = staking.depositId(staker1, epochid_0)

      await approve(staker2, DEMO, StakingOraclyV1, 100)
      await staking.stake(staker2, epochid_0, 100)
      const depositid_2 = staking.depositId(staker2, epochid_0)

      expect(await balanceOf(DEMO, staker1)).to.be.equal(0)
      expect(await balanceOf(DEMO, staker2)).to.be.equal(0)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(120)

      // mentoring (mentor2 => mentor1 => player)
      await mentoring.joinMentor(mentor1, mentor2)
      await mentoring.joinMentor(player, mentor1)

      const roundid_1 = await oraclyv1.forwardTimeToRoundOpen(game)

      await approve(player, DEMO2, OraclyV1, 1000)
      const predictionid_zero_1 = await oraclyv1.placePrediction(player, 800, RESOLUTION.ZERO, game.gameid, roundid_1)
      const predictionid_down_1 = await oraclyv1.placePrediction(player, 50, RESOLUTION.DOWN, game.gameid, roundid_1)
      const predictionid_up_1 = await oraclyv1.placePrediction(player, 150, RESOLUTION.UP, game.gameid, roundid_1)

      await forwardTime(game.schedule)

      // not creates initial staking epoch epochid=1 (nothing collected)
      await oraclyv1.resolve4withdraw(player, roundid_1, predictionid_up_1, DEMO2)
      expect(await balanceOf(DEMO2, player)).to.be.equal(990)
      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(7)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(3)

      const epochid_1 = await staking.ACTUAL_EPOCH_ID()
      expect(epochid_1).to.be.equal(1)

      await staking.unstake(staker1, epochid_1, depositid_1)

      await staking.forwardTimeToNextEpoch()

      const roundid_2 = await oraclyv1.forwardTimeToRoundOpen(game)

      await approve(player, DEMO2, OraclyV1, 990)
      const predictionid_down_2 = await oraclyv1.placePrediction(addr1, 900, RESOLUTION.DOWN, game.gameid, roundid_2)
      const predictionid_up_2 = await oraclyv1.placePrediction(addr1, 90, RESOLUTION.UP, game.gameid, roundid_2)
      expect(await balanceOf(DEMO2, player)).to.be.equal(0)

      await forwardTime(game.schedule)

      // creates next staking epoch epochid=2
      await oraclyv1.resolve4withdraw(player, roundid_2, predictionid_up_2, DEMO2)
      expect(await balanceOf(DEMO2, player)).to.be.equal(980)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(3+3)
      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(7+7)

      await staking.withdraw(staker1, depositid_1)
      expect(await balanceOf(DEMO, staker1)).to.be.equal(20)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(100)

      await staking.claimReward(staker1, epochid_1, depositid_1, DEMO2)
      expect(await balanceOf(DEMO2, staker1)).to.be.equal(1)
      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(13)

      await staking.claimReward(staker2, epochid_1, depositid_2, DEMO2)
      expect(await balanceOf(DEMO2, staker2)).to.be.equal(6)
      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(7)

      await mentoring.claimReward(mentor1, DEMO2)
      expect(await balanceOf(DEMO2, mentor1)).to.be.equal(3+3)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(0)

      await expect(mentoring.claimReward(mentor2, DEMO2)).to.be.revertedWith('NothingToWithdraw')
      expect(await balanceOf(DEMO2, mentor2)).to.be.equal(0)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(0)

      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(7)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO2, staker1)).to.be.equal(1)
      expect(await balanceOf(DEMO2, staker2)).to.be.equal(6)
      expect(await balanceOf(DEMO2, mentor1)).to.be.equal(6)
      expect(await balanceOf(DEMO2, mentor2)).to.be.equal(0)
      expect(await balanceOf(DEMO2, player)).to.be.equal(980)
      expect(await balanceOf(DEMO2, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 1000n)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(100)
      expect(await balanceOf(DEMO, staker1)).to.be.equal(20)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 120n)
    })

  })

})


