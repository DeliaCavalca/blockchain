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

    // Funzione per cifrare il file
    async encryptFile() {
      try {
        if (!this.file) throw new Error("No file selected");
        if (!this.encryptionKey) throw new Error("No encryption key provided");

        console.log("Encrypting text file...");
        const fileContent = await this.file.text();
        const encryptedData = CryptoJS.AES.encrypt(fileContent, this.encryptionKey).toString();
        console.log("File encrypted successfully!");
        console.log("encryptedData:",encryptedData)
        return new Blob([encryptedData], { type: "text/plain" });
      } catch (error) {
        this.message = "Error encrypting file.";
        console.error("Error encrypting file:", error);
        throw error;
      }
    },

    // Carica il file su IPFS
    async uploadToIpfs() {
      try {
        if (!this.file) {
          throw new Error("No file selected");
        }

        const encryptedBlob = await this.encryptFile();
        console.log("Uploading file to IPFS...");

        // Caricamento dati su IPFS
        const added = await client.add(encryptedBlob);
        // IPFS Hash (CID): posizione in cui sono stati salvati i dati
        this.ipfsHash = added.path; // Salva l'hash IPFS del file caricato

        console.log("File uploaded to IPFS with hash:", this.ipfsHash);
        
      } catch (error) {
        // emit event
        eventBus.emit('showAlertErrorLoad');
        console.error("Error uploading file to IPFS:", error);
      }
    },

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