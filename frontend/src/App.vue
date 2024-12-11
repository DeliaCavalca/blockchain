<template>

  <div id="app">
    <h1>{{ message }}</h1>
    <button @click="fetchMessage">Fetch Message</button>
  </div>

</template>

<script>
import { JsonRpcProvider, Contract } from "ethers";

export default {
  data() {
    return {
      message: "",
    };
  },
  methods: {
    async fetchMessage() {
      try {
        console.log("Get message from Contract HelloWorld");

        const provider = new JsonRpcProvider("http://localhost:8545");  // Hardhat deve essere in esecuzione su questa URL
        const contractAddress = "0x5fbdb2315678afecb367f032d93f642f64180aa3";  // Indirizzo del contratto distribuito
        const contractABI = [
          "function message() view returns (string)"
        ];

        // Crea il contratto
        const contract = new Contract(contractAddress, contractABI, provider);

        // Ottieni il messaggio dal contratto
        const msg = await contract.message();
        this.message = msg;
      } catch (err) {
        console.error("Errore durante il fetch del messaggio:", err);
      }
    }
  }
};

</script>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>
