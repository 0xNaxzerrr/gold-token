// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

interface IGoldLottery {
    // Events
    event LotteryStarted(uint256 indexed roundId, uint256 startTime);
    event LotteryEnded(uint256 indexed roundId, address winner, uint256 prize);
    event FundsReceived(address indexed from, uint256 amount);
    event PrizeWithdrawn(address indexed winner, uint256 amount);

    // Structs
    struct Round {
        uint256 startTime;
        uint256 endTime;
        uint256 prizePool;
        address winner;
        bool isComplete;
        bool prizeClaimed;
    }

    // Core functions
    function receiveFunds() external payable;
    function startNewRound() external;
    function claimPrize(uint256 roundId) external;
    
    // View functions
    function getCurrentRound() external view returns (uint256);
    function getRoundInfo(uint256 roundId) external view returns (Round memory);
    function checkUpkeep(bytes calldata checkData) external view returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
    
    // Admin functions
    function setDrawInterval(uint256 _interval) external;
    function setMinimumPrizePool(uint256 _minimum) external;
    function emergencyWithdraw() external;
}