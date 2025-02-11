<template>

    <div class="w-100 box">
      <h1 class="">Crowdsensing App</h1>
      <p class="m-auto mt-3 p-0" style="max-width: 500px;">
        Benvenuto nel Sistema di Crowdsensing Decentralizzato!
      </p>
      <p class="m-auto p-0" style="max-width: 500px; font-size: 13px;">
        Raccogli, verifica e accedi a dati autentici in modo sicuro e trasparente grazie a blockchain, IPFS e crittografia avanzata. Unisciti a una rete collaborativa per la condivisione di dati affidabili e decentralizzati.
      </p>

      <div class="border loginBox">
        <p class="m-0 p-0" style="font-size: 19px;">Connessione alla Blockchain</p>
        <p class="m-0 p-0 mt-4 mb-2" style="font-size: 14px;" >Inserisci l'Indirizzo del tuo Account</p>
        
        <p v-if="errorMsg" class="m-0 p-0" style="font-weight: bold; font-size: 12px; color: darkred;">{{ errorMsg }}</p>

        <input v-model="userAddress" placeholder="User Address" class="form-control mt-1">
        <button @click="connectUser" class="btn btn-primary mt-2 w-100">Connetti</button>
      </div>


    </div>
    

</template>
  
<script>
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/Crowdsensing.sol/Crowdsensing.json"; // Percorso corretto

export default {
    name: 'SignInBox',
    components: {
      
    },
  
    data() {
      return {
        userAddress: null, // Indirizzo dell'utente Ethereum

        errorMsg: null,

      };
    },
  
  
    created() {
      
    },
  
    methods: {
      // Funzione per connettere l'utente       
      async connectUser() {

        const contractAddress = this.$store.state.contractAddress
        
        let provider, contract; //signer, contractWithSigner;
      
        try {
          provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
          contract = new ethers.Contract(contractAddress, DataStorage.abi, provider);


          // Verifica che l'indirizzo sia valido
          if (!ethers.utils.isAddress(this.userAddress)) {
            //alert("Indirizzo non valido!");
            this.errorMsg = "Attenzione! Indirizzo non valido."
            console.error("USER NON VALIDO")  
            return;
          }
 
          const accounts = await provider.listAccounts(); // Ottiene tutti gli account disponibili
          // Verifica che l'indirizzo esista tra quelli del provider
          if (!accounts.includes(this.userAddress)) {
            //alert("Indirizzo non valido!");
            this.errorMsg = "Attenzione! Indirizzo non valido."
            console.error("USER NON VALIDO")                    
            return;
          }

          console.log("USER CORRETTO") 

                
          // Ottieni il saldo ETH dell'utente
          const balance = await provider.getBalance(this.userAddress); // Saldo
          console.log(`Initial Balance: ${ethers.utils.formatEther(balance)} ETH`);
          const ethBalance = ethers.utils.formatEther(balance); // Converte il saldo in ETH
                
          // Ottieni il ruolo dell'utente       
          const role = await contract.getUserRole(this.userAddress);
          let roleString;
          console.log("RUOLO dell'utente:", role);
          /**
           * RUOLO 0 = USER
           * RUOLO 1 = VERIFIER
           * RUOLO 2 = ADMIN
          */
          if(role == 0) {
            roleString = "User"
          }
          if(role == 1) {
            roleString = "Verifier"
          }
          if(role == 2) {
            roleString = "Admin"
          }
          
          // Ottieni lo Stato della campagna
          const status = await contract.getCampaignStatus();
          console.log("Stato della campagna: ", status);

          // Ottieni il chunk size (dimensione dei blocchi in cui suddividere i dati)      
          const chunkSize = await contract.getChunkSize();
          console.log("Chunk Size: ", chunkSize);
          
          console.log("Connesso con l'indirizzo:", this.userAddress);

          this.$store.commit('SET_USER_ADDRESS', this.userAddress);
          this.$store.commit('SET_USER_ROLE', roleString);
          this.$store.commit('SET_ETH_BALANCE', ethBalance);
          this.$store.commit('SET_STATUS', status);
          this.$store.commit('SET_CHUNK_SIZE', chunkSize);
                   
        } catch (error) {
          console.error("Errore durante la connessione:", error);
        }

      },
    },
  
  }
</script>

<style scoped>
.box {
  padding: 100px;
}
.loginBox {
  max-width: 500px;
  margin: auto;
  margin-top: 30px;
  padding: 50px;
  border-radius: 10px;
}
</style>