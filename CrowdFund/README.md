# CrowdFund Project

This project implements a decentralized crowdfunding platform with MYB token functionality.

## Project Structure

- `contract/`: Smart contracts for the CrowdFund platform
- `scripts/`: Deployment and utility scripts
- `test/`: Test files for the contracts
- `artifacts/`: Compiled contracts (auto-generated)
- `cache/`: Hardhat cache files (auto-generated)

## Getting Started

### Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- Hardhat

### Installation

```bash
cd CrowdFund
npm install
```

### Available Scripts

- `npm run compile`: Compile the smart contracts
- `npm run test`: Run the tests
- `npm run deploy`: Deploy to local network
- `npm run deploy:sepolia`: Deploy to Sepolia testnet
- `npm run deploy:mumbai`: Deploy to Mumbai testnet
- `npm run node`: Start a local Hardhat node
- `npm run coverage`: Run code coverage
- `npm run lint`: Run Solhint linter

## Key Contracts

- `MYBToken.sol`: ERC-20 token for the crowdfunding platform with 100,000 MYB initial supply
- `InvestorRegistry.sol`: Manages investor information and records
- `CrowdFundCore.sol`: Core functionality for creating and managing crowdfunding campaigns

## Configuration

Create a `.env` file based on `.env.example` with your network credentials:

```
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_infura_key
MUMBAI_RPC_URL=https://polygon-mumbai.infura.io/v3/your_infura_key
ETHERSCAN_API_KEY=your_etherscan_api_key
POLYGONSCAN_API_KEY=your_polygonscan_api_key
```