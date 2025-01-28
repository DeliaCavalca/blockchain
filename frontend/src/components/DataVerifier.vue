<template>
  <div style="font-size: 13px; text-align: left;">
    
    <p class="m-0 p-0 mb-3">File da validare:</p>

    <input v-model="ipfsHash" placeholder="IPFS Hash">
    <input v-model="encryptionKey" placeholder="Encryption Key">
    <button @click="verifyAndCheckBalance">Verify</button>
    <p>{{ message }}</p>

  </div>
</template>

<script>
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto

export default {
  data() {
    return {
      contractAddress: null, // Indirizzo del Contratto
      userAddress: null, // Indirizzo dell'utente Ethereum

      ipfsHash: "",
      encryptionKey: "",
      message: "",
    };
  },

  created() {
    this.contractAddress = this.$store.state.contractAddress
    this.userAddress = this.$store.state.userAddress
  },

  methods: {

    // Converti la stringa hash IPFS in bytes32
    ipfsHashToBytes32(ipfsHash) {
      return ethers.utils.id(ipfsHash);
    },

    // Verifica i dati sulla blockchain e controlla il saldo
    async verifyAndCheckBalance() {
      if (!this.ipfsHash || !this.encryptionKey) {
        this.message = "IPFS hash and encryption key are required.";
        console.log(this.message);
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

        console.log("Verifying data on blockchain...");
        const ipfsHashBytes32 = this.ipfsHashToBytes32(this.ipfsHash);
        const tx = await contractWithSigner.verifyData(ipfsHashBytes32, this.encryptionKey);
        console.log("Transaction sent:", tx.hash);
        this.message = `Transaction sent: ${tx.hash}`;
        console.log("Transaction hash:", tx.hash);
        await tx.wait();

        const finalBalance = await provider.getBalance(this.userAddress);
        const finalEthBalance = ethers.utils.formatEther(finalBalance); // Converte il saldo in ETH
        console.log(`Final Balance: ${finalEthBalance} ETH`);
        this.$store.commit('SET_ETH_BALANCE', finalEthBalance);

        console.log("DATA VERIFIED SUCCESSFULLY!");

      } catch (error) {
        console.error("Error connecting to Ethereum provider:", error);
        return;
      }
      
    }
  }
};
</script>

<style scoped>



</style>