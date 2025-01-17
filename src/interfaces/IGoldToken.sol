// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGoldToken is IERC20 {
    // Events
    event TokensMinted(address indexed user, uint256 ethAmount, uint256 goldTokens);
    event TokensBurned(address indexed user, uint256 goldTokens, uint256 ethAmount);
    event PriceFeedException(string message);
    event BridgeInitiated(address indexed user, uint256 amount, uint64 destinationChainSelector);
    event BridgeCompleted(address indexed user, uint256 amount, uint64 sourceChainSelector);

    // Core functions
    function mint() external payable;
    function burn(uint256 amount) external;
    function bridgeMint(address user, uint256 amount) external;
    function bridgeBurn(address user, uint256 amount) external;
    
    // View functions
    function getEthUsdPrice() external view returns (uint256);
    function getXauUsdPrice() external view returns (uint256);
    function calculateGoldTokens(uint256 ethAmount) external view returns (uint256);

    // Admin functions
    function updatePriceFeeds(address _ethUsdPriceFeed, address _xauUsdPriceFeed) external;
    function updateLotteryContract(address _lotteryContract) external;
    function updateBridgeContract(address _bridgeContract) external;
    function withdrawCommissions() external;
}