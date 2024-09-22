const { approve, address } = require('../common/utils')

let MentoringOraclyV1
const init = (contract) => {
  MentoringOraclyV1 = contract
}

const joinMentor = async (protege, mentor) => {

  const mentoring = MentoringOraclyV1.connect(protege)
  await mentoring.joinMentor(address(mentor))

}

const expelProtege = async (mentor, protege) => {

  const mentoring = MentoringOraclyV1.connect(mentor)
  await mentoring.expelProtege(address(protege))

}

const transferProtege = async (from, to, protege) => {

  const mentoring = MentoringOraclyV1.connect(from)
  await mentoring.transferProtege(address(protege), address(to))

}

const calculateReward = async (protege, amount) => {

  const mentoring = MentoringOraclyV1.connect(protege)
  const reward = await mentoring.calculateReward(address(protege), amount)
  return reward

}

const collectCommission = async (gatherer, protege, erc20, amount) => {

  await approve(gatherer, erc20, MentoringOraclyV1, amount)
  const mentoring = MentoringOraclyV1.connect(gatherer)
  await mentoring.collectCommission(address(protege), address(erc20), amount)

}

const claimReward = async (mentor, erc20) => {

  const mentoring = MentoringOraclyV1.connect(mentor)
  await mentoring.claimReward(address(erc20))

}

const setGatherer = async (gatherer) => {

  const mentoring = MentoringOraclyV1.connect(gatherer)
  await mentoring.setGatherer(address(gatherer))

}

const getProtege = async (protege, erc20) => {

  const mentoring = MentoringOraclyV1.connect(protege)
  return await mentoring.getProtege(address(protege), address(erc20))

}

const getMentorProteges = async (mentor, offset) => {

  const mentoring = MentoringOraclyV1.connect(mentor)
  return await mentoring.getMentorProteges(address(mentor), offset)

}

const getMentor = async (mentor, erc20) => {

  const mentoring = MentoringOraclyV1.connect(mentor)
  return await mentoring.getMentor(address(mentor), address(erc20))

}

const getProtegeMentorEarned = async (protege, erc20, mentor) => {

  const mentoring = MentoringOraclyV1.connect(protege)
  return await mentoring.getProtegeMentorEarned(address(protege), address(erc20), address(mentor))

}

module.exports = {
  init,

  joinMentor,
  setGatherer,
  claimReward,
  expelProtege,
  transferProtege,
  collectCommission,
  calculateReward,

  // getters
  getMentor,
  getProtege,
  getMentorProteges,
  getProtegeMentorEarned,

}

