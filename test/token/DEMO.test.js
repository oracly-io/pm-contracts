require('../common/init')

const { expect } = require('chai')
const { ethers } = require('hardhat')

const { deployToken } = require('../common')
const { DEMO_INITIAL_SUPPLY, address } = require('../common/utils')

require('@openzeppelin/test-helpers/configure')({
  provider: process.env.LDE_URL
})

describe('Token DEMO', () => {

  let DEMO
  let DEMOaddr1
  let DEMOaddr2

  let owner
  let addr1
  let addr2
  let addrs // eslint-disable-line

  beforeEach(async () => {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners()

    DEMO = await deployToken('DEMO', address(owner))

    DEMOaddr1 = DEMO.connect(addr1)
    DEMOaddr2 = DEMO.connect(addr2)

  })

  describe('Smoke', () => {

    it('DEMO has right total supply', async () => {
      const total = await DEMO.totalSupply()
      expect(total).to.equal(DEMO_INITIAL_SUPPLY)
    })

    it('DEMO has right name', async () => {
      const name = await DEMO.name()
      expect(name).to.equal('Oracly Demo')
    })

    it('DEMO has right symbol', async () => {
      const sym = await DEMO.symbol()
      expect(sym).to.equal('DEMO')
    })

    it('DEMO has right decimals', async () => {
      const decimals = await DEMO.decimals()
      expect(decimals).to.equal(18)
    })

    it('Should assign the total supply of tokens to the owner', async () => {
      const balance = await DEMO.balanceOf(address(owner))
      const total = await DEMO.totalSupply()
      expect(total).to.equal(balance)
    })

  })

  describe('Transactions', () => {

    it('Can mint tokens', async () => {

      expect(await DEMO.balanceOf(addr1)).to.equal(0n)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY * 2n)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY * 3n)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY * 4n)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY * 5n)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY * 6n)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY * 7n)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY * 8n)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY * 9n)
      await DEMOaddr1.mint()
      expect(await DEMO.balanceOf(addr1)).to.equal(DEMO_INITIAL_SUPPLY * 10n)

      await expect(DEMOaddr1.mint(addr1)).to.be.revertedWith('MintLimitExceeded')

    })

    it('Can approve spender and transfer ERC20', async () => {

      await DEMO.approve(address(addr1), 50)
      const amount1 = await DEMO.allowance(address(owner), address(addr1))
      expect(amount1).to.equal(50)

      await DEMOaddr1.transferFrom(address(owner), address(addr1), 25)
      const amount2 = await DEMO.allowance(address(owner), address(addr1))
      expect(amount2).to.equal(25)

      await DEMOaddr1.transferFrom(address(owner), address(addr2), 25)
      const amount3 = await DEMO.allowance(address(owner), address(addr1))
      expect(amount3).to.equal(0)

      expect(await DEMO.balanceOf(address(addr1))).to.equal(25)
      expect(await DEMO.balanceOf(address(addr2))).to.equal(25)
      expect(await DEMO.balanceOf(address(owner))).to.equal(DEMO_INITIAL_SUPPLY - (25n + 25n))

      await DEMOaddr1.transfer(address(owner), 25)
      await DEMOaddr2.transfer(address(owner), 25)

      expect(await DEMO.balanceOf(address(owner))).to.equal(DEMO_INITIAL_SUPPLY)

    })

  })

})
