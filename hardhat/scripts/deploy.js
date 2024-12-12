async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const IPFSMessage = await ethers.getContractFactory("IPFSMessage");
    const ipfsMessage = await IPFSMessage.deploy();

    console.log("Contract deployed to:", ipfsMessage.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
