require('../common/init')

const { expect } = require('chai')
const { ethers } = require('hardhat')

const { deployStakingOraclyV1, initStakingOraclyV1 } = require('../common')
const { deployToken, deployVesting } = require('../common')

const { approve, send, balanceOf } = require('../common/utils')
const { address, getLatestBlock, UNIX_DAY } = require('../common/utils')
const { forwardTime } = require('../common/utils')

require('@openzeppelin/test-helpers/configure')({
  provider: process.env.LDE_URL
})

describe('Vesting', () => {

  const ORCY_DECIMALS = 18n
  const ORCY_DEC = 10n**ORCY_DECIMALS

  const ACCEPTABLE_DIVIATION = 10_000_000n // 1/10M = 0.00000001%
  const orcy = (value) => {
    value = value * ORCY_DEC
    if (typeof value !== 'bigint') return [value, 0]
    return [value, value / 10_000_000n]
  }

  let VestingOraclyV1_growth
  let VestingOraclyV1_team
  let VestingOraclyV1_seed

  let ORCY
  let ORCY2

  let owner
  let GROWTH_WALLET
  let TEAM_WALLET
  let SEED_WALLET
  let SEED_WALLET_2
  let BUY4STAKE_WALLET

  let addrs

  beforeEach(async () => {
    [owner, GROWTH_WALLET, TEAM_WALLET, SEED_WALLET, SEED_WALLET_2, BUY4STAKE_WALLET, ...addrs] = await ethers.getSigners()

    VestingOraclyV1_growth = await deployVesting(GROWTH_WALLET)
    VestingOraclyV1_team = await deployVesting(TEAM_WALLET)
    VestingOraclyV1_seed = await deployVesting(SEED_WALLET)

    ORCY = await deployToken(
      'ORCY',
      address(owner),
      [
        address(GROWTH_WALLET),
        address(TEAM_WALLET),
        address(SEED_WALLET),
        address(BUY4STAKE_WALLET),

        address(VestingOraclyV1_growth),
        address(VestingOraclyV1_team),
        address(VestingOraclyV1_seed),
      ]
    )

    ORCY2 = await deployToken(
      'ORCY',
      address(owner),
      [
        address(GROWTH_WALLET),
        address(TEAM_WALLET),
        address(SEED_WALLET),
        address(BUY4STAKE_WALLET),

        address(VestingOraclyV1_growth),
        address(VestingOraclyV1_team),
        address(VestingOraclyV1_seed),
      ]
    )

  })

  describe('VestingOraclyV1 Contract', () => {

    it('Check Initial Distribution ', async () => {

      expect(await balanceOf(ORCY, owner)).to.be.equal(0)

      expect(await balanceOf(ORCY, GROWTH_WALLET)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY, TEAM_WALLET)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))
      expect(await balanceOf(ORCY, BUY4STAKE_WALLET)).to.be.closeTo(...orcy(5_000_000n))

      expect(await balanceOf(ORCY, VestingOraclyV1_growth)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY, VestingOraclyV1_team)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY, VestingOraclyV1_seed)).to.be.closeTo(...orcy(500_000n))

      expect(await balanceOf(ORCY2, owner)).to.be.equal(0)

      expect(await balanceOf(ORCY2, GROWTH_WALLET)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY2, TEAM_WALLET)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))
      expect(await balanceOf(ORCY2, BUY4STAKE_WALLET)).to.be.closeTo(...orcy(5_000_000n))

      expect(await balanceOf(ORCY2, VestingOraclyV1_growth)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY2, VestingOraclyV1_team)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY2, VestingOraclyV1_seed)).to.be.closeTo(...orcy(500_000n))

    })


    it('Check GROWTH_WALLET Liner Vesting 1_000_000 over ~20month after 6 month cliff', async () => {

      const block = await getLatestBlock()
      const BLOCK_TIME_INCRIMENT = 4
      const deploy = block.timestamp - BLOCK_TIME_INCRIMENT

      expect(await VestingOraclyV1_growth.owner()).to.be.equal(address(GROWTH_WALLET))

      expect(await VestingOraclyV1_growth.start()).to.be.equal(deploy + UNIX_DAY*30*6)
      expect(await VestingOraclyV1_growth.duration()).to.be.equal(UNIX_DAY*30*20)

      expect(await VestingOraclyV1_growth.released()).to.be.equal(0)
      expect(await VestingOraclyV1_growth.vestedAmount(deploy)).to.be.equal(0)
      expect(await VestingOraclyV1_growth.vestedAmount(deploy + UNIX_DAY*30*6)).to.be.equal(0)

      expect(await VestingOraclyV1_growth['released(address)'](address(ORCY))).to.be.equal(0)
      expect(await VestingOraclyV1_growth['vestedAmount(address, uint64)'](address(ORCY), deploy)).to.be.equal(0)
      expect(await VestingOraclyV1_growth['vestedAmount(address, uint64)'](address(ORCY), deploy + UNIX_DAY*30*6)).to.be.equal(0)
      expect(await VestingOraclyV1_growth['vestedAmount(address, uint64)'](address(ORCY), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20)).to.be.closeTo(...orcy(1_000_000n))
      expect(await VestingOraclyV1_growth['vestedAmount(address, uint64)'](address(ORCY), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20 - UNIX_DAY*30*10)).to.be.closeTo(...orcy(500_000n))

      expect(await VestingOraclyV1_growth['released(address)'](address(ORCY2))).to.be.equal(0)
      expect(await VestingOraclyV1_growth['vestedAmount(address, uint64)'](address(ORCY2), deploy)).to.be.equal(0)
      expect(await VestingOraclyV1_growth['vestedAmount(address, uint64)'](address(ORCY2), deploy + UNIX_DAY*30*6)).to.be.equal(0)
      expect(await VestingOraclyV1_growth['vestedAmount(address, uint64)'](address(ORCY2), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20)).to.be.closeTo(...orcy(1_000_000n))
      expect(await VestingOraclyV1_growth['vestedAmount(address, uint64)'](address(ORCY2), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20 - UNIX_DAY*30*10)).to.be.closeTo(...orcy(500_000n))

      await expect(owner.sendTransaction({ to: address(VestingOraclyV1_growth), value: 1 })).to.be.revertedWith('NativeTokenReceiveIsNOOP')
      await expect(VestingOraclyV1_growth.release()).to.be.revertedWith('NativeTokenReleaseIsNOOP')

      await expect(VestingOraclyV1_growth['release(address)'](address(0))).to.be.reverted

      await expect(VestingOraclyV1_growth['release(address)'](address(ORCY2))).to.not.be.reverted
      await expect(VestingOraclyV1_growth['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, GROWTH_WALLET)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY2, GROWTH_WALLET)).to.be.closeTo(...orcy(1_000_000n))

      forwardTime(UNIX_DAY*30*6 - BLOCK_TIME_INCRIMENT*2) // <-- 6 month and cliff

      // await expect(VestingOraclyV1_growth['release(address)'](address(ORCY2))).to.be.revertedWith('UnreleasableERC20Specified')
      await expect(VestingOraclyV1_growth['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, GROWTH_WALLET)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY2, GROWTH_WALLET)).to.be.closeTo(...orcy(1_000_000n))

      forwardTime(UNIX_DAY*30) // <-- 1th month pass

      // await expect(VestingOraclyV1_growth['release(address)'](address(ORCY2))).to.be.revertedWith('UnreleasableERC20Specified')
      await expect(VestingOraclyV1_growth['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, GROWTH_WALLET)).to.be.closeTo(...orcy(1_050_000n))
      expect(await balanceOf(ORCY2, GROWTH_WALLET)).to.be.closeTo(...orcy(1_000_000n))

      forwardTime(UNIX_DAY*30 - 1) // <-- 2th month pass

      // await expect(VestingOraclyV1_growth['release(address)'](address(ORCY2))).to.be.revertedWith('UnreleasableERC20Specified')
      await expect(VestingOraclyV1_growth['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, GROWTH_WALLET)).to.be.closeTo(...orcy(1_100_000n))
      expect(await balanceOf(ORCY2, GROWTH_WALLET)).to.be.closeTo(...orcy(1_000_000n))

      forwardTime(UNIX_DAY*30*11 - 1) // <-- 13th month pass

      await expect(VestingOraclyV1_growth['release(address)'](address(ORCY2))).to.not.be.reverted
      // await expect(VestingOraclyV1_growth['release(address)'](address(ORCY))).to.be.revertedWith('UnreleasableERC20Specified')

      expect(await balanceOf(ORCY, GROWTH_WALLET)).to.be.closeTo(...orcy(1_100_000n))
      expect(await balanceOf(ORCY2, GROWTH_WALLET)).to.be.closeTo(...orcy(1_650_000n))

      forwardTime(UNIX_DAY*30*7) // <-- 20th month pass

      await expect(VestingOraclyV1_growth['release(address)'](address(ORCY2))).to.not.be.reverted
      // await expect(VestingOraclyV1_growth['release(address)'](address(ORCY))).to.be.revertedWith('UnreleasableERC20Specified')

      expect(await balanceOf(ORCY, GROWTH_WALLET)).to.be.closeTo(...orcy(1_100_000n))
      expect(await balanceOf(ORCY2, GROWTH_WALLET)).to.be.closeTo(...orcy(2_000_000n))

      forwardTime(UNIX_DAY*30) // <-- 20th month + 1 month pass

      // await expect(VestingOraclyV1_growth['release(address)'](address(ORCY2))).to.be.revertedWith('UnreleasableERC20Specified')
      await expect(VestingOraclyV1_growth['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, GROWTH_WALLET)).to.be.closeTo(...orcy(2_000_000n))
      expect(await balanceOf(ORCY2, GROWTH_WALLET)).to.be.closeTo(...orcy(2_000_000n))

    })

    it('Check TEAM_WALLET Liner Vesting 1_000_000 over ~20month after 6 month cliff', async () => {

      const block = await getLatestBlock()
      const BLOCK_TIME_INCRIMENT = 4
      const deploy = block.timestamp - (BLOCK_TIME_INCRIMENT - 1)

      expect(await VestingOraclyV1_team.owner()).to.be.equal(address(TEAM_WALLET))

      expect(await VestingOraclyV1_team.start()).to.be.equal(deploy + UNIX_DAY*30*6)
      expect(await VestingOraclyV1_team.duration()).to.be.equal(UNIX_DAY*30*20)

      expect(await VestingOraclyV1_team.released()).to.be.equal(0)
      expect(await VestingOraclyV1_team.vestedAmount(deploy)).to.be.equal(0)
      expect(await VestingOraclyV1_team.vestedAmount(deploy + UNIX_DAY*30*6)).to.be.equal(0)

      expect(await VestingOraclyV1_team['released(address)'](address(ORCY))).to.be.equal(0)
      expect(await VestingOraclyV1_team['vestedAmount(address, uint64)'](address(ORCY), deploy)).to.be.equal(0)
      expect(await VestingOraclyV1_team['vestedAmount(address, uint64)'](address(ORCY), deploy + UNIX_DAY*30*6)).to.be.equal(0)
      expect(await VestingOraclyV1_team['vestedAmount(address, uint64)'](address(ORCY), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20)).to.be.closeTo(...orcy(1_000_000n))
      expect(await VestingOraclyV1_team['vestedAmount(address, uint64)'](address(ORCY), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20 - UNIX_DAY*30*10)).to.be.closeTo(...orcy(500_000n))

      expect(await VestingOraclyV1_team['released(address)'](address(ORCY2))).to.be.equal(0)
      expect(await VestingOraclyV1_team['vestedAmount(address, uint64)'](address(ORCY2), deploy)).to.be.equal(0)
      expect(await VestingOraclyV1_team['vestedAmount(address, uint64)'](address(ORCY2), deploy + UNIX_DAY*30*6)).to.be.equal(0)
      expect(await VestingOraclyV1_team['vestedAmount(address, uint64)'](address(ORCY2), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20)).to.be.closeTo(...orcy(1_000_000n))
      expect(await VestingOraclyV1_team['vestedAmount(address, uint64)'](address(ORCY2), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20 - UNIX_DAY*30*10)).to.be.closeTo(...orcy(500_000n))

      await expect(owner.sendTransaction({ to: address(VestingOraclyV1_team), value: 1 })).to.be.revertedWith('NativeTokenReceiveIsNOOP')
      await expect(VestingOraclyV1_team.release()).to.be.revertedWith('NativeTokenReleaseIsNOOP')

      await expect(VestingOraclyV1_team['release(address)'](address(0))).to.be.reverted

      await expect(VestingOraclyV1_team['release(address)'](address(ORCY2))).to.not.be.reverted
      await expect(VestingOraclyV1_team['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, TEAM_WALLET)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY2, TEAM_WALLET)).to.be.closeTo(...orcy(1_000_000n))

      forwardTime(UNIX_DAY*30*6 - BLOCK_TIME_INCRIMENT*2) // <-- 6 month and cliff

      await expect(VestingOraclyV1_team['release(address)'](address(ORCY2))).to.not.be.reverted
      await expect(VestingOraclyV1_team['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, TEAM_WALLET)).to.be.closeTo(...orcy(1_000_000n))
      expect(await balanceOf(ORCY2, TEAM_WALLET)).to.be.closeTo(...orcy(1_000_000n))

      forwardTime(UNIX_DAY*30) // <-- 1th month pass

      await expect(VestingOraclyV1_team['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, TEAM_WALLET)).to.be.closeTo(...orcy(1_050_000n))
      expect(await balanceOf(ORCY2, TEAM_WALLET)).to.be.closeTo(...orcy(1_000_000n))

      forwardTime(UNIX_DAY*30 - 1) // <-- 2th month pass

      await expect(VestingOraclyV1_team['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, TEAM_WALLET)).to.be.closeTo(...orcy(1_100_000n))
      expect(await balanceOf(ORCY2, TEAM_WALLET)).to.be.closeTo(...orcy(1_000_000n))

      forwardTime(UNIX_DAY*30*11 - 1) // <-- 13th month pass

      await expect(VestingOraclyV1_team['release(address)'](address(ORCY2))).to.not.be.reverted

      expect(await balanceOf(ORCY, TEAM_WALLET)).to.be.closeTo(...orcy(1_100_000n))
      expect(await balanceOf(ORCY2, TEAM_WALLET)).to.be.closeTo(...orcy(1_650_000n))

      forwardTime(UNIX_DAY*30*7) // <-- 20th month pass

      await expect(VestingOraclyV1_team['release(address)'](address(ORCY2))).to.not.be.reverted

      expect(await balanceOf(ORCY, TEAM_WALLET)).to.be.closeTo(...orcy(1_100_000n))
      expect(await balanceOf(ORCY2, TEAM_WALLET)).to.be.closeTo(...orcy(2_000_000n))

      forwardTime(UNIX_DAY*30) // <-- 20th month + 1 month pass

      await expect(VestingOraclyV1_team['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, TEAM_WALLET)).to.be.closeTo(...orcy(2_000_000n))
      expect(await balanceOf(ORCY2, TEAM_WALLET)).to.be.closeTo(...orcy(2_000_000n))

    })

    it('Check SEED_WALLET Liner Vesting 1_000_000 over ~20month after 6 month cliff', async () => {

      const block = await getLatestBlock()
      const BLOCK_TIME_INCRIMENT = 4
      const deploy = block.timestamp - (BLOCK_TIME_INCRIMENT - 2)

      expect(await VestingOraclyV1_seed.owner()).to.be.equal(address(SEED_WALLET))

      expect(await VestingOraclyV1_seed.start()).to.be.equal(deploy + UNIX_DAY*30*6)
      expect(await VestingOraclyV1_seed.duration()).to.be.equal(UNIX_DAY*30*20)

      expect(await VestingOraclyV1_seed.released()).to.be.equal(0)
      expect(await VestingOraclyV1_seed.vestedAmount(deploy)).to.be.equal(0)
      expect(await VestingOraclyV1_seed.vestedAmount(deploy + UNIX_DAY*30*6)).to.be.equal(0)

      expect(await VestingOraclyV1_seed['released(address)'](address(ORCY))).to.be.equal(0)
      expect(await VestingOraclyV1_seed['vestedAmount(address, uint64)'](address(ORCY), deploy)).to.be.equal(0)
      expect(await VestingOraclyV1_seed['vestedAmount(address, uint64)'](address(ORCY), deploy + UNIX_DAY*30*6)).to.be.equal(0)
      expect(await VestingOraclyV1_seed['vestedAmount(address, uint64)'](address(ORCY), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20)).to.be.closeTo(...orcy(500_000n))
      expect(await VestingOraclyV1_seed['vestedAmount(address, uint64)'](address(ORCY), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20 - UNIX_DAY*30*10)).to.be.closeTo(...orcy(250_000n))

      expect(await VestingOraclyV1_seed['released(address)'](address(ORCY2))).to.be.equal(0)
      expect(await VestingOraclyV1_seed['vestedAmount(address, uint64)'](address(ORCY2), deploy)).to.be.equal(0)
      expect(await VestingOraclyV1_seed['vestedAmount(address, uint64)'](address(ORCY2), deploy + UNIX_DAY*30*6)).to.be.equal(0)
      expect(await VestingOraclyV1_seed['vestedAmount(address, uint64)'](address(ORCY2), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20)).to.be.closeTo(...orcy(500_000n))
      expect(await VestingOraclyV1_seed['vestedAmount(address, uint64)'](address(ORCY2), deploy + UNIX_DAY*30*6 + UNIX_DAY*30*20 - UNIX_DAY*30*10)).to.be.closeTo(...orcy(250_000n))

      await expect(owner.sendTransaction({ to: address(VestingOraclyV1_seed), value: 1 })).to.be.revertedWith('NativeTokenReceiveIsNOOP')
      await expect(VestingOraclyV1_seed.release()).to.be.revertedWith('NativeTokenReleaseIsNOOP')

      await expect(VestingOraclyV1_seed['release(address)'](address(0))).to.be.reverted

      await expect(VestingOraclyV1_seed['release(address)'](address(ORCY2))).to.not.be.reverted
      await expect(VestingOraclyV1_seed['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))

      forwardTime(UNIX_DAY*30*6 - BLOCK_TIME_INCRIMENT*2) // <-- 6 month and cliff

      await expect(VestingOraclyV1_seed['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))

      forwardTime(UNIX_DAY*30 + 2) // <-- 1th month pass

      await expect(VestingOraclyV1_seed['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, SEED_WALLET)).to.be.closeTo(...orcy(525_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))

      await expect(VestingOraclyV1_seed.transferOwnership(address(SEED_WALLET_2))).to.be.reverted

      const oraclyv1_vesting_seed = VestingOraclyV1_seed.connect(SEED_WALLET)
      await expect(oraclyv1_vesting_seed.transferOwnership(address(SEED_WALLET_2))).to.not.be.reverted

      forwardTime(UNIX_DAY*30 - 2) // <-- 2th month pass

      expect(await balanceOf(ORCY, SEED_WALLET_2)).to.be.equal(0)

      await expect(VestingOraclyV1_seed['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, SEED_WALLET_2)).to.be.closeTo(...orcy(25_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET_2)).to.be.equal(0)

      expect(await balanceOf(ORCY, SEED_WALLET)).to.be.closeTo(...orcy(525_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))

      forwardTime(UNIX_DAY*30*11 - 1) // <-- 13th month pass

      await expect(VestingOraclyV1_seed['release(address)'](address(ORCY2))).to.not.be.reverted

      expect(await balanceOf(ORCY, SEED_WALLET_2)).to.be.closeTo(...orcy(25_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET_2)).to.be.closeTo(...orcy(325_000n))

      expect(await balanceOf(ORCY, SEED_WALLET)).to.be.closeTo(...orcy(525_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))

      forwardTime(UNIX_DAY*30*7) // <-- 20th month pass

      await expect(VestingOraclyV1_seed['release(address)'](address(ORCY2))).to.not.be.reverted

      expect(await balanceOf(ORCY, SEED_WALLET_2)).to.be.closeTo(...orcy(25_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET_2)).to.be.closeTo(...orcy(500_000n))

      expect(await balanceOf(ORCY, SEED_WALLET)).to.be.closeTo(...orcy(525_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))

      forwardTime(UNIX_DAY*30) // <-- 20th month + 1 month pass

      await expect(VestingOraclyV1_seed['release(address)'](address(ORCY))).to.not.be.reverted

      expect(await balanceOf(ORCY, SEED_WALLET_2)).to.be.closeTo(...orcy(475_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET_2)).to.be.closeTo(...orcy(500_000n))

      expect(await balanceOf(ORCY, SEED_WALLET)).to.be.closeTo(...orcy(525_000n))
      expect(await balanceOf(ORCY2, SEED_WALLET)).to.be.closeTo(...orcy(500_000n))

    })
  })

})

