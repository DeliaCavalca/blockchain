<template>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons/font/bootstrap-icons.css">

  
    <div v-if="this.showAlertSuccessLoad" class="alert alert-success alert-dismissible fade show" role="alert" style="text-align: left; font-size: 14px;">
        I tuoi dati sono stati caricati correttamente!
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close" @click="closeAlertSuccess"></button>
    </div>
    <div v-if="this.showAlertErrorLoad" class="alert alert-danger alert-dismissible fade show" role="alert" style="text-align: left; font-size: 14px;">
        <strong>Attenzione!</strong> Si è verificato un errore. I tuoi dati <strong>NON</strong> sono stati caricati.
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close" @click="closeAlertError"></button>
    </div>

    <div v-if="isClosed && !isAdmin" class="alert alert-warning alert-dismissible fade show" role="alert" style="text-align: left; font-size: 14px;">
        <strong>Attenzione!</strong> La campagna di Crowdsensing è stata <strong>chiusa</strong>. Attualmente non è possibile caricare ulteriori dati.
    </div>

    <div v-if="uploading" class="alert alert-warning alert-dismissible fade show" role="alert" style="text-align: left; font-size: 14px;">
        <strong>Attendere il caricamento dati...</strong>
    </div>

    <div v-if="searching" class="alert alert-warning alert-dismissible fade show" role="alert" style="text-align: left; font-size: 14px;">
        <strong>Attendere la ricerca dei dati da validare...</strong>
    </div>

    <!-- User INFO -->
    <div class="border p-3" style="border-radius: 6px;">
        
        <div class="row">
            <div v-if="!seeUserAddress" class="col" style="font-size: 12px; text-align: left;">
                <span class="" @click="seeUserAddress=!seeUserAddress" style="cursor: pointer;">Guarda Indirizzo Utente</span>
            </div>
            <div v-else class="col" style="font-size: 12px; text-align: left;">
                <span class="" @click="seeUserAddress=!seeUserAddress" style="cursor: pointer;">Nascondi Indirizzo Utente</span>
            </div>

            <div class="col" style="font-size: 12px; text-align: right; color: darkRed; font-weight: bold;">
                <span @click="logoutUser" class="" style="cursor: pointer;">Esci dall'App</span>
            </div>
        </div>

        <div v-if="seeUserAddress" class="d-flex justify-content-between mt-2" style="font-size: 12px;">
            <span>User Address:</span>
            <span><strong>{{ userAddress }}</strong></span>
        </div>

        <div class="mt-3" style="text-align: left">
            <span><strong>{{ userRole }}</strong></span>
            <i v-if="isVerifier" class="bi bi-patch-check-fill text-primary m-2"></i>
            <i v-if="isAdmin" class="bi bi-patch-check-fill m-2" style="color: gold;"></i>
        </div>

        <div class="d-flex mt-3 mb-1">
            <span style="font-size: 12px;">Disponibilità attuale:</span>
        </div>
        <div class="d-flex">
            <span class="border" style="border-radius: 10px; padding: 5px 6px 5px 6px;"><strong>{{ formattedEthBalance }}</strong></span>
            <span style="padding: 5px 6px 5px 6px;"><strong>ETH</strong></span>
        </div>
        
    </div>

    <!-- User Box: Data Uploading -->
    <div class="border mt-3 p-3" v-if="!isVerifier && !isAdmin" style="border-radius: 6px;">
        <p class="m-0 p-0" style="font-weight: bold;  text-align: left;">Caricamento Dati Crowdsensing</p>
        <p class="m-0 p-0 mb-3" style="text-align: left; font-size: 13px;">
            Contribuisci al nostro sistema decentralizzato caricando i tuoi dati in modo sicuro e verificabile!
        </p>
        
        <DataUploader />
    </div>

    <!-- Verifier Box: Data Verifyng -->
    <div class="border mt-3 p-3" v-if="isVerifier" style="border-radius: 6px;">
        <p class="m-0 p-0" style="font-weight: bold; text-align: left;">Validazione Dati Crowdsensing</p>
        <p class="m-0 p-0 mb-3" style="text-align: left; font-size: 13px;">
            Esamina i dati caricati dagli utenti e convalidali!
        </p>
        
        <DataVerifier />
    </div>

    <!-- Admin Box: Data Managing -->
    <div class="border mt-3 p-3" v-if="isAdmin" style="border-radius: 6px;">
        <p class="m-0 p-0" style="font-weight: bold; text-align: left;">Gestione Campagna Crowdsensing</p>
        <p class="m-0 p-0 mb-3" style="text-align: left; font-size: 13px;">
            Impostazioni della tua campagna di Crowdsensing.
        </p>

        <SettingsManager />
    </div>
    <div class="border mt-3 p-3" v-if="isAdmin" style="border-radius: 6px;">
        <p class="m-0 p-0" style="font-weight: bold; text-align: left;">Analisi Dati</p>
        <p class="m-0 p-0 mb-3" style="text-align: left; font-size: 13px;">
            Dati caricati sulla piattaforma.
        </p>
        
        <DataManager />
    </div>
    <div class="border mt-3 p-3" v-if="isAdmin && isClosed" style="border-radius: 6px;">
        <p class="m-0 p-0" style="font-weight: bold; text-align: left;">Dati Caricati</p>
        <p class="m-0 p-0 mb-3" style="text-align: left; font-size: 13px;">
            Lista file caricati sulla piattaforma.
        </p>
        
        <FileUploaded />
    </div>

  
