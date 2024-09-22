const { use, expect, Assertion } = require('chai')
const { ethers } = require('ethers')

use((chai, utils) => {
  // Function to convert values to a comparable format
  const toComparable = (value) => {
    if (typeof value === 'bigint') {
      return value.toString()
    } else if (typeof value === 'number') {
      return value.toString()
    } else {
      return value
    }
  }

  // Override the assertEql method
  Assertion.overwriteMethod('eql', function (_super) {
    return function (expected, msg) {
      if (msg) utils.flag(this, 'message', msg)

      this._obj = toComparable(this._obj)
      expected = toComparable(expected)

      // Use the original equal method for comparison
      _super.call(this, expected)
    }
  })

  // Alias eql to equal
  Assertion.overwriteMethod('equal', function (_super) {
    return function (expected, msg) {
      return this.eql(expected, msg)
    }
  })
})
