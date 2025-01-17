// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IChainHelper {
    struct ChainConfig {
        address ethUsdFeed;
        address xauUsdFeed;
        address router;
        address link;
        address vrfCoordinator;
        bytes32 keyHash;
        uint64 subscriptionId;
        uint64 chainSelector;
    }

    enum ChainType {
        SepoliaTestnet,
        BNBTestnet,
        Local
    }

    function getChainConfig() external view returns (ChainConfig memory);
    function chainConfigs(ChainType chainType) external view returns (ChainConfig memory);
}