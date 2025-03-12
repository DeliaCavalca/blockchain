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
import DataStorage from "../../../hardhat/artifacts/contracts/Crowdsensing.sol/Crowdsensing.json"; 
import eventBus from '@/eventBus';
import { mapGetters } from 'vuex'
//import accounts from "@/assets/hardhat-accounts.json";

import CryptoJS from "crypto-js";
import EC from 'elliptic';
const ec = new EC.ec('secp256k1');

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
      contract: null,

      ethToPay: "0.1",

      publicKey: '',
      privateKey: '',

      waitingKey: false,
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
    async fileToString(file) {
      return new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.readAsText(file);
          reader.onload = () => resolve(reader.result);
          reader.onerror = error => reject(error);
      });
    },



    // Funzioni per la codifica del file
    async importPublicKey(K_enc) {
            // Decodifica la chiave pubblica K_enc da base64
            const binaryKey = Uint8Array.from(atob(K_enc), c => c.charCodeAt(0));

            // Importa la chiave pubblica in formato leggibile da Crypto API
            const publicKey = await window.crypto.subtle.importKey(
                "spki", // Formato della chiave pubblica (SPKI)
                binaryKey, // Chiave decodificata
                {
                    name: "RSA-OAEP", // Algoritmo RSA-OAEP
                    hash: "SHA-256",  // Hashing per RSA-OAEP
                },
                false, // La chiave pubblica non è per la firma
                ["encrypt"] // Operazioni consentite (solo cifratura)
            );

            return publicKey;
    },
    
    async encryptMessage(message, K_enc) {
      const publicKey = await this.importPublicKey(K_enc);

      const encoder = new TextEncoder();
      const encodedMessage = encoder.encode(message);

      const encrypted = await window.crypto.subtle.encrypt(
        {
          name: "RSA-OAEP",
        },
          publicKey,
          encodedMessage
      );

      return btoa(String.fromCharCode(...new Uint8Array(encrypted))); // Convertito in Base64
    },

   
    


    // Carica il file su IPFS
    async uploadToIpfs(encryptedFile) {
      try {

        let dataToUpload = {
          file: encryptedFile
        };
        
        const indexBlob = new Blob([JSON.stringify(dataToUpload)], { type: "application/json" });
        const indexAdded = await client.add(indexBlob);

        this.ipfsHash = indexAdded.path; // CID del file contenente i blocchi


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

        // Salva il CID e la chiave usata per criptare il file sullo Smart Contract
        console.log("Sending CID to blockchain...");
        
        // Non invia la chiave allo Smart Contract
        const tx = await contractWithSigner.uploadData(this.ipfsHash, "", {
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
      this.$store.commit('SET_UPLOADING', true);

      // l'utente genera una nuova coppia di chiavi privata-pubblica
      const keys = await this.generateKeyPair()
      console.log("USER: CHIAVI GENERATE")
      console.log(keys)
      this.publicKey = keys.publicKey
      this.privateKey = keys.privateKey
      

      // notifica lo SC che vuole mandare il file, inviando la sua chiave pubblica
      await this.sendPublicKeyToContract()

    },

    // Genera una coppia di chiavi pubblica-privata
    async generateKeyPair() {
      // Genera un nuovo wallet
      const wallet = ethers.Wallet.createRandom();
      
      // Estrai la chiave privata e l'indirizzo (chiave pubblica)
      const privateKey = wallet.privateKey;
      //console.log(privateKey)
      //const publicKey = wallet.address;
      const publicKey = ethers.utils.computePublicKey(privateKey, false);
      //console.log(publicKey)
      
      return {
        privateKey: privateKey,
        publicKey: publicKey
      };
    }, 

    // Comunica allo Smart Contract la chiave pubblica
    async sendPublicKeyToContract() {
      
      let provider, contract, signer, contractWithSigner;

      try {
        provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
        contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);

        signer = provider.getSigner(this.userAddress);
        contractWithSigner = contract.connect(signer);

        console.log("USER: Sending Public Key to Contract...")
        const tx = await contractWithSigner.uploadPublicKey(this.publicKey);
        await tx.wait();
        console.log("SENT SUCCESSFULLY!");

        this.waitingKey = true

        contract.removeAllListeners("KeySent");

        // Operazioni svolte dall'Utente
        // User in ascolto dell'evento "KeySent" dallo SC
        contract.on("KeySent", async (user, encryptedKey) => {
          console.log("user: ", user)
          
          if(this.waitingKey){
            console.log("------- USER EVENT 2: KeySent")
            signer = provider.getSigner(this.userAddress);
            contractWithSigner = contract.connect(signer);

            console.log(`USER: DECRYPT Encrypted_K: ${encryptedKey}`);
            
            // l'utente decifra la encryptedKey con la sua chiave privata
            try{
              const decryptedKey = await this.decryptKeyECIES(encryptedKey, this.privateKey);
              console.log(`USER: K: ${decryptedKey}`);
              
              // ottieni il file e convertilo in stringa
              const fileString = await this.fileToString(this.file);
              //console.log("STRING: ", fileString)

              // l'utente cifra i dati e li carica su IPFS
              const encryptedFile = await this.encryptMessage(fileString, decryptedKey)
              //console.log("ENCRYPTED FILE: ", encryptedFile);
              
              await this.uploadToIpfs(encryptedFile);
              console.log("USER: UPLOAD TO IPFS DONE");

              // comunicare allo SC la posizione dei dati su IPFS (CID)
              await this.sendCIDToContract(this.ipfsHash);
              console.log("USER: CID SENT TO CONTRACT");
              

              this.$store.commit('SET_UPLOADING', false);
              this.waitingKey = false
            } catch(error) {
              console.log("...")
            }
            
          }

        });

        
      } catch (error) {
        console.error("Error connecting to Ethereum provider:", error);
        return;
      }
    },

    

    // decodifica la chiave per la codifica del file con la chiave privata dell'utente
    async decryptKeyECIES(K_ciphered, privateKeyHex) { 
      const privateKey = ec.keyFromPrivate(privateKeyHex.slice(2), 'hex');
      const sharedSecret = privateKey.getPublic().encode('hex');

      const decryptedBytes = CryptoJS.AES.decrypt(K_ciphered, sharedSecret);
      const decrypted = decryptedBytes.toString(CryptoJS.enc.Utf8);
      //console.log('Decrypted Key:', decrypted);
      return decrypted;
    },


  }
};
</script>

<style scoped>
.disabled-label {
  opacity: 0.7;
  pointer-events: none; /* Impedisce il click */
}
</style>