</template>
  
<script>
import { mapGetters } from 'vuex'
import eventBus from '@/eventBus';
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/Crowdsensing.sol/Crowdsensing.json"; // Percorso corretto

import CryptoJS from "crypto-js";
import EC from 'elliptic';
const ec = new EC.ec('secp256k1');

import DataUploader from '../components/DataUploader.vue';
import DataVerifier from '../components/DataVerifier.vue';
import DataManager from '../components/DataManager.vue';
import FileUploaded from '../components/FileUploaded.vue';
import SettingsManager from '../components/SettingsManager.vue';

export default {
    name: 'HomeView',
    components: {
        DataUploader, DataVerifier, DataManager, SettingsManager, FileUploaded
    },
  
    data() {
      return {
        contractAddress: null, // Indirizzo del Contratto
        
        userAddress: null, // Indirizzo dell'utente Ethereum
        userRole: null,

        k_enc: null,
        k_dec: null,

        seeUserAddress: false,
        showAlertSuccessLoad: false,
        showAlertErrorLoad: false,
      };
    },

    computed: {
        ...mapGetters(['ethBalance']),
        ...mapGetters(['isAdmin']),
        ...mapGetters(['isVerifier']),

        ...mapGetters(['isClosed']),

        ...mapGetters(['uploading']),

        ...mapGetters(['searching']),

        formattedEthBalance() {
            return Number(this.ethBalance)
                .toLocaleString('it-IT', { 
                minimumFractionDigits: 2, 
                maximumFractionDigits: 4 
            });
        },
    },
  
  
    created() {
        this.contractAddress = this.$store.state.contractAddress
        this.userAddress = this.$store.state.userAddress
        this.userRole = this.$store.state.userRole

        this.getCampaignStatus();

        
        if (this.$store.state.k_enc == null) {
            this.adminKeys();
        } else {
            console.log('K_ENC: ', this.$store.state.k_enc);
            console.log('K_DEC: ', this.$store.state.k_dec);
            this.k_enc = this.$store.state.k_enc
            this.k_dec = this.$store.state.k_dec
        }

        this.adminOperations();
        
        // manage the event showAlertSuccessLoad
        eventBus.on('showAlertSuccessLoad', () => {
            this.showAlertSuccessLoad = true
        });
    },
  
    methods: {

        // Funzione per disconnettere l'utente 
        logoutUser() {
            this.userAddress = null
            this.ethBalance = null
            this.userRole = null
            this.$store.commit('SET_USER_ADDRESS', this.userAddress);
        },

        closeAlertSuccess() {
            this.showAlertSuccessLoad = false
        },
        closeAlertError() {
            this.showAlertErrorLoad = false
        },

        async getCampaignStatus() {

            let provider, contract; 

            try {
                provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
                contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
                
                // Ottieni lo Stato della campagna
                const status = await contract.getCampaignStatus();
                this.$store.commit('SET_STATUS', status);
                    
            } catch (error) {
                console.error("Errore nel ottenere Status:", error);
            }

        },


        // Genera le chiavi dell'Admin
        async adminKeys() {

            // l'Admin genera una nuova coppia di chiavi privata-pubblica
            const keys = await this.generateKeyPair()
            console.log("ADMIN: CHIAVI GENERATE")
            console.log(keys)
            this.k_enc = keys.publicKey
            this.k_dec = keys.privateKey
            this.$store.commit('SET_K_ENC', this.k_enc);
            this.$store.commit('SET_K_DEC', this.k_dec);

            const encryptedMessage = await this.encryptMessage("Ciao ciao", this.k_enc);
            const decryptedMessage = await this.decryptMessage(encryptedMessage, this.k_dec);
            console.log("TEST Decrypted:", decryptedMessage);

        },

        // Operazioni svolte dall'ADMIN
        async adminOperations() {
            console.log("ADMIN OPERATIONS")

            let provider, contract, signer, contractWithSigner;

            try {
                provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
                contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);

                contract.removeAllListeners("UserEnrolled");
                contract.removeAllListeners("VerifierEnrolled");

                // Operazioni svolte dall'ADMIN
                // Admin in ascolto dell'evento "UserEnrolled" dallo SC
                contract.on("UserEnrolled", async (user, publicKey) => {
                    console.log("------- ADMIN EVENT 1: UserEnrolled")
                    signer = provider.getSigner("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"); // Admin Address
                    contractWithSigner = contract.connect(signer);

                    console.log(`Nuovo utente logged: ${user}, Chiave pubblica: ${publicKey}`);
                    // l'Admin ottiene la chiave pubblica dell'utente
                    // cifra la encryptionKey K con la chiave pubblica dell'utente
                    console.log("ADMIN: ENCRYPT K_ENC")
                    //const K = "qAR0LRGH2JhMVw8k2+zg1ECAk1j9xo3ZDc7DA2rCpwo=";
                    //const encryptedKey = await this.encryptKeyECIES(K, publicKey);
                    const encryptedKey = await this.encryptKeyECIES(this.$store.state.k_enc, publicKey);
                    console.log('ADMIN: Encrypted K:', encryptedKey);

                    // invia encryptedKey allo SC
                    console.log("SENDING Encripted Key to Contract...")
                    const tx = await contractWithSigner.sendEncryptedKey(this.$store.state.userAddress, encryptedKey);
                    await tx.wait();
                    console.log("SENT SUCCESSFULLY!");
                });

                // Operazioni svolte dall'ADMIN
                // Admin in ascolto dell'evento "VerifierEnrolled" dallo SC
                contract.once("VerifierEnrolled", async (user, publicKey) => {
                    console.log("------- ADMIN EVENT 2: VerifierEnrolled")

                    signer = provider.getSigner("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"); // Admin Address
                    contractWithSigner = contract.connect(signer);

                    console.log(`Verifier address: ${user}, Chiave pubblica: ${publicKey}`);
                    // l'Admin ottiene la chiave pubblica del Verifier
                    // cifra la encryptionKey K con la chiave pubblica del Verifier
                    console.log("ADMIN: ENCRYPT K_DEC")
                    //const K = "qAR0LRGH2JhMVw8k2+zg1ECAk1j9xo3ZDc7DA2rCpwo=";
                    //const encryptedKey = await this.encryptKeyECIES(K, publicKey);
                    const encryptedKey = await this.encryptKeyECIES(this.$store.state.k_dec, publicKey);
                    console.log('ADMIN: Encrypted K:', encryptedKey);

                    // invia encryptedKey allo SC
                    console.log("SENDING Encripted Key to Contract...")
                    const tx = await contractWithSigner.sendEncryptedKey(this.$store.state.userAddress, encryptedKey);
                    await tx.wait();
                    console.log("SENT SUCCESSFULLY!");
                    
                });


            } catch (error) {
                console.error("Error connecting to Ethereum provider:", error);
                return;
            }
        },

        // codifica la chiave per la codifica del file con la chiave pubblica dell'utente
        async encryptKeyECIES(K, publicKeyHex) { 
            const publicKey = ec.keyFromPublic(publicKeyHex.slice(2), 'hex');
            console.log("Public Key: ", publicKey);

            const sharedSecret = publicKey.getPublic().encode('hex');

            // Usa AES per cifrare la chiave con il segreto condiviso
            const encrypted = CryptoJS.AES.encrypt(K, sharedSecret).toString();
            //console.log('Encrypted Key:', encrypted);
            return encrypted; 
        },

        

        
        // Genera la coppia di chiavi del Admin
        async generateKeyPair() {
            const keyPair = await window.crypto.subtle.generateKey(
                {
                    name: "RSA-OAEP",
                    modulusLength: 2048,
                    publicExponent: new Uint8Array([1, 0, 1]),
                    hash: "SHA-256",
                },
                true, // True per permettere l'export delle chiavi
                ["encrypt", "decrypt"] // Operazioni consentite
            );

            return {
                publicKey: await this.exportPublicKey(keyPair.publicKey),
                privateKey: await this.exportPrivateKey(keyPair.privateKey),
            };
        },
        async exportPublicKey(key) {
            const exported = await window.crypto.subtle.exportKey("spki", key);
            return btoa(String.fromCharCode(...new Uint8Array(exported)));
        },
        async exportPrivateKey(key) {
            const exported = await window.crypto.subtle.exportKey("pkcs8", key);
            return btoa(String.fromCharCode(...new Uint8Array(exported)));
        },
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

        // Test codifica messaggio con la chiave k_enc
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
        // Test decodifica messaggio con la chiave k_dec
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


        



    },
  
    
}
</script>
