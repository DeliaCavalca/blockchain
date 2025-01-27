<template>
  <div>
    <h1>Verify Data on Blockchain</h1>
    <input v-model="ipfsHash" placeholder="IPFS Hash">
    <input v-model="encryptionKey" placeholder="Encryption Key">
    <button @click="verifyAndCheckBalance">Verify</button>
    <p>{{ message }}</p>
  </div>
</template>

<script>
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto

export default {
  data() {
    return {
      ipfsHash: "",
      encryptionKey: "",
      message: "",
      contractAddress: "0x5fbdb2315678afecb367f032d93f642f64180aa3" // Indirizzo del contratto sulla blockchain
    };
  },
  methods: {
    // Converti la stringa hash IPFS in bytes32
    ipfsHashToBytes32(ipfsHash) {
      return ethers.utils.id(ipfsHash);
    },
    // Verifica i dati sulla blockchain e controlla il saldo
    async verifyAndCheckBalance() {
      if (!this.ipfsHash || !this.encryptionKey) {
        this.message = "IPFS hash and encryption key are required.";
        console.log(this.message);
        return;
      }

      let provider, contract, signer, contractWithSigner;

      try {
        console.log("Connecting to Ethereum provider...");
        provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
        console.log("Provider connected.");
      } catch (error) {
        this.message = "Error connecting to Ethereum provider.";
        console.error("Error connecting to Ethereum provider:", error);
        return;
      }

      try {
        console.log("Getting contract instance...");
        contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
        console.log("Contract instance obtained.");
      } catch (error) {
        this.message = "Error getting contract instance.";
        console.error("Error getting contract instance:", error);
        return;
      }

      try {
        console.log("Getting signer...");
        signer = provider.getSigner(0);
        console.log("Signer obtained. Address:", await signer.getAddress());
      } catch (error) {
        this.message = "Error getting signer.";
        console.error("Error getting signer:", error);
        return;
      }

      try {
        console.log("Connecting contract with signer...");
        contractWithSigner = contract.connect(signer);
        console.log("Contract connected with signer.");
      } catch (error) {
        this.message = "Error connecting contract with signer.";
        console.error("Error connecting contract with signer:", error);
        return;
      }

      try {
        const userAddress = await signer.getAddress();
        const initialBalance = await provider.getBalance(userAddress);
        console.log(`Initial Balance: ${ethers.utils.formatEther(initialBalance)} ETH`);

        console.log("Verifying data on blockchain...");
        const ipfsHashBytes32 = this.ipfsHashToBytes32(this.ipfsHash);
        const tx = await contractWithSigner.verifyData(ipfsHashBytes32, this.encryptionKey);
        console.log("Transaction sent:", tx.hash);
        this.message = `Transaction sent: ${tx.hash}`;
        console.log("Transaction hash:", tx.hash);
        await tx.wait();
        console.log("Data verified successfully!");

        const finalBalance = await provider.getBalance(userAddress);
        console.log(`Final Balance: ${ethers.utils.formatEther(finalBalance)} ETH`);

        this.message = `Data verified successfully! \nInitial Balance: ${ethers.utils.formatEther(initialBalance)} ETH\nFinal Balance: ${ethers.utils.formatEther(finalBalance)} ETH`;
      } catch (error) {
        this.message = "Error verifying data on blockchain.";
        console.error("Error verifying data on blockchain:", error);
      }
    }
  }
};
</script>

<style>
/* Stili per il componente */
input[type="text"],
button {
  display: block;
  margin: 10px 0;
}

button {
  padding: 10px 20px;
  background-color: #007bff;
  color: white;
  border: none;
  cursor: pointer;
}

button:disabled {
  background-color: #cccccc;
  cursor: not-allowed;
}
</style>