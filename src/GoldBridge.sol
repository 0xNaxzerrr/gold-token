// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";
import "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IGoldToken.sol";
import "./interfaces/IGoldBridge.sol";

contract GoldBridge is Initializable, OwnableUpgradeable, CCIPReceiver, IGoldBridge {
    IRouterClient public router;
    IERC20 public linkToken;
    IGoldToken public goldToken;

    mapping(uint64 => bool) public supportedChains;
    mapping(address => bool) public bridgeOperators;

    event TokensBridged(
        address indexed from, 
        uint64 indexed destinationChainSelector, 
        uint256 amount
    );
    event TokensReceived(
        bytes32 indexed messageId, 
        uint64 indexed sourceChainSelector, 
        address sender, 
        uint256 amount
    );

    constructor(
        address _router, 
        address _linkToken
    ) CCIPReceiver(_router) {
        router = IRouterClient(_router);
        linkToken = IERC20(_linkToken);
    }

    function initialize(address _goldTokenAddress) public initializer {
        __Ownable_init(msg.sender);
        goldToken = IGoldToken(_goldTokenAddress);
    }

    function bridgeTokens(
        uint64 destinationChainSelector,
        address recipient, 
        uint256 amount
    ) external payable {
        // Validate and perform cross-chain token transfer logic
        require(supportedChains[destinationChainSelector], "Unsupported destination chain");
        require(amount > 0, "Invalid bridge amount");

        // Approve tokens for bridge transfer
        goldToken.transferFrom(msg.sender, address(this), amount);
        
        // Estimate and collect bridge fees
        uint256 fees = getFeeEstimate(destinationChainSelector, recipient, amount);
        require(msg.value >= fees, "Insufficient bridge fees");

        // Perform token bridge using CCIP
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(recipient),
            data: abi.encode(amount),
            tokenAmounts: new Client.TokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });

        // Send cross-chain message
        bytes32 messageId = router.ccipSend{value: fees}(destinationChainSelector, message);

        emit TokensBridged(msg.sender, destinationChainSelector, amount);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        // Validate source chain
        require(supportedChains[message.sourceChainSelector], "Unsupported source chain");

        // Decode recipient and amount
        (address recipient, uint256 amount) = abi.decode(message.data, (address, uint256));

        // Mint tokens to recipient
        goldToken.mint(recipient, amount);

        emit TokensReceived(
            message.messageId, 
            message.sourceChainSelector, 
            abi.decode(message.sender, (address)), 
            amount
        );
    }

    function getFeeEstimate(
        uint64 destinationChainSelector,
        address recipient, 
        uint256 amount
    ) public view returns (uint256) {
        // Perform fee estimation for token bridge
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(recipient),
            data: abi.encode(amount),
            tokenAmounts: new Client.TokenAmount[](0),
            extraArgs: "",
            feeToken: address(0)
        });

        return router.getFee(destinationChainSelector, message);
    }

    function addSupportedChain(uint64 chainSelector) external onlyOwner {
        supportedChains[chainSelector] = true;
    }

    function removeSupportedChain(uint64 chainSelector) external onlyOwner {
        supportedChains[chainSelector] = false;
    }

    function updateRouter(address _router) external onlyOwner {
        router = IRouterClient(_router);
    }

    function updateLinkToken(address _linkToken) external onlyOwner {
        linkToken = IERC20(_linkToken);
    }

    receive() external payable {}
}