# Gold Token Protocol

A decentralized ERC20 token backed by physical gold, with cross-chain capabilities and an integrated lottery system.

## Features

- **Gold-Backed Token**: 1 GOLD token represents 1 gram of physical gold
- **Price Oracle**: Uses Chainlink price feeds for accurate ETH/USD and XAU/USD conversion
- **Cross-Chain Bridge**: Enables token transfers between Ethereum and BSC using Chainlink CCIP
- **Lottery System**: Integrated lottery with Chainlink VRF for fair winner selection
- **Automated Draws**: Chainlink Automation for automatic lottery draws
- **UUPS Upgradeable**: Contracts can be upgraded to add new features
- **Safe Operations**: Built with security best practices and comprehensive testing

## Architecture

### Smart Contracts

1. **GoldToken.sol**
   - ERC20 implementation
   - Price feed integration
   - Minting and burning logic
   - Commission handling

2. **GoldLottery.sol**
   - VRF integration for randomness
   - Automated draws with Chainlink Automation
   - Prize distribution system

3. **GoldBridge.sol**
   - CCIP integration for cross-chain transfers
   - Chain-specific token management
   - Fee handling

## Development

### Prerequisites

- [Foundry](https://github.com/foundry-rs/foundry)
- [Node.js](https://nodejs.org/) (>=14.0.0)
- [Yarn](https://yarnpkg.com/) or [npm](https://www.npmjs.com/)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/0xNaxzerrr/gold-token.git
cd gold-token
```

2. Install dependencies:
```bash
forge install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

### Testing

Run all tests:
```bash
forge test
```

Run specific test file:
```bash
forge test --match-path test/GoldToken.t.sol
```

Run with gas reporting:
```bash
forge test --gas-report
```

Run fork tests:
```bash
forge test --fork-url $ETH_RPC_URL
```

### Deployment

1. Local deployment:
```bash
forge script script/Deploy.s.sol:DeployScript --fork-url localhost --broadcast
```

2. Mainnet deployment:
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $ETH_RPC_URL --broadcast --verify
```

3. BSC deployment:
```bash
forge script script/Deploy.s.sol:DeployGoldBSC --rpc-url $BSC_RPC_URL --broadcast --verify
```

## Protocol Usage

### Minting Tokens

Users can mint GOLD tokens by sending ETH to the contract:
```solidity
// Amount of GOLD tokens received is based on:
// 1. Current ETH/USD price
// 2. Current XAU/USD price
// 3. 5% commission deduction
// 4. 50% of remaining for token minting
function mint() external payable;
```

### Burning Tokens

Users can burn their GOLD tokens to receive ETH:
```solidity
// Amount of ETH received is based on:
// 1. Current token/gold ratio (1:1)
// 2. Current XAU/USD price
// 3. Current ETH/USD price
// 4. 5% commission deduction
function burn(uint256 amount) external;
```

### Cross-Chain Bridging

Transfer tokens between Ethereum and BSC:
```solidity
// Fees are paid in native token (ETH/BNB)
function bridgeTokens(
    uint64 destinationChainSelector,
    address receiver,
    uint256 amount
) external payable;
```

### Lottery Participation

Lottery entries are automatic with minting:
```solidity
// 50% of remaining ETH after commission goes to lottery
// Draws occur automatically every 7 days
// Winners selected using Chainlink VRF
```

## Security

### Audit Status

This protocol is not audited yet. Use at your own risk.

### Security Features

1. **Price Feed Safety**
   - Chainlink price feed heartbeat monitoring
   - Fallback mechanisms for price feed failures
   - Price sanity checks

2. **Access Control**
   - Role-based access control
   - Owner-only sensitive functions
   - Time-locks for critical operations

3. **Bridge Security**
   - CCIP message verification
   - Supported chains whitelist
   - Emergency pause functionality

4. **Lottery Fairness**
   - VRF-based randomness
   - Automated, tamper-proof draws
   - Transparent prize distribution

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- OpenZeppelin for their secure contract implementations
- Chainlink for their oracle infrastructure
- Foundry for their development framework