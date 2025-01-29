<template>
  <div style="font-size: 13px; text-align: left;">
    
    <p v-if="fileToVerifyList.length > 0" class="m-0 p-0 mb-3">File da validare:</p>
    <p v-else class="m-0 p-0">Nessun file da validare.</p>

    <div v-for="(file, index) in fileToVerifyList" :key="file.hash" class="file-item">
      <span><strong>File {{ index + 1 }}</strong></span>
      <a :href="file.url" target="_blank">Vedi File</a>
      <button class="custom-btn" @click="validateFile(file.hash)">Valida</button>
      <button class="custom-btn-2" @click="deleteFile(file.hash)">Elimina</button>
    </div>

  </div>
</template>

<script>
import { create as ipfsHttpClient } from 'ipfs-http-client';
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto
import eventBus from '@/eventBus';

const client = ipfsHttpClient({ url: 'http://localhost:5001' });

export default {
  data() {
    return {
      contractAddress: null, // Indirizzo del Contratto
      userAddress: null, // Indirizzo dell'utente Ethereum

      ipfsHash: "",
      encryptionKey: "",
      hashToVerifyList: [],
      fileToVerifyList: [],
    };
  },

  created() {
    this.contractAddress = this.$store.state.contractAddress
    this.userAddress = this.$store.state.userAddress

    this.getUnverifiedFile();

    // manage the event showAlertSuccessLoad
    eventBus.on('showAlertSuccessLoad', () => {
      this.getUnverifiedFile();
    });
  },

  methods: {

    // Converti la stringa hash IPFS in bytes32
    /*
    ipfsHashToBytes32(ipfsHash) {
      return ethers.utils.id(ipfsHash);
    },*/

    // Ottenere l'elenco di hash da verificare dallo SC
    async getUnverifiedHash() {
      let provider, contract;

      try {
        provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
        contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
        
        // Ottieni gli hash in formato bytes32
        const unverifiedHashes = await contract.getUnverifiedData();
        console.log("Unverified IPFS Hashes:", unverifiedHashes.length);

        this.hashToVerifyList = unverifiedHashes;
        
        return;
      } catch (error) {
        console.error("Error fetching unverified hashes:", error);
        return;
      }
    },

    // Ottenere l'elenco di file da verificare da IPFS
    async getUnverifiedFile() {
      await this.getUnverifiedHash()

      if (this.hashToVerifyList.length === 0) {
        console.log("Nessun file da validare");
        return;
      }

      const files = await Promise.all(
        this.hashToVerifyList.map(async (ipfsHash) => {
            try {

              // Recupera il file da IPFS, usando il CID
              const stream = client.cat(ipfsHash);
              
              let data = new Uint8Array();
              for await (const chunk of stream) {
                data = new Uint8Array([...data, ...chunk]); // Concatena i chunk ricevuti
              }
              
              const blob = new Blob([data]);
              return { hash: ipfsHash, url: URL.createObjectURL(blob) };

            } catch (error) {
                console.error(`Errore nel download del file IPFS con hash ${ipfsHash}:`, error);
                return null;
            }
        })
      );

      this.fileToVerifyList = files.filter(file => file !== null);
      return;

    },


    // Valida un file
    async validateFile(hash) {
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
        const key = await contract.getEncryptedKey(hash);

        if(!key) {
          console.log("Errore durante la validazione. Key non valida.");
          return;
        }

        signer = provider.getSigner(this.userAddress);
        contractWithSigner = contract.connect(signer);

        const initialBalance = await provider.getBalance(this.userAddress);
        console.log(`Initial Balance: ${ethers.utils.formatEther(initialBalance)} ETH`);


        // Valida il File
        const tx = await contractWithSigner.verifyData(hash, key);
        console.log("Transaction hash:", tx.hash);
        await tx.wait();

        console.log("DATA VERIFIED SUCCESSFULLY!");

        // Controlla e Aggiorna il Balance dell'utente
        /**  
         * TODO: viene aggiornato/ottenuto il saldo di user che crea la transazione o del verifier??
        
        */
        const finalBalance = await provider.getBalance(this.userAddress);
        const finalEthBalance = ethers.utils.formatEther(finalBalance); // Converte il saldo in ETH
        console.log(`Final Balance: ${finalEthBalance} ETH`);
        this.$store.commit('SET_ETH_BALANCE', finalEthBalance);


        // Ottieni e Aggiorna lo Stato della campagna
        const status = await contractWithSigner.getCampaignStatus();
        console.log("Stato della campagna: ", status);
        this.$store.commit('SET_STATUS', status);

        // Aggiorna la lista dei file da validare
        this.getUnverifiedFile();

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
  gap: 20px; /* Distanza tra gli elementi */
  margin-top: 5px;
}
.file-item:hover {
  background-color: rgb(238, 235, 235);
}

</style>