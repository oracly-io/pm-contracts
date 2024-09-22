require('dotenv').config()

require('@nomicfoundation/hardhat-ethers')
require('@nomicfoundation/hardhat-verify')

require('solidity-docgen')

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  docgen: {
    outputDir: 'docs',
    pages: 'files',
    exclude: [
      'interfaces/IRewardCalculator.sol',
      'interfaces/ICommissionCollector.sol',
      'interfaces/IRewardCollector.sol',
      'staking/AutoStaking.sol',
      'token/TEST.sol',
      'predicting/mocks/MockAggregatorProxy.sol',
    ]
  },
  solidity: {
    version: '0.8.23',
    settings: {
      evmVersion: 'london',
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
}
