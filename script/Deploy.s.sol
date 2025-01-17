// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";
import "../src/GoldBridge.sol";

/**
 * @title DeployScript
 * @author 0xNaxzerrr
 * @notice Script to deploy the Gold Token ecosystem
 */
contract DeployScript is Script {
    // Price Feed addresses - Mainnet
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant XAU_USD_FEED = 0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6;
    
    // Chainlink VRF settings - Mainnet
    address constant VRF_COORDINATOR = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
    bytes32 constant KEY_HASH = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;
    uint64 constant SUBSCRIPTION_ID = 1; // Replace with your subscription ID
    
    // CCIP settings - Mainnet
    address constant ROUTER = 0xE561d5E02207fb5eB32cca20a699E0d8919a1476;
    address constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Lottery
        GoldLottery lottery = new GoldLottery(VRF_COORDINATOR);
        lottery.initialize(
            VRF_COORDINATOR,
            KEY_HASH,
            SUBSCRIPTION_ID,
            7 days, // Draw interval
            1 ether  // Minimum prize pool
        );

        // Deploy Token
        GoldToken token = new GoldToken();
        token.initialize(
            ETH_USD_FEED,
            XAU_USD_FEED,
            address(lottery)
        );

        // Deploy Bridge
        GoldBridge bridge = new GoldBridge(
            ROUTER,
            LINK
        );
        bridge.initialize(address(token));

        // Set up permissions
        token.updateBridgeContract(address(bridge));
        
        console.log("Deployment addresses:");
        console.log("GoldToken:", address(token));
        console.log("GoldLottery:", address(lottery));
        console.log("GoldBridge:", address(bridge));

        vm.stopBroadcast();
    }
}

contract DeployGoldBSC is Script {
    // BSC Addresses
    address constant BSC_ROUTER = 0x536d7E53D0aDeB1F20E7c81fea45d02eC9dBD698;
    address constant BSC_LINK = 0x404460C6A5EdE2D891e8297795264fDe62ADBB75;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy BSC Bridge
        GoldBridge bridge = new GoldBridge(
            BSC_ROUTER,
            BSC_LINK
        );

        // Deploy BSC Token
        GoldToken token = new GoldToken();
        token.initialize(
            address(0), // No price feeds needed on BSC
            address(0), // No price feeds needed on BSC
            address(0)  // No lottery on BSC
        );

        // Setup bridge
        bridge.initialize(address(token));
        token.updateBridgeContract(address(bridge));

        console.log("BSC Deployment addresses:");
        console.log("BSC GoldToken:", address(token));
        console.log("BSC Bridge:", address(bridge));

        vm.stopBroadcast();
    }
}