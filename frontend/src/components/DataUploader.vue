<template>
  <div>
    <h1>Upload Data to IPFS</h1>
    <input type="file" @change="onFileChange">
    <input v-model="encryptionKey" placeholder="Encryption Key">
    <button @click="generateKey">Generate Key</button>
    <button @click="uploadToIpfs">Upload to IPFS</button>
    <p v-if="ipfsHash">IPFS Hash: {{ ipfsHash }}</p>
    <button @click="uploadData" :disabled="!ipfsHash || !encryptionKey">Upload Data to Blockchain</button>
    <p>{{ message }}</p>
  </div>
</template>

<script>
import { create as ipfsHttpClient } from 'ipfs-http-client';
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto

const client = ipfsHttpClient({ url: 'http://localhost:5001' });

export default {
  data() {
    return {
      file: null,
      ipfsHash: "",
      encryptionKey: "",
      message: "",
      contractAddress: "0x5fbdb2315678afecb367f032d93f642f64180aa3", // Indirizzo del contratto sulla blockchain
      signerAddress: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", // Sostituisci con l'indirizzo del tuo account Hardhat
      contract: null
    };
  },
  methods: {
    generateKey() {
      const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      let key = '';
      for (let i = 0; i < 32; i++) {
        const randomIndex = Math.floor(Math.random() * charset.length);
        key += charset.charAt(randomIndex);
      }
      this.encryptionKey = key;
      console.log("Generated Encryption Key:", this.encryptionKey);
    },
    // Gestisce il cambiamento del file
    onFileChange(event) {
      this.file = event.target.files[0];
    },
    // Carica il file su IPFS
    async uploadToIpfs() {
      try {
        console.log("Uploading file to IPFS...");
        const added = await client.add(this.file);
        this.ipfsHash = added.path; // Salva l'hash IPFS del file caricato
        console.log("File uploaded to IPFS with hash:", this.ipfsHash);
      } catch (error) {
        this.message = "Error uploading file to IPFS.";
        console.error("Error uploading file to IPFS:", error);
      }
    },
    // Converti la stringa hash IPFS in bytes32
    ipfsHashToBytes32(ipfsHash) {
      return ethers.utils.id(ipfsHash);
    },
    // Carica i dati sulla blockchain
    async uploadData() {
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
        const initialBalance = await provider.getBalance(this.signerAddress);
        console.log(`Initial Balance: ${ethers.utils.formatEther(initialBalance)} ETH`);

        console.log("Uploading data to blockchain...");
        const ipfsHashBytes32 = this.ipfsHashToBytes32(this.ipfsHash);
        const tx = await contractWithSigner.uploadData(ipfsHashBytes32, this.encryptionKey, {
          value: ethers.utils.parseEther("0.1")
        });
        console.log("Transaction sent:", tx);
        this.message = `Transaction sent: ${tx.hash}`;
        console.log("Transaction hash:", tx.hash);
        await tx.wait();
        console.log("Data uploaded successfully!");

        const finalBalance = await provider.getBalance(this.signerAddress);
        console.log(`Final Balance: ${ethers.utils.formatEther(finalBalance)} ETH`);

        this.message = `Data uploaded successfully! \nInitial Balance: ${ethers.utils.formatEther(initialBalance)} ETH\nFinal Balance: ${ethers.utils.formatEther(finalBalance)} ETH`;
      } catch (error) {
        if (error.code === ethers.errors.INSUFFICIENT_FUNDS) {
          this.message = "Error: Insufficient funds for gas.";
        } else if (error.code === ethers.errors.NONCE_EXPIRED) {
          this.message = "Error: Transaction nonce is too low.";
        } else if (error.code === ethers.errors.REPLACEMENT_UNDERPRICED) {
          this.message = "Error: Replacement transaction underpriced.";
        } else if (error.code === ethers.errors.NETWORK_ERROR) {
          this.message = "Error: Network error.";
        } else {
          this.message = "Error uploading data to blockchain.";
        }
        console.error("Error uploading data to blockchain:", error);
      }
    }
  }
};
</script>

<style>
/* Stili per il componente */
input[type="file"],
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