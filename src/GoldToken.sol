// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IGoldLottery.sol";
import "./interfaces/IGoldToken.sol";

/**
 * @title GoldToken
 * @author 0xNaxzerrr
 * @notice ERC20 token backed by physical gold using Chainlink Oracles for conversion
 * @dev This contract implements an ERC20 token that can be minted in exchange for ETH
 * The token value is based on the gold price (XAU/USD) and ETH/USD rate
 */
contract GoldToken is IGoldToken, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    // Chainlink Price Feed Interfaces
    AggregatorV3Interface public ethUsdPriceFeed;
    AggregatorV3Interface public xauUsdPriceFeed;

    // Lottery and Bridge contracts
    IGoldLottery public lotteryContract;
    address public bridgeContract;

    // State variables
    uint256 public constant COMMISSION_RATE = 500; // 5% = 500 basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant GOLD_DECIMALS = 18;
    
    // Price feed heartbeat
    uint256 public constant PRICE_FEED_TIMEOUT = 1 hours;
    
    /**
     * @dev Constructor disabled as using upgradeable pattern
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with price feeds and lottery contract addresses
     * @param _ethUsdPriceFeed ETH/USD price feed address
     * @param _xauUsdPriceFeed XAU/USD price feed address
     * @param _lotteryContract Lottery contract address
     */
    function initialize(
        address _ethUsdPriceFeed,
        address _xauUsdPriceFeed,
        address _lotteryContract
    ) public initializer {
        __ERC20_init("GoldToken", "GOLD");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        require(_ethUsdPriceFeed != address(0), "Invalid ETH/USD feed");
        require(_xauUsdPriceFeed != address(0), "Invalid XAU/USD feed");
        require(_lotteryContract != address(0), "Invalid lottery");

        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        xauUsdPriceFeed = AggregatorV3Interface(_xauUsdPriceFeed);
        lotteryContract = IGoldLottery(_lotteryContract);
    }

    /**
     * @notice Gets the latest ETH/USD price from Chainlink
     * @return price The ETH/USD price
     */
    function getEthUsdPrice() public view returns (uint256) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = ethUsdPriceFeed.latestRoundData();

        require(answer > 0, "Negative ETH/USD price");
        require(block.timestamp - updatedAt <= PRICE_FEED_TIMEOUT, "Stale ETH price");
        require(answeredInRound >= roundId, "ETH price round not complete");

        return uint256(answer);
    }

    /**
     * @notice Gets the latest XAU/USD price from Chainlink
     * @return price The XAU/USD price
     */
    function getXauUsdPrice() public view returns (uint256) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = xauUsdPriceFeed.latestRoundData();

        require(answer > 0, "Negative XAU/USD price");
        require(block.timestamp - updatedAt <= PRICE_FEED_TIMEOUT, "Stale gold price");
        require(answeredInRound >= roundId, "Gold price round not complete");

        return uint256(answer);
    }

    /**
     * @notice Calculates the amount of GOLD tokens to mint based on ETH sent
     * @param ethAmount Amount of ETH sent
     * @return goldTokens Amount of GOLD tokens to mint
     */
    function calculateGoldTokens(uint256 ethAmount) public view returns (uint256) {
        uint256 ethUsdPrice = getEthUsdPrice();
        uint256 xauUsdPrice = getXauUsdPrice();
        
        // Calculate USD value of sent ETH
        uint256 ethDecimals = 18;
        uint256 usdValue = (ethAmount * ethUsdPrice) / 10**ethDecimals;
        
        // Apply 5% commission
        uint256 commissionAmount = (usdValue * COMMISSION_RATE) / BASIS_POINTS;
        uint256 remainingUsdValue = usdValue - commissionAmount;
        
        // 50% of remaining amount for tokens
        uint256 tokenUsdValue = remainingUsdValue / 2;
        
        // Convert to GOLD tokens (1 GOLD = 1 gram of gold)
        uint256 priceDecimals = 8; // Chainlink price feeds use 8 decimals
        return (tokenUsdValue * 10**GOLD_DECIMALS) / (xauUsdPrice * 10**(priceDecimals - 8));
    }

    /**
     * @notice Allows users to mint GOLD tokens by sending ETH
     */
    function mint() external payable {
        require(msg.value > 0, "Must send ETH");
        
        uint256 goldTokens = calculateGoldTokens(msg.value);
        require(goldTokens > 0, "Invalid token amount");

        // Calculate commission and lottery amount (50% each after commission)
        uint256 commission = (msg.value * COMMISSION_RATE) / BASIS_POINTS;
        uint256 lotteryAmount = (msg.value - commission) / 2;
        uint256 remainingCommission = msg.value - lotteryAmount - commission;

        // Mint tokens
        _mint(msg.sender, goldTokens);

        // Send to lottery
        (bool success, ) = address(lotteryContract).call{value: lotteryAmount}("");
        require(success, "Lottery transfer failed");

        emit TokensMinted(msg.sender, msg.value, goldTokens);
    }

    /**
     * @notice Allows users to burn their GOLD tokens and receive ETH
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 ethUsdPrice = getEthUsdPrice();
        uint256 xauUsdPrice = getXauUsdPrice();

        // Calculate USD value of tokens
        uint256 usdValue = (amount * xauUsdPrice) / 10**GOLD_DECIMALS;
        
        // Convert to ETH
        uint256 ethAmount = (usdValue * 10**18) / ethUsdPrice;
        
        // Apply 5% commission
        uint256 commissionAmount = (ethAmount * COMMISSION_RATE) / BASIS_POINTS;
        uint256 returnAmount = ethAmount - commissionAmount;

        require(address(this).balance >= returnAmount, "Insufficient ETH in contract");

        // Burn tokens
        _burn(msg.sender, amount);

        // Transfer ETH
        (bool success, ) = msg.sender.call{value: returnAmount}("");
        require(success, "ETH transfer failed");

        emit TokensBurned(msg.sender, amount, returnAmount);
    }

    /**
     * @notice Allows bridge contract to mint tokens
     * @param user Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function bridgeMint(address user, uint256 amount) external {
        require(msg.sender == bridgeContract, "Only bridge can mint");
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be > 0");

        _mint(user, amount);
    }

    /**
     * @notice Allows bridge contract to burn tokens
     * @param user Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function bridgeBurn(address user, uint256 amount) external {
        require(msg.sender == bridgeContract, "Only bridge can burn");
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be > 0");
        require(balanceOf(user) >= amount, "Insufficient balance");

        _burn(user, amount);
    }

    /**
     * @notice Updates the bridge contract address
     * @param _bridgeContract New bridge contract address
     */
    function updateBridgeContract(address _bridgeContract) external onlyOwner {
        require(_bridgeContract != address(0), "Invalid bridge address");
        bridgeContract = _bridgeContract;
    }

    /**
     * @notice Allows owner to update price feed addresses
     * @param _ethUsdPriceFeed New ETH/USD price feed address
     * @param _xauUsdPriceFeed New XAU/USD price feed address
     */
    function updatePriceFeeds(
        address _ethUsdPriceFeed,
        address _xauUsdPriceFeed
    ) external onlyOwner {
        require(_ethUsdPriceFeed != address(0), "Invalid ETH/USD address");
        require(_xauUsdPriceFeed != address(0), "Invalid XAU/USD address");
        
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        xauUsdPriceFeed = AggregatorV3Interface(_xauUsdPriceFeed);
    }

    /**
     * @notice Allows owner to update the lottery contract address
     * @param _lotteryContract New lottery contract address
     */
    function updateLotteryContract(address _lotteryContract) external onlyOwner {
        require(_lotteryContract != address(0), "Invalid lottery address");
        lotteryContract = IGoldLottery(_lotteryContract);
    }

    /**
     * @notice Allows owner to withdraw accumulated fees
     */
    function withdrawCommissions() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No commissions to withdraw");
        
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Commission withdrawal failed");
    }

    /**
     * @notice Required implementation by UUPS
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}
}