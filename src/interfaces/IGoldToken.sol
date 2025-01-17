// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGoldToken {
    // Events
    event TokensMinted(address indexed user, uint256 ethAmount, uint256 goldTokens);
    event TokensBurned(address indexed user, uint256 goldTokens, uint256 ethAmount);
    event PriceFeedException(string message);
    event BridgeInitiated(address indexed user, uint256 amount, uint64 destinationChainSelector);
    event BridgeCompleted(address indexed user, uint256 amount, uint64 sourceChainSelector);

    // Core functions
    function mint() external payable;
    function burn(uint256 amount) external;
    function bridgeTokens(uint64 destinationChainSelector, address receiver, uint256 amount) external;
    
    // View functions
    function getEthUsdPrice() external view returns (uint256);
    function getXauUsdPrice() external view returns (uint256);
    function calculateGoldTokens(uint256 ethAmount) external view returns (uint256);

    // Admin functions
    function updatePriceFeeds(address _ethUsdPriceFeed, address _xauUsdPriceFeed) external;
    function updateLotteryContract(address _lotteryContract) external;
    function withdrawCommissions() external;
}