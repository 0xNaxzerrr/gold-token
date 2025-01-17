// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract MockVRFCoordinator is VRFCoordinatorV2Interface {
    mapping(uint64 => address) public consumers;
    mapping(uint256 => uint64) public requestToSubscriptionId;
    
    uint64 private nextSubscriptionId = 1;

    function createSubscription() external pure returns (uint64 subId) {
        return 1;
    }

    function getSubscription(uint64 /* subId */) external pure returns (
        uint96 balance,
        uint64 reqCount,
        address owner,
        address[] memory consumers
    ) {
        balance = 0;
        reqCount = 0;
        owner = address(0);
        consumers = new address[](0);
    }

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId) {
        requestId = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, subId)));
        requestToSubscriptionId[requestId] = subId;
        return requestId;
    }

    function fundSubscription(uint64 /* subId */, uint96 /* amount */) external pure {}

    function cancelSubscription(uint64 /* subId */, address /* to */) external pure {}

    function getRequestConfig() external pure returns (
        uint16, 
        uint32, 
        bytes32[] memory
    ) {
        uint16 minimumRequestConfirmations = 3;
        uint32 maxGasLimit = 500000;
        bytes32[] memory keyHashes = new bytes32[](1);
        keyHashes[0] = keccak256("TEST_KEYHASH");
        return (minimumRequestConfirmations, maxGasLimit, keyHashes);
    }

    function addConsumer(uint64 /* subId */, address /* consumer */) external pure {}

    function removeConsumer(uint64 /* subId */, address /* consumer */) external pure {}
}