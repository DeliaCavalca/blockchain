<template>
  <div style="font-size: 13px; text-align: left;">
    
    <p v-if="fileToVerifyList.length > 0" class="m-0 p-0 mb-3">File da validare:</p>
    <p v-else class="m-0 p-0">Nessun file da validare.</p>

    <div v-for="(file, index) in fileToVerifyList" :key="file.hash">
      <div class="file-item mt-3">
        <i v-if="file.signatureError == ''" class="bi bi-check-circle-fill text-primary"></i>
        <i v-if="file.signatureError != ''" class="bi bi-check-circle-fill" style="color: darkred;"></i>

        <span><strong>File {{ index + 1 }}</strong></span>
        <a :href="processedFileUrl" @click.prevent="prepareDownload(file)" target="_blank">Vedi File</a>
        <button class="custom-btn" @click="validateFile(file.hash, true)" :disabled="file.validationError != ''">Valida</button>
        <button class="custom-btn-2" @click="validateFile(file.hash, false)">Scarta</button>
      </div>

      <p v-if="file.signatureError != ''" class="m-0 p-0" style="color: darkred; font-weight: bold; font-size: 12px;">{{ file.signatureError }}</p>
      <p v-if="file.validationError != ''" class="m-0 p-0" style="color: darkred; font-weight: bold; font-size: 12px;">{{ file.validationError }}</p>
    </div>

  </div>
</template>

<script>
import { create as ipfsHttpClient } from 'ipfs-http-client';
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/Crowdsensing.sol/Crowdsensing.json"; // Percorso corretto
//import eventBus from '@/eventBus';

import CryptoJS from "crypto-js";
import EC from 'elliptic';
const ec = new EC.ec('secp256k1');

const client = ipfsHttpClient({ url: 'http://localhost:5001' });

