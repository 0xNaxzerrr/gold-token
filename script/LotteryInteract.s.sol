// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IGoldLottery.sol";
import "./ChainHelper.s.sol";

/**
 * @title LotteryInteractScript
 * @author 0xNaxzerrr
 * @notice Script to interact with the Gold Lottery
 */
contract LotteryInteractScript is Script {
    // Contract address to be set before running
    address public constant LOTTERY_ADDRESS = address(0);  // Set your deployed address

    ChainHelper public chainHelper;
    IGoldLottery public lottery;

    function setUp() public {
        chainHelper = new ChainHelper();
        lottery = IGoldLottery(LOTTERY_ADDRESS);
    }

    function viewLottery() public view {
        uint256 currentRound = lottery.getCurrentRound();
        IGoldLottery.Round memory round = lottery.getRoundInfo(currentRound);

        console.log("Current Lottery Status");
        console.log("----------------------");
        console.log("Round:", currentRound);
        console.log("Prize Pool:", round.prizePool);
        console.log("Start Time:", round.startTime);
        console.log("End Time:", round.endTime);
        console.log("Time Remaining:", round.endTime > block.timestamp ? round.endTime - block.timestamp : 0);

        if (round.isComplete) {
            console.log("Status: Complete");
            console.log("Winner:", round.winner);
            console.log("Prize Claimed:", round.prizeClaimed ? "Yes" : "No");
        } else {
            console.log("Status: In Progress");
            (bool upkeepNeeded, ) = lottery.checkUpkeep("");
            console.log("Ready for Draw:", upkeepNeeded ? "Yes" : "No");
        }
    }

    function participate(uint256 amount) public {
        require(amount > 0, "Amount must be positive");

        console.log("Participating in lottery with", amount, "ETH");

        vm.broadcast();
        lottery.receiveFunds{value: amount}();

        console.log("Successfully participated");
        viewLottery();
    }

    function claimPrize(uint256 roundId) public {
        IGoldLottery.Round memory round = lottery.getRoundInfo(roundId);
        require(round.isComplete, "Round not complete");
        require(!round.prizeClaimed, "Prize already claimed");

        console.log("Claiming prize for round", roundId);
        console.log("Prize amount:", round.prizePool);

        vm.broadcast();
        lottery.claimPrize(roundId);

        console.log("Prize claimed successfully");
    }

    function performDraw() public {
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        require(upkeepNeeded, "Draw not needed yet");

        console.log("Initiating lottery draw");

        vm.broadcast();
        lottery.performUpkeep("");

        console.log("Draw requested, waiting for VRF response...");
    }

    function run() public {
        viewLottery();
    }
}

contract ParticipateLotteryScript is LotteryInteractScript {
    function run() public override {
        uint256 amount = vm.envUint("PARTICIPATION_AMOUNT");
        participate(amount);
    }
}

contract ClaimPrizeScript is LotteryInteractScript {
    function run() public override {
        uint256 roundId = vm.envUint("ROUND_ID");
        claimPrize(roundId);
    }
}

contract PerformDrawScript is LotteryInteractScript {
    function run() public override {
        performDraw();
    }
}