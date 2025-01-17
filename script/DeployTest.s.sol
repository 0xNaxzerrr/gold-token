// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../test/mocks/MockPriceFeed.sol";
import "../src/GoldLottery.sol";
import "../src/GoldToken.sol";
import "../script/ChainHelper.s.sol";

contract DeployTestScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Déployer les MockPriceFeeds
        MockPriceFeed ethUsdFeed = new MockPriceFeed();
        MockPriceFeed xauUsdFeed = new MockPriceFeed();

        ethUsdFeed.setPrice(2000 * 10 ** 8);
        xauUsdFeed.setPrice(2000 * 10 ** 8);

        // Déployer la lottery
        address mockVRFCoordinator = address(0x1);
        GoldLottery lottery = new GoldLottery(mockVRFCoordinator);

        lottery.initialize(mockVRFCoordinator, bytes32(0), 0, 7 days, 1 ether);

        // Déployer le token
        GoldToken goldToken = new GoldToken();

        console.log("Deployer:", deployer);
        console.log("ETH/USD Price Feed:", address(ethUsdFeed));
        console.log("XAU/USD Price Feed:", address(xauUsdFeed));
        console.log("Gold Lottery:", address(lottery));
        console.log("Gold Token:", address(goldToken));

        // Log avant initialisation
        console.log("Before initialize: ETH Feed", address(ethUsdFeed));
        console.log("Before initialize: XAU Feed", address(xauUsdFeed));
        console.log("Before initialize: Lottery", address(lottery));

        // Initialisation du token
        goldToken.initialize(
            address(ethUsdFeed),
            address(xauUsdFeed),
            address(lottery)
        );

        vm.stopBroadcast();
    }
}
