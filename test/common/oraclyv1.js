const { ethers } = require('hardhat')
const { getLatestBlock, forwardTime } = require('../common/utils')
const { keccak256, address } = require('../common/utils')

const PRICE_FEED_TIMESTAMP_OFFSET = 22n
const RESOLUTION = {
  ALL: 0,
  UNDEFINED: 0,
  DOWN: 1,
  UP: 2,
  NOCONTEST: 4,
  ZERO: 3,
}

let OraclyV1
const init = (contract) => {
  OraclyV1 = contract
}

const getFutureRoundId = async (game, future = 1) => {
  const block = await getLatestBlock()

  const now = block.timestamp
  const round = Number(game.schedule)
  const sincestart = now % round
  const startDate = now - sincestart
  const futureStartDate = startDate + (round*future)

  return getRoundId(game.gameid, futureStartDate)

}

const forwardTimeToRoundOpen = async (game) => {
  const block = await getLatestBlock()

  const fora = 20

  const now = block.timestamp
  const round = Number(game.schedule)
  const sincestart = now % round
  const startDate = now - sincestart
  const nextStartDate = startDate + round

  const firein = (nextStartDate - now) + fora

  console.log('Start prev block ts', now)
  console.log('Start mext block ts', now + firein)
  await forwardTime(firein)

  return getRoundId(game.gameid, nextStartDate)
}

const getRoundId = (gameid, startDate) => {
  return keccak256(
    [
      gameid,
      startDate,
    ],
    [
      'bytes32',
      'uint',
    ]
  )
}

const withdraw = async (bettor, roundid, predictionid, token) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  await oraclyv1.withdraw(roundid, predictionid, token.target)

}

const resolve4withdraw = async (bettor, roundid, predictionid, token) => {

  const priceid = await getExitPriceid(roundid)

  const oraclyv1 = OraclyV1.connect(bettor)
  await oraclyv1.resolve4withdraw(roundid, predictionid, token.target, priceid)

}

const isBettorInRound = async (bettor, roundid) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  return await oraclyv1.isBettorInRound(address(bettor), roundid)

}

const placePrediction = async (bettor, amount, position, gameid, roundid) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  await oraclyv1.placePrediction(amount, position, gameid, roundid)

  return getPredictionId(bettor, roundid, position)

}

const getPredictionId = (bettor, roundid, position) => {

  const apiencode = ethers.AbiCoder.defaultAbiCoder().encode(
    [
      'bytes32',
      'address',
      'uint8',
    ],
    [
      roundid,
      address(bettor),
      position,
    ]
  )

  return ethers.keccak256(apiencode)
}

const getPrediction = async (bettor, predictionid) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  return await oraclyv1.getPrediction(predictionid)

}

const getRound = async (bettor, roundid) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  const [round, prizepool, predictions, bettors] = await oraclyv1.getRound(roundid)

  return round

}

const getBettor = async (bettor, erc20) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  const bcbettor = await oraclyv1.getBettor(address(bettor), address(erc20))

  return bcbettor

}

const resolve = async (bettor, roundid) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  const priceid = await getExitPriceid(roundid)

  await oraclyv1.resolve(
    roundid,
    priceid
  )

}

const calculateRoundid = (phaseId, aggrRoundid, timestamp) => {

  return (phaseId << 64n) | (timestamp << PRICE_FEED_TIMESTAMP_OFFSET) | aggrRoundid

}

const getExitPriceid = async (roundid) => {

  const [round, prizepool] = await OraclyV1.getRound(roundid)
  if (round.endDate == 0) return 0 // eslint-disable-line

  const phaseId1 = 1n
  const aggrRoundid1 = 111n
  const timestamp1 = (BigInt(round.endDate) - 10n)
  const priceid = calculateRoundid(phaseId1, aggrRoundid1, timestamp1)

  return priceid

}

const calcPayout = (prizepool, positionpool, deposit, vigorish = 1) => {

  const prize = Math.floor((prizepool * deposit) / positionpool)
  const commission = Math.ceil(prize * vigorish / 100)
  const payout = prize - commission

  return [ payout, commission ]

}

const getRoundPredictions = async (bettor, roundid, position, offset) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  return await oraclyv1.getRoundPredictions(roundid, position, offset)

}

const getBettorPredictions = async (bettor, position, offset) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  return await oraclyv1.getBettorPredictions(bettor, position, offset)

}

const getGameRounds = async (bettor, gameid, offset) => {

  const oraclyv1 = OraclyV1.connect(bettor)
  return await oraclyv1.getGameRounds(gameid, offset)

}

module.exports = {
  init,

  RESOLUTION,
  getLatestBlock,
  getFutureRoundId,
  forwardTimeToRoundOpen,
  getRoundId,
  withdraw,
  isBettorInRound,
  resolve4withdraw,
  placePrediction,
  getPredictionId,
  resolve,
  calculateRoundid,
  calcPayout,

  getPrediction,
  getRound,
  getBettor,
  getRoundPredictions,
  getBettorPredictions,
  getGameRounds,
}

