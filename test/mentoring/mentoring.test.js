require('../common/init')

const { expect } = require('chai')
const { ethers } = require('hardhat')

const { deployMentoring, initMentoring } = require('../common')
const { deployToken } = require('../common')

const { joinMentor, expelProtege } = require('../common/mentoring')
const { calculateReward, collectCommission, claimReward } = require('../common/mentoring')
const { setGatherer, transferProtege } = require('../common/mentoring')
const { init } = require('../common/mentoring')

const { balanceOf, DEMO_INITIAL_SUPPLY } = require('../common/utils')

require('@openzeppelin/test-helpers/configure')({
  provider: process.env.LDE_URL
})

describe('Mentoring', () => {

  let MentoringOraclyV1

  let DEMO
  let DEMO2

  let owner
  let addr1
  let addr2
  let addr3
  let addr4
  let addrs // eslint-disable-line

  beforeEach(async () => {
    [owner, addr1, addr2, addr3, addr4, ...addrs] = await ethers.getSigners()

    DEMO = await deployToken('DEMO', owner.address)
    DEMO2 = await deployToken('DEMO', owner.address)

    MentoringOraclyV1 = await deployMentoring()
    await initMentoring(MentoringOraclyV1, owner.address)
    init(MentoringOraclyV1)

  })

  describe('MentoringOraclyV1 Contract', () => {

    it('Access Control', async () => {
      await expect(setGatherer(addr1)).to.be.reverted
    })

    it('Join Mentor / Expel Protege', async () => {

      console.log('========================================')
      console.log(ethers)

      const mentor = owner
      const protege0 = { address: ethers.ZeroAddress }
      const protege1 = addr1
      const protege2 = addr2
      const protege3 = addr3
      const protege4 = addr4

      //Errors check
      await expect(expelProtege(mentor, protege0)).to.be.revertedWith('ProtegeAddressCannotBeZero')
      await expect(expelProtege(mentor, protege1)).to.be.revertedWith('CannotRemoveUnmentoredProtege')
      await expect(expelProtege(protege1, protege1)).to.be.revertedWith('CannotRemoveUnmentoredProtege')
      await expect(joinMentor(mentor, mentor)).to.be.revertedWith('CannotJoinToSelf')
      await expect(joinMentor(protege1, protege0)).to.be.revertedWith('MentorAddressCannotBeZero')
      //

      await joinMentor(protege1, mentor)
      await joinMentor(protege2, protege1)
      await joinMentor(protege3, protege2)
      await joinMentor(protege4, mentor)

      //Errors check
      await expect(joinMentor(protege1, protege2)).to.be.revertedWith('CannotRejoinProtege')
      await expect(joinMentor(mentor, protege1)).to.be.revertedWith('MentorCannotBecomeProtege')
      await expect(joinMentor(mentor, protege2)).to.be.revertedWith('MentorCannotBecomeProtege')
      await expect(joinMentor(mentor, protege3)).to.be.revertedWith('MentorCannotBecomeProtege')
      await expect(joinMentor(mentor, protege4)).to.be.revertedWith('MentorCannotBecomeProtege')
      //

      await expelProtege(mentor, protege1)

      //Errors check
      await expect(expelProtege(mentor, mentor)).to.be.revertedWith('CannotRemoveUnmentoredProtege')
      await expect(expelProtege(mentor, protege2)).to.be.revertedWith('CannotRemoveUnmentoredProtege')
      await expect(expelProtege(mentor, protege3)).to.be.revertedWith('CannotRemoveUnmentoredProtege')
      await expect(joinMentor(mentor, protege1)).to.be.revertedWith('MentorCannotBecomeProtege')
      //

      await expelProtege(mentor, protege4)
      await joinMentor(protege4, protege1)

      await expelProtege(protege1, protege4)
      await joinMentor(mentor, protege1)

      //Errors check
      await expect(expelProtege(protege4, protege1)).to.be.revertedWith('CannotRemoveUnmentoredProtege')
      //

    })

    it('Join Collect Claim Transfer', async () => {

      const mentor = owner
      const protege0 = { address: ethers.ZeroAddress }
      const protege1 = addr1
      const protege2 = addr2
      const protege3 = addr3
      const protege4 = addr4

      expect(await calculateReward(protege1, 100)).to.be.equal(0)

      await collectCommission(owner, protege1, DEMO, 1)
      // check that ^ takes not effect because of absent of mentoring structure
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY)
      expect(await balanceOf(DEMO, MentoringOraclyV1)).to.be.equal(0)

      await joinMentor(protege1, mentor)
      await joinMentor(protege2, protege1)
      await joinMentor(protege3, protege2)
      await joinMentor(protege4, protege3)

      // check Error
      await expect(collectCommission(owner, protege0, DEMO, 1)).to.be.revertedWith('CannotCollectFromZeroProtege')
      await expect(collectCommission(owner, protege1, DEMO, 0)).to.be.revertedWith('CannotCollectZeroAmount')
      await expect(collectCommission(protege1, owner, DEMO, 1)).to.be.revertedWith('RejectUnknownGathere')
      //

      await collectCommission(owner, protege4, DEMO, 1)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 1n)
      expect(await balanceOf(DEMO, MentoringOraclyV1)).to.be.equal(1)

      // check Error
      await expect(claimReward(owner, DEMO)).to.be.revertedWith('NothingToWithdraw')
      await expect(claimReward(protege1, DEMO)).to.be.revertedWith('NothingToWithdraw')
      await expect(claimReward(protege2, DEMO)).to.be.revertedWith('NothingToWithdraw')
      //

      await claimReward(protege3, DEMO)
      expect(await balanceOf(DEMO, protege3)).to.be.equal(1)
      expect(await balanceOf(DEMO, MentoringOraclyV1)).to.be.equal(0)

      // check Error
      await expect(claimReward(owner, DEMO)).to.be.revertedWith('NothingToWithdraw')
      await expect(claimReward(protege1, DEMO)).to.be.revertedWith('NothingToWithdraw')
      await expect(claimReward(protege2, DEMO)).to.be.revertedWith('NothingToWithdraw')
      await expect(claimReward(protege3, DEMO)).to.be.revertedWith('NothingToWithdraw')
      //

      await collectCommission(owner, protege4, DEMO, 10)
      expect(await balanceOf(DEMO, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 3n - 1n)
      expect(await balanceOf(DEMO, MentoringOraclyV1)).to.be.equal(3)

      // check Error
      await expect(claimReward(owner, DEMO)).to.be.revertedWith('NothingToWithdraw')
      await expect(claimReward(protege1, DEMO)).to.be.revertedWith('NothingToWithdraw')
      await expect(claimReward(protege2, DEMO)).to.be.revertedWith('NothingToWithdraw')
      //

      await claimReward(protege3, DEMO)

      // check Error
      await expect(claimReward(protege3, DEMO)).to.be.revertedWith('NothingToWithdraw')
      //

      expect(await balanceOf(DEMO, protege2)).to.be.equal(0)
      expect(await balanceOf(DEMO, protege3)).to.be.equal(3 + 1)
      expect(await balanceOf(DEMO, MentoringOraclyV1)).to.be.equal(0)

      await collectCommission(owner, protege3, DEMO2, 99)
      expect(await balanceOf(DEMO2, owner)).to.be.equal(DEMO_INITIAL_SUPPLY - 25n)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(25)

      // check Error
      await expect(claimReward(owner, DEMO2)).to.be.revertedWith('NothingToWithdraw')
      await expect(claimReward(protege4, DEMO2)).to.be.revertedWith('NothingToWithdraw')
      await expect(claimReward(protege1, DEMO2)).to.be.revertedWith('NothingToWithdraw')
      //

      // Transfers
      // check Error
      await expect(transferProtege(protege2, protege4, protege3)).to.be.revertedWith('MentorCannotBecomeProtege')
      //
      // transfer protege3 out of protege2
      await expelProtege(protege3, protege4)
      await transferProtege(protege2, protege4, protege3)

      // still able to claim reward collected by protege3 before transfer
      expect(await balanceOf(DEMO2, protege2)).to.be.equal(0)
      await claimReward(protege2, DEMO2)
      expect(await balanceOf(DEMO2, protege2)).to.be.equal(25)

      expect(await balanceOf(DEMO2, protege1)).to.be.equal(0)
      expect(await balanceOf(DEMO2, protege3)).to.be.equal(0)
      expect(await balanceOf(DEMO2, protege4)).to.be.equal(0)
      expect(await balanceOf(DEMO2, MentoringOraclyV1)).to.be.equal(0)
      expect(await balanceOf(DEMO, MentoringOraclyV1)).to.be.equal(0)

    })


  })

})
