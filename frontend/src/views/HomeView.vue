<template>
  
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

        <div class="d-flex justify-content-between mt-3">
            <span><strong>{{ userRole }}</strong></span>
        </div>

        <div class="d-flex mt-3 mb-1">
            <span style="font-size: 12px;">Disponibilità attuale:</span>
        </div>
        <div class="d-flex">
            <span class="border p-1" style="border-radius: 10px;"><strong>{{ formattedEthBalance }}</strong></span>
            <span class="p-1"><strong>ETH</strong></span>
        </div>
        
    </div>

    <div class="border mt-3 p-3" style="border-radius: 6px;">
        <p class="m-0 p-0" style="font-weight: bold;  text-align: left;">Caricamento Dati Crowdsensing</p>
        <p class="m-0 p-0 mb-3" style="text-align: left; font-size: 13px;">
            Contribuisci al nostro sistema decentralizzato caricando i tuoi dati in modo sicuro e verificabile!
        </p>
        
        <DataUploader />
    </div>

    <div class="border mt-3 p-3" v-if="isVerifier" style="border-radius: 6px;">
        <p class="m-0 p-0" style="font-weight: bold; text-align: left;">Validazione Dati Crowdsensing</p>
        <p class="m-0 p-0 mb-3" style="text-align: left; font-size: 13px;">
            Esamina i dati caricati dagli utenti e convalidali!
        </p>
        
        <DataVerifier />
    </div>

  
</template>
  
<script>
import { mapGetters } from 'vuex'

import DataUploader from '../components/DataUploader.vue';
import DataVerifier from '../components/DataVerifier.vue';

export default {
    name: 'HomeView',
    components: {
        DataUploader, DataVerifier
    },
  
    data() {
      return {
        contractAddress: null, // Indirizzo del Contratto
        
        userAddress: null, // Indirizzo dell'utente Ethereum
        userRole: null,

        seeUserAddress: false,
      };
    },

    computed: {
        ...mapGetters(['ethBalance']),
        ...mapGetters(['isAdmin']),
        ...mapGetters(['isVerifier']),

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
    },
  
    methods: {

        // Funzione per disconnettere l'utente 
        logoutUser() {
            this.userAddress = null
            this.ethBalance = null
            this.userRole = null
            this.$store.commit('SET_USER_ADDRESS', this.userAddress);
        },
    },
  
    
  }
</script>
