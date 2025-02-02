// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "./interfaces/IGoldLottery.sol";

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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _vrfCoordinator) VRFConsumerBaseV2(_vrfCoordinator) {}

    function initialize(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint256 _interval,
        uint256 _minimumPrize
    ) external initializer {
        require(_vrfCoordinator != address(0), "Invalid VRF coordinator");
        require(_interval >= MIN_DRAW_INTERVAL, "Interval too short");
        require(_interval <= MAX_DRAW_INTERVAL, "Interval too long");

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        if (_vrfCoordinator == address(0)) revert InvalidAddress();
        if (_interval < MIN_DRAW_INTERVAL || _interval > MAX_DRAW_INTERVAL)
            revert InvalidInterval(_interval);

        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        drawInterval = _interval;
        minimumPrizePool = _minimumPrize;

        _startNewRound();
    }

    error InvalidAddress();
    error InvalidInterval(uint256 interval);

    function receiveFunds() external payable override {
        require(msg.value > 0, "No funds sent");

        rounds[currentRoundId].prizePool += msg.value;

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

    function startNewRound() external override {
        require(
            msg.sender == address(this) || msg.sender == owner(),
            "Unauthorized"
        );
        _startNewRound();
    }

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

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal virtual override(VRFConsumerBaseV2) {
        require(randomWords.length > 0, "No random words");

        uint256 roundId = requestIdToRoundId[requestId];
        require(!rounds[roundId].isComplete, "Round already complete");

        address[] memory participants = roundParticipants[roundId];
        require(participants.length > 0, "No participants");

        uint256 winnerIndex = randomWords[0] % participants.length;
        address winner = participants[winnerIndex];

        rounds[roundId].winner = winner;
        rounds[roundId].isComplete = true;

        emit LotteryEnded(roundId, winner, rounds[roundId].prizePool);

        _startNewRound();
    }

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

    function checkUpkeep(
        bytes calldata checkData
    )
        external
        view
        override(IGoldLottery, AutomationCompatibleInterface)
        returns (bool upkeepNeeded, bytes memory performData)
    {
        Round memory currentRound = rounds[currentRoundId];
        upkeepNeeded =
            block.timestamp >= currentRound.endTime &&
            currentRound.prizePool >= minimumPrizePool &&
            !currentRound.isComplete &&
            roundParticipants[currentRoundId].length > 0;

        return (upkeepNeeded, "");
    }

    function performUpkeep(
        bytes calldata performData
    ) external override(IGoldLottery, AutomationCompatibleInterface) {
        (bool upkeepNeeded, ) = this.checkUpkeep("");
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

    function getCurrentRound() external view override returns (uint256) {
        return currentRoundId;
    }

    function getRoundInfo(
        uint256 roundId
    ) external view override returns (Round memory) {
        return rounds[roundId];
    }

    function getRoundParticipants(
        uint256 roundId
    ) external view returns (address[] memory) {
        return roundParticipants[roundId];
    }

    function setDrawInterval(uint256 _interval) external override onlyOwner {
        require(_interval >= MIN_DRAW_INTERVAL, "Interval too short");
        require(_interval <= MAX_DRAW_INTERVAL, "Interval too long");
        drawInterval = _interval;
    }

    function setMinimumPrizePool(uint256 _minimum) external override onlyOwner {
        minimumPrizePool = _minimum;
    }

    function emergencyWithdraw() external override onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    receive() external payable {
        this.receiveFunds();
    }
}
