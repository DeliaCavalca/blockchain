const { ethers } = require("hardhat");

async function main() {
    // Ottieni tutti gli account dal network Hardhat
    const accounts = await ethers.getSigners();

    // Il primo account è il "deployer"
    const deployer = accounts[0];
    console.log("Deploying contracts with the account:", deployer.address);

    let accounts_address = []
    for (let i = 0; i < accounts.length; i++) {
        accounts_address[i] = accounts[i].address
    }

    // Get the contract factory for the 'IPFSMessage' contract
    const IPFSMessage = await ethers.getContractFactory("IPFSMessage");
    // Deploy the contract to the network
    const ipfsMessage = await IPFSMessage.deploy(accounts_address);

    // Address of the contract
    console.log("Contract deployed to:", ipfsMessage.target);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
