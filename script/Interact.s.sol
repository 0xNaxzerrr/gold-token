// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/interfaces/IGoldToken.sol";
import "../src/interfaces/IGoldBridge.sol";
import "./ChainHelper.s.sol";

contract InteractScript is Script {
    address public constant GOLD_TOKEN_ETH = address(0); // Set your deployed address
    address public constant GOLD_TOKEN_BSC = address(0); // Set your deployed address
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

            uint64 chainSelector = chainHelper.getChainSelector(
                ChainHelper.ChainType.SepoliaTestnet
            );
            uint256 fees = bridge.getFeeEstimate(
                chainSelector,
                msg.sender,
                amount
            );

            console.log("Bridging", amount, "tokens from BSC to ETH");
            console.log("Estimated fees:", fees);

            vm.broadcast();
            token.approve(GOLD_BRIDGE_BSC, amount);

            vm.broadcast();
            bridge.bridgeTokens{value: fees}(chainSelector, msg.sender, amount);
        } else {
            // Bridge from ETH to BSC
            IGoldToken token = IGoldToken(GOLD_TOKEN_ETH);
            IGoldBridge bridge = IGoldBridge(GOLD_BRIDGE_ETH);

            uint64 chainSelector = chainHelper
                .chainConfigs(ChainType.SepoliaTestnet)
                .chainSelector;

            uint256 fees = bridge.getFeeEstimate(
                chainSelector,
                msg.sender,
                amount
            );

            console.log("Bridging", amount, "tokens from ETH to BSC");
            console.log("Estimated fees:", fees);

            vm.broadcast();
            token.approve(GOLD_BRIDGE_ETH, amount);

            vm.broadcast();
            bridge.bridgeTokens{value: fees}(chainSelector, msg.sender, amount);
        }

        console.log("Bridge transaction sent successfully");
    }

    function run() public virtual {
        getPrices();
    }

    function getPrices() internal view {
        IGoldToken token = IGoldToken(GOLD_TOKEN_ETH);

        uint256 ethPrice = token.getEthUsdPrice();
        uint256 goldPrice = token.getXauUsdPrice();

        console.log("Current ETH/USD price:", ethPrice);
        console.log("Current XAU/USD price:", goldPrice);

        // Calculate example token amounts
        uint256 tokensFor1ETH = token.calculateGoldTokens(1 ether);
        console.log("GOLD tokens for 1 ETH:", tokensFor1ETH);
    }
}

contract MintScript is InteractScript {
    function run() public override {
        uint256 amount = vm.envUint("MINT_AMOUNT");
        mintTokens(amount);
    }
}

contract BurnScript is InteractScript {
    function run() public override {
        uint256 amount = vm.envUint("BURN_AMOUNT");
        burnTokens(amount);
    }
}

contract BridgeScript is InteractScript {
    function run() public override {
        uint256 amount = vm.envUint("BRIDGE_AMOUNT");
        bool toETH = vm.envBool("TO_ETH");
        bridgeTokens(amount, toETH);
    }
}
