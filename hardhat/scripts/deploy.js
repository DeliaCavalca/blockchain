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

    // Get the contract factory for the 'Crowdsensing' contract
    const Crowdsensing = await ethers.getContractFactory("Crowdsensing");
    // Deploy the contract to the network: deploy with 10 ETH
    const crowdsensing = await Crowdsensing.deploy(accounts_address, {
        value: ethers.parseEther("10")
    });

    await crowdsensing.waitForDeployment();
    
    // Address of the contract
    console.log("Contract deployed to:", crowdsensing.target);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
