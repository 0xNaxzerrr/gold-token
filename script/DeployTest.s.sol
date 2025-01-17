// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../test/mocks/MockPriceFeed.sol";
import "../src/GoldLottery.sol";
import "../src/GoldToken.sol";
import "../script/ChainHelper.s.sol";

contract DeployTestScript is Script {
    function run() public {
        // Définir explicitement le deployer
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Déployer les MockPriceFeeds
        MockPriceFeed ethUsdFeed = new MockPriceFeed();
        MockPriceFeed xauUsdFeed = new MockPriceFeed();

        // Définir des prix de test
        ethUsdFeed.setPrice(2000 * 10**8);  // $2000 
        xauUsdFeed.setPrice(2000 * 10**8);  // $2000

        // Déployer la lottery
        address mockVRFCoordinator = address(0x1);  // Mock VRF Coordinator
        GoldLottery lottery = new GoldLottery(mockVRFCoordinator);
        
        // Initialiser la lottery
        lottery.initialize(
            mockVRFCoordinator,  // VRF Coordinator
            bytes32(0),           // Key Hash
            0,                    // Subscription ID
            7 days,               // Duration
            1 ether               // Entry Price
        );

        // Déployer le token
        GoldToken goldToken = new GoldToken();
        goldToken.initialize(
            address(ethUsdFeed),
            address(xauUsdFeed),
            address(lottery)
        );

        // Afficher les adresses déployées
        console.log("Deployer:", deployer);
        console.log("ETH/USD Price Feed:", address(ethUsdFeed));
        console.log("XAU/USD Price Feed:", address(xauUsdFeed));
        console.log("Gold Lottery:", address(lottery));
        console.log("Gold Token:", address(goldToken));

        vm.stopBroadcast();
    }
}