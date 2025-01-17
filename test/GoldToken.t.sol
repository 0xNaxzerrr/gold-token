// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";
import "./mocks/MockPriceFeed.sol";

contract GoldTokenTest is Test {
    GoldToken public token;
    GoldLottery public lottery;
    MockPriceFeed public ethUsdFeed;
    MockPriceFeed public xauUsdFeed;
    
    address public constant OWNER = address(1);
    address public constant USER = address(2);
    
    uint256 public constant ETH_PRICE = 2000e8; // $2000 per ETH
    uint256 public constant GOLD_PRICE = 2000e8; // $2000 per oz of gold
    
    event TokensMinted(address indexed user, uint256 ethAmount, uint256 goldTokens);
    event TokensBurned(address indexed user, uint256 goldTokens, uint256 ethAmount);

    function setUp() public {
        vm.startPrank(OWNER);
        
        // Deploy mock price feeds
        ethUsdFeed = new MockPriceFeed();
        xauUsdFeed = new MockPriceFeed();
        ethUsdFeed.setPrice(ETH_PRICE);
        xauUsdFeed.setPrice(GOLD_PRICE);
        
        // Deploy lottery
        lottery = new GoldLottery(address(0)); // Mock VRF coordinator not needed for token tests
        lottery.initialize(
            address(0),
            bytes32(0),
            0,
            7 days,
            1 ether
        );
        
        // Deploy token
        token = new GoldToken();
        token.initialize(
            address(ethUsdFeed),
            address(xauUsdFeed),
            address(lottery)
        );
        
        vm.stopPrank();
        
        // Fund USER with ETH
        vm.deal(USER, 100 ether);
    }
    
    function test_Initialize() public {
        assertEq(token.name(), "GoldToken");
        assertEq(token.symbol(), "GOLD");
        assertEq(address(token.ethUsdPriceFeed()), address(ethUsdFeed));
        assertEq(address(token.xauUsdPriceFeed()), address(xauUsdFeed));
    }
    
    function test_GetPrices() public {
        assertEq(token.getEthUsdPrice(), ETH_PRICE);
        assertEq(token.getXauUsdPrice(), GOLD_PRICE);
    }
    
    function test_CalculateGoldTokens() public {
        // Send 1 ETH, ETH price = $2000, Gold price = $2000
        // Commission = 5% = 0.05 ETH = $100
        // Remaining = 0.95 ETH = $1900
        // 50% for tokens = $950
        // Gold price = $2000/oz
        // Expected tokens = 0.475 GOLD
        uint256 expectedTokens = 0.475 ether;
        uint256 calculatedTokens = token.calculateGoldTokens(1 ether);
        
        assertApproxEqRel(calculatedTokens, expectedTokens, 0.01e18); // 1% tolerance
    }
    
    function test_Mint() public {
        vm.startPrank(USER);
        
        uint256 initialBalance = USER.balance;
        uint256 expectedTokens = token.calculateGoldTokens(1 ether);
        
        vm.expectEmit(true, false, false, true);
        emit TokensMinted(USER, 1 ether, expectedTokens);
        
        token.mint{value: 1 ether}();
        
        assertEq(token.balanceOf(USER), expectedTokens);
        assertEq(USER.balance, initialBalance - 1 ether);
        
        vm.stopPrank();
    }
    
    function test_Burn() public {
        // First mint some tokens
        vm.startPrank(USER);
        token.mint{value: 1 ether}();
        uint256 tokenBalance = token.balanceOf(USER);
        
        // Then burn them
        vm.expectEmit(true, false, false, true);
        emit TokensBurned(USER, tokenBalance, 0.475 ether); // Expected ETH return
        
        token.burn(tokenBalance);
        
        assertEq(token.balanceOf(USER), 0);
        vm.stopPrank();
    }
    
    function test_UpdatePriceFeeds() public {
        vm.startPrank(OWNER);
        
        MockPriceFeed newEthFeed = new MockPriceFeed();
        MockPriceFeed newGoldFeed = new MockPriceFeed();
        
        token.updatePriceFeeds(address(newEthFeed), address(newGoldFeed));
        
        assertEq(address(token.ethUsdPriceFeed()), address(newEthFeed));
        assertEq(address(token.xauUsdPriceFeed()), address(newGoldFeed));
        
        vm.stopPrank();
    }
    
    function test_RevertsOnZeroMint() public {
        vm.startPrank(USER);
        vm.expectRevert("Must send ETH");
        token.mint{value: 0}();
        vm.stopPrank();
    }
    
    function test_RevertsOnInvalidBurn() public {
        vm.startPrank(USER);
        vm.expectRevert("Amount must be > 0");
        token.burn(0);
        vm.stopPrank();
    }
    
    function test_RevertsOnUnauthorizedPriceFeedUpdate() public {
        vm.startPrank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        token.updatePriceFeeds(address(0), address(0));
        vm.stopPrank();
    }
    
    receive() external payable {}
}