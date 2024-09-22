// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// solhint-disable
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// import { console } from "hardhat/console.sol";

contract MockAggregatorProxy is AggregatorV3Interface {

  function decimals()
    external
    view
    override
    returns (uint8)
  {
    return 8;
  }

  function description()
    external
    view
    override
    returns (string memory)
  {
    return "ALL / USD";
  }

  function version()
    external
    view
    override
    returns (uint256)
  {
    return 1;
  }

  function latestRoundData()
    public
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    roundId = computeRoundid(1, 0);
    answer = 1000;
    startedAt = block.timestamp;
    updatedAt = block.timestamp;
    answeredInRound = roundId;
  }

  function getRoundData(
    uint80 _roundId
  )
    public
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {

    (uint256 timestamp, uint16 phaseId, uint64 aggregatorRoundId) = reparseRoundid(_roundId);

    // in case of phaseid == 1 and even priceid, we add 10 sec to timestamp (need for tests)
    if (phaseId == 1 && (aggregatorRoundId % 2) == 0) {
      timestamp += 10;
    }

    roundId = _roundId;
    answer = 1001;
    startedAt = timestamp;
    updatedAt = timestamp;
    answeredInRound = roundId;
  }

  function reparseRoundid(
    uint256 roundId
  )
    internal
    view
    returns (uint256, uint16, uint64)
  {
    uint16 phaseId = uint16(roundId >> 64);
    uint256 timestamp = (roundId >> 22) - (uint256(phaseId) << 64 >> 22);
    uint64 aggregatorRoundId = uint64(uint8(roundId));

    return (timestamp, phaseId, aggregatorRoundId);
  }

  function computeRoundid(
    uint16 phaseId,
    uint64 aggregatorRoundId
  )
    internal
    pure
    returns (uint80)
  {
    uint80 roundId = uint80(uint256(phaseId) << 64 | aggregatorRoundId);
    return roundId;
  }

}
