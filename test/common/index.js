const { ethers } = require('hardhat')

async function deployToken(name, owner, args) {

  const token = (
    args
      ? await ethers.deployContract(name, args, { gasLimit: 1_000_000 })
      : await ethers.deployContract(name)
  )
  await token.waitForDeployment()

  console.log(name+'!-------------------------')
  console.log(token.target)
  console.log('------------------------------')

  token.connect(owner)

  return token
}

async function attachToken(target, name) {

  const ContractFactory = await ethers.getContractFactory(name)
  const token = await ContractFactory.attach(target)

  console.log(name+'!-------------------------')
  console.log(token.target)
  console.log('------------------------------')

  return token
}

async function deployAggregatorProxyMock() {

  const contract = await ethers.deployContract('MockAggregatorProxy')
  await contract.waitForDeployment()

  console.log('MockAggregatorProxy-----------')
  console.log(contract.target)
  console.log('------------------------------')

  return contract
}

async function attachAggregatorProxyMock(target) {

  const ContractFactory = await ethers.getContractFactory('MockAggregatorProxy')
  const contract = await ContractFactory.attach(target)

  console.log('MockAggregatorProxy-----------')
  console.log(contract.target)
  console.log('------------------------------')

  return contract
}

async function deployMeta() {

  const MetaOraclyV1 = await ethers.deployContract('MetaOraclyV1')
  await MetaOraclyV1.waitForDeployment()

  console.log('MetaOraclyV1--------------')
  console.log(MetaOraclyV1.target)
  console.log('------------------------------')

  return MetaOraclyV1
}

async function attachMeta(target) {

  const MetaContractFactory = await ethers.getContractFactory('MetaOraclyV1')
  const MetaOraclyV1 = await MetaContractFactory.attach(target)

  console.log('MetaOraclyV1--------------')
  console.log(MetaOraclyV1.target)
  console.log('------------------------------')

  return MetaOraclyV1
}


async function deployOraclyV1(
  distributorEOA,
  staking,
  mentoring,
  mate
) {

  const OraclyV1 = await ethers.deployContract('OraclyV1',
    [
      distributorEOA,
      staking,
      mentoring,
      mate,
    ],
    { gasLimit: 5_000_000 }
  )
  await OraclyV1.waitForDeployment()

  console.log('OraclyV1--------------------')
  console.log(OraclyV1.target)
  console.log('------------------------------')

  return OraclyV1
}

async function attachOraclyV1(target) {

  const OraclyV1Factory = await ethers.getContractFactory('OraclyV1')
  const OraclyV1 = await OraclyV1Factory.attach(target)

  console.log('OraclyV1--------------------')
  console.log(OraclyV1.target)
  console.log('------------------------------')

  return OraclyV1
}

async function deployStakingOraclyV1(stakingToken) {

  const StakingOraclyV1 = await ethers.deployContract('StakingOraclyV1', [stakingToken, stakingToken])
  await StakingOraclyV1.waitForDeployment()

  console.log('Staking-----------------------')
  console.log(StakingOraclyV1.target)
  console.log('------------------------------')

  return StakingOraclyV1

}

async function attachStakingOraclyV1(target) {

  const StakingOraclyV1Factory = await ethers.getContractFactory('StakingOraclyV1')
  const StakingOraclyV1 = await StakingOraclyV1Factory.attach(target)

  console.log('Staking-----------------------')
  console.log(StakingOraclyV1.target)
  console.log('------------------------------')

  return StakingOraclyV1

}

async function initStakingOraclyV1(contract, gatherer) {
  await contract.setGatherer(gatherer)
}

async function deployMentoring() {

  const MentoringOraclyV1 = await ethers.deployContract('MentoringOraclyV1')
  await MentoringOraclyV1.waitForDeployment()

  console.log('Mentoring---------------------')
  console.log(MentoringOraclyV1.target)
  console.log('------------------------------')

  return MentoringOraclyV1

}

async function attachMentoring(target) {

  const MentoringOraclyV1Factory = await ethers.getContractFactory('MentoringOraclyV1')
  const MentoringOraclyV1 = await MentoringOraclyV1Factory.attach(target)

  console.log('Mentoring---------------------')
  console.log(MentoringOraclyV1.target)
  console.log('------------------------------')

  return MentoringOraclyV1

}

async function initMentoring(contract, gatherer) {
  await contract.setGatherer(gatherer)
}

async function deployVesting(beneficiary) {

  const VestingOraclyV1 = await ethers.deployContract('VestingOraclyV1', [beneficiary])
  await VestingOraclyV1.waitForDeployment()

  console.log('Vesting-----------------------')
  console.log(VestingOraclyV1.target)
  console.log('------------------------------')

  return VestingOraclyV1

}

async function attachVesting(target) {

  const VestingOraclyV1Factory = await ethers.getContractFactory('VestingOraclyV1')
  const VestingOraclyV1 = await VestingOraclyV1Factory.attach(target)

  console.log('Vesting-----------------------')
  console.log(VestingOraclyV1.target)
  console.log('------------------------------')

  return VestingOraclyV1

}

async function initVesting(contrect, erc20) {

  await contrect.setVestingERC20(erc20)

}

module.exports = {

  deployToken,
  attachToken,

  deployAggregatorProxyMock,
  attachAggregatorProxyMock,

  deployMeta,
  attachMeta,

  deployOraclyV1,
  attachOraclyV1,

  deployStakingOraclyV1,
  attachStakingOraclyV1,
  initStakingOraclyV1,

  deployMentoring,
  attachMentoring,
  initMentoring,

  deployVesting,
  attachVesting,
  initVesting,
}
