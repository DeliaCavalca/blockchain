async function main() {
    // Imposta il provider e l'indirizzo del contratto
    const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545/");
    const contractAddress = "0x5fbdb2315678afecb367f032d93f642f64180aa3"; // Indirizzo del contratto
    const contractABI = [
        // ABI del contratto HelloWorld, che dovrebbe includere il metodo `getMessage`
        {
            "inputs": [],
            "name": "getMessage",
            "outputs": [
                {
                    "internalType": "string",
                    "name": "",
                    "type": "string"
                }
            ],
            "stateMutability": "view",
            "type": "function"
        }
    ];

    // Connessione al contratto
    const contract = new ethers.Contract(contractAddress, contractABI, provider);

    // Chiamata al contratto
    const message = await contract.getMessage();
    console.log("Message from contract:", message);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
