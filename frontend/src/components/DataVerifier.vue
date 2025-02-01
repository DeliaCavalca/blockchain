<template>
  <div style="font-size: 13px; text-align: left;">
    
    <p v-if="fileToVerifyList.length > 0" class="m-0 p-0 mb-3">File da validare:</p>
    <p v-else class="m-0 p-0">Nessun file da validare.</p>

    <div v-for="(file, index) in fileToVerifyList" :key="file.hash">
      <div class="file-item mt-3">
        <span><strong>File {{ index + 1 }}</strong></span>
        <a :href="processedFileUrl" @click.prevent="prepareDownload(file)" target="_blank">Vedi File</a>
        <button class="custom-btn" @click="validateFile(file.hash, true)" :disabled="file.validationError != ''">Valida</button>
        <button class="custom-btn-2" @click="validateFile(file.hash, false)">Scarta</button>
      </div>
      <p v-if="file.validationError != ''" class="m-0 p-0" style="color: darkred; font-weight: bold; font-size: 12px;">{{ file.validationError }}</p>
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
      processedFileUrl: null,
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
      await this.getUnverifiedHash();

      if (this.hashToVerifyList.length === 0) {
        console.log("Nessun file da validare");
        this.fileToVerifyList = [];
        return;
      }

      // Imposta il provider e il contratto una sola volta
      const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
      const contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);

      const files = await Promise.all(
        this.hashToVerifyList.map(async (ipfsHash) => {
            try {

              // Recupera la chiave AES con la quale è stato criptato il file
              const encryptedKey = await contract.getEncryptedKey(ipfsHash, this.userAddress);
              console.log("GET Encrypted Key:", encryptedKey);

              // Recupera il file da IPFS, usando il CID
              const stream = client.cat(ipfsHash);
              
              let data = new Uint8Array();
              for await (const chunk of stream) {
                data = new Uint8Array([...data, ...chunk]); // Concatena i chunk ricevuti
              }

              // Converti il Uint8Array in una stringa
              const fileContent = new TextDecoder().decode(data);
              console.log(`Contenuto del file PRIMA di DECRIPT (${ipfsHash}):`, fileContent);

              // Decodifica il file, usando la sua chiave AES
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
      await this.validateGeoDataForAllFiles();  // Esegui la validazione per ogni file caricato

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

        console.log("Chiave passata:", key);
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


    // Funzione per validare in automatico tutti i file caricati
    async validateGeoDataForAllFiles() {
      this.fileToVerifyList.forEach(async file => {
        
        const validationResult = await this.validateGeoData(file);

        if (validationResult) {
          file.validationError = '';  // Se valido, rimuovi eventuali errori
        } else {
          file.validationError = 'Attenzione! Il contenuto del file non è valido.'
        }
      });
    },

    // Recupera il contenuto del file e trasforma in Json corretto
    async getFileContent(file) {
      
      try {
        // Recupera il contenuto del file dal Blob URL
        const response = await fetch(file.url);
        const fileText  = await response.text();

        // Il contenuto può presentare caratteri speciali alla file
        //console.log("Contenuto del file:", fileText);

        // Elimina eventuali caratteri extra (se presenti)
        const cleanFileText = fileText.split('')
          .filter(c => c.charCodeAt(0) >= 32 || c.charCodeAt(0) === 9) // Mantiene solo caratteri visibili e tabulazione
          .join('');

        // Parsing in Json
        try {
          const parsedData = JSON.parse(cleanFileText);
          return parsedData;
        } catch (error) {
          console.error("Errore durante il parsing del file JSON:", error);
          return null;
        }
      } catch (error) {
        console.error("Errore nel leggere il contenuto del file:", error);
        return null;
      }

    },

    // Verifica se il file è valido
    async validateGeoData(file) {
      try {
        // Recupera il contenuto del file
        let fileContent = await this.getFileContent(file);
        
        // Verifica se presente il campo "data"
        if (fileContent && Array.isArray(fileContent.data)) {
          // Passa l'array 'data' alla funzione di validazione
          const validationResult = this.validateGeoDataFormat(fileContent.data); // Passa l'array "data" alla funzione di validazione

          if (!validationResult.isValid) {
            console.log("Errore di validazione:", validationResult.message);
            return false
          } else {
            console.log("I dati sono validi.");
            return true
          }
        } else {
          console.error("Il campo 'data' non è presente o non è un array.");
          return false
        }

      } catch (error) {
        console.error("Errore nel leggere il contenuto del file:", error);
        return false
      }
    },

    // Funzione per preparazione del file al download
    async prepareDownload(file) {
      const cleanedData = await this.getFileContent(file);
      if (!cleanedData) {
        alert("Errore nella pulizia del file!");
        return;
      }

      // Converti i dati in stringa JSON formattata
      const formattedJson = JSON.stringify(cleanedData, null, 2);

      // Crea un Blob con il contenuto trasformato
      const blob = new Blob([formattedJson], { type: "application/json" });

      // Crea un URL temporaneo per il download
      this.processedFileUrl = URL.createObjectURL(blob);

      // Simula un click per avviare il download immediato
      setTimeout(() => {
        const link = document.createElement("a");
        link.href = this.processedFileUrl;
        link.download = "file.json"; // Nome del file scaricato
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      }, 100);
    },

    // Verifica se il contenuto del file è valido
    validateGeoDataFormat(fileContent) {
      // Verifica che il file non sia vuoto
      if (!fileContent || fileContent.length === 0) {
        return { isValid: false, message: 'Il file è vuoto.' };
      }

      // Funzione per validare la struttura di ciascun oggetto
      const validateEntry = (entry) => {
        //console.log("Entry: ", entry)

        // Verifica la presenza dei campi obbligatori
        if (!entry.timestamp || !entry.latitude || !entry.longitude || !entry.speed || !entry.accuracy) {
          return { isValid: false, message: 'Mancano campi obbligatori nel file.' };
        }

        // Verifica che il timestamp sia nel formato ISO 8601
        if (!isValidTimestamp(entry.timestamp)) {
          return { isValid: false, message: `Timestamp non valido: ${entry.timestamp}` };
        }

        // Verifica che latitude e longitude siano nel range corretto
        if (entry.latitude < -90 || entry.latitude > 90 || entry.longitude < -180 || entry.longitude > 180) {
          return { isValid: false, message: `Coordinate non valide: ${entry.latitude}, ${entry.longitude}` };
        }

        // Verifica che speed e accuracy siano numerici
        if (typeof entry.speed !== 'number' || typeof entry.accuracy !== 'number') {
          return { isValid: false, message: `Speed o accuracy non numerici: ${entry.speed}, ${entry.accuracy}` };
        }

        // Se l'altitude è presente, deve essere numerico
        if (entry.altitude && typeof entry.altitude !== 'number') {
          return { isValid: false, message: `Altitude non numerico: ${entry.altitude}` };
        }

        return { isValid: true };
      };

      // Funzione per validare il formato del timestamp (ISO 8601)
      function isValidTimestamp(timestamp) {
        const date = new Date(timestamp);
        return !isNaN(date.getTime()) && timestamp === date.toISOString();
      }

      // Esegui la validazione su ciascun elemento dei dati
      for (const entry of fileContent) {
        const result = validateEntry(entry);
        if (!result.isValid) {
          return result; // Ritorna il primo errore trovato
        }
      }

      // Se tutti i dati sono validi
      return { isValid: true, message: 'Dati validi.' };
    },


    // Valida un file
    async validateFile(hash, validationResult) {
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
        const key = await contract.getEncryptedKey(hash, this.userAddress);

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
        // Rimborso al'utente che ha caricato i dati, se validationResult=true
        // Ricompensa al verficatore
        const tx = await contractWithSigner.verifyData(hash, key, validationResult);
        console.log("Transaction hash:", tx.hash);
        await tx.wait();

        console.log("DATA VERIFIED SUCCESSFULLY!");

        // Controlla e Aggiorna il Balance dell'utente
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
  gap: 30px; /* Distanza tra gli elementi */
  margin-top: 5px;
}
.file-item:hover {
  background-color: rgb(238, 235, 235);
}

a {
  cursor: pointer;
}

</style>