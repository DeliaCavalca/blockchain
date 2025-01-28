const { ethers } = require("hardhat");

async function main() {
    // Get the first account (deployer) from the Hardhat network
    const [deployer] = await ethers.getSigners();
    // Address of the account that is deploying the contract
    console.log("Deploying contracts with the account:", deployer.address);

    // Get the contract factory for the 'IPFSMessage' contract
    const IPFSMessage = await ethers.getContractFactory("IPFSMessage");
     // Deploy the contract to the network
    const ipfsMessage = await IPFSMessage.deploy();

    // Address of the contract
    console.log("Contract deployed to:", ipfsMessage.target);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
