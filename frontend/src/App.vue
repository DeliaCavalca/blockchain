<template>
  <div id="app">
    <h1>IPFS Decentralized Messaging</h1>
    <textarea v-model="message" placeholder="Write your message here"></textarea>
    <button @click="uploadToIPFS">Save to IPFS</button>
    <p v-if="ipfsHash">IPFS Hash: {{ ipfsHash }}</p>
    <ul>
      <li v-for="msg in messages" :key="msg.ipfsHash">
        <a :href="`https://ipfs.io/ipfs/${msg.ipfsHash}`" target="_blank">{{ msg.ipfsHash }}</a> - {{ msg.sender }}
      </li>
    </ul>
  </div>
</template>

<script>
import { create as ipfsHttpClient } from "ipfs-http-client";
import { ethers } from "ethers";
//import IPFSMessageABI from "/Users/giuseppecacciapuoti/Desktop/blockchain-main/hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json";
import IPFSMessageABI from "./../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json";


export default {
  data() {
    return {
      message: "",
      ipfsHash: "",
      messages: [],
      contractAddress: "0x5fbdb2315678afecb367f032d93f642f64180aa3", // Indirizzo del contratto
      contract: null,
    };
  },
  methods: {
    async uploadToIPFS() {
      console.log("UPLOAD TO IPFS")
      try {
        const ipfs = ipfsHttpClient({ url: "http://localhost:5001" });
        const result = await ipfs.add(this.message);
        this.ipfsHash = result.path; //CID

        // Interagire con il contratto per salvare l'hash IPFS
        const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545"); // Connessione alla rete Hardhat
        const signer = provider.getSigner(0); //Prende il primo address tra gli account hardhat creati
        this.contract = new ethers.Contract(this.contractAddress, IPFSMessageABI.abi, signer);

        const tx = await this.contract.storeMessage(this.ipfsHash);
        await tx.wait();
        alert("Message stored on the blockchain!");

        this.fetchMessages();
      } catch (error) {
        console.error("Error uploading to IPFS:", error);
      }
    },
    async fetchMessages() {
      console.log("FETCH MESSAGES")
      try {
        const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545"); // Connessione alla rete Hardhat
        const contract = new ethers.Contract(this.contractAddress, IPFSMessageABI.abi, provider);

        const messages = await contract.getMessages();
        console.log(messages)
        this.messages = messages.map((msg) => ({
          ipfsHash: msg.ipfsHash,
          sender: msg.sender,
        }));
      } catch (error) {
        console.error("Error fetching messages:", error);
      }
    },
  },
  async mounted() {

    console.log("Test Connection to IPFS")
  
    const ipfs = ipfsHttpClient({ url: "http://localhost:5001" });
    console.log(ipfs)
    ipfs.add("Test message")
      .then(result => console.log("Uploaded CID:", result.path))
      .catch(error => console.error("CORS error:", error));


    await this.fetchMessages();

  },
};
</script>

<style>
textarea {
  width: 100%;
  height: 100px;
  margin-bottom: 10px;
}
</style>
