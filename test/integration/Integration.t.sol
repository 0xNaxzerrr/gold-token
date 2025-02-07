// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/GoldToken.sol";
import "../../src/GoldLottery.sol";
import "../../src/GoldBridge.sol";
import "../../script/ChainHelper.s.sol";
import "../../test/mocks/MockPriceFeed.sol";
import "../../test/mocks/MockVRFCoordinator.sol";

contract IntegrationTest is Test {
    // Mocks
    MockPriceFeed mockEthUsdFeed;
    MockPriceFeed mockXauUsdFeed;
    MockVRFCoordinator mockVRFCoordinator;
    ChainHelper chainHelper;

    // ETH Fork contracts
    GoldLottery lotteryETH;
    GoldToken tokenETH;
    GoldBridge bridgeETH;

    // BSC Fork contracts
    GoldLottery lotteryBSC;
    GoldToken tokenBSC;
    GoldBridge bridgeBSC;

    // Users
    address public constant OWNER = address(1);
    address public constant USER1 = address(2);
    address public constant USER2 = address(3);

    // Fork URLs
    string MAINNET_RPC_URL = vm.envString("ETH_RPC_URL");
    string BSC_RPC_URL = vm.envString("BSC_RPC_URL");

    // Fork IDs
    uint256 mainnetFork;
    uint256 bscFork;

    function setUp() public {
        console.log("Setting up test environment...");
        
        // Create forks
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        bscFork = vm.createFork(BSC_RPC_URL);

        vm.selectFork(mainnetFork);
        
        // Deploy mocks
        mockEthUsdFeed = new MockPriceFeed();
        mockXauUsdFeed = new MockPriceFeed();
        mockVRFCoordinator = new MockVRFCoordinator();

        // Set initial prices with current timestamp
        uint256 currentTime = block.timestamp;
        mockEthUsdFeed.setPrice(2000 * 1e8);
        mockEthUsdFeed.setUpdateTime(currentTime);
        mockXauUsdFeed.setPrice(2000 * 1e8);
        mockXauUsdFeed.setUpdateTime(currentTime);

        // Initialize chainHelper
        chainHelper = new ChainHelper();

        // Make mocks persistent
        vm.makePersistent(address(mockEthUsdFeed));
        vm.makePersistent(address(mockXauUsdFeed));
        vm.makePersistent(address(mockVRFCoordinator));
        vm.makePersistent(address(chainHelper));

        // Labels
        vm.label(address(mockEthUsdFeed), "MockEthUsdFeed");
        vm.label(address(mockXauUsdFeed), "MockXauUsdFeed");
        vm.label(address(mockVRFCoordinator), "MockVRFCoordinator");
    }

    function deployETHContracts() private {
        console.log("Deploying ETH contracts...");
        lotteryETH = GoldLottery(
            payable(
                deployCode(
                    "GoldLottery.sol:GoldLottery",
                    abi.encode(address(mockVRFCoordinator))
                )
            )
        );
        vm.label(address(lotteryETH), "LotteryETH");

        lotteryETH.initialize(
            address(mockVRFCoordinator),
            bytes32(uint256(1)),
            1,
            7 days,
            0.5 ether
        );
        console.log("LotteryETH deployed at:", address(lotteryETH));

        tokenETH = GoldToken(
            payable(deployCode("GoldToken.sol:GoldToken"))
        );
        vm.label(address(tokenETH), "TokenETH");

        tokenETH.initialize(
            address(mockEthUsdFeed),
            address(mockXauUsdFeed),
            address(lotteryETH)
        );
        console.log("TokenETH deployed at:", address(tokenETH));

        bridgeETH = GoldBridge(
            payable(
                deployCode(
                    "GoldBridge.sol:GoldBridge",
                    abi.encode(address(1), address(2))
                )
            )
        );
        vm.label(address(bridgeETH), "BridgeETH");

        bridgeETH.initialize(address(tokenETH));
        tokenETH.updateBridgeContract(address(bridgeETH));
        console.log("BridgeETH deployed and linked at:", address(bridgeETH));
    }

    function deployBSCContracts() private {
        console.log("Deploying BSC contracts...");
        lotteryBSC = GoldLottery(
            payable(
                deployCode(
                    "GoldLottery.sol:GoldLottery",
                    abi.encode(address(mockVRFCoordinator))
                )
            )
        );
        vm.label(address(lotteryBSC), "LotteryBSC");

        lotteryBSC.initialize(
            address(mockVRFCoordinator),
            bytes32(uint256(1)),
            1,
            7 days,
            0.5 ether
        );
        console.log("LotteryBSC deployed at:", address(lotteryBSC));

        tokenBSC = GoldToken(
            payable(deployCode("GoldToken.sol:GoldToken"))
        );
        vm.label(address(tokenBSC), "TokenBSC");

        tokenBSC.initialize(
            address(mockEthUsdFeed),
            address(mockXauUsdFeed),
            address(lotteryBSC)
        );
        console.log("TokenBSC deployed at:", address(tokenBSC));

        bridgeBSC = GoldBridge(
            payable(
                deployCode(
                    "GoldBridge.sol:GoldBridge",
                    abi.encode(address(1), address(2))
                )
            )
        );
        vm.label(address(bridgeBSC), "BridgeBSC");

        bridgeBSC.initialize(address(tokenBSC));
        tokenBSC.updateBridgeContract(address(bridgeBSC));
        console.log("BridgeBSC deployed and linked at:", address(bridgeBSC));
    }

    function testCrosschainTransfer() public {
        // Deploy contracts on both chains
        vm.selectFork(mainnetFork);
        vm.startPrank(OWNER);
        deployETHContracts();
        vm.stopPrank();

        vm.selectFork(bscFork);
        vm.startPrank(OWNER);
        deployBSCContracts();
        vm.stopPrank();

        // Test minting and bridging
        vm.selectFork(mainnetFork);
        vm.startPrank(USER1);
        vm.deal(USER1, 100 ether);

        // Log initial state
        console.log("\nInitial state on ETH:");
        console.log("USER1 ETH balance:", USER1.balance);
        console.log("USER1 token balance:", tokenETH.balanceOf(USER1));
        console.log("LotteryETH balance:", address(lotteryETH).balance);

        // Mint tokens
        console.log("\nMinting tokens...");
        uint256 mintAmount = 2 ether;
        tokenETH.mint{value: mintAmount}();
        
        uint256 userBalance = tokenETH.balanceOf(USER1);
        console.log("Balance after mint:", userBalance);
        console.log("LotteryETH balance after mint:", address(lotteryETH).balance);
        assertGt(userBalance, 0, "Minting failed");

        // Bridge transfer
        console.log("\nInitiating bridge transfer...");
        tokenETH.approve(address(bridgeETH), userBalance);
        
        uint64 destChainSelector = chainHelper.getChainSelector(ChainHelper.ChainType.BNBTestnet);
        bridgeETH.bridgeTokens{value: 0.1 ether}(
            destChainSelector,
            USER1,
            userBalance
        );
        
        vm.stopPrank();

        // Verify balances on BSC
        vm.selectFork(bscFork);
        uint256 bscBalance = tokenBSC.balanceOf(USER1);
        console.log("\nFinal state on BSC:");
        console.log("USER1 BSC token balance:", bscBalance);
        assertEq(bscBalance, userBalance, "Bridge transfer failed");

        console.log("\nTest completed successfully");
    }

    receive() external payable {}
}