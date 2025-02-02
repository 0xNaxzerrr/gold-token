// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

/**
 * @title ChainHelper
 * @author 0xNaxzerrr
 * @notice Helper contract for chain detection and configuration
 */
contract ChainHelper is Script {
    enum ChainType {
        SepoliaTestnet,
        BNBTestnet,
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

    mapping(ChainType => ChainConfig) public chainConfigs;

    constructor() {
        // Sepolia Testnet Configuration
        chainConfigs[ChainType.SepoliaTestnet] = ChainConfig({
            ethUsdFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH/USD Sepolia
            xauUsdFeed: 0x7b219F57a8e9C7303204Af681e9fA69d17ef626f, // XAU/USD Sepolia
            router: 0xD0daae2231E9CB96b94C8512223533293C3693Bf, // CCIP Router Sepolia
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // LINK Token Sepolia
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, // VRF Coordinator Sepolia
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // To be filled
            chainSelector: 16015286601757825753 // Sepolia chain selector
        });

        // BNB Testnet Configuration
        chainConfigs[ChainType.BNBTestnet] = ChainConfig({
            ethUsdFeed: 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526, // BNB/USD BSC Testnet
            xauUsdFeed: 0x4962E69104ccb255133811b53a78D54385Ee60D0, // Gold/USD BSC Testnet
            router: 0x9527E2D01a3064eF6B50c1DA1C0cc523803BcDf3, // CCIP Router BSC Testnet
            link: 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06, // LINK Token BSC Testnet
            vrfCoordinator: 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f, // VRF Coordinator BSC Testnet
            keyHash: 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314,
            subscriptionId: 0, // To be filled
            chainSelector: 13264668187771770619 // BSC Testnet chain selector
        });

        // Local Configuration (for testing)
        chainConfigs[ChainType.Local] = ChainConfig({
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
     * @return chain The detected chain type
     */
    function detectChain() public view returns (ChainType) {
        // Get chainId
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        // Determine chain based on chainId
        if (chainId == 11155111) {
            return ChainType.SepoliaTestnet;
        } else if (chainId == 97) {
            return ChainType.BNBTestnet;
        } else {
            return ChainType.Local;
        }
    }

    /**
     * @notice Gets the configuration for the current chain
     * @return config The chain configuration
     */
    function getChainConfig() public view returns (ChainConfig memory) {
        ChainType currentChain = detectChain();
        return chainConfigs[currentChain];
    }

    /**
     * @notice Updates subscription ID for VRF on current chain
     * @param subscriptionId New subscription ID
     */
    function setSubscriptionId(uint64 subscriptionId) public {
        ChainType currentChain = detectChain();
        chainConfigs[currentChain].subscriptionId = subscriptionId;
    }

    function getChainSelector(
        ChainType chainType
    ) public view returns (uint64) {
        return chainConfigs[chainType].chainSelector;
    }
}
