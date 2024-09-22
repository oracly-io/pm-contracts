const { address } = require('../common/utils')

let VestingOraclyV1
const init = (contract) => {
  VestingOraclyV1 = contract
}

const setVestingERC20 = async (sender, erc20) => {

  const vesting = VestingOraclyV1.connect(sender)
  return await vesting.setVestingERC20(address(erc20))

}

const owner = async (sender) => {

  const vesting = VestingOraclyV1.connect(sender)
  return await vesting.owner()

}

const receive = async (sender) => {

  const vesting = VestingOraclyV1.connect(sender)
  return await vesting.receive()

}

const released = async (sender, erc20) => {

  const vesting = VestingOraclyV1.connect(sender)
  return erc20
    ? await vesting['released(address)'](address(erc20))
    : await vesting.released()

}

const release = async (sender, erc20) => {

  const vesting = VestingOraclyV1.connect(sender)
  return erc20
    ? await vesting['release(address)'](address(erc20))
    : await vesting.release()

}

const vestedAmount = async (sender, erc20, timestamp) => {

  const vesting = VestingOraclyV1.connect(sender)
  return erc20
    ? await vesting['vestedAmount(address, uint64)'](address(erc20), timestamp)
    : await vesting.vestedAmount(timestamp)

}

const duration = async (sender) => {

  const vesting = VestingOraclyV1.connect(sender)
  return await vesting.duration()

}

const start = async (sender) => {

  const vesting = VestingOraclyV1.connect(sender)
  return await vesting.start()

}

const end = async (sender) => {

  const vesting = VestingOraclyV1.connect(sender)
  return await vesting.end()

}

module.exports = {
  init,

  setVestingERC20,

  receive,
  release,

  // getters
  vestedAmount,
  owner,
  released,
  duration,
  start,
  end,
}


