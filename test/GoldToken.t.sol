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

    event TokensMinted(
        address indexed user,
        uint256 ethAmount,
        uint256 goldTokens
    );
    event TokensBurned(
        address indexed user,
        uint256 goldTokens,
        uint256 ethAmount
    );

    function setUp() public {
        vm.startPrank(OWNER);

        // Deploy mock price feeds
        ethUsdFeed = new MockPriceFeed();
        xauUsdFeed = new MockPriceFeed();
        ethUsdFeed.setPrice(int256(ETH_PRICE));
        xauUsdFeed.setPrice(int256(GOLD_PRICE));

        // Deploy lottery
        lottery = new GoldLottery(address(0)); // Mock VRF coordinator not needed for token tests
        lottery.initialize(address(0), bytes32(0), 0, 7 days, 1 ether);

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

    function testMint() public {
        vm.startPrank(USER);

        // Mint avec 1 ETH
        uint256 initialBalance = token.balanceOf(USER);
        vm.deal(USER, 10 ether);

        token.mint{value: 1 ether}();

        uint256 finalBalance = token.balanceOf(USER);
        assertTrue(
            finalBalance > initialBalance,
            "Balance should increase after minting"
        );
    }

    function testCalculateGoldTokens() public {
        uint256 goldTokens = token.calculateGoldTokens(1 ether);
        assertTrue(goldTokens > 0, "Should calculate non-zero gold tokens");
    }
}
