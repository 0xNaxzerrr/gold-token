// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IGoldToken.sol";
import "./interfaces/IGoldLottery.sol";

contract GoldToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, IGoldToken {
    AggregatorV3Interface public ethUsdPriceFeed;
    AggregatorV3Interface public xauUsdPriceFeed;
    IGoldLottery public lottery;

    uint256 public constant COMMISSION_PERCENTAGE = 5;
    uint256 public constant LOTTERY_PERCENTAGE = 10;

    event TokensMinted(address indexed user, uint256 ethAmount, uint256 goldTokens);
    event TokensBurned(address indexed user, uint256 goldTokens, uint256 ethAmount);

    function initialize(
        address _ethUsdPriceFeed,
        address _xauUsdPriceFeed,
        address _lottery
    ) public initializer {
        __ERC20_init("GoldToken", "GOLD");
        __Ownable_init(msg.sender);

        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        xauUsdPriceFeed = AggregatorV3Interface(_xauUsdPriceFeed);
        lottery = IGoldLottery(_lottery);
    }

    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (
            /* uint80 roundID */,
            int256 price,
            /* uint256 startedAt */,
            /* uint256 timeStamp */,
            /* uint80 answeredInRound */
        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getEthUsdPrice() external view returns (uint256) {
        return getLatestPrice(ethUsdPriceFeed);
    }

    function getXauUsdPrice() external view returns (uint256) {
        return getLatestPrice(xauUsdPriceFeed);
    }

    function calculateGoldTokens(uint256 ethAmount) external view returns (uint256) {
        uint256 ethPrice = getLatestPrice(ethUsdPriceFeed);
        uint256 goldPrice = getLatestPrice(xauUsdPriceFeed);

        uint256 ethValueUsd = (ethAmount * ethPrice) / 10**18;
        uint256 commission = (ethValueUsd * COMMISSION_PERCENTAGE) / 100;
        uint256 lotteryAmount = (ethValueUsd * LOTTERY_PERCENTAGE) / 100;
        uint256 remainingValueUsd = ethValueUsd - commission - lotteryAmount;

        return (remainingValueUsd * 10**18) / goldPrice;
    }

    function mint() external payable {
        require(msg.value > 0, "Must send ETH");

        uint256 ethPrice = getLatestPrice(ethUsdPriceFeed);
        uint256 goldPrice = getLatestPrice(xauUsdPriceFeed);

        uint256 ethValueUsd = (msg.value * ethPrice) / 10**18;
        uint256 commission = (ethValueUsd * COMMISSION_PERCENTAGE) / 100;
        uint256 lotteryAmount = (ethValueUsd * LOTTERY_PERCENTAGE) / 100;
        uint256 remainingValueUsd = ethValueUsd - commission - lotteryAmount;

        uint256 goldTokens = (remainingValueUsd * 10**18) / goldPrice;

        // Lottery contribution
        if (address(lottery) != address(0)) {
            (bool success, ) = payable(address(lottery)).call{value: (msg.value * LOTTERY_PERCENTAGE) / 100}("");
            require(success, "Failed to send lottery contribution");
        }

        _mint(msg.sender, goldTokens);

        emit TokensMinted(msg.sender, msg.value, goldTokens);
    }

    function burn(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");

        uint256 ethPrice = getLatestPrice(ethUsdPriceFeed);
        uint256 goldPrice = getLatestPrice(xauUsdPriceFeed);

        uint256 tokenValueUsd = (amount * goldPrice) / 10**18;
        uint256 commission = (tokenValueUsd * COMMISSION_PERCENTAGE) / 100;
        uint256 remainingValueUsd = tokenValueUsd - commission;

        uint256 ethToReturn = (remainingValueUsd * 10**18) / ethPrice;

        _burn(msg.sender, amount);
        (bool success, ) = payable(msg.sender).call{value: ethToReturn}("");
        require(success, "Failed to send ETH");

        emit TokensBurned(msg.sender, amount, ethToReturn);
    }

    function updateBridgeContract(address _bridge) external onlyOwner {
        // Implement bridge contract update logic
    }

    function updatePriceFeeds(address _ethUsdFeed, address _xauUsdFeed) external onlyOwner {
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdFeed);
        xauUsdPriceFeed = AggregatorV3Interface(_xauUsdFeed);
    }

    receive() external payable {}
}