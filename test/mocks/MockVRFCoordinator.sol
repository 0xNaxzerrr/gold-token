// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title MockVRFCoordinator
 * @notice Mock VRF Coordinator for testing
 */
contract MockVRFCoordinator is VRFCoordinatorV2Interface {
    uint256 private nextRequestId = 1;
    mapping(uint256 => address) private consumerAddresses;

    struct RequestConfig {
        bytes32 keyHash;
        uint64 subId;
        uint32 callbackGasLimit;
        uint16 requestConfirmations;
        uint32 numWords;
    }

    mapping(uint256 => RequestConfig) private requests;

    /**
     * @notice Actually fulfill random words (internal function)
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) public {
        VRFConsumerBaseV2(consumerAddresses[requestId]).rawFulfillRandomWords(
            requestId,
            randomWords
        );
    }

    function createSubscription() external override returns (uint64 subId) {
        return 1;
    }

    function getSubscription(
        uint64 subId
    )
        external
        view
        override
        returns (
            uint96 balance,
            uint64 reqCount,
            address owner,
            address[] memory consumersList
        )
    {
        return (0, 0, address(0), new address[](0));
    }

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external override returns (uint256 requestId) {
        requestId = nextRequestId++;
        consumerAddresses[requestId] = msg.sender;
        requests[requestId] = RequestConfig({
            keyHash: keyHash,
            subId: subId,
            callbackGasLimit: callbackGasLimit,
            requestConfirmations: requestConfirmations,
            numWords: numWords
        });
        return requestId;
    }

    // Helper function for tests
    function fulfillRequest(uint256 requestId, uint256 randomness) external {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomness;
        fulfillRandomWords(requestId, randomWords);
    }

    function getRequestConfig()
        external
        pure
        returns (uint16, uint32, bytes32[] memory)
    {
        bytes32[] memory keysHash = new bytes32[](0);
        return (3, 1000000, keysHash);
    }

    // Not implemented functions
    function cancelSubscription(uint64 subId, address to) external override {}
    function addConsumer(uint64 subId, address consumer) external override {}
    function removeConsumer(uint64 subId, address consumer) external override {}
    function requestSubscriptionOwnerTransfer(
        uint64 subId,
        address newOwner
    ) external override {}
    function acceptSubscriptionOwnerTransfer(uint64 subId) external override {}
    function pendingRequestExists(
        uint64 subId
    ) external view override returns (bool) {}
    function fundSubscription(uint64 subId, uint256 amount) external {}
}
