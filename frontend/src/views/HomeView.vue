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

  
</template>
  
<script>
import { mapGetters } from 'vuex'
import eventBus from '@/eventBus';
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto

import DataUploader from '../components/DataUploader.vue';
import DataVerifier from '../components/DataVerifier.vue';
import DataManager from '../components/DataManager.vue';
import SettingsManager from '../components/SettingsManager.vue';

export default {
    name: 'HomeView',
    components: {
        DataUploader, DataVerifier, DataManager, SettingsManager
    },
  
    data() {
      return {
        contractAddress: null, // Indirizzo del Contratto
        
        userAddress: null, // Indirizzo dell'utente Ethereum
        userRole: null,

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

    },
  
    
}
</script>
