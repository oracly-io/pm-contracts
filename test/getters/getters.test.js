require('../common/init')

const { expect } = require('chai')
const { ethers } = require('hardhat')

const { deployToken, deployAggregatorProxyMock } = require('../common')
const { deployMeta, deployOraclyV1 } = require('../common')
const { deployStakingOraclyV1, initStakingOraclyV1 } = require('../common')
const { deployMentoring, initMentoring } = require('../common')

const { approve, send, balanceOf, forwardTime, address } = require('../common/utils')

const { RESOLUTION } = require('../common/oraclyv1')

const staking = require('../common/staking')
const mentoring = require('../common/mentoring')
const oraclyv1 = require('../common/oraclyv1')
const meta = require('../common/meta')

require('@openzeppelin/test-helpers/configure')({
  provider: process.env.LDE_URL
})

const DEMO_INITIAL_SUPPLY= 1000000000000000000000n

describe('GETTERS', () => {

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

  describe('Getter from contracts', () => {

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

      const [
        bcbettor1,
        [
          bcpredictionsTotal1,
          bcpredictionsUp1,
          bcpredictionsDown1,
          bcpredictionsZero1,
        ], [
          bcdepositTotal1,
          bcdepositUp1,
          bcdepositDown1,
          bcdepositZero1,
        ], [
          bcpaidoutTotal1,
          bcpaidoutUp1,
          bcpaidoutDown1,
          bcpaidoutZero1,
        ],
      ] = await oraclyv1.getBettor(player, DEMO2)
      expect(bcbettor1).to.be.equal(address(0))
      expect(bcpredictionsTotal1).to.be.equal(0)
      expect(bcpredictionsUp1).to.be.equal(0)
      expect(bcpredictionsDown1).to.be.equal(0)
      expect(bcpredictionsZero1).to.be.equal(0)
      expect(bcdepositTotal1).to.be.equal(0)
      expect(bcdepositUp1).to.be.equal(0)
      expect(bcdepositDown1).to.be.equal(0)
      expect(bcdepositZero1).to.be.equal(0)
      expect(bcpaidoutTotal1).to.be.equal(0)
      expect(bcpaidoutUp1).to.be.equal(0)
      expect(bcpaidoutDown1).to.be.equal(0)
      expect(bcpaidoutZero1).to.be.equal(0)

      await approve(player, DEMO2, OraclyV1, 1000)
      const predictionid_zero_1 = await oraclyv1.placePrediction(player, 800, RESOLUTION.ZERO, game.gameid, roundid_1)
      const predictionid_down_1 = await oraclyv1.placePrediction(player, 50, RESOLUTION.DOWN, game.gameid, roundid_1)
      const predictionid_up_1 = await oraclyv1.placePrediction(player, 150, RESOLUTION.UP, game.gameid, roundid_1)

      const [
        bcbettor2,
        [
          bcpredictionsTotal2,
          bcpredictionsUp2,
          bcpredictionsDown2,
          bcpredictionsZero2,
        ], [
          bcdepositTotal2,
          bcdepositUp2,
          bcdepositDown2,
          bcdepositZero2,
        ], [
          bcpaidoutTotal2,
          bcpaidoutUp2,
          bcpaidoutDown2,
          bcpaidoutZero2,
        ],
      ] = await oraclyv1.getBettor(player, DEMO2)
      expect(bcbettor2).to.be.equal(player)
      expect(bcpredictionsTotal2).to.be.equal(3)
      expect(bcpredictionsUp2).to.be.equal(1)
      expect(bcpredictionsDown2).to.be.equal(1)
      expect(bcpredictionsZero2).to.be.equal(1)
      expect(bcdepositTotal2).to.be.equal(1000)
      expect(bcdepositUp2).to.be.equal(150)
      expect(bcdepositDown2).to.be.equal(50)
      expect(bcdepositZero2).to.be.equal(800)
      expect(bcpaidoutTotal2).to.be.equal(0)
      expect(bcpaidoutUp2).to.be.equal(0)
      expect(bcpaidoutDown2).to.be.equal(0)
      expect(bcpaidoutZero2).to.be.equal(0)

      await forwardTime(game.schedule)

      // not creates initial staking epoch epochid=1 (nothing collected)
      await oraclyv1.resolve4withdraw(player, roundid_1, predictionid_up_1, DEMO2)
      expect(await balanceOf(DEMO2, player)).to.be.equal(990)
      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(7)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(3)

      const [
        bcbettor3,
        [
          bcpredictionsTotal3,
          bcpredictionsUp3,
          bcpredictionsDown3,
          bcpredictionsZero3,
        ], [
          bcdepositTotal3,
          bcdepositUp3,
          bcdepositDown3,
          bcdepositZero3,
        ], [
          bcpaidoutTotal3,
          bcpaidoutUp3,
          bcpaidoutDown3,
          bcpaidoutZero3,
        ],
      ] = await oraclyv1.getBettor(player, DEMO2)
      expect(bcbettor3).to.be.equal(player)
      expect(bcpredictionsTotal3).to.be.equal(3)
      expect(bcpredictionsUp3).to.be.equal(1)
      expect(bcpredictionsDown3).to.be.equal(1)
      expect(bcpredictionsZero3).to.be.equal(1)
      expect(bcdepositTotal3).to.be.equal(1000)
      expect(bcdepositUp3).to.be.equal(150)
      expect(bcdepositDown3).to.be.equal(50)
      expect(bcdepositZero3).to.be.equal(800)
      expect(bcpaidoutTotal3).to.be.equal(990)
      expect(bcpaidoutUp3).to.be.equal(990)
      expect(bcpaidoutDown3).to.be.equal(0)
      expect(bcpaidoutZero3).to.be.equal(0)

      const epochid_1 = await staking.ACTUAL_EPOCH_ID()
      expect(epochid_1).to.be.equal(1)

      expect(await staking.getStakeOf(staker1)).to.be.equal(20)

      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(3)

      await staking.unstake(staker1, epochid_1, depositid_1)

      expect(await staking.getStakeOf(staker1)).to.be.equal(0)
      const [[[bcdepositid_1]], bcdepositsize] = await staking.getStakerDeposits(staker1, 0)
      expect(bcdepositsize).to.be.equal(1)
      expect(bcdepositid_1).to.be.equal(depositid_1)

      const [deposits, bcdepositsize_2] = await staking.getStakerDeposits(staker1, 1)
      expect(bcdepositsize_2).to.be.equal(1)
      expect(deposits).to.be.equal([])

      await staking.forwardTimeToNextEpoch()

      const roundid_2 = await oraclyv1.forwardTimeToRoundOpen(game)

      await approve(player, DEMO2, OraclyV1, 990)
      const predictionid_down_2 = await oraclyv1.placePrediction(player, 900, RESOLUTION.DOWN, game.gameid, roundid_2)
      const predictionid_up_2 = await oraclyv1.placePrediction(player, 90, RESOLUTION.UP, game.gameid, roundid_2)
      expect(await balanceOf(DEMO2, player)).to.be.equal(0)

      await forwardTime(game.schedule)

      // creates next staking epoch epochid=2
      await oraclyv1.resolve4withdraw(player, roundid_2, predictionid_up_2, DEMO2)
      expect(await balanceOf(DEMO2, player)).to.be.equal(980)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(3+3)
      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(7+7)

      const epochid_2 = await staking.ACTUAL_EPOCH_ID()
      expect(epochid_2).to.be.equal(2)

      await staking.withdraw(staker1, depositid_1)
      expect(await balanceOf(DEMO, staker1)).to.be.equal(20)
      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(100)

      expect(await staking.getStakerPaidout(staker1, DEMO2)).to.be.equal(0)
      expect(await staking.getDepositPaidout(staker1, depositid_1, DEMO2)).to.be.equal(0)
      expect(await staking.getDepositEpochPaidout(staker1, depositid_1, DEMO2, epochid_1)).to.be.equal(0)

      await staking.claimReward(staker1, epochid_1, depositid_1, DEMO2)
      expect(await balanceOf(DEMO2, staker1)).to.be.equal(1)
      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(13)

      expect(await staking.getStakerPaidout(staker1, DEMO2)).to.be.equal(1)
      expect(await staking.getDepositPaidout(staker1, depositid_1, DEMO2)).to.be.equal(1)
      expect(await staking.getDepositEpochPaidout(staker1, depositid_1, DEMO2, epochid_1)).to.be.equal(1)

      const {
        epoch: [bcepochid],
        stakers: [bcstakers],
        stakepool: [bcstakepool],
        rewards: [bccollected, bcreleased]
      } = await staking.getEpoch(staker1, epochid_1, DEMO2)
      expect(bcepochid).to.be.equal(epochid_1)
      expect(bcstakers).to.be.equal(2)
      expect(bcstakepool).to.be.equal(100 + 20)
      expect(bccollected).to.be.equal(7)
      expect(bcreleased).to.be.equal(1)

      await staking.claimReward(staker2, epochid_1, depositid_2, DEMO2)
      expect(await balanceOf(DEMO2, staker2)).to.be.equal(6)
      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(7)

      expect(await staking.getStakerPaidout(staker2, DEMO2)).to.be.equal(6)
      expect(await staking.getDepositPaidout(staker2, depositid_2, DEMO2)).to.be.equal(6)
      expect(await staking.getDepositEpochPaidout(staker2, depositid_2, DEMO2, epochid_1)).to.be.equal(6)

      await staking.claimReward(staker2, epochid_2, depositid_2, DEMO2)
      expect(await balanceOf(DEMO2, staker2)).to.be.equal(13)
      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(0)

      expect(await staking.getStakerPaidout(staker2, DEMO2)).to.be.equal(13)
      expect(await staking.getDepositPaidout(staker2, depositid_2, DEMO2)).to.be.equal(13)
      expect(await staking.getDepositEpochPaidout(staker2, depositid_2, DEMO2, epochid_2)).to.be.equal(7)

      const [
        bcprotege,       // protege
        bcmentor,        // mentor
        bcearned,        // earned
        bcearnedTotal,   // earnedTotal
        bccreatedAt,     // createdAt
        bcupdatedAt      // updatedAt
      ] = await mentoring.getProtege(mentor1, DEMO2)

      expect(bcprotege).to.be.equal(mentor1)
      expect(bcmentor).to.be.equal(mentor2)
      expect(bcearned).to.be.equal(0)
      expect(bcearnedTotal).to.be.equal(0)
      expect(bccreatedAt).to.not.be.equal(0)
      expect(bcupdatedAt).to.not.be.equal(0)

      const [[bcplayer], bcsize_protege] = await mentoring.getMentorProteges(mentor1, 0)
      expect(bcplayer).to.be.equal(player)
      expect(bcsize_protege).to.be.equal(1)

      const [bcproteges, bcsize_protege2] = await mentoring.getMentorProteges(mentor1, 1)
      expect(bcproteges).to.be.equal([])
      expect(bcsize_protege2).to.be.equal(1)

      const [
        bcprotege1,       // protege
        bcmentor1,        // mentor
        bcearned1,        // earned
        bcearnedTotal1,   // earnedTotal
        bccreatedAt1,     // createdAt
        bcupdatedAt1      // updatedAt
      ] = await mentoring.getProtege(player, DEMO2)

      expect(bcprotege1).to.be.equal(player)
      expect(bcmentor1).to.be.equal(mentor1)
      expect(bcearned1).to.be.equal(6)
      expect(bcearnedTotal1).to.be.equal(6)
      expect(bccreatedAt1).to.not.be.equal(0)
      expect(bcupdatedAt1).to.not.be.equal(0)

      expect(await mentoring.getProtegeMentorEarned(player, DEMO2, mentor1)).to.be.equal(6)
      expect(await mentoring.getProtegeMentorEarned(mentor1, DEMO2, mentor2)).to.be.equal(0)
      expect(await mentoring.getProtegeMentorEarned(player, DEMO2, mentor2)).to.be.equal(0)
      expect(await mentoring.getProtegeMentorEarned(mentor1, DEMO2, player)).to.be.equal(0)

      const [
        bcmentor2,         // mentor
        bccircle2,         // circle
        bcrewards2,        // rewards
        bcpayouts2,        // payouts
        bccreatedAt2,      // createdAt
        bcupdatedAt2       // updatedAt
      ] = await mentoring.getMentor(mentor1, DEMO2)

      expect(bcmentor2).to.be.equal(mentor1)
      expect(bccircle2).to.be.equal(1)
      expect(bcrewards2).to.be.equal(6)
      expect(bcpayouts2).to.be.equal(0)
      expect(bccreatedAt2).to.not.be.equal(0)
      expect(bcupdatedAt2).to.not.be.equal(0)

      const [
        bcmentor3,         // mentor
        bccircle3,         // circle
        bcrewards3,        // rewards
        bcpayouts3,        // payouts
        bccreatedAt3,      // createdAt
        bcupdatedAt3       // updatedAt
      ] = await mentoring.getMentor(mentor2, DEMO2)

      expect(bcmentor3).to.be.equal(mentor2)
      expect(bccircle3).to.be.equal(1)
      expect(bcrewards3).to.be.equal(0)
      expect(bcpayouts3).to.be.equal(0)
      expect(bccreatedAt3).to.not.be.equal(0)
      expect(bcupdatedAt3).to.not.be.equal(0)

      await mentoring.claimReward(mentor1, DEMO2)
      expect(await balanceOf(DEMO2, mentor1)).to.be.equal(3+3)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(0)

      await expect(mentoring.claimReward(mentor2, DEMO2)).to.be.revertedWith('NothingToWithdraw')
      expect(await balanceOf(DEMO2, mentor2)).to.be.equal(0)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(0)

      const [
        bcmentor4,         // mentor
        bccircle4,         // circle
        bcrewards4,        // rewards
        bcpayouts4,        // payouts
        bccreatedAt4,      // createdAt
        bcupdatedAt4       // updatedAt
      ] = await mentoring.getMentor(mentor1, DEMO2)

      expect(bcmentor4).to.be.equal(mentor1)
      expect(bccircle4).to.be.equal(1)
      expect(bcrewards4).to.be.equal(6)
      expect(bcpayouts4).to.be.equal(6)
      expect(bccreatedAt4).to.not.be.equal(0)
      expect(bcupdatedAt4).to.not.be.equal(0)

      const [
        bcmentor5,         // mentor
        bccircle5,         // circle
        bcrewards5,        // rewards
        bcpayouts5,        // payouts
        bccreatedAt5,      // createdAt
        bcupdatedAt5       // updatedAt
      ] = await mentoring.getMentor(mentor2, DEMO2)

      expect(bcmentor5).to.be.equal(mentor2)
      expect(bccircle5).to.be.equal(1)
      expect(bcrewards5).to.be.equal(0)
      expect(bcpayouts5).to.be.equal(0)
      expect(bccreatedAt5).to.not.be.equal(0)
      expect(bcupdatedAt5).to.not.be.equal(0)

      const [
        bcmentor6,         // mentor
        bccircle6,         // circle
        bcrewards6,        // rewards
        bcpayouts6,        // payouts
        bccreatedAt6,      // createdAt
        bcupdatedAt6       // updatedAt
      ] = await mentoring.getMentor(player, DEMO2)

      expect(bcmentor6).to.be.equal(address(0))
      expect(bccircle6).to.be.equal(0)
      expect(bcrewards6).to.be.equal(0)
      expect(bcpayouts6).to.be.equal(0)
      expect(bccreatedAt6).to.be.equal(0)
      expect(bcupdatedAt6).to.be.equal(0)

      const [
        bcprotege_2,      // protege
        bcmentor_2,       // mentor
        bcearned_2,       // earned
        bcearnedTotal_2,  // earnedTotal
        bccreatedAt_2,    // createdAt
        bcupdatedAt_2     // updatedAt
      ] = await mentoring.getProtege(mentor2, DEMO2)

      expect(bcprotege_2).to.be.equal(address(0))
      expect(bcmentor_2).to.be.equal(address(0))
      expect(bcearned_2).to.be.equal(0)
      expect(bcearnedTotal_2).to.be.equal(0)
      expect(bccreatedAt_2).to.be.equal(0)
      expect(bcupdatedAt_2).to.be.equal(0)

      expect(await balanceOf(DEMO2, StakingOraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO2, staker1)).to.be.equal(1)
      expect(await balanceOf(DEMO2, staker2)).to.be.equal(13)
      expect(await balanceOf(DEMO2, mentor1)).to.be.equal(6)
      expect(await balanceOf(DEMO2, mentor2)).to.be.equal(0)
      expect(await balanceOf(DEMO2, player)).to.be.equal(980)
      expect(await balanceOf(DEMO2, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 1000n)

      expect(await balanceOf(DEMO, StakingOraclyV1)).to.be.equal(100)
      expect(await balanceOf(DEMO, staker1)).to.be.equal(20)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 120n)

      const [roundid] = await oraclyv1.getRound(player, roundid_2)
      expect(roundid).to.be.equal(roundid_2)

      const [predictionid] = await oraclyv1.getPrediction(player, predictionid_up_2)
      expect(predictionid).to.be.equal(predictionid_up_2)

      const [[[bcgameid1]], bcgamesize1] = await meta.getActiveGames(game.erc20, 0)
      expect(bcgamesize1).to.be.equal(1)
      expect(bcgameid1).to.be.equal(game.gameid)

      const [bcgames, bcgamesize2] = await meta.getActiveGames(game.erc20, 1)
      expect(bcgamesize2).to.be.equal(1)
      expect(bcgames).to.be.equal([])

      const [[bcroundid2, bcroundid1], bcsize1] = await oraclyv1.getGameRounds(player, game.gameid, 0)
      expect(bcsize1).to.be.equal(2)
      expect(bcroundid1).to.be.equal(roundid_1)
      expect(bcroundid2).to.be.equal(roundid_2)

      const [[[bcpredictionid2, bcroundid4], [bcpredictionid1, bcroundid3]], bcsize2] = await oraclyv1.getRoundPredictions(player, roundid_2, RESOLUTION.ALL, 0)

      expect(bcpredictionid1).to.be.equal(predictionid_down_2)
      expect(bcroundid3).to.be.equal(roundid_2)

      expect(bcpredictionid2).to.be.equal(predictionid_up_2)
      expect(bcroundid4).to.be.equal(roundid_2)

      expect(bcsize2).to.be.equal(2)

      const [bcitems1, bcsize3] = await oraclyv1.getRoundPredictions(player, roundid_2, RESOLUTION.UP, 0)
      expect(bcitems1.length).to.be.equal(1)
      expect(bcsize3).to.be.equal(1)

      const [bcitems2, bcsize4] = await oraclyv1.getRoundPredictions(player, roundid_2, RESOLUTION.UP, 1)
      expect(bcitems2.length).to.be.equal(0)
      expect(bcsize4).to.be.equal(1)

      const [bcitems3, bcsize5] = await oraclyv1.getRoundPredictions(player, roundid_2, RESOLUTION.DOWN, 0)
      expect(bcitems3.length).to.be.equal(1)
      expect(bcsize5).to.be.equal(1)

      const [bcitems4, bcsize6] = await oraclyv1.getRoundPredictions(player, roundid_2, RESOLUTION.DOWN, 1)
      expect(bcitems4.length).to.be.equal(0)
      expect(bcsize6).to.be.equal(1)

      const [bcitems5, bcsize7] = await oraclyv1.getRoundPredictions(player, roundid_2, RESOLUTION.ZERO, 0)
      expect(bcitems5.length).to.be.equal(0)
      expect(bcsize7).to.be.equal(0)

      const [bcitems6, bcsize8] = await oraclyv1.getRoundPredictions(player, roundid_2, RESOLUTION.ZERO, 1)
      expect(bcitems6.length).to.be.equal(0)
      expect(bcsize8).to.be.equal(0)

      const [bcitems7, bcsize9] = await oraclyv1.getBettorPredictions(player, RESOLUTION.ALL, 0)
      expect(bcitems7.length).to.be.equal(5)
      expect(bcsize9).to.be.equal(5)

      const [bcitems8, bcsize10] = await oraclyv1.getBettorPredictions(player, RESOLUTION.ALL, 1)
      expect(bcitems8.length).to.be.equal(4)
      expect(bcsize10).to.be.equal(5)

      const [bcitems9, bcsize11] = await oraclyv1.getBettorPredictions(player, RESOLUTION.ALL, 2)
      expect(bcitems9.length).to.be.equal(3)
      expect(bcsize11).to.be.equal(5)

      const [bcitems10, bcsize12] = await oraclyv1.getBettorPredictions(player, RESOLUTION.ALL, 3)
      expect(bcitems10.length).to.be.equal(2)
      expect(bcsize12).to.be.equal(5)

      const [bcitems11, bcsize13] = await oraclyv1.getBettorPredictions(player, RESOLUTION.ALL, 4)
      expect(bcitems11.length).to.be.equal(1)
      expect(bcsize13).to.be.equal(5)

      const [bcitems12, bcsize14] = await oraclyv1.getBettorPredictions(player, RESOLUTION.ALL, 5)
      expect(bcitems12.length).to.be.equal(0)
      expect(bcsize14).to.be.equal(5)

      const [bcitems13, bcsize15] = await oraclyv1.getBettorPredictions(player, RESOLUTION.ALL, 5000)
      expect(bcitems13.length).to.be.equal(0)
      expect(bcsize15).to.be.equal(5)


    })

  })

})



