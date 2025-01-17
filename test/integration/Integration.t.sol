// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/GoldToken.sol";
import "../../src/GoldLottery.sol";
import "../../src/GoldBridge.sol";
import "../../script/ChainHelper.s.sol";

/**
 * @title IntegrationTest
 * @author 0xNaxzerrr
 * @notice Integration tests for the entire Gold Token protocol
 */
contract IntegrationTest is Test {
    // Contracts
    GoldToken public tokenETH;
    GoldToken public tokenBSC;
    GoldLottery public lottery;
    GoldBridge public bridgeETH;
    GoldBridge public bridgeBSC;
    ChainHelper public chainHelper;

    // Users
    address public constant OWNER = address(1);
    address public constant USER1 = address(2);
    address public constant USER2 = address(3);

    // Fork URLs
    string MAINNET_RPC_URL = vm.envString("ETH_RPC_URL");
    string BSC_RPC_URL = vm.envString("BSC_RPC_URL");

    // Fork IDs
    uint256 public mainnetFork;
    uint256 public bscFork;

    function setUp() public {
        // Create forks
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        bscFork = vm.createFork(BSC_RPC_URL);

        // Initialize chainHelper
        chainHelper = new ChainHelper();
    }

    function testCrosschainTransfer() public {
        // Test on Ethereum
        vm.selectFork(mainnetFork);
        ChainHelper.ChainConfig memory ethConfig = chainHelper.getChainConfig();

        vm.startPrank(OWNER);

        // Deploy Ethereum contracts
        lottery = new GoldLottery(ethConfig.vrfCoordinator);
        lottery.initialize(
            ethConfig.vrfCoordinator,
            ethConfig.keyHash,
            ethConfig.subscriptionId,
            7 days,
            1 ether
        );

        tokenETH = new GoldToken();
        tokenETH.initialize(
            ethConfig.ethUsdFeed,
            ethConfig.xauUsdFeed,
            address(lottery)
        );

        bridgeETH = new GoldBridge(ethConfig.router, ethConfig.link);
        bridgeETH.initialize(address(tokenETH));

        tokenETH.updateBridgeContract(address(bridgeETH));

        vm.stopPrank();

        // Test on BSC
        vm.selectFork(bscFork);
        ChainHelper.ChainConfig memory bscConfig = chainHelper.getChainConfig();

        vm.startPrank(OWNER);

        // Deploy BSC contracts
        tokenBSC = new GoldToken();
        tokenBSC.initialize(
            bscConfig.ethUsdFeed,
            bscConfig.xauUsdFeed,
            address(0) // No lottery on BSC
        );

        bridgeBSC = new GoldBridge(bscConfig.router, bscConfig.link);
        bridgeBSC.initialize(address(tokenBSC));

        tokenBSC.updateBridgeContract(address(bridgeBSC));

        vm.stopPrank();

        // Test minting on Ethereum
        vm.selectFork(mainnetFork);
        vm.startPrank(USER1);
        vm.deal(USER1, 100 ether);

        tokenETH.mint{value: 1 ether}();
        uint256 balance = tokenETH.balanceOf(USER1);
        assertGt(balance, 0, "Should have minted tokens");

        // Mock bridge transfer
        tokenETH.approve(address(bridgeETH), balance);
        bridgeETH.bridgeTokens{value: 0.1 ether}(
            chainHelper.chainConfigs(ChainHelper.Chain.BSC).chainSelector,
            USER1,
            balance
        );

        vm.stopPrank();

        // Verify balance on BSC
        vm.selectFork(bscFork);
        uint256 bscBalance = tokenBSC.balanceOf(USER1);
        assertEq(bscBalance, balance, "Bridged balance should match");
    }

    function testLotteryIntegration() public {
        vm.selectFork(mainnetFork);
        ChainHelper.ChainConfig memory config = chainHelper.getChainConfig();

        vm.startPrank(OWNER);

        // Deploy contracts
        lottery = new GoldLottery(config.vrfCoordinator);
        lottery.initialize(
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId,
            7 days,
            1 ether
        );

        tokenETH = new GoldToken();
        tokenETH.initialize(
            config.ethUsdFeed,
            config.xauUsdFeed,
            address(lottery)
        );

        vm.stopPrank();

        // Test lottery entry through minting
        vm.startPrank(USER1);
        vm.deal(USER1, 100 ether);

        tokenETH.mint{value: 5 ether}();

        // Mock time passage and VRF
        vm.warp(block.timestamp + 7 days);
        vm.roll(block.number + 1);

        // Simulate lottery completion
        uint256 roundId = lottery.getCurrentRound();
        IGoldLottery.Round memory round = lottery.getRoundInfo(roundId);
        
        assertGt(round.prizePool, 0, "Prize pool should be funded");
        vm.stopPrank();
    }

    function testPriceFeedIntegration() public {
        vm.selectFork(mainnetFork);
        ChainHelper.ChainConfig memory config = chainHelper.getChainConfig();

        vm.startPrank(OWNER);

        // Deploy contracts
        lottery = new GoldLottery(config.vrfCoordinator);
        lottery.initialize(
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId,
            7 days,
            1 ether
        );

        tokenETH = new GoldToken();
        tokenETH.initialize(
            config.ethUsdFeed,
            config.xauUsdFeed,
            address(lottery)
        );

        vm.stopPrank();

        // Test price feed interactions
        uint256 ethPrice = tokenETH.getEthUsdPrice();
        uint256 xauPrice = tokenETH.getXauUsdPrice();

        assertGt(ethPrice, 0, "ETH price should be positive");
        assertGt(xauPrice, 0, "XAU price should be positive");

        // Test token calculations
        uint256 tokens = tokenETH.calculateGoldTokens(1 ether);
        assertGt(tokens, 0, "Should calculate positive token amount");
    }

    receive() external payable {}
}