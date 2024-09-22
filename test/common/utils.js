const { ethers } = require('hardhat')

const UNIX_SECOND = 1
const UNIX_MINUTE = 60
const UNIX_HOUR = 60 * UNIX_MINUTE
const UNIX_DAY = 24 * UNIX_HOUR
const UNIX_WEEK = 7 * UNIX_DAY

const DEMO_DECIMALS = 18n
const ORCY_DECIMALS = 18n
const TEST_DECIMALS = 6n

const DEMO_INITIAL_SUPPLY = 1_000n *10n**DEMO_DECIMALS
const TEST_TOTAL_SUPPLY = 1_000n *10n**TEST_DECIMALS
const ORCY_TOTAL_SUPPLY = 10_000_000n *10n**ORCY_DECIMALS

const address = (entity) => {
  if (!entity) return ethers.ZeroAddress

  return (entity.target || entity.address)
}

const approve = async (staker, token, contract, amount) => {

  const tokenSigned = token.connect(staker)
  await tokenSigned.approve(address(contract), amount)

}

const allowance = async (token, staker, entity) => {
  return await token.allowance(address(staker), address(entity))
}

const send = async (staker, token, entity, amount) => {

  const tokenSigned = token.connect(staker)
  await tokenSigned.transfer(address(entity), amount)

}

const balanceOf = async (token, entity) => {
  return await token.balanceOf(address(entity))
}

const keccak256 = (values, types) => {
  const abicoder = ethers.AbiCoder.defaultAbiCoder()
  const abiencode = abicoder.encode(
    types,
    values
  )
  return ethers.keccak256(abiencode)
}

const getLatestBlock = async () => {
  const lastblockId = await ethers.provider.getBlockNumber()
  const block = await ethers.provider.getBlock(lastblockId)

  return block
}

const forwardTime = async (seconds) => {
  seconds = Number(seconds)
  console.log('forwardTime by ', seconds)
  await network.provider.send('evm_increaseTime', [seconds])
  await network.provider.send('evm_mine')
}

module.exports = {
  send,
  approve,
  address,
  allowance,
  balanceOf,

  keccak256,
  getLatestBlock,
  forwardTime,

  DEMO_INITIAL_SUPPLY,
  TEST_TOTAL_SUPPLY,
  ORCY_TOTAL_SUPPLY,

  DEMO_DECIMALS,
  ORCY_DECIMALS,
  TEST_DECIMALS,

  UNIX_SECOND,
  UNIX_MINUTE,
  UNIX_HOUR,
  UNIX_DAY,
  UNIX_WEEK
}
