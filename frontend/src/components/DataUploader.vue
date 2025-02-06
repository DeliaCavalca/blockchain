<template>
  <div style="font-size: 13px; text-align: left;">
    <p class="m-0 p-0">Quota richiesta per l'upload: <span><strong>{{ ethToPay }} ETH</strong></span></p>
    <p class="m-0 p-0 mb-4">Tale quantità ti verrà restituita non appena i tuoi dati saranno stati validati.</p>

    <p v-if="!selectedFileName" class="m-0 p-0">Seleziona il tuo file <span><strong>.json </strong></span>:</p>
    <p v-else class="m-0 p-0">File selezionato: <span><strong>{{ selectedFileName }}</strong></span></p>

    <div>
      <label class="p-1 mt-1 custom-btn" :class="{ 'disabled-label': isClosed }">
        <span>Scegli file</span>
        <input class="selectfileBtn" type="file" @change="onFileChange" :disabled="isClosed" accept=".json"/>
      </label>
    </div>
    <p v-if="invalidFile" class="text-danger m-0 p-0">Il file deve essere un file .json valido.</p>

    <div class="mt-5">
      <p class="m-0 p-0">Carica i tuoi dati sulla piattaforma!</p>
      <p class="m-0 p-0">I tuoi dati verranno criptati per garantire la tua privacy.</p>

      <button class="custom-btn mt-2 p-1" :disabled="!file" @click="encryptAndLoadData">Carica Dati</button>
    </div>
  </div>
</template>

<script>
import { create as ipfsHttpClient } from 'ipfs-http-client';
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto
import eventBus from '@/eventBus';
import CryptoJS from "crypto-js";
import { mapGetters } from 'vuex'
import accounts from "@/assets/hardhat-accounts.json"; 

const client = ipfsHttpClient({ url: 'http://localhost:5001' });

