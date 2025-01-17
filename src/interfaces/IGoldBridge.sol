// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGoldBridge {
    // Events
    event TokensBridged(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address sender,
        address receiver,
        uint256 amount,
        address feeToken,
        uint256 fees
    );
    
    event MessageReceived(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        address receiver,
        uint256 amount
    );
    
    event BridgingPausedEvent(address admin);
    event BridgingResumedEvent(address admin);

    // Errors
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientFees();
    error InvalidDestination();
    error BridgingPaused();
    error NotAdmin();
    error InvalidSourceChain();

    // Core functions
    function bridgeTokens(
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    ) external payable;
    
    function _ccipReceive(bytes memory data) external;
    
    // View functions
    function getSupportedChains() external view returns (uint64[] memory);
    function getFeeEstimate(
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    ) external view returns (uint256);
    
    // Admin functions
    function pauseBridging() external;
    function resumeBridging() external;
    function addSupportedChain(uint64 chainSelector) external;
    function removeSupportedChain(uint64 chainSelector) external;
    function withdrawStuckTokens(address token, address recipient) external;

    function initialize(address _token) external;
}