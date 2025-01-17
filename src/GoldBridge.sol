// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts-ccip/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IGoldBridge.sol";
import "./interfaces/IGoldToken.sol";

/**
 * @title GoldBridge
 * @author 0xNaxzerrr
 * @notice Bridge contract for cross-chain token transfers using Chainlink CCIP
 * @dev Handles token transfers between Ethereum and BSC
 */
contract GoldBridge is IGoldBridge, UUPSUpgradeable, OwnableUpgradeable {
    using Client for Client.EVM2AnyMessage;

    // Immutable state variables
    IRouterClient private immutable i_router;
    LinkTokenInterface private immutable i_link;

    // State variables
    IGoldToken public token;
    mapping(uint64 => bool) public supportedChains;
    bool public paused;

    // BSC Chain Selector
    uint64 private constant BSC_CHAIN_SELECTOR = 13264668187771770619;
    
    /**
     * @dev Constructor to set immutable variables
     * @param _router CCIP router address
     * @param _link LINK token address
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _router, address _link) {
        i_router = IRouterClient(_router);
        i_link = LinkTokenInterface(_link);
        _disableInitializers();
    }

    /**
     * @notice Initializes the bridge contract
     * @param _token GoldToken address
     */
    function initialize(address _token) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        token = IGoldToken(_token);
        supportedChains[BSC_CHAIN_SELECTOR] = true;
    }

    /**
     * @notice Bridges tokens to another chain
     * @param destinationChainSelector Chain selector for the destination chain
     * @param receiver Address to receive tokens on the destination chain
     * @param amount Amount of tokens to bridge
     */
    function bridgeTokens(
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    ) external payable override {
        if (paused) revert BridgingPaused();
        if (!supportedChains[destinationChainSelector]) revert InvalidDestination();
        if (amount == 0) revert InvalidAmount();
        if (token.balanceOf(msg.sender) < amount) revert InsufficientBalance();
        if (receiver == address(0)) revert InvalidDestination();

        // Prepare the message
        bytes memory messageData = abi.encode(msg.sender, receiver, amount);
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            receiver,
            messageData,
            destinationChainSelector
        );

        // Get the fee for the CCIP transfer
        uint256 fees = i_router.getFee(destinationChainSelector, evm2AnyMessage);
        if (msg.value < fees) revert InsufficientFees();

        // Transfer the tokens to this contract
        token.transferFrom(msg.sender, address(this), amount);

        // Send the CCIP message
        bytes32 messageId = i_router.ccipSend{value: fees}(
            destinationChainSelector,
            evm2AnyMessage
        );

        emit TokensBridged(
            messageId,
            destinationChainSelector,
            msg.sender,
            receiver,
            amount,
            address(0), // Native token for fees
            fees
        );

        // Refund excess fees
        if (msg.value > fees) {
            (bool success, ) = msg.sender.call{value: msg.value - fees}("");
            require(success, "Fee refund failed");
        }
    }

    /**
     * @notice Builds a CCIP message
     * @param receiver Receiving address
     * @param messageData Encoded message data
     * @param destinationChainSelector Destination chain selector
     * @return CCIP message struct
     */
    function _buildCCIPMessage(
        address receiver,
        bytes memory messageData,
        uint64 destinationChainSelector
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        return Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: messageData,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200_000})
            ),
            feeToken: address(0) // Use native token for fees
        });
    }

    /**
     * @notice Receives CCIP messages
     * @param data The CCIP message data
     */
    function _ccipReceive(bytes memory data) external override {
        if (msg.sender != address(i_router)) revert NotAdmin();
        if (paused) revert BridgingPaused();

        (address sender, address receiver, uint256 amount) = abi.decode(
            data,
            (address, address, uint256)
        );

        if (receiver == address(0)) revert InvalidDestination();
        
        // Mint tokens to the receiver
        token.bridgeMint(receiver, amount);

        emit MessageReceived(
            bytes32(0), // Message ID not available in the receiver
            BSC_CHAIN_SELECTOR,
            sender,
            receiver,
            amount
        );
    }

    /**
     * @notice Gets supported chains
     * @return Array of supported chain selectors
     */
    function getSupportedChains() external view override returns (uint64[] memory) {
        uint256 count;
        uint64[] memory chains = new uint64[](2); // Max supported chains

        if (supportedChains[BSC_CHAIN_SELECTOR]) {
            chains[count++] = BSC_CHAIN_SELECTOR;
        }

        uint64[] memory result = new uint64[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = chains[i];
        }

        return result;
    }

    /**
     * @notice Gets fee estimate for bridging
     * @param destinationChainSelector Destination chain selector
     * @param receiver Receiving address
     * @param amount Amount to bridge
     * @return Fee estimate
     */
    function getFeeEstimate(
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    ) external view override returns (uint256) {
        bytes memory messageData = abi.encode(msg.sender, receiver, amount);
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            receiver,
            messageData,
            destinationChainSelector
        );

        return i_router.getFee(destinationChainSelector, evm2AnyMessage);
    }

    /**
     * @notice Pauses bridging operations
     */
    function pauseBridging() external override onlyOwner {
        paused = true;
        emit BridgingPausedEvent(msg.sender);
    }

    /**
     * @notice Resumes bridging operations
     */
    function resumeBridging() external override onlyOwner {
        paused = false;
        emit BridgingResumedEvent(msg.sender);
    }

    /**
     * @notice Adds a supported chain
     * @param chainSelector Chain selector to add
     */
    function addSupportedChain(uint64 chainSelector) external override onlyOwner {
        supportedChains[chainSelector] = true;
    }

    /**
     * @notice Removes a supported chain
     * @param chainSelector Chain selector to remove
     */
    function removeSupportedChain(uint64 chainSelector) external override onlyOwner {
        supportedChains[chainSelector] = false;
    }

    /**
     * @notice Withdraws stuck tokens
     * @param tokenAddress Token address to withdraw
     * @param recipient Address to receive tokens
     */
    function withdrawStuckTokens(
        address tokenAddress,
        address recipient
    ) external override onlyOwner {
        if (recipient == address(0)) revert InvalidDestination();

        if (tokenAddress == address(token)) {
            uint256 balance = token.balanceOf(address(this));
            token.transfer(recipient, balance);
        } else if (tokenAddress == address(0)) {
            uint256 balance = address(this).balance;
            (bool success, ) = recipient.call{value: balance}("");
            require(success, "Transfer failed");
        } else {
            uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
            IERC20(tokenAddress).transfer(recipient, balance);
        }
    }

    /**
     * @notice Required implementation by UUPS
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}
}