export default {
  data() {
    return {
      contractAddress: null, // Indirizzo del Contratto
      userAddress: null, // Indirizzo dell'utente Ethereum

      ipfsHash: "",
      encryptionKey: '',

      hashToVerifyList: [],
      fileToVerifyList: [],
      processedFileUrl: null,

      publicKey: '',
      privateKey: '',
      verifierKeySent: false,
      waitingKey: false,
    };
  },

  created() {
    this.contractAddress = this.$store.state.contractAddress
    this.userAddress = this.$store.state.userAddress

    console.log("CREATED - LIST: ", this.hashToVerifyList.length)

    this.getVerificationRequests();

    /*
    this.getUnverifiedFile();

    // manage the event showAlertSuccessLoad
    eventBus.on('showAlertSuccessLoad', () => {
      this.getUnverifiedFile();
    });
    */
  },

  methods: {

    // Verifier in ascolto dell'evento VerificationRequested
    async getVerificationRequests() {
      
      this.$store.commit('SET_SEARCHING', true);

      // il Verificatore genera una nuova coppia di chiavi privata-pubblica
      const keys = await this.generateKeyPair()
      console.log("VERIFIER: CHIAVI GENERATE")
      console.log(keys)
      this.publicKey = keys.publicKey
      this.privateKey = keys.privateKey


      let provider, contract, signer, contractWithSigner;

      try {
        provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
        contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
        
        if(this.$store.state.userRole == "Verifier") {

          signer = provider.getSigner(this.userAddress);
          contractWithSigner = contract.connect(signer);

          const tx = await contractWithSigner.requestVerificationForUnverifiedData();
          await tx.wait();

          
          contract.on("DebugLog", (message, value) => {
            console.log(message, value.toString());
          });

          contract.removeAllListeners("VerificationRequested");
          contract.removeAllListeners("KeySent");
          
          // Operazioni svolte dal Verifier
          // Verifier in ascolto dell'evento "VerificationRequested" dallo SC
          // ottenere gli hash dei file da validare
          contract.on("VerificationRequested", async (ipfsHash) => {
            console.log("VERIFIER EVENT 1: VerificationRequested");

            if(ipfsHash == "") {
              console.log("NESSUN FILE DA VALIDARE!");
              this.$store.commit('SET_SEARCHING', false);
              return;
            } else {
              const index = this.hashToVerifyList.indexOf(ipfsHash);
              if (index !== -1) {
                console.log("GIA AGGIUNTO ALLA LISTA!");
                return;
              }
            }

            console.log("IPFS HASH: ", ipfsHash)
            this.hashToVerifyList.push(ipfsHash)

            // il Verifier contatta SC per registrare l'intenzione di verifica, inviando la propria chiave pubblica PK
            signer = provider.getSigner(this.userAddress);
            contractWithSigner = contract.connect(signer);

            console.log("VERIFIER: Sending Public Key to Contract...")
            this.verifierKeySent = true
            const tx = await contractWithSigner.uploadVerifierPublicKey(this.publicKey);
            await tx.wait();
            console.log("SENT SUCCESSFULLY!");

            this.waitingKey = true
              
          });

          
          // Operazioni svolte dal Verifier
          // Verifier in ascolto dell'evento "KeySent" dallo SC
          contract.on("KeySent", async (user, encryptedKey) => {
            
            if(this.waitingKey){

              console.log("VERIFIER EVENT 2: KeySent")
              signer = provider.getSigner(this.userAddress);
              contractWithSigner = contract.connect(signer);

              console.log(`VERIFIER: DECRYPT Encrypted_K`);
              
              // il Verifier decifra la encryptedKey con la sua chiave privata
              const decryptedKey = await this.decryptKeyECIES(encryptedKey, this.privateKey);
              //console.log(`VERIFIER: K: ${decryptedKey}`);
              
              // Recupera i dati da IPFS, decriptandoli con la chiave ottenuta
              this.encryptionKey = decryptedKey

              await this.getUnverifiedFile()

            }

            this.waitingKey = false

          });

        }
        
        return;
      } catch (error) {
        console.error("Error fetching unverified hashes:", error);
        return;
      }
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


    // decodifica la chiave per la codifica del file con la chiave privata dell'utente
    async decryptKeyECIES(K_ciphered, privateKeyHex) { 
      const privateKey = ec.keyFromPrivate(privateKeyHex.slice(2), 'hex');
      const sharedSecret = privateKey.getPublic().encode('hex');

      const decryptedBytes = CryptoJS.AES.decrypt(K_ciphered, sharedSecret);
      const decrypted = decryptedBytes.toString(CryptoJS.enc.Utf8);
      //console.log('Decrypted Key:', decrypted);
      return decrypted;
    },



    // Funzioni per la decodifica del file
    async importPrivateKey(K_dec) {
            // Decodifica la chiave privata K_dec da base64
            const binaryKey = Uint8Array.from(atob(K_dec), c => c.charCodeAt(0));

            // Importa la chiave privata in formato leggibile da Crypto API
            const privateKey = await window.crypto.subtle.importKey(
                "pkcs8", // Formato della chiave privata (PKCS8)
                binaryKey, // Chiave decodificata
                {
                    name: "RSA-OAEP", // Algoritmo RSA-OAEP
                    hash: "SHA-256",  // Hashing per RSA-OAEP
                },
                false, // La chiave privata non è per la firma
                ["decrypt"] // Operazioni consentite (solo decriptazione)
            );

            return privateKey;
    },
    async decryptMessage(encryptedMessage, K_dec) {
      const privateKey = await this.importPrivateKey(K_dec);

      const binaryStr = atob(encryptedMessage);
      const binaryArray = new Uint8Array([...binaryStr].map(char => char.charCodeAt(0)));

      const decrypted = await window.crypto.subtle.decrypt(
        {
          name: "RSA-OAEP",
        },
          privateKey,
          binaryArray
      );

      return new TextDecoder().decode(decrypted);
    }, 



    // Ottenere l'elenco di file da verificare da IPFS
    async getUnverifiedFile() {

      if (this.hashToVerifyList.length === 0) {
        console.log("Nessun file da validare");
        this.fileToVerifyList = [];
        return;
      }

      console.log("FILE DA VALIDARE: ", this.hashToVerifyList.length)

      // Imposta il provider e il contratto una sola volta
      //const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
      //const contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);

      const files = await Promise.all(
        this.hashToVerifyList.map(async (indexIpfsHash) => {
            try {
              
              // Recupera la struttura dati dei blocchi da IPFS
              const stream = client.cat(indexIpfsHash);
              let indexData = new Uint8Array();
              for await (const chunk of stream) {
                indexData = new Uint8Array([...indexData, ...chunk]);
              }

              const indexJson = JSON.parse(new TextDecoder().decode(indexData));
              const encryptedFile = indexJson.file; // File
              console.log("FILE ENC: ", encryptedFile)
              
              // Recupera la chiave con la quale è stato criptato il file: K_DEC
              const encryptedKey = this.encryptionKey;

              // Decripta il file
              const decryptedFile = await this.decryptMessage(encryptedFile, encryptedKey);
              console.log("FILE DEC: ", decryptedFile)

              // Ricostruire il file completo
              const blob = new Blob([decryptedFile], { type: "application/octet-stream" });

              return { hash: indexIpfsHash, url: URL.createObjectURL(blob), signatureError: "" };
              
            } catch (error) {
              console.error(`Errore nel download del file IPFS con hash ${indexIpfsHash}:`, error);
              return null;
            }
        })
      );

      this.$store.commit('SET_SEARCHING', false);
      this.fileToVerifyList = files.filter(file => file !== null);
      await this.validateGeoDataForAllFiles();  // Esegui la validazione per ogni file caricato

      return;

    },



    // Funzione per validare in automatico tutti i file caricati
    async validateGeoDataForAllFiles() {
      this.fileToVerifyList.forEach(async file => {
        
        const validationResult = await this.validateGeoData(file);

        if (validationResult) {
          file.validationError = '';
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
        console.log("Contenuto del file:", fileText);

        // Elimina eventuali caratteri extra (se presenti)
        
        const cleanFileText = fileText.split('')
          .filter(c => c.charCodeAt(0) >= 32 || c.charCodeAt(0) === 9) // Mantiene solo caratteri visibili e tabulazione
          .join('');
        
        console.log("Contenuto del file CLEANED:", cleanFileText);
        

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
          return true
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
        //const key = await contract.getEncryptedKey(hash, this.userAddress);
        
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
        const tx = await contractWithSigner.verifyData(hash, validationResult);
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
        const index = this.hashToVerifyList.indexOf(hash);
        if (index !== -1) {
          this.hashToVerifyList.splice(index, 1);
        }
        
        await this.getUnverifiedFile();

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