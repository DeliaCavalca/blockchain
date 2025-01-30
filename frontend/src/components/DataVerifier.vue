<template>
  <div style="font-size: 13px; text-align: left;">
    
    <p v-if="fileToVerifyList.length > 0" class="m-0 p-0 mb-3">File da validare:</p>
    <p v-else class="m-0 p-0">Nessun file da validare.</p>

    <div v-for="(file, index) in fileToVerifyList" :key="file.hash" class="file-item">
      <span><strong>File {{ index + 1 }}</strong></span>
      <a :href="file.url" target="_blank">Vedi File</a>
      <button class="custom-btn" @click="validateFile(file.hash)">Valida</button>
      <button class="custom-btn-2" @click="deleteFile(file.hash)">Elimina</button>
    </div>

  </div>
</template>

<script>
import { create as ipfsHttpClient } from 'ipfs-http-client';
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto
import eventBus from '@/eventBus';
import CryptoJS from "crypto-js";

const client = ipfsHttpClient({ url: 'http://localhost:5001' });

export default {
  data() {
    return {
      contractAddress: null, // Indirizzo del Contratto
      userAddress: null, // Indirizzo dell'utente Ethereum

      ipfsHash: "",
      encryptionKey: "",
      hashToVerifyList: [],
      fileToVerifyList: [],
    };
  },

  created() {
    this.contractAddress = this.$store.state.contractAddress
    this.userAddress = this.$store.state.userAddress

    this.getUnverifiedFile();

    // manage the event showAlertSuccessLoad
    eventBus.on('showAlertSuccessLoad', () => {
      this.getUnverifiedFile();
    });
  },

  methods: {

    // Converti la stringa hash IPFS in bytes32
    /*
    ipfsHashToBytes32(ipfsHash) {
      return ethers.utils.id(ipfsHash);
    },*/

    // Ottenere l'elenco di hash da verificare dallo SC
    async getUnverifiedHash() {
      let provider, contract;

      try {
        provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
        contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
        
        // Ottieni gli hash in formato bytes32
        const unverifiedHashes = await contract.getUnverifiedData();
        console.log("Unverified IPFS Hashes:", unverifiedHashes.length);

        this.hashToVerifyList = unverifiedHashes;
        
        return;
      } catch (error) {
        console.error("Error fetching unverified hashes:", error);
        return;
      }
    },

    // Ottenere l'elenco di file da verificare da IPFS
    async getUnverifiedFile() {
      await this.getUnverifiedHash()

      if (this.hashToVerifyList.length === 0) {
        console.log("Nessun file da validare");
        return;
      }

      // Imposta il provider e il contratto una sola volta
      const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
      const contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);


      const files = await Promise.all(
        this.hashToVerifyList.map(async (ipfsHash) => {
            try {

              const encryptedKey = await contract.getEncryptedKey(ipfsHash);
              console.log("Encrypted Key:", encryptedKey);

              // Recupera il file da IPFS, usando il CID
              const stream = client.cat(ipfsHash);
              
              let data = new Uint8Array();
              for await (const chunk of stream) {
                data = new Uint8Array([...data, ...chunk]); // Concatena i chunk ricevuti
              }

              // Converti il Uint8Array in una stringa
              const fileContent = new TextDecoder().decode(data);
              console.log(`Contenuto del file (${ipfsHash}):`, fileContent);

              const decryptedData = this.decryptFile(fileContent, encryptedKey);
              
              const blob = new Blob([decryptedData], { type: "application/octet-stream" });
              return { hash: ipfsHash, url: URL.createObjectURL(blob) };

            } catch (error) {
                console.error(`Errore nel download del file IPFS con hash ${ipfsHash}:`, error);
                return null;
            }
        })
      );

      this.fileToVerifyList = files.filter(file => file !== null);
      return;

    }
    ,

    /**
     * Decripta il file con la chiave fornita
     * @param {string} encryptedBase64 - File criptato in Base64
     * @param {string} key - Chiave di decrittografia
     * @returns {Uint8Array} - File decriptato come dati binari
     */
    decryptFile(encryptedBase64, key) {
      try {

        console.log("Chiave passata:",key);
        // Decripta usando AES e la chiave fornita
        const decryptedBytes = CryptoJS.AES.decrypt(encryptedBase64, key);

        // Verifica se la decrittografia ha prodotto dei dati
        if (!decryptedBytes || !decryptedBytes.words) {
          throw new Error("Decryption failed. Check your key and data format.");
        }

        // Converte i dati decriptati in un array di byte (Uint8Array)
        const decryptedData = this.wordsToByteArray(decryptedBytes.words);

        console.log("Decrypted Data (binary):", decryptedData);

        // Ritorna i dati binari decriptati come Uint8Array
        return new Uint8Array(decryptedData);
      } catch (error) {
        console.error("Decryption error:", error);
        throw error;
      }
    },

    /**
     * Converte un array di parole (CryptoJS) in un array di byte
     * @param {Array} words - Array di parole (oggetti WordArray)
     * @returns {Array} - Array di byte
     */
    wordsToByteArray(words) {
      const byteArray = [];
      for (let i = 0; i < words.length; i++) {
        const word = words[i];
        byteArray.push((word >> 24) & 0xff);
        byteArray.push((word >> 16) & 0xff);
        byteArray.push((word >> 8) & 0xff);
        byteArray.push(word & 0xff);
      }
      return byteArray;
    },


    // Valida un file
    async validateFile(hash) {
      if(!hash) {
        console.log("Errore durante la validazione. Hash non valido.");
        return;
      }

      // Validare il file
      let provider, contract, signer, contractWithSigner;

      try {
        provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
        contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);

        // Ottieni la Chiave
        const key = await contract.getEncryptedKey(hash);

        if(!key) {
          console.log("Errore durante la validazione. Key non valida.");
          return;
        }

        signer = provider.getSigner(this.userAddress);
        contractWithSigner = contract.connect(signer);

        const initialBalance = await provider.getBalance(this.userAddress);
        console.log(`Initial Balance of User: ${ethers.utils.formatEther(initialBalance)} ETH`);

        const initBalanceContratc = await contractWithSigner.getContractBalance();
        const initBalanceContratcStr = ethers.utils.formatEther(initBalanceContratc);
        console.log("FONDI del Contratto PRIMA della Validazione:", initBalanceContratcStr);

        // Valida il File
        // Rimborso al'utente che ha caricato i dati
        // Ricompensa al verficatore
        const tx = await contractWithSigner.verifyData(hash, key);
        console.log("Transaction hash:", tx.hash);
        await tx.wait();

        console.log("DATA VERIFIED SUCCESSFULLY!");

        // Controlla e Aggiorna il Balance dell'utente
        /**  
         * TODO: viene aggiornato/ottenuto il saldo di user che crea la transazione o del verifier??
        
        */
        const finalBalance = await provider.getBalance(this.userAddress);
        const finalEthBalance = ethers.utils.formatEther(finalBalance); // Converte il saldo in ETH
        console.log(`Final Balance of User: ${finalEthBalance} ETH`);
        this.$store.commit('SET_ETH_BALANCE', finalEthBalance);

        const finalBalanceContratc = await contractWithSigner.getContractBalance();
        const finalBalanceContratcStr = ethers.utils.formatEther(finalBalanceContratc);
        console.log("FONDI del Contratto DOPO la Validazione:", finalBalanceContratcStr);


        // Ottieni e Aggiorna lo Stato della campagna
        const status = await contractWithSigner.getCampaignStatus();
        console.log("Stato della campagna: ", status);
        this.$store.commit('SET_STATUS', status);

        // Aggiorna la lista dei file da validare
        this.getUnverifiedFile();

      } catch (error) {
        console.error("Error connecting to Ethereum provider:", error);
        return;
      }

    }


  }
};
</script>

<style scoped>

.file-item {
  display: flex;
  align-items: center;
  gap: 20px; /* Distanza tra gli elementi */
  margin-top: 5px;
}
.file-item:hover {
  background-color: rgb(238, 235, 235);
}

</style>