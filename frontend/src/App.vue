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
import IPFSMessageABI from "./../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json";


export default {
  data() {
    return {
      message: "",
      ipfsHash: "",
      messages: [],
      contractAddress: "0x5fbdb2315678afecb367f032d93f642f64180aa3", // Indirizzo del contratto sulla blockchain
      contract: null,
    };
  },
  methods: {

    isBase64(str) {
      try {
        return btoa(atob(str)) === str;
      } catch (err) {
        return false;
      }
    },

    /** Connessione a un nodo blockchain locale tramite Hardhat: 
     * Interazione con uno Smart Contract per il recupero dei messaggi */
    async fetchMessages() {
      console.log("FETCH MESSAGES")
      try {
        // Connessione alla rete locale Hardhat
        const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
        // Crea un'istanza del contratto
        const contract = new ethers.Contract(this.contractAddress, IPFSMessageABI.abi, provider);

        // Recupera i messaggi dal contratto
        const messages = await contract.getMessages();
        console.log(messages)
        this.messages = messages.map((msg) => ({
          ipfsHash: msg.ipfsHash, // hash che rappresenta i dati del messaggio salvati su IPFS
          sender: msg.sender, // indirizzo del mittente che ha inviato il messaggio
        }));

        // Scarica e decifra i messaggi da IPFS (Privato)
        const ipfs = ipfsHttpClient({ url: "http://localhost:5001" }); // Nodo privato
        console.log("--- Connect to IPFS")

        for (const message of this.messages) {
          // Recupera il dato (messaggio) dal nodo IPFS usando l'hash
          let ipfsData = '';
          for await (const chunk of ipfs.cat(message.ipfsHash)) {
            // Unisce tutti i chunk restituiti da IPFS
            ipfsData += String.fromCharCode(...chunk); // `chunk` è un Buffer, quindi lo convertiamo in stringa
          }
          console.log(ipfsData)

          // Assicurati che ipfsData sia valido
          if (this.isBase64(ipfsData)) {
            // Decodifica da Base64
            const decodedMessage = atob(ipfsData); // Decodifica correttamente
            console.log("Decoded Message:", decodedMessage);
            this.message = decodedMessage;  // Salva il messaggio decodificato
          } else {
            console.error("The data retrieved from IPFS is not in Base64 format");
          }
        }


      } catch (error) {
        console.error("Error fetching messages:", error);
      }
    },

    /** Salvataggio dati su IPFS, salvare hash IPFS del dato su Smart Contract sulla blockchain */
    async uploadToIPFS() {
      console.log("UPLOAD TO IPFS")
      try {
        // connessione al nodo locale IPFS
        const ipfs = ipfsHttpClient({ url: "http://localhost:5001" });

        // Crittografa il messaggio prima del caricamento 
        console.log("Messaggio da salvare: ", this.message)
        const encryptedMessage = btoa(this.message); // Semplice Base64 
        console.log("Messaggio codificato: ", encryptedMessage)

        // caricamento del messaggio su IPFS
        const result = await ipfs.add(encryptedMessage);
        this.ipfsHash = result.path; // CID del dato caricato su IPFS

        // Interagire con il contratto per salvare l'hash IPFS
        const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545"); // Connessione alla rete Hardhat
        // Prende il primo address tra gli account Hardhat disponibili
        const signer = provider.getSigner(0); 
        // Crea un'istanza del contratto
        this.contract = new ethers.Contract(this.contractAddress, IPFSMessageABI.abi, signer);

        // Salvataggio del CID sullo Smart Contract (CID del dato salvato su IPFS) 
        const tx = await this.contract.storeMessage(this.ipfsHash);
        await tx.wait();
        alert("Message stored on the blockchain!");

        this.fetchMessages();
      } catch (error) {
        console.error("Error uploading to IPFS:", error);
      }
    },

    
    
  },
  async mounted() {

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
