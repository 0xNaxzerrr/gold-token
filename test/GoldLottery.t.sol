// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GoldLottery.sol";
import "./mocks/MockVRFCoordinator.sol";

contract GoldLotteryTest is Test {
    GoldLottery public lottery;
    MockVRFCoordinator public vrfCoordinator;

    address public constant OWNER = address(1);
    address public constant USER1 = address(2);
    address public constant USER2 = address(3);

    bytes32 public constant KEY_HASH = keccak256("test-key-hash");
    uint64 public constant SUBSCRIPTION_ID = 1;
    uint256 public constant DRAW_INTERVAL = 7 days;
    uint256 public constant MIN_PRIZE_POOL = 1 ether;

    function setUp() public {
        vm.startPrank(OWNER);

        // Deploy Mock VRF Coordinator
        vrfCoordinator = new MockVRFCoordinator();

        // Deploy Lottery
        lottery = new GoldLottery(address(vrfCoordinator));
        lottery.initialize(
            address(vrfCoordinator),
            KEY_HASH,
            SUBSCRIPTION_ID,
            DRAW_INTERVAL,
            MIN_PRIZE_POOL
        );

        vm.stopPrank();

        // Fund users
        vm.deal(USER1, 100 ether);
        vm.deal(USER2, 100 ether);
    }

    function test_Initialize() public {
        assertEq(lottery.getCurrentRound(), 1, "Should start at round 1");
        IGoldLottery.Round memory round = lottery.getRoundInfo(1);
        assertEq(round.startTime, block.timestamp, "Should start now");
        assertEq(round.endTime, block.timestamp + DRAW_INTERVAL, "Should end after interval");
        assertEq(round.prizePool, 0, "Should start with empty pool");
        assertFalse(round.isComplete, "Should not be complete");
    }

    function test_ReceiveFunds() public {
        vm.startPrank(USER1);
        lottery.receiveFunds{value: 1 ether}();

        IGoldLottery.Round memory round = lottery.getRoundInfo(1);
        assertEq(round.prizePool, 1 ether, "Prize pool should be updated");
        vm.stopPrank();
    }

    function test_MultipleParticipants() public {
        vm.prank(USER1);
        lottery.receiveFunds{value: 1 ether}();

        vm.prank(USER2);
        lottery.receiveFunds{value: 2 ether}();

        IGoldLottery.Round memory round = lottery.getRoundInfo(1);
        assertEq(round.prizePool, 3 ether, "Prize pool should be sum of contributions");

        address[] memory participants = lottery.getRoundParticipants(1);
        assertEq(participants.length, 2, "Should have two participants");
        assertEq(participants[0], USER1, "First participant should be USER1");
        assertEq(participants[1], USER2, "Second participant should be USER2");
    }

    function test_DrawWinner() public {
        // Add participants
        vm.prank(USER1);
        lottery.receiveFunds{value: 1 ether}();

        vm.prank(USER2);
        lottery.receiveFunds{value: 2 ether}();

        // Advance time to draw
        vm.warp(block.timestamp + DRAW_INTERVAL);

        // Check upkeep
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assertTrue(upkeepNeeded, "Should need upkeep");

        // Perform upkeep to request random number
        lottery.performUpkeep("");

        // Mock VRF response
        uint256 randomness = 123;
        vrfCoordinator.fulfillRequest(1, randomness);

        // Check round completion
        IGoldLottery.Round memory round = lottery.getRoundInfo(1);
        assertTrue(round.isComplete, "Round should be complete");
        assertEq(round.prizePool, 3 ether, "Prize pool should be unchanged");
        assertNotEq(round.winner, address(0), "Should have a winner");

        // Winner should be either USER1 or USER2
        assertTrue(
            round.winner == USER1 || round.winner == USER2,
            "Winner should be a participant"
        );
    }

    function test_ClaimPrize() public {
        // Setup winner
        vm.prank(USER1);
        lottery.receiveFunds{value: 3 ether}();

        vm.warp(block.timestamp + DRAW_INTERVAL);
        lottery.performUpkeep("");
        vrfCoordinator.fulfillRequest(1, 123); // USER1 will win

        // Get winner's initial balance
        IGoldLottery.Round memory round = lottery.getRoundInfo(1);
        address winner = round.winner;
        uint256 initialBalance = winner.balance;

        // Claim prize
        vm.prank(winner);
        lottery.claimPrize(1);

        // Check balances
        assertEq(
            winner.balance,
            initialBalance + 3 ether,
            "Winner should receive prize"
        );
        assertEq(
            address(lottery).balance,
            0,
            "Lottery should have no balance"
        );

        // Verify round state
        round = lottery.getRoundInfo(1);
        assertTrue(round.prizeClaimed, "Prize should be marked as claimed");
    }

    function test_CannotClaimTwice() public {
        // Setup winner
        vm.prank(USER1);
        lottery.receiveFunds{value: 1 ether}();

        vm.warp(block.timestamp + DRAW_INTERVAL);
        lottery.performUpkeep("");
        vrfCoordinator.fulfillRequest(1, 123);

        // First claim
        IGoldLottery.Round memory round = lottery.getRoundInfo(1);
        vm.prank(round.winner);
        lottery.claimPrize(1);

        // Second claim should fail
        vm.expectRevert("Prize already claimed");
        vm.prank(round.winner);
        lottery.claimPrize(1);
    }

    function test_OnlyWinnerCanClaim() public {
        // Setup winner
        vm.prank(USER1);
        lottery.receiveFunds{value: 1 ether}();

        vm.warp(block.timestamp + DRAW_INTERVAL);
        lottery.performUpkeep("");
        vrfCoordinator.fulfillRequest(1, 123);

        // Non-winner tries to claim
        vm.prank(USER2);
        vm.expectRevert("Not winner");
        lottery.claimPrize(1);
    }

    function test_EmergencyWithdraw() public {
        // Add funds
        vm.prank(USER1);
        lottery.receiveFunds{value: 1 ether}();

        // Only owner can withdraw
        vm.prank(USER2);
        vm.expectRevert("Ownable: caller is not the owner");
        lottery.emergencyWithdraw();

        // Owner withdraws
        uint256 initialBalance = OWNER.balance;
        vm.prank(OWNER);
        lottery.emergencyWithdraw();

        assertEq(
            OWNER.balance,
            initialBalance + 1 ether,
            "Owner should receive funds"
        );
        assertEq(
            address(lottery).balance,
            0,
            "Lottery should have no balance"
        );
    }

    receive() external payable {}
}