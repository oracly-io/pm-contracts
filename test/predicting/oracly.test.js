require('../common/init')

const { expect } = require('chai')
const { ethers } = require('hardhat')

const { deployToken, deployMeta, deployAggregatorProxyMock, deployOraclyV1 } = require('../common')
const { approve, send, allowance, balanceOf, forwardTime } = require('../common/utils')
const { DEMO_INITIAL_SUPPLY } = require('../common/utils')

const {
  init: initOraclyV1,
  RESOLUTION,
  getFutureRoundId,
  isBettorInRound,
  forwardTimeToRoundOpen,
  withdraw,
  resolve4withdraw,
  placePrediction,
  getPredictionId,
  getRound,
  resolve,
  calculateRoundid,
  calcPayout,
} = require('../common/oraclyv1')

const {
  init: initMeta,
  addGame,
} = require('../common/meta')

require('@openzeppelin/test-helpers/configure')({
  provider: process.env.LDE_URL
})

describe('Gaming', () => {

  let MetaOraclyV1
  let MockAggregatorProxy

  let OraclyV1

  let DEMO

  let owner
  let addr1
  let addr2
  let addrs // eslint-disable-line

  beforeEach(async () => {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners()

    DEMO = await deployToken('DEMO')
    MockAggregatorProxy = await deployAggregatorProxyMock()
    MetaOraclyV1 = await deployMeta()
    initMeta(MetaOraclyV1)

    OraclyV1 = await deployOraclyV1(
      owner.address,
      // NOTE: we are using MetaOraclyV1 as stakers reward distributor contract
      // in order to test fallback distribution mechanism via EOA owner.address
      MetaOraclyV1.target,
      // NOTE: we are using MetaOraclyV1 as mentors reward distributor contract
      // in order to test fallback distribution mechanism via EOA owner.address
      MetaOraclyV1.target,
      MetaOraclyV1.target,
    )

    initOraclyV1(OraclyV1)

  })

  describe('OraclyV1', () => {

    it('Early No Contest round resolution Withdraw', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 60,
        schedule: 120,
        expiration: 3600,
        version: 1,
        minDeposit: 1
      })

      const roundid = await forwardTimeToRoundOpen(game)

      await approve(owner, DEMO, OraclyV1, 200)

      expect(await isBettorInRound(owner, roundid)).to.be.equal(false)

      const predictionid_up = await placePrediction(owner, 100, RESOLUTION.UP, game.gameid, roundid)
      await placePrediction(owner, 100, RESOLUTION.UP, game.gameid, roundid)

      expect(await isBettorInRound(owner, roundid)).to.be.equal(true)

      expect(await allowance(DEMO, owner, OraclyV1)).to.be.equal(0)

      await forwardTime(game.positioning)

      await resolve(owner, roundid)

      let round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.NOCONTEST)
      expect(round.archived).to.be.equal(false)
      expect(round.archivedAt).to.be.equal(0)

      await withdraw(owner, roundid, predictionid_up, DEMO)

      round = await getRound(owner, roundid)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

    })

    it('Later No Contest round resolution Withdraw', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 2,
        minDeposit: 1
      })
      const roundid = await forwardTimeToRoundOpen(game)

      await approve(owner, DEMO, OraclyV1, 260)

      await expect(placePrediction(owner, 100, RESOLUTION.UNDEFINED, game.gameid, roundid)).to.be.revertedWith('NotSupportedPosition')
      await expect(placePrediction(owner, 100, RESOLUTION.NOCONTEST, game.gameid, roundid)).to.be.revertedWith('NotSupportedPosition')
      await expect(placePrediction(owner, 0, RESOLUTION.ZERO, game.gameid, roundid)).to.be.revertedWith('UnacceptableDepositAmount')

      const predictionid_zero = await placePrediction(owner, 100, RESOLUTION.ZERO, game.gameid, roundid)
      await placePrediction(owner, 10, RESOLUTION.ZERO, game.gameid, roundid)

      const predictionid_down = await placePrediction(owner, 100, RESOLUTION.DOWN, game.gameid, roundid)
      await placePrediction(owner, 20, RESOLUTION.DOWN, game.gameid, roundid)
      await placePrediction(owner, 30, RESOLUTION.DOWN, game.gameid, roundid)

      expect(await allowance(DEMO, owner, OraclyV1)).to.be.equal(0)

      await forwardTime(game.schedule)

      await resolve(owner, roundid)
      let round = await getRound(owner, roundid)

      expect(round.resolution).to.be.equal(RESOLUTION.NOCONTEST)
      expect(round.archived).to.be.equal(false)
      expect(round.archivedAt).to.be.equal(0)

      await withdraw(owner, roundid, predictionid_zero, DEMO)

      round = await getRound(owner, roundid)
      expect(round.archived).to.be.equal(false)

      await withdraw(owner, roundid, predictionid_down, DEMO)

      round = await getRound(owner, roundid)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

    })

    it('minDeposit 100 with Round Resolution UP, Withdraw', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 3,
        minDeposit: 100
      })

      const roundid = await forwardTimeToRoundOpen(game)

      await approve(owner, DEMO, OraclyV1, 300)

      await expect(placePrediction(owner, 99, RESOLUTION.UP, game.gameid, roundid)).to.be.revertedWith('UnacceptableDepositAmount')

      const predictionid_zero = await placePrediction(owner, 100, RESOLUTION.ZERO, game.gameid, roundid)
      const predictionid_down = await placePrediction(owner, 100, RESOLUTION.DOWN, game.gameid, roundid)
      const predictionid_up = await placePrediction(owner, 100, RESOLUTION.UP, game.gameid, roundid)

      expect(await allowance(DEMO, owner, OraclyV1)).to.be.equal(0)

      await forwardTime(game.schedule)

      await resolve(owner, roundid)
      let round = await getRound(owner, roundid)

      expect(round.resolution).to.be.equal(RESOLUTION.UP)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 300n)

      await expect(withdraw(owner, roundid, predictionid_zero, DEMO)).to.be.revertedWith('CannotClaimLostPrediction')
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 300n)

      await expect(withdraw(owner, roundid, predictionid_down, DEMO)).to.be.revertedWith('CannotClaimLostPrediction')
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 300n)

      await withdraw(owner, roundid, predictionid_up, DEMO)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

      round = await getRound(owner, roundid)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

    })

    it('Rounding Error Multiplayer Withdraw', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 1,
        minDeposit: 20
      })

      await send(owner, DEMO, addr1, 200)
      await send(owner, DEMO, addr2, 20)

      await approve(addr1, DEMO, OraclyV1, 200)
      await approve(addr2, DEMO, OraclyV1, 20)
      await approve(owner, DEMO, OraclyV1, 101)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_up_addr1 = await placePrediction(addr1, 200, RESOLUTION.UP, game.gameid, roundid)
      const predictionid_up_addr2 = await placePrediction(addr2, 20, RESOLUTION.UP, game.gameid, roundid)
      const predictionid_zero = await placePrediction(owner, 101, RESOLUTION.ZERO, game.gameid, roundid)

      expect(await allowance(DEMO, addr1, OraclyV1)).to.be.equal(0)
      expect(await allowance(DEMO, addr2, OraclyV1)).to.be.equal(0)
      expect(await allowance(DEMO, owner, OraclyV1)).to.be.equal(0)

      expect(await balanceOf(DEMO, addr1)).to.be.equal(0)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(0)

      await forwardTime(game.schedule)

      await resolve(owner, roundid)
      let round = await getRound(owner, roundid)

      expect(round.resolution).to.be.equal(RESOLUTION.UP)

      // cannot claims not own lost prediction
      await expect(withdraw(addr1, roundid, predictionid_zero, DEMO)).to.be.revertedWith('BettorPredictionMismatch')
      // cannot claims own lost prediction
      await expect(withdraw(owner, roundid, predictionid_zero, DEMO)).to.be.revertedWith('CannotClaimLostPrediction')
      // cannot claims not own won prediction
      await expect(withdraw(addr1, roundid, predictionid_up_addr2, DEMO)).to.be.revertedWith('BettorPredictionMismatch')

      // cannot claims not existing won prediction
      const predictionid_unexist = getPredictionId(owner, roundid, RESOLUTION.UP)
      await expect(withdraw(owner, roundid, predictionid_unexist, DEMO)).to.be.revertedWith('PredictionRoundMismatch')

      // claims own won prediction
      await withdraw(addr1, roundid, predictionid_up_addr1, DEMO)
      await withdraw(addr2, roundid, predictionid_up_addr2, DEMO)

      const [payout_addr1, com_add1] = calcPayout(321, 220, 200)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(payout_addr1)

      const [payout_addr2, com_add2] = calcPayout(321, 220, 20)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(payout_addr2)

      const roundingerror = 321 - (payout_addr1 + payout_addr2 + com_add1 + com_add2)
      expect(roundingerror).to.be.equal(1)

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)

      await send(addr1, DEMO, owner, payout_addr1)
      await send(addr2, DEMO, owner, payout_addr2)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

      expect(await isBettorInRound(owner, roundid)).to.be.equal(true)
      expect(await isBettorInRound(addr1, roundid)).to.be.equal(true)
      expect(await isBettorInRound(addr2, roundid)).to.be.equal(true)

      round = await getRound(owner, roundid)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

    })

    it('Early Withdraw No Contest', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 4,
        minDeposit: 20
      })

      await approve(owner, DEMO, OraclyV1, 101)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_down = await placePrediction(owner, 101, RESOLUTION.DOWN, game.gameid, roundid)

      expect(await allowance(DEMO, owner, OraclyV1)).to.be.equal(0)

      await forwardTime(game.positioning)

      await resolve4withdraw(owner, roundid, predictionid_down, DEMO)
      await expect(resolve4withdraw(owner, roundid, predictionid_down, DEMO)).to.be.revertedWith('CannotClaimClaimedPrediction')

      const round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.NOCONTEST)
      expect(round.resolved).to.be.equal(true)
      expect(round.resolvedAt).not.to.be.equal(0)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)
    })

    it('Later Withdraw Resolve to Empty No Contest Multiplayer', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 8,
        minDeposit: 20
      })

      await send(owner, DEMO, addr1, 333)

      await approve(owner, DEMO, OraclyV1, 101)
      await approve(addr1, DEMO, OraclyV1, 333)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_up_owner = await placePrediction(owner, 101, RESOLUTION.UP, game.gameid, roundid)
      const predictionid_up_addr1 = await placePrediction(addr1, 333, RESOLUTION.UP, game.gameid, roundid)

      expect(await allowance(DEMO, owner, OraclyV1)).to.be.equal(0)
      expect(await allowance(DEMO, addr1, OraclyV1)).to.be.equal(0)

      await forwardTime(game.schedule + game.schedule)

      await resolve4withdraw(addr1, roundid, predictionid_up_addr1, DEMO)
      let round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.NOCONTEST)
      expect(round.resolved).to.be.equal(true)
      expect(round.resolvedAt).not.to.be.equal(0)
      expect(round.archived).to.be.equal(false)
      expect(round.archivedAt).to.be.equal(0)

      await resolve4withdraw(owner, roundid, predictionid_up_owner, DEMO)


      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)
      await send(addr1, DEMO, owner, 333)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

      round = await getRound(owner, roundid)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

    })

    it('Later Withdraw Resolve No Contest', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 6,
        minDeposit: 20
      })

      await approve(owner, DEMO, OraclyV1, 121)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_down = await placePrediction(owner, 100, RESOLUTION.DOWN, game.gameid, roundid)
      const predictionid_zero = await placePrediction(owner, 21, RESOLUTION.ZERO, game.gameid, roundid)

      expect(await allowance(DEMO, owner, OraclyV1)).to.be.equal(0)

      await forwardTime(game.schedule)

      await expect(withdraw(owner, roundid, predictionid_down, DEMO)).to.be.revertedWith('CannotClaimPredictionUnresolvedRound')
      await resolve4withdraw(owner, roundid, predictionid_down, DEMO)

      let round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.NOCONTEST)

      await resolve4withdraw(owner, roundid, predictionid_zero, DEMO)

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

      round = await getRound(owner, roundid)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)
    })

    it('Later Withdraw Resolve Up Multiplayer Win', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 7,
        minDeposit: 10
      })

      await send(owner, DEMO, addr1, 333)
      await send(owner, DEMO, addr2, 33)

      await approve(addr1, DEMO, OraclyV1, 333)
      await approve(addr2, DEMO, OraclyV1, 33)
      await approve(owner, DEMO, OraclyV1, 13)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_up_addr1 = await placePrediction(addr1, 333, RESOLUTION.UP, game.gameid, roundid)
      const predictionid_up_addr2 = await placePrediction(addr2, 33, RESOLUTION.UP, game.gameid, roundid)
      const predictionid_zero_owner = await placePrediction(owner, 13, RESOLUTION.DOWN, game.gameid, roundid)

      await forwardTime(game.schedule)

      await expect(resolve4withdraw(owner, roundid, predictionid_zero_owner, DEMO)).to.be.revertedWith('CannotClaimLostPrediction')
      let round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.UNDEFINED)
      expect(round.archived).to.be.equal(false)
      expect(round.archivedAt).to.be.equal(0)

      await resolve4withdraw(addr2, roundid, predictionid_up_addr2, DEMO)
      round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.UP)
      expect(round.archived).to.be.equal(false)
      expect(round.archivedAt).to.be.equal(0)

      await resolve4withdraw(addr1, roundid, predictionid_up_addr1, DEMO)

      const [payout_addr1, com_add1] = calcPayout(379, 366, 333)
      expect(await balanceOf(DEMO, addr1)).to.be.equal(payout_addr1)

      const [payout_addr2, com_add2] = calcPayout(379, 366, 33)
      expect(await balanceOf(DEMO, addr2)).to.be.equal(payout_addr2)

      const roundingerror = 379 - (payout_addr1 + payout_addr2 + com_add1 + com_add2)
      expect(roundingerror).to.be.equal(1)

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)

      await send(addr1, DEMO, owner, payout_addr1)
      await send(addr2, DEMO, owner, payout_addr2)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

      round = await getRound(owner, roundid)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

    })

    it('Cannot Place prediction in future Round and cannot Withdraw Resolve', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 9,
        minDeposit: 10
      })

      const roundid = await getFutureRoundId(game, 4)

      await approve(owner, DEMO, OraclyV1, 13)

      await expect(placePrediction(owner, 13, RESOLUTION.DOWN, game.gameid, roundid)).to.be.revertedWith('CannotPlacePredictionIntoUnactualRound')
      const predictionid = getPredictionId(owner, roundid, RESOLUTION.DOWN)

      await forwardTime(Number(game.schedule) * 4)

      await expect(resolve4withdraw(owner, roundid, predictionid, DEMO)).to.be.revertedWith('CannotResolveUnopenedRound')

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)

      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

    })

    it('Resolve Round to NO_CONTEST and cannot Withdraw Resolve Again', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 10,
        minDeposit: 10
      })

      await approve(owner, DEMO, OraclyV1, 13)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_zero = await placePrediction(owner, 13, RESOLUTION.ZERO, game.gameid, roundid)

      await forwardTime(game.positioning)

      const oraclyv1 = OraclyV1.connect(owner)
      await oraclyv1.resolve4withdraw(roundid, predictionid_zero, DEMO.target, 0)

      await expect(resolve4withdraw(owner, roundid, predictionid_zero, DEMO)).to.be.revertedWith('CannotClaimClaimedPrediction')
      const round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.NOCONTEST)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

    })

    it('Resolve Round to UP and cannot Resolve with invalid pricepairs', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 11,
        minDeposit: 10
      })

      await approve(owner, DEMO, OraclyV1, 65)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_up = await placePrediction(owner, 30, RESOLUTION.UP, game.gameid, roundid)
      const predictionid_zero = await placePrediction(owner, 20, RESOLUTION.ZERO, game.gameid, roundid)
      const predictionid_down = await placePrediction(owner, 15, RESOLUTION.DOWN, game.gameid, roundid)

      await forwardTime(game.positioning)

      const oraclyv1 = OraclyV1.connect(owner)
      await expect(oraclyv1.resolve4withdraw(roundid, predictionid_zero, DEMO.target, 0)).to.be.revertedWith('CannotResolveRoundBeforeEndDate')
      await expect(oraclyv1.resolve4withdraw(roundid, predictionid_down, DEMO.target, 0)).to.be.revertedWith('CannotResolveRoundBeforeEndDate')

      let round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.UNDEFINED)

      await forwardTime(game.positioning)

      await expect(oraclyv1.resolve4withdraw(roundid, predictionid_zero, DEMO.target, 0)).to.be.revertedWith('CannotResolveRoundWithoutPrice')

      let exitPriceid = calculateRoundid(1n, 2n, BigInt(round.endDate) - 20n)
      await expect(oraclyv1.resolve4withdraw(roundid, predictionid_zero, DEMO.target, exitPriceid)).to.be.revertedWith('InvalidRoundResolution')

      round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.UNDEFINED)

      exitPriceid = calculateRoundid(5n, 1n, BigInt(round.endDate) - 10n)
      await expect(oraclyv1.resolve4withdraw(roundid, predictionid_up, DEMO.target, exitPriceid)).to.be.revertedWith('InvalidRoundResolution')

      round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.UNDEFINED)

      exitPriceid = calculateRoundid(1n, 1n, BigInt(round.endDate) - 10n)
      await oraclyv1.resolve4withdraw(roundid, predictionid_up, DEMO.target, exitPriceid)

      round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.UP)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

    })

    it('Resolve Round to NO_CONTEST by blocking Game', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 12,
        minDeposit: 10
      })

      await approve(owner, DEMO, OraclyV1, 65)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_up = await placePrediction(owner, 30, RESOLUTION.UP, game.gameid, roundid)
      const predictionid_zero = await placePrediction(owner, 20, RESOLUTION.ZERO, game.gameid, roundid)
      const predictionid_down = await placePrediction(owner, 15, RESOLUTION.DOWN, game.gameid, roundid)

      await forwardTime(game.positioning)

      await MetaOraclyV1.blockGame(game.gameid)

      const oraclyv1 = OraclyV1.connect(owner)
      await expect(oraclyv1.resolve4withdraw(roundid, predictionid_zero, DEMO.target, 0)).to.be.revertedWith('CannotResolveRoundBeforeEndDate')

      let round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.UNDEFINED)

      await forwardTime(game.positioning)
      await oraclyv1.resolve4withdraw(roundid, predictionid_zero, DEMO.target, 0)
      await oraclyv1.resolve4withdraw(roundid, predictionid_up, DEMO.target, 0)
      await withdraw(owner, roundid, predictionid_down, DEMO)

      round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.NOCONTEST)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

    })

    it('Resolve Round to NO_CONTEST by settlment expiration, resolve by resolve4withdraw', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 13,
        minDeposit: 10
      })

      await approve(owner, DEMO, OraclyV1, 65)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_up = await placePrediction(owner, 30, RESOLUTION.UP, game.gameid, roundid)
      const predictionid_zero = await placePrediction(owner, 20, RESOLUTION.ZERO, game.gameid, roundid)
      const predictionid_down = await placePrediction(owner, 15, RESOLUTION.DOWN, game.gameid, roundid)

      // forward time not enought
      // because expiration period starts from endDate
      await forwardTime(game.expiration)

      const oraclyv1 = OraclyV1.connect(owner)
      await expect(oraclyv1.resolve4withdraw(roundid, predictionid_zero, DEMO.target, 0)).to.be.revertedWith('CannotResolveRoundWithoutPrice')
      await expect(oraclyv1.resolve4withdraw(roundid, predictionid_up, DEMO.target, 0)).to.be.revertedWith('CannotResolveRoundWithoutPrice')

      // forward time one round
      // just enough for settlement period to expire
      await forwardTime(game.schedule)

      // now resolution should work without price ids resolving round into NO_CONTEST
      await oraclyv1.resolve4withdraw(roundid, predictionid_zero, DEMO.target, 0)
      await oraclyv1.resolve4withdraw(roundid, predictionid_up, DEMO.target, 0)
      await withdraw(owner, roundid, predictionid_down, DEMO)

      const round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.NOCONTEST)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

    })

    it('Resolve Round to NO_CONTEST by settlment expiration, resolved by resolve', async () => {

      const game = await addGame({
        pricefeed: MockAggregatorProxy.target,
        erc20: DEMO.target,
        positioning: 90,
        schedule: 180,
        expiration: 3600,
        version: 14,
        minDeposit: 10
      })

      await approve(owner, DEMO, OraclyV1, 65)

      const roundid = await forwardTimeToRoundOpen(game)

      const predictionid_up = await placePrediction(owner, 30, RESOLUTION.UP, game.gameid, roundid)
      const predictionid_zero = await placePrediction(owner, 20, RESOLUTION.ZERO, game.gameid, roundid)
      const predictionid_down = await placePrediction(owner, 15, RESOLUTION.DOWN, game.gameid, roundid)

      // Forward time, so round settlment expirs
      // Round should resolve as NO_CONTEST
      await forwardTime(game.schedule + game.expiration)

      const oraclyv1 = OraclyV1.connect(owner)
      await oraclyv1.resolve(roundid, 0)
      await oraclyv1.withdraw(roundid, predictionid_zero, DEMO.target)
      await oraclyv1.resolve4withdraw(roundid, predictionid_up, DEMO.target, 0)
      await withdraw(owner, roundid, predictionid_down, DEMO)

      const round = await getRound(owner, roundid)
      expect(round.resolution).to.be.equal(RESOLUTION.NOCONTEST)
      expect(round.archived).to.be.equal(true)
      expect(round.archivedAt).not.to.be.equal(0)

      expect(await balanceOf(DEMO, OraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)

    })

  })

})
