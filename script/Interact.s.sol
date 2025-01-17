// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IGoldToken.sol";
import "../src/interfaces/IGoldLottery.sol";
import "../src/interfaces/IGoldBridge.sol";
import "./ChainHelper.s.sol";

/**
 * @title InteractScript
 * @author 0xNaxzerrr
 * @notice Script to interact with deployed Gold Token protocol
 */
contract InteractScript is Script {
    // Contract addresses - to be set before running
    address public constant GOLD_TOKEN_ETH = address(0);  // Set your deployed address
    address public constant GOLD_TOKEN_BSC = address(0);  // Set your deployed address
    address public constant GOLD_LOTTERY = address(0);    // Set your deployed address
    address public constant GOLD_BRIDGE_ETH = address(0); // Set your deployed address
    address public constant GOLD_BRIDGE_BSC = address(0); // Set your deployed address

    ChainHelper public chainHelper;

    function setUp() public {
        chainHelper = new ChainHelper();
    }

    function mintTokens(uint256 ethAmount) public {
        require(ethAmount > 0, "Amount must be positive");

        IGoldToken token = IGoldToken(GOLD_TOKEN_ETH);
        uint256 expectedTokens = token.calculateGoldTokens(ethAmount);

        console.log("Minting tokens with", ethAmount, "ETH");
        console.log("Expected tokens:", expectedTokens);

        vm.broadcast();
        token.mint{value: ethAmount}();

        console.log("Tokens minted successfully");
        console.log("Your balance:", token.balanceOf(msg.sender));
    }

    function burnTokens(uint256 amount) public {
        IGoldToken token = IGoldToken(GOLD_TOKEN_ETH);
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");

        console.log("Burning", amount, "tokens");

        vm.broadcast();
        token.burn(amount);

        console.log("Tokens burned successfully");
        console.log("Remaining balance:", token.balanceOf(msg.sender));
    }

    function bridgeTokens(uint256 amount, bool toETH) public {
        if (toETH) {
            // Bridge from BSC to ETH
            IGoldToken token = IGoldToken(GOLD_TOKEN_BSC);
            IGoldBridge bridge = IGoldBridge(GOLD_BRIDGE_BSC);

            uint256 chainSelector = chainHelper.chainConfigs(ChainHelper.Chain.Mainnet).chainSelector;
            uint256 fees = bridge.getFeeEstimate(uint64(chainSelector), msg.sender, amount);

            console.log("Bridging", amount, "tokens from BSC to ETH");
            console.log("Estimated fees:", fees);

            vm.broadcast();
            token.approve(GOLD_BRIDGE_BSC, amount);

            vm.broadcast();
            bridge.bridgeTokens{value: fees}(
                uint64(chainSelector),
                msg.sender,
                amount
            );
        } else {
            // Bridge from ETH to BSC
            IGoldToken token = IGoldToken(GOLD_TOKEN_ETH);
            IGoldBridge bridge = IGoldBridge(GOLD_BRIDGE_ETH);

            uint256 chainSelector = chainHelper.chainConfigs(ChainHelper.Chain.BSC).chainSelector;
            uint256 fees = bridge.getFeeEstimate(uint64(chainSelector), msg.sender, amount);

            console.log("Bridging", amount, "tokens from ETH to BSC");
            console.log("Estimated fees:", fees);

            vm.broadcast();
            token.approve(GOLD_BRIDGE_ETH, amount);

            vm.broadcast();
            bridge.bridgeTokens{value: fees}(
                uint64(chainSelector),
                msg.sender,
                amount
            );
        }

        console.log("Bridge transaction sent successfully");
    }

    function checkLottery() public view {
        IGoldLottery lottery = IGoldLottery(GOLD_LOTTERY);
        uint256 currentRound = lottery.getCurrentRound();
        IGoldLottery.Round memory round = lottery.getRoundInfo(currentRound);

        console.log("Current lottery round:", currentRound);
        console.log("Prize pool:", round.prizePool);
        console.log("Start time:", round.startTime);
        console.log("End time:", round.endTime);
        
        if (round.isComplete) {
            console.log("Round is complete");
            console.log("Winner:", round.winner);
            if (round.prizeClaimed) {
                console.log("Prize has been claimed");
            } else {
                console.log("Prize not yet claimed");
            }
        } else {
            console.log("Round is ongoing");
            console.log("Time until draw:", round.endTime - block.timestamp);
        }
    }

    function getPrices() public view {
        IGoldToken token = IGoldToken(GOLD_TOKEN_ETH);

        uint256 ethPrice = token.getEthUsdPrice();
        uint256 goldPrice = token.getXauUsdPrice();

        console.log("Current ETH/USD price:", ethPrice);
        console.log("Current XAU/USD price:", goldPrice);

        // Calculate example token amounts
        uint256 tokensFor1ETH = token.calculateGoldTokens(1 ether);
        console.log("GOLD tokens for 1 ETH:", tokensFor1ETH);
    }

    function run() public {
        // Default behavior: show current prices and lottery status
        getPrices();
        checkLottery();
    }
}

/**
 * @notice Helper contract for mint interaction
 */
contract MintScript is InteractScript {
    function run() public override {
        // Read amount from command line
        uint256 amount = vm.envUint("MINT_AMOUNT");
        mintTokens(amount);
    }
}

/**
 * @notice Helper contract for burn interaction
 */
contract BurnScript is InteractScript {
    function run() public override {
        // Read amount from command line
        uint256 amount = vm.envUint("BURN_AMOUNT");
        burnTokens(amount);
    }
}

/**
 * @notice Helper contract for bridge interaction
 */
contract BridgeScript is InteractScript {
    function run() public override {
        // Read parameters from command line
        uint256 amount = vm.envUint("BRIDGE_AMOUNT");
        bool toETH = vm.envBool("TO_ETH");
        bridgeTokens(amount, toETH);
    }
}