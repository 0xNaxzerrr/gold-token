// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockPriceFeed is AggregatorV3Interface {
    int256 private price;
    uint8 private decimals_ = 8;
    uint80 private roundId = 1;
    uint256 private timestamp = block.timestamp;
    uint256 private startedAt = block.timestamp;
    
    function setPrice(int256 _price) external {
        price = _price;
        roundId++;
        timestamp = block.timestamp;
        startedAt = block.timestamp;
    }
    
    function latestRoundData() external view override returns (
        uint80 roundId_,
        int256 answer,
        uint256 startedAt_,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (
            roundId,
            price,
            startedAt,
            timestamp,
            roundId
        );
    }
    
    function decimals() external view override returns (uint8) {
        return decimals_;
    }
    
    function description() external pure override returns (string memory) {
        return "Mock Price Feed";
    }
    
    function version() external pure override returns (uint256) {
        return 1;
    }
    
    function getRoundData(uint80 _roundId) external view override returns (
        uint80 roundId_,
        int256 answer,
        uint256 startedAt_,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        require(_roundId <= roundId, "No data present");
        return (
            _roundId,
            price,
            startedAt,
            timestamp,
            _roundId
        );
    }
}