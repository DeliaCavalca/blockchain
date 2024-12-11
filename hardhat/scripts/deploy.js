async function main() {
    // Ottieni il provider (a questo punto è importante che il provider sia correttamente configurato)
    const [deployer] = await ethers.getSigners();  // Questo è il "signer" che effettua la transazione
    console.log("Deploying contracts with the account:", deployer.address);

    // Ottieni il contratto HelloWorld
    const HelloWorld = await ethers.getContractFactory("HelloWorld");

    // Distribuisci il contratto
    const helloWorld = await HelloWorld.deploy();
    console.log("HelloWorld deployed to:", helloWorld.address);  // Qui stiamo stampando l'indirizzo del contratto
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
