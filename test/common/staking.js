const { getLatestBlock, forwardTime } = require('../common/utils')
const { keccak256, approve, address } = require('../common/utils')

let StakingOraclyV1
const init = (contract) => {
  StakingOraclyV1 = contract
}

const depositId = (staker, epochid) => {

  const depositid = keccak256([epochid, address(staker)], ['uint', 'address'])
  return depositid

}

const getDeposit = async (sender, depositid) => {

  const staking = StakingOraclyV1.connect(sender)
  const [
    _depositid,
    staker,
    inEpochid,
    createdAt,
    amount,
    outEpochid,
    unstaked,
    unstakedAt,
    withdrawn,
    withdrawnAt
  ] = await staking.getDeposit(depositid)
  return {
    depositid: _depositid,
    staker,
    inEpochid,
    createdAt,
    amount,
    outEpochid,
    unstaked,
    unstakedAt,
    withdrawn,
    withdrawnAt
  }
}

const getEpoch = async (sender, epochid, erc20) => {

  const staking = StakingOraclyV1.connect(sender)
  const [
    epoch,
    stakers,
    stakepool,
    rewards,
  ] = await staking.getEpoch(epochid, address(erc20))
  return {
    epoch,
    stakers,
    stakepool,
    rewards,
  }
}

const getStakeOf = async (staker) => {

  const staking = StakingOraclyV1.connect(staker)
  return await staking.getStakeOf(address(staker))

}

const getStakerDeposits = async (staker, offset) => {

  const staking = StakingOraclyV1.connect(staker)
  return await staking.getStakerDeposits(address(staker), offset)

}

const getStakerPaidout = async (staker, erc20) => {

  const staking = StakingOraclyV1.connect(staker)
  return await staking.getStakerPaidout(staker, address(erc20))

}

const getDepositPaidout = async (sender, depositid, erc20) => {

  const staking = StakingOraclyV1.connect(sender)
  return await staking.getDepositPaidout(depositid, address(erc20))

}

const getDepositEpochPaidout = async (sender, depositid, erc20, epochid) => {

  const staking = StakingOraclyV1.connect(sender)
  return await staking.getDepositEpochPaidout(depositid, address(erc20), epochid)

}

const setBuy4stakeERC20 = async (admin, erc20) => {

  const staking = StakingOraclyV1.connect(admin)
  await staking.setBuy4stakeERC20(erc20)

}

const donateBuy4stake = async (donator, amount) => {

  const staking = StakingOraclyV1.connect(donator)
  await staking.donateBuy4stake(amount)

}

const buy4stake = async (staker, erc20, epochid, amount) => {

  const staking = StakingOraclyV1.connect(staker)
  await staking.buy4stake(erc20, epochid, amount)

}

const stake = async (staker, epochid, amount) => {

  const staking = StakingOraclyV1.connect(staker)
  await staking.stake(epochid, amount)

}

const withdraw = async (staker, depositid) => {

  const staking = StakingOraclyV1.connect(staker)
  await staking.withdraw(depositid)

}

const unstake = async (staker, epochid, depositid) => {

  const staking = StakingOraclyV1.connect(staker)
  await staking.unstake(epochid, depositid)

}

const collectCommission = async (staker, erc20, amount) => {

  await approve(staker, erc20, StakingOraclyV1, amount)
  const staking = StakingOraclyV1.connect(staker)
  await staking.collectCommission(address(staker), address(erc20), amount)

}

const claimReward = async (staker, epochid, depositid, erc20) => {

  const staking = StakingOraclyV1.connect(staker)
  await staking.claimReward(epochid, depositid, address(erc20))

}

const setGatherer = async (gatherer) => {

  const staking = StakingOraclyV1.connect(gatherer)
  await staking.setGatherer(address(gatherer))

}

const forwardTimeToNextEpoch = async () => {
  const block = await getLatestBlock()

  const fora = 20

  const now = block.timestamp
  const round = Number(await StakingOraclyV1.SCHEDULE())
  const sincestart = now % round
  const startDate = now - sincestart
  const nextStartDate = startDate + round

  const firein = (nextStartDate - now) + fora

  await forwardTime(firein)
}

const BUY_4_STAKEPOOL = async () => {
  return await StakingOraclyV1.BUY_4_STAKEPOOL()
}

const ACTUAL_EPOCH_ID = async () => {
  return await StakingOraclyV1.ACTUAL_EPOCH_ID()
}

module.exports = {
  init,

  stake,
  unstake,
  withdraw,
  depositId,
  setGatherer,
  claimReward,
  collectCommission,

  donateBuy4stake,
  buy4stake,

  ACTUAL_EPOCH_ID,
  BUY_4_STAKEPOOL,

  setBuy4stakeERC20,

  forwardTimeToNextEpoch,

  // getters
  getDeposit,
  getEpoch,
  getStakeOf,
  getStakerDeposits,
  getStakerPaidout,
  getDepositPaidout,
  getDepositEpochPaidout,
}

