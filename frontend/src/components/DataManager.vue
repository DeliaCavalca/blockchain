<template>
    <div style="font-size: 13px; text-align: left;">
      
      <!-- Numero di file caricati -->
      <div class="row mt-4">
          <div class="col" style="text-align: left;">
            <span>Numero totale di file caricati:</span>
          </div>
      </div>
      <div class="row mt-1">
          <div class="col d-flex" style="text-align: left;">
            <span class="border" style="border-radius: 10px; padding: 3px 8px 3px 8px;"><strong>{{ numFileTot }}</strong></span>
          </div>
      </div>

      <!-- Numero di file validati -->
      <div class="row mt-2">
          <div class="col" style="text-align: left;">
            <span>Numero di file validati:</span>
          </div>
          <div class="col" style="text-align: left;">
            <span>Numero di file scartati:</span>
          </div>
          <div class="col" style="text-align: left;">
            <span>Numero di file da verificare:</span>
          </div>
      </div>
      <div class="row mt-1">
          <div class="col d-flex" style="text-align: left;">
            <span class="border" style="border-radius: 10px; padding: 3px 8px 3px 8px;"><strong>{{ numFileValid }}</strong></span>
          </div>
          <div class="col d-flex" style="text-align: left;">
            <span class="border" style="border-radius: 10px; padding: 3px 8px 3px 8px;"><strong>{{ numFileNotValid }}</strong></span>
          </div>
          <div class="col d-flex" style="text-align: left;">
            <span class="border" style="border-radius: 10px; padding: 3px 8px 3px 8px;"><strong>{{ numFileToCheck }}</strong></span>
          </div>
      </div>
  
    </div>
  </template>
  
<script>
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto

export default {
    name: 'DataManager',
    data() {
      return {
        contractAddress: null, // Indirizzo del Contratto
        userAddress: null, // Indirizzo dell'utente Ethereum
  
        numFileTot: null, // Num tot di file caricati
        numFileValid: null,
        numFileNotValid: null,
        numFileToCheck: null,
      };
    },
  
    created() {
      this.contractAddress = this.$store.state.contractAddress
      this.userAddress = this.$store.state.userAddress

      this.getUploadedFiles();
    },
  
    methods: {
      // Funzione per ottenere i file caricati su IPFS
      async getUploadedFiles() {

        let provider, contract; 

        try {
          provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
          contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
            
          // Ottieni i dati caricati
          const data = await contract.getAllData();

          const uploadedHashes = data[0]
          //const owners = data[1]
          const verified = data[2]
          const verifiedNotValid = data[3]

          this.numFileTot = uploadedHashes.length
          this.numFileValid = verified.filter(Boolean).length;
          this.numFileNotValid = verifiedNotValid.filter(Boolean).length;
          this.numFileToCheck = this.numFileTot - this.numFileValid - this.numFileNotValid
                
        } catch (error) {
          console.error("Errore nel ottenere Numero Tot di File:", error);
        }

      },


    }
};
</script>
  
<style scoped>

  
</style>