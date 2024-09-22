const { keccak256 } = require('../common/utils')

let MetaOraclyV1
const init = (contract) => {
  MetaOraclyV1 = contract
}

const getGameid = async (mtp) => {
  return keccak256(
    [
      mtp.pricefeed,
      mtp.erc20,
      mtp.version,
      mtp.schedule,
      mtp.positioning,
    ],
    [
      'address',
      'address',
      'uint16',
      'uint256',
      'uint256',
    ]
  )
}

const getActiveGames = async (erc20, offset) => {

  return await MetaOraclyV1.getActiveGames(erc20, offset)

}

const addGame = async (mtp) => {
  await MetaOraclyV1.addGame(
    mtp.pricefeed,
    mtp.erc20,
    mtp.version,
    mtp.schedule,
    mtp.positioning,
    mtp.expiration,
    mtp.minDeposit,
  )
  const game = await MetaOraclyV1.getGame(getGameid(mtp))

  return game
}

module.exports = {
  init,

  getActiveGames,
  getGameid,
  addGame,
}


