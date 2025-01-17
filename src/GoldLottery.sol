// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IGoldLottery.sol";

contract GoldLottery is 
    Initializable, 
    VRFConsumerBaseV2, 
    OwnableUpgradeable, 
    AutomationCompatibleInterface, 
    IGoldLottery 
{
    VRFCoordinatorV2Interface immutable COORDINATOR;
    
    // Lottery configuration
    uint256 public constant ENTRY_PRICE = 1 ether;
    uint256 public constant LOTTERY_DURATION = 7 days;

    // VRF Configuration
    bytes32 public keyHash;
    uint64 public subscriptionId;

    // Lottery state
    uint256 public currentRoundId;
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => address[]) public roundEntrants;
    mapping(address => uint256) public lastEntryRound;

    event LotteryRoundStarted(uint256 indexed roundId, uint256 startTime);
    event LotteryEntryReceived(address indexed entrant, uint256 indexed roundId);
    event LotteryWinnerSelected(uint256 indexed roundId, address winner, uint256 prize);

    constructor(
        address vrfCoordinator
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    }

    function initialize(
        address vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint256 duration,
        uint256 entryPrice
    ) public initializer {
        __Ownable_init(msg.sender);
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;

        currentRoundId = 1;
        rounds[currentRoundId].startTime = block.timestamp;
        
        emit LotteryRoundStarted(currentRoundId, block.timestamp);
    }

    function enterLottery() external payable {
        require(msg.value >= ENTRY_PRICE, "Insufficient entry fee");
        
        Round storage currentRound = rounds[currentRoundId];
        require(block.timestamp <= currentRound.startTime + LOTTERY_DURATION, "Lottery round expired");
        
        // Ensure user enters only once per round
        require(lastEntryRound[msg.sender] < currentRoundId, "Already entered this round");
        
        roundEntrants[currentRoundId].push(msg.sender);
        lastEntryRound[msg.sender] = currentRoundId;
        currentRound.prizePool += msg.value;
        
        emit LotteryEntryReceived(msg.sender, currentRoundId);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view override returns (bool upkeepNeeded, bytes memory performData) {
        Round memory currentRound = rounds[currentRoundId];
        upkeepNeeded = block.timestamp >= currentRound.startTime + LOTTERY_DURATION 
            && roundEntrants[currentRoundId].length > 0;
        
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        require(upkeepNeeded, "Upkeep not needed");

        // Request random winner
        COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            3, // Request confirmations
            500000, // Callback gas limit
            1 // Number of random words
        );
    }

    function fulfillRandomWords(
        uint256 /* requestId */, 
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % roundEntrants[currentRoundId].length;
        address winner = roundEntrants[currentRoundId][winnerIndex];
        
        Round storage currentRound = rounds[currentRoundId];
        uint256 prize = currentRound.prizePool;
        
        // Transfer prize to winner
        (bool success, ) = payable(winner).call{value: prize}("");
        require(success, "Prize transfer failed");
        
        emit LotteryWinnerSelected(currentRoundId, winner, prize);
        
        // Start new round
        currentRoundId++;
        rounds[currentRoundId].startTime = block.timestamp;
        
        emit LotteryRoundStarted(currentRoundId, block.timestamp);
    }

    function getCurrentRound() external view returns (uint256) {
        return currentRoundId;
    }

    function getRoundInfo(uint256 roundId) external view returns (Round memory) {
        return rounds[roundId];
    }

    receive() external payable {}
}