<template>
    <div style="font-size: 13px; text-align: left;">
      
        <div class="row">
            <div class="col" style="text-align: left;">
                <span>Status:</span>
            </div>

            <div class="col" style="font-weight: bold; text-align: right;">
                <span>{{ this.$store.state.status }}</span>
                <i v-if="isClosed" class="bi bi-x-circle-fill m-2" style="color: darkred;"></i>
                <i v-else class="bi bi-opencollective text-primary m-2"></i>
            </div>
        </div>

        
        <!-- Saldo SC -->
        <div class="row mt-3">
            <div class="col" style="text-align: left;">
                <span>Disponibilità attuale sul Contratto:</span>
            </div>

            <div class="col" style="text-align: right;">
                <span>Modifica</span>
            </div>
        </div>
 
        <div class="row mt-1">
            <div class="col d-flex" style="text-align: left;">
                <span class="border p-1" style="border-radius: 10px;"><strong>{{ formattedEthBalance }}</strong></span>
                <span class="p-1"><strong>ETH</strong></span>
            </div>

            <div class="col" style="text-align: right; font-weight: bold;">
                <button @click="addBalance" class="border btn-balance" style="border-radius: 10px; padding: 3px 8px 3px 8px; margin-right: 5px;"><strong>+</strong></button>
                <button @click="removeBalance" class="border btn-balance" :disabled="Number(this.ethBalanceSC) === Number(this.ethBalanceTemp)" style="border-radius: 10px; padding: 3px 10px 3px 10px;"><strong>-</strong></button>
            </div>
        </div>

        <div class="row mt-1">
            <div class="col" style="">
                <span @click="resetBalance" class="" style="cursor: pointer;">Reset</span>
            </div>
            <div class="col" style=" text-align: right;">
                <button class="btn-update" @click="depositFunds" :disabled="Number(this.ethBalanceSC) === Number(this.ethBalanceTemp)">Aggiorna Disponibilità</button>
            </div>
        </div>

        <!-- Chiusura Campagna -->
        <div class="row mt-5">
            <div class="col" style="text-align: left;">
                <span>Numero minimo di partecipazioni per la chiusura:</span>
            </div>

            <div class="col" style="text-align: right;">
                <span>Modifica</span>
            </div>
        </div>

        <div class="row mt-1">
            <div class="col d-flex" style="text-align: left;">
                <span class="border p-1" style="border-radius: 10px;"><strong>{{ numPartecipantsTemp }}</strong></span>
            </div>

            <div class="col" style="text-align: right; font-weight: bold;">
                <button @click="addPartecipant" class="border btn-balance" style="border-radius: 10px; padding: 3px 8px 3px 8px; margin-right: 5px;"><strong>+</strong></button>
                <button @click="removePartecipant" class="border btn-balance" :disabled="Number(numPartecipantsTemp) < 2" style="border-radius: 10px; padding: 3px 10px 3px 10px;"><strong>-</strong></button>
            </div>
        </div>

        <div class="row mt-1">
            <div class="col" style="">
                <span @click="resetPartecipants" class="" style="cursor: pointer;">Reset</span>
            </div>
            <div class="col" style=" text-align: right;">
                <button class="btn-update" @click="updatePartecipants" :disabled="Number(this.numPartecipants) === Number(this.numPartecipantsTemp)">Aggiorna Partecipanti</button>
            </div>
        </div>
  
    </div>
  </template>
  
<script>
import { mapGetters } from 'vuex'
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto

