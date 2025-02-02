# Crowdsensing Platform with Smart Contracts & Blockchain

This project is a decentralized crowdsensing platform designed to collect, validate, and reward data submissions from users. It utilizes **smart contracts**, **blockchain technology (Ethereum)**, and **IPFS (InterPlanetary File System)** for secure, decentralized data storage and verification. The platform incentivizes both **data submitters** and **verifiers** while ensuring privacy and security through cryptographic techniques.

## Table of Contents

- [Project Overview](#project-overview)
- [Technologies Used](#technologies-used)
- [Setup Instructions](#setup-instructions)

## Project Overview

The platform enables users to participate in crowdsensing campaigns, submit data, and be rewarded for valid data contributions. The platform's core features include:

1. **Smart Contract Deployment:** 
   - Handles the creation of crowdsensing campaigns.
   - Manages user data submissions, verifications, and rewards.
   - Implements privacy protections using data encryption.
  
2. **Data Storage with IPFS:** 
   - Secure decentralized file storage for user-submitted data.
  
3. **User Role Management:** 
   - Differentiates between data submitters and verifiers.
  
4. **Incentive Mechanism:** 
   - Rewards both data submitters and verifiers for their contributions to the campaign.
  
5. **Blockchain for Transparency:** 
   - Uses Ethereum (via Hardhat for local testing) to ensure transparency and security of transactions.

## Technologies Used

- **Ethereum (Hardhat)** for smart contract development and testing.
- **IPFS** for decentralized file storage.
- **Solidity** for smart contract coding.
- **Vue.js** for the user interface (UI).
- **Node.js**, **Express.js** for backend interaction.

## Setup Instructions

Before running the project, ensure you have the following installed:

- **Node.js** (LTS version recommended)
- **npm** (comes with Node.js)
- **Hardhat** for local Ethereum network setup
- **IPFS Desktop**

### 1. Clone the Repository
```bash
git clone https://github.com/DeliaCavalca/blockchain.git
cd blockchain
```
### 2. Install Dependencies
```bash
npm install
```
### 3. Start Hardhat Node
Open a terminal in the hardhat/ directory and start the Hardhat local Ethereum network:
```bash
npx hardhat node
```
This command will start a local Ethereum network. It will generate 20 accounts with 10,000 ETH each, which can be used for testing.
### 4. Deploy the Smart Contract
In a new terminal, navigate to the hardhat/ directory and run the deployment script:
```bash
npx hardhat run scripts/deploy.js --network localhost
```
This will deploy the smart contract to the local Hardhat network. The contract address will be printed in the terminal. You'll need this address to interact with the contract from the frontend.
### 5. Run IPFS Daemon
In the main directory, run the following command to start the IPFS daemon:
```bash
ipfs daemon
```
This will start the IPFS service for decentralized file storage.
### 6. Run the Frontend
In the frontend/ directory, run the following command to start the frontend:
```bash
npm run serve
```
This will launch the frontend at http://localhost:8081, where you can interact with the platform and test the crowdsensing functionality.
