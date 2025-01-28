<template>
  <div style="font-size: 13px; text-align: left;">
    
    <p v-if="!selectedFileName" class="m-0 p-0">Seleziona il tuo file <span><strong>.txt </strong></span>:</p>
    <p v-else class="m-0 p-0">File selezionato: <span><strong>{{ selectedFileName }}</strong></span></p>


    <div class="">
      <label class="p-1 mt-1 custom-file-upload">
        <span>Scegli file</span>
        <input class="selectfileBtn" type="file" @change="onFileChange">
      </label>
    </div>

    <div class="mt-5">
      <input v-model="encryptionKey" placeholder="Encryption Key">
      <button class="mt-2 p-1" @click="generateKey">Generate Key</button>
    </div>

    <div class="mt-2">
      <button @click="uploadToIpfs">Upload to IPFS</button>
      <p v-if="ipfsHash">IPFS Hash: {{ ipfsHash }}</p>
      <button @click="uploadData" :disabled="!ipfsHash || !encryptionKey">Upload Data to Blockchain</button>
      <p>{{ message }}</p>
    </div>

    <div class="mt-5">
      <button class="btn uploadBtn mt-2 p-1" >Carica Dati</button>
    </div>

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
      contractAddress: null, // Indirizzo del Contratto
      userAddress: null, // Indirizzo dell'utente Ethereum

      file: null,
      selectedFileName: null,
      ipfsHash: "",
      encryptionKey: "",
      message: "",
      contract: null,

    };
  },

  created() {
    this.contractAddress = this.$store.state.contractAddress
    this.userAddress = this.$store.state.userAddress
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
      this.file = event.target.files[0]; // Ottieni il file selezionato
      if(this.file) {
        this.selectedFileName = this.file.name; // Aggiorna il nome del file
      } else {
        this.selectedFileName = null;
      }
    },

    // Carica il file su IPFS
    async uploadToIpfs() {
      try {
        if (!this.file) {
          throw new Error("No file selected");
        }

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
        
        provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
        contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);

        signer = provider.getSigner(this.userAddress);
        contractWithSigner = contract.connect(signer);

        const initialBalance = await provider.getBalance(this.userAddress);
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

        const finalBalance = await provider.getBalance(this.userAddress);
        const finalEthBalance = ethers.utils.formatEther(finalBalance); // Converte il saldo in ETH
        console.log(`Final Balance: ${finalEthBalance} ETH`);
        this.$store.commit('SET_ETH_BALANCE', finalEthBalance);

        console.log("DATA UPLOADED SUCCESSFULLY");
        
      } catch (error) {
        console.error("Error connecting to Ethereum provider:", error);
        return;
      }
      
    }
  }
};
</script>

<style scoped>

.custom-file-upload {
  display: inline-block;
  border: 1px solid #0d442b;
  border-radius: 3px;        
  cursor: pointer;           
  background-color: transparent; 
  transition: background-color 0.3s, color 0.3s; 
}
.custom-file-upload:hover {
  background-color: #0d442b;  
  color: white;              
}
.custom-file-upload input[type="file"] {
  display: none; /* Nascondi il vero input file */
}

.uploadBtn {
  display: block;
  font-size: 13px;
  border: 1px solid #0d442b;
  border-radius: 3px;        
  cursor: pointer;  
  background-color: transparent; 
  transition: background-color 0.3s, color 0.3s;   
}
.uploadBtn:hover {
  background-color: #0d442b;  
  color: white;              
}

</style>