export default {
    name: 'SettingsManager',
    data() {
      return {
        contractAddress: null, // Indirizzo del Contratto
        userAddress: null, // Indirizzo dell'utente Ethereum
        
        ethBalanceSC: null, // Balance sullo Smart Contract
        ethBalanceTemp: null,

        numPartecipants: null, // Numero minimo di partecipanti per la chiusura 
        numPartecipantsTemp: null,
    };
    },
  
    created() {
        this.contractAddress = this.$store.state.contractAddress
        this.userAddress = this.$store.state.userAddress

        this.getContractBalance();

        this.getCampaignStatus();

        this.getNumPartecipants();
    },

    computed: {

        ...mapGetters(['isClosed']),

        formattedEthBalance() {
            return Number(this.ethBalanceTemp)
                .toLocaleString('it-IT', { 
                minimumFractionDigits: 2, 
                maximumFractionDigits: 4 
            });
        },
    },
  
    methods: {
        async getContractBalance() {
            let provider, contract;

            try {
                provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
                contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
                
                // Ottieni il balance del Contratto
                const balance = await contract.getContractBalance();
                console.log("Saldo del contratto:", ethers.utils.formatEther(balance), "ETH");

                this.ethBalanceSC = parseFloat(ethers.utils.formatEther(balance));
                this.ethBalanceTemp = this.ethBalanceSC
                
                return;
            } catch (error) {
                console.error("Error getting contract balance:", error);
                return;
            }
        },

        resetBalance() {
            this.ethBalanceTemp = this.ethBalanceSC
        },

        addBalance() {
            this.ethBalanceTemp = Number(this.ethBalanceTemp) + 1
        },

        removeBalance() {
            if(Number(this.ethBalanceTemp) > Number(this.ethBalanceSC)) {
                this.ethBalanceTemp = Number(this.ethBalanceTemp) - 1
            }
        },

        async depositFunds() {
            let amount = Number(this.ethBalanceTemp) - Number(this.ethBalanceSC)
            console.log("Amount to Deposit: ", amount)

            let provider, contract, signer, contractWithSigner;

            try {
                provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
                contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
                
                signer = provider.getSigner(this.userAddress);
                contractWithSigner = contract.connect(signer);

                // Aggiorna il balance del Contratto
                const tx = await contractWithSigner.depositFunds({value: ethers.utils.parseEther(amount.toString())});
                await tx.wait();
                
                console.log("Deposito SC aggiornato.")

                // Aggiorna il Saldo del Contratto
                this.getContractBalance();
                // Aggiorna il Saldo dell'Utente
                this.getUserBalance();
                
                return;
            } catch (error) {
                console.error("Error getting contract balance:", error);
                return;
            }
        },

        async getUserBalance() {

            let provider;

            try {
                provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
                    
                // Ottieni il saldo ETH dell'utente
                const balance = await provider.getBalance(this.userAddress); // Saldo
                const ethBalance = ethers.utils.formatEther(balance); // Converte il saldo in ETH
                this.$store.commit('SET_ETH_BALANCE', ethBalance);
                    
            } catch (error) {
                console.error("Errore nel caricamento di User Balance:", error);
            }

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

        async getNumPartecipants() {
            let provider, contract;

            try {
                provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
                contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
                
                // Ottieni il numero minimo di partecipanti
                const num = await contract.getNumPartecipants();
                console.log("MIN Partecipanti:", num);

                this.numPartecipants = num
                this.numPartecipantsTemp = num
                
                return;
            } catch (error) {
                console.error("Error getting MIN Partecipanti:", error);
                return;
            }
        },

        addPartecipant() {
            this.numPartecipantsTemp = Number(this.numPartecipantsTemp) + 1
        },

        removePartecipant() {
            if(Number(this.numPartecipantsTemp) > 1) {
                this.numPartecipantsTemp = Number(this.numPartecipantsTemp) - 1
            }
        },

        resetPartecipants() {
            this.numPartecipantsTemp = this.numPartecipants
        },

        async updatePartecipants() {

            let provider, contract, signer, contractWithSigner; 

            try {
                provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
                contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
                
                signer = provider.getSigner(this.userAddress);
                contractWithSigner = contract.connect(signer);

                // Aggiorna il numero di partecipanti
                const tx = await contractWithSigner.setMinimumParticipants(this.numPartecipantsTemp);
                await tx.wait();

                // Aggiorna partecipanti e status
                this.getCampaignStatus();
                this.getNumPartecipants();
                    
            } catch (error) {
                console.error("Errore nel aggiornamento Partecipanti:", error);
            }
        }
    }
};
</script>
  
<style scoped>

.btn-balance:hover {
    background-color: rgb(241, 241, 241);
    cursor: pointer;
}
.btn-balance:disabled {
    cursor: not-allowed;  /* Mostra un cursore di tipo 'non consentito' */
    background-color: transparent;  /* Non cambia il colore di sfondo */
    color: #ccc; /* Imposta il colore del testo come grigio chiaro per indicare che è disabilitato */
    border: 1px solid #ccc;
}
.btn-balance:disabled:hover {
    background-color: transparent;  /* Mantiene lo sfondo trasparente */
    color: #ccc;
    border: 1px solid #ccc;
}

.btn-update {
    border: 0px;
    font-weight: bold;
    background-color: transparent;
    cursor: pointer;
}
.btn-update:disabled {
    border: 0px;
    background-color: transparent;
    cursor: not-allowed;
}
  
</style>