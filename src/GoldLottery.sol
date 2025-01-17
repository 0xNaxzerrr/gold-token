// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "./interfaces/IGoldLottery.sol";

/**
 * @title GoldLottery
 * @author 0xNaxzerrr
 * @notice Lottery contract that uses Chainlink VRF for random number generation and Automation for automated draws
 * @dev This contract implements a lottery system with automatic draws and VRF-based winner selection
 */
contract GoldLottery is 
    IGoldLottery, 
    UUPSUpgradeable, 
    OwnableUpgradeable, 
    VRFConsumerBaseV2,
    AutomationCompatibleInterface
{
    // VRF Coordinator
    VRFCoordinatorV2Interface private vrfCoordinator;
    bytes32 private keyHash;
    uint64 private subscriptionId;
    uint32 private constant CALLBACK_GAS_LIMIT = 100000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Lottery Settings
    uint256 private drawInterval;
    uint256 private minimumPrizePool;
    mapping(uint256 => address[]) private roundParticipants;
    
    // Round management
    uint256 private currentRoundId;
    mapping(uint256 => Round) private rounds;
    mapping(uint256 => uint256) private requestIdToRoundId;
    
    // Constants
    uint256 private constant MIN_DRAW_INTERVAL = 1 days;
    uint256 private constant MAX_DRAW_INTERVAL = 30 days;
    
    /**
     * @dev Constructor disabled as using upgradeable pattern
     * @param _vrfCoordinator VRF Coordinator V2 address
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _vrfCoordinator) VRFConsumerBaseV2(_vrfCoordinator) {
        _disableInitializers();
    }

    /**
     * @notice Initializes the lottery contract
     * @param _vrfCoordinator VRF coordinator address
     * @param _keyHash VRF key hash
     * @param _subscriptionId VRF subscription ID
     * @param _interval Time between lottery draws
     * @param _minimumPrize Minimum prize pool for a draw
     */
    function initialize(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint256 _interval,
        uint256 _minimumPrize
    ) public initializer {
        require(_vrfCoordinator != address(0), "Invalid VRF coordinator");
        require(_interval >= MIN_DRAW_INTERVAL, "Interval too short");
        require(_interval <= MAX_DRAW_INTERVAL, "Interval too long");
        
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        drawInterval = _interval;
        minimumPrizePool = _minimumPrize;
        
        // Initialize first round
        _startNewRound();
    }

    /**
     * @notice Receives funds for the lottery
     */
    function receiveFunds() external payable override {
        require(msg.value > 0, "No funds sent");
        
        // Add to current round's prize pool
        rounds[currentRoundId].prizePool += msg.value;
        
        // Add sender to participants if not already included
        address[] storage participants = roundParticipants[currentRoundId];
        bool isNewParticipant = true;
        
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == msg.sender) {
                isNewParticipant = false;
                break;
            }
        }
        
        if (isNewParticipant) {
            participants.push(msg.sender);
        }
        
        emit FundsReceived(msg.sender, msg.value);
    }

    /**
     * @notice Starts a new lottery round
     * @dev Can only be called by the contract itself or the owner
     */
    function startNewRound() external override {
        require(msg.sender == address(this) || msg.sender == owner(), "Unauthorized");
        _startNewRound();
    }

    /**
     * @notice Internal function to start a new round
     */
    function _startNewRound() private {
        currentRoundId++;
        rounds[currentRoundId] = Round({
            startTime: block.timestamp,
            endTime: block.timestamp + drawInterval,
            prizePool: 0,
            winner: address(0),
            isComplete: false,
            prizeClaimed: false
        });
        
        emit LotteryStarted(currentRoundId, block.timestamp);
    }

    /**
     * @notice Callback function used by VRF Coordinator
     * @param requestId ID of the VRF request
     * @param randomWords Random numbers from VRF
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        require(randomWords.length > 0, "No random words");
        
        uint256 roundId = requestIdToRoundId[requestId];
        require(!rounds[roundId].isComplete, "Round already complete");
        
        address[] memory participants = roundParticipants[roundId];
        require(participants.length > 0, "No participants");
        
        // Select winner
        uint256 winnerIndex = randomWords[0] % participants.length;
        address winner = participants[winnerIndex];
        
        rounds[roundId].winner = winner;
        rounds[roundId].isComplete = true;
        
        emit LotteryEnded(roundId, winner, rounds[roundId].prizePool);
        
        // Start new round
        _startNewRound();
    }

    /**
     * @notice Allows winner to claim their prize
     * @param roundId ID of the round to claim prize for
     */
    function claimPrize(uint256 roundId) external override {
        Round storage round = rounds[roundId];
        require(round.isComplete, "Round not complete");
        require(round.winner == msg.sender, "Not winner");
        require(!round.prizeClaimed, "Prize already claimed");
        
        round.prizeClaimed = true;
        uint256 prize = round.prizePool;
        
        (bool success, ) = msg.sender.call{value: prize}("");
        require(success, "Transfer failed");
        
        emit PrizeWithdrawn(msg.sender, prize);
    }

    /**
     * @notice Chainlink Automation compatible checkUpkeep function
     * @param checkData Additional data for upkeep check
     * @return upkeepNeeded Whether upkeep is needed
     * @return performData Data to be used in performUpkeep
     */
    function checkUpkeep(
        bytes calldata checkData
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        Round memory currentRound = rounds[currentRoundId];
        upkeepNeeded = block.timestamp >= currentRound.endTime && 
                       currentRound.prizePool >= minimumPrizePool &&
                       !currentRound.isComplete &&
                       roundParticipants[currentRoundId].length > 0;
        
        return (upkeepNeeded, "");
    }

    /**
     * @notice Chainlink Automation compatible performUpkeep function
     * @param performData Data from checkUpkeep
     */
    function performUpkeep(bytes calldata performData) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        require(upkeepNeeded, "Upkeep not needed");

        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
        
        requestIdToRoundId[requestId] = currentRoundId;
    }

    /**
     * @notice Get current round information
     * @return Current round ID
     */
    function getCurrentRound() external view override returns (uint256) {
        return currentRoundId;
    }

    /**
     * @notice Get round information
     * @param roundId ID of the round
     * @return Round information
     */
    function getRoundInfo(uint256 roundId) external view override returns (Round memory) {
        return rounds[roundId];
    }

    /**
     * @notice Get participants for a specific round
     * @param roundId ID of the round
     * @return Array of participant addresses
     */
    function getRoundParticipants(uint256 roundId) external view returns (address[] memory) {
        return roundParticipants[roundId];
    }

    /**
     * @notice Updates the draw interval
     * @param _interval New interval duration
     */
    function setDrawInterval(uint256 _interval) external override onlyOwner {
        require(_interval >= MIN_DRAW_INTERVAL, "Interval too short");
        require(_interval <= MAX_DRAW_INTERVAL, "Interval too long");
        drawInterval = _interval;
    }

    /**
     * @notice Updates the minimum prize pool
     * @param _minimum New minimum amount
     */
    function setMinimumPrizePool(uint256 _minimum) external override onlyOwner {
        minimumPrizePool = _minimum;
    }

    /**
     * @notice Emergency function to withdraw stuck funds
     * @dev Only callable by owner
     */
    function emergencyWithdraw() external override onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Required by UUPS
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Receive function to accept ETH payments
     */
    receive() external payable {
        receiveFunds();
    }
}