require('../common/init')

const { expect } = require('chai')
const { ethers } = require('hardhat')

const { deployToken } = require('../common')
const { address, ORCY_TOTAL_SUPPLY } = require('../common/utils')

require('@openzeppelin/test-helpers/configure')({
  provider: process.env.LDE_URL
})

describe('Token ORCY', () => {

  let ORCY
  let ORCYaddr1
  let ORCYaddr2

  let owner
  let addr1
  let addr2
  let addrs // eslint-disable-line

  beforeEach(async () => {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners()

    ORCY = await deployToken(
      'ORCY',
      address(owner),
      [
        // growthfund
        address(owner),
        // teamfund
        address(owner),
        // seedfund
        address(owner),
        // buy4stake
        address(owner),

        // growthfund_vesting
        address(owner),
        // teamfund_vesting
        address(owner),
        // seedfund_vesting
        address(owner),
      ]
    )

    ORCYaddr1 = ORCY.connect(addr1)
    ORCYaddr2 = ORCY.connect(addr2)

  })

  describe('Smoke', () => {

    it('ORCY has right total supply', async () => {
      const total = await ORCY.totalSupply()
      expect(total).to.equal(ORCY_TOTAL_SUPPLY)
    })

    it('ORCY has right name', async () => {
      const name = await ORCY.name()
      expect(name).to.equal('Oracly Glyph')
    })

    it('ORCY has right symbol', async () => {
      const sym = await ORCY.symbol()
      expect(sym).to.equal('ORCY')
    })

    it('ORCY has right decimals', async () => {
      const decimals = await ORCY.decimals()
      expect(decimals).to.equal(18)
    })

    it('Should assign the total supply of tokens to the owner', async () => {
      const balance = await ORCY.balanceOf(address(owner))
      const total = await ORCY.totalSupply()
      expect(total).to.equal(balance)
    })

  })

  describe('Transactions', () => {

    it('Can approve spender and transfer ERC20', async () => {

      await ORCY.approve(address(addr1), 50)
      const amount1 = await ORCY.allowance(address(owner), address(addr1))
      expect(amount1).to.equal(50)

      await ORCYaddr1.transferFrom(address(owner), address(addr1), 25)
      const amount2 = await ORCY.allowance(address(owner), address(addr1))
      expect(amount2).to.equal(25)

      await ORCYaddr1.transferFrom(address(owner), address(addr2), 25)
      const amount3 = await ORCY.allowance(address(owner), address(addr1))
      expect(amount3).to.equal(0)

      expect(await ORCY.balanceOf(address(addr1))).to.equal(25)
      expect(await ORCY.balanceOf(address(addr2))).to.equal(25)
      expect(await ORCY.balanceOf(address(owner))).to.equal(ORCY_TOTAL_SUPPLY - 50n)

      await ORCYaddr1.transfer(address(owner), 25)
      await ORCYaddr2.transfer(address(owner), 25)

      expect(await ORCY.balanceOf(address(owner))).to.equal(ORCY_TOTAL_SUPPLY)

    })

  })

})