export default {
  data() {
    return {
      contractAddress: null, // Indirizzo del Contratto
      userAddress: null, // Indirizzo dell'utente Ethereum

      file: null,
      invalidFile: false,
      selectedFileName: null,
      ipfsHash: "",
      encryptionKey: "",
      contract: null,

      ethToPay: "0.1",
    };
  },

  created() {
    this.contractAddress = this.$store.state.contractAddress
    this.userAddress = this.$store.state.userAddress
  },

  computed: {
    ...mapGetters(['isClosed']),
  },

  methods: {
    // Funzione di utilità per convertire un ArrayBuffer in Base64
    arrayBufferToBase64(buffer) {
      let binary = '';
      const bytes = new Uint8Array(buffer);
      const len = bytes.length;
      for (let i = 0; i < len; i++) {
        binary += String.fromCharCode(bytes[i]);
      }
      return window.btoa(binary);
    },

    // Genera la chiave di crittografia
    async generateKey() {
      // Crea una chiave AES a 256 bit
      const key = await window.crypto.subtle.generateKey(
        {
          name: "AES-GCM",
          length: 256, // Lunghezza della chiave (256 bit)
        },
        true, // La chiave può essere esportata
        ["encrypt", "decrypt"] // Operazioni consentite con la chiave
      );

      // Converti la chiave in un formato leggibile (ad esempio, in base64)
      const exportedKey = await window.crypto.subtle.exportKey("raw", key);
      const exportedKeyBase64 = this.arrayBufferToBase64(exportedKey);
    
      console.log("Generated AES Key (Base64):", exportedKeyBase64);
      this.encryptionKey = exportedKeyBase64; // Imposta la chiave nel data
    },

    // Gestisce il cambiamento del file
    onFileChange(event) {
      const file = event.target.files[0]; // Ottieni il file selezionato

      if(file) {
        // Controllo se il file è presente e ha estensione .json
        if (file.name.endsWith('.json')) {
          this.file = file;
          this.selectedFileName = this.file.name; // Aggiorna il nome del file
          this.invalidFile = false; // Nessun errore
        } else {
          this.selectedFileName = null;
          this.file = null;
          this.invalidFile = true; // Mostra errore se il file non è .json
        }
      } else {
        this.selectedFileName = null;
        this.file = null;
      }
    },

    // Funzione per cifrare il file con la chiave AES
    /*
    async encryptFile() {
      try {
        if (!this.file) throw new Error("No file selected");
        if (!this.encryptionKey) throw new Error("No encryption key provided");

        console.log("Encrypting text file...");
        const fileContent = await this.file.text();
        const encryptedData = CryptoJS.AES.encrypt(fileContent, this.encryptionKey).toString();
        console.log("File encrypted successfully!");
        console.log("encryptedData:", encryptedData);
        //return new Blob([encryptedData], { type: "text/plain" });
        return encryptedData;
      } catch (error) {
        this.message = "Error encrypting file.";
        console.error("Error encrypting file:", error);
        throw error;
      }
    },*/

    async encryptBlock(block) {
      try {
        if (!this.encryptionKey) throw new Error("No encryption key provided");

        console.log("Encrypting block...");

        // Converte il blocco binario in stringa Base64
        const blockWordArray = CryptoJS.lib.WordArray.create(block);
        const blockBase64 = CryptoJS.enc.Base64.stringify(blockWordArray);

        // Cifra il blocco con AES
        const encryptedData = CryptoJS.AES.encrypt(blockBase64, this.encryptionKey).toString();

        return encryptedData;
      } catch (error) {
        console.error("Errore nella cifratura:", error);
        throw error;
      }
    },


    // Funzione per calcolare SHA-256 del file
    async computeSHA256(input) {
      if (input instanceof Blob) {
        input = await input.arrayBuffer(); // Converte Blob in ArrayBuffer
      }

      const buffer = new Uint8Array(input);
      const hash = ethers.utils.keccak256(buffer); // Calcola l'hash
      return hash;
    },

    // Carica il file su IPFS
    async uploadToIpfs() {
      try {
        if (!this.file) {
          throw new Error("No file selected");
        }

        // Converti il file in un array di byte
        const fileArrayBuffer = await this.file.arrayBuffer();
        const fileUint8Array = new Uint8Array(fileArrayBuffer);

        // Definisci la dimensione del blocco
        const BLOCK_SIZE = Number(this.$store.state.chunkSize);
        let blocks = [];

        // recupera la chiave privata dell'utente
        const user = accounts.find(acc => acc.address === this.userAddress);
        const privateKey = user.privateKey;
        const wallet = new ethers.Wallet(privateKey);
        

        // Cifra ogni blocco
        for (let i = 0; i < fileUint8Array.length; i += BLOCK_SIZE) {
            console.log("CODIFICA BLOCCO - ", i);
            
            // Estrai il blocco
            let block = fileUint8Array.slice(i, i + BLOCK_SIZE);
            console.log(block) // Unit8Array(256)

            // Cifra il blocco con AES
            let encryptedData = await this.encryptBlock(block);
            console.log("ENCRYPTED BLOCK: ", encryptedData) // U2FsdGVkX19

            // Calcola l'hash del blocco cifrato
            let blockHash = await this.computeSHA256(encryptedData);
            console.log("BLOCK DIGEST: ", blockHash)
            // 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470

            // Firma l'hash con la chiave privata dell'utente
            let signature = await wallet.signMessage(blockHash);

            // Crea un oggetto con il blocco cifrato + firma
            let dataToUpload = {
              block: encryptedData,
              signature: signature
            };

            console.log("DATA TO UPLOAD")
            console.log(dataToUpload)

            // Converti in Blob e carica su IPFS
            const dataBlob = new Blob([JSON.stringify(dataToUpload)], { type: "application/json" });
            const added = await client.add(dataBlob);

            // Salva l'hash IPFS del blocco
            blocks.push(added.path);
        }

        // Salva la struttura dati dei blocchi su IPFS
        const indexData = { blocks: blocks }; // Lista dei CID
        const indexBlob = new Blob([JSON.stringify(indexData)], { type: "application/json" });
        const indexAdded = await client.add(indexBlob);

        this.ipfsHash = indexAdded.path; // CID del file contenente i blocchi


        console.log("File uploaded to IPFS with hash:", this.ipfsHash);
        
      } catch (error) {
        // emit event
        eventBus.emit('showAlertErrorLoad');
        console.error("Error uploading file to IPFS:", error);
      }
    },
    /*
    async uploadToIpfs2() {
      try {
        if (!this.file) {
          throw new Error("No file selected");
        }

        // codifica il file con la chiave AES
        const encryptedBlob = await this.encryptFile();
        
        // calcolo hash (SHA-256) del file: genera il digest
        const fileHash = await this.computeSHA256(encryptedBlob);
        console.log("FILE DIGEST: ", fileHash);

        // recupera la chiave privata dell'utente
        const user = accounts.find(acc => acc.address === this.userAddress);
        const privateKey = user.privateKey;
        // firma del digest con la chiave privata dell'utente
        const wallet = new ethers.Wallet(privateKey);
        const signature = await wallet.signMessage(fileHash);
        //console.log("SIGNATURE: ", signature);


        // Caricamento dati su IPFS: file cifrato + firma del digest
        const dataToUpload = {
          file: encryptedBlob,     // File cifrato
          signature: signature     // Firma del digest
        };
        console.log("DATA TO UPLOAD")
        console.log(dataToUpload)
        const dataBlob = new Blob([JSON.stringify(dataToUpload)], { type: "application/json" });
        
        // Caricamento dati su IPFS
        const added = await client.add(dataBlob);
        // IPFS Hash (CID): posizione in cui sono stati salvati i dati
        this.ipfsHash = added.path; // Salva l'hash IPFS del file caricato

        console.log("File uploaded to IPFS with hash:", this.ipfsHash);
        
      } catch (error) {
        // emit event
        eventBus.emit('showAlertErrorLoad');
        console.error("Error uploading file to IPFS:", error);
      }
    },*/

    // Comunica allo Smart Contract la posizione dei dati su IPFS
    async sendCIDToContract() {
      if (!this.ipfsHash) {
        console.log("ERRORE nel caricamento dei dati su SC");
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

        // Salva il CID e la chiave usata per criptare il file sullo Smart Contract
        console.log("Sending CID to blockchain...");
        const tx = await contractWithSigner.uploadData(this.ipfsHash, this.encryptionKey, {
          value: ethers.utils.parseEther(this.ethToPay)
        });

        console.log("Transaction sent:", tx);
        this.message = `Transaction sent: ${tx.hash}`;
        console.log("Transaction hash:", tx.hash);
        await tx.wait();

        const finalBalance = await provider.getBalance(this.userAddress);
        const finalEthBalance = ethers.utils.formatEther(finalBalance); // Converte il saldo in ETH
        console.log(`Final Balance: ${finalEthBalance} ETH`);
        this.$store.commit('SET_ETH_BALANCE', finalEthBalance);

        console.log("CID SENT SUCCESSFULLY");

        // emit event
        eventBus.emit('showAlertSuccessLoad');

        this.file = null
        this.selectedFileName = null
        this.encryptionKey = ""
        this.contract = null
        
      } catch (error) {
        console.error("Error connecting to Ethereum provider:", error);
        
        // emit event
        eventBus.emit('showAlertErrorLoad');

        return;
      }
    },

    // Codifica i dati dell'utente e li carica su IPFS
    async encryptAndLoadData() {

      // genera chiave AES-256 per criptare file
      await this.generateKey(); 

      // codifica dei dati 
      // genera e firma del digest
      // upload su IPFS: file + firma
      await this.uploadToIpfs();
      
      // comunicare allo SC la posizione dei dati su IPFS (CID)
      // pagamento della quota
      await this.sendCIDToContract(this.ipfsHash);
    }
  }
};
</script>

<style scoped>
.disabled-label {
  opacity: 0.7;
  pointer-events: none; /* Impedisce il click */
}
</style>