// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/**
 * @title ChainHelper
 * @author 0xNaxzerrr
 * @notice Helper contract for chain detection and configuration
 */
contract ChainHelper is Script {
    enum Chain {
        Mainnet,
        BSC,
        Local
    }

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

    mapping(Chain => ChainConfig) public chainConfigs;

    constructor() {
        // Ethereum Mainnet Configuration
        chainConfigs[Chain.Mainnet] = ChainConfig({
            ethUsdFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            xauUsdFeed: 0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6,
            router: 0xE561d5E02207fb5eB32cca20a699E0d8919a1476,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            vrfCoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            keyHash: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef,
            subscriptionId: 0, // To be filled
            chainSelector: 5009297550715157269 // Ethereum mainnet selector
        });

        // BSC Configuration
        chainConfigs[Chain.BSC] = ChainConfig({
            ethUsdFeed: address(0), // Not used on BSC
            xauUsdFeed: address(0), // Not used on BSC
            router: 0x536d7E53D0aDeB1F20E7c81fea45d02eC9dBD698,
            link: 0x404460C6A5EdE2D891e8297795264fDe62ADBB75,
            vrfCoordinator: 0x721DFbc5Cfe53d32ab00A9bdFa605d3b8E1f3f42,
            keyHash: 0x84c5c015f9974ea91be7ee57676d2891e64f931068efaaf1e14c6dbb9ee54618,
            subscriptionId: 0, // To be filled
            chainSelector: 13264668187771770619 // BSC mainnet selector
        });

        // Local Configuration (for testing)
        chainConfigs[Chain.Local] = ChainConfig({
            ethUsdFeed: address(1),
            xauUsdFeed: address(2),
            router: address(3),
            link: address(4),
            vrfCoordinator: address(5),
            keyHash: 0x0000000000000000000000000000000000000000000000000000000000000000,
            subscriptionId: 0,
            chainSelector: 0
        });
    }

    /**
     * @notice Detects the current chain based on known characteristics
     * @return chain The detected chain enum
     */
    function detectChain() public view returns (Chain) {
        // Get chainId
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        // Determine chain based on chainId
        if (chainId == 1) {
            return Chain.Mainnet;
        } else if (chainId == 56) {
            return Chain.BSC;
        } else {
            return Chain.Local;
        }
    }

    /**
     * @notice Gets the configuration for the current chain
     * @return config The chain configuration
     */
    function getChainConfig() public view returns (ChainConfig memory) {
        Chain currentChain = detectChain();
        return chainConfigs[currentChain];
    }

    /**
     * @notice Updates subscription ID for VRF on current chain
     * @param subscriptionId New subscription ID
     */
    function setSubscriptionId(uint64 subscriptionId) public {
        Chain currentChain = detectChain();
        chainConfigs[currentChain].subscriptionId = subscriptionId;
    }
}
