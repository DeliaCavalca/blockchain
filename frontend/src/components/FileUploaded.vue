<template>
    <div style="font-size: 13px; text-align: left;">
      
        <div v-for="(file, index) in fileList" :key="file.hash">
            <div class="file-item mt-3">
                <span><strong>File {{ index + 1 }}</strong></span>
                <a :href="processedFileUrl" @click.prevent="prepareDownload(file)" target="_blank">Vedi File</a>
            </div>
        </div>
  
    </div>
  </template>
  
<script>
import { create as ipfsHttpClient } from 'ipfs-http-client';
import { ethers } from 'ethers';
import DataStorage from "../../../hardhat/artifacts/contracts/IPFSMessage.sol/IPFSMessage.json"; // Percorso corretto
import CryptoJS from "crypto-js";

const client = ipfsHttpClient({ url: 'http://localhost:5001' });

export default {
    name: 'DataManager',
    data() {
      return {
        contractAddress: null, // Indirizzo del Contratto
        userAddress: null, // Indirizzo dell'utente Ethereum
        
        encryptionKey: "qAR0LRGH2JhMVw8k2+zg1ECAk1j9xo3ZDc7DA2rCpwo=",
        
        hashList: [],
        fileList: [],
      };
    },
  
    created() {
      this.contractAddress = this.$store.state.contractAddress
      this.userAddress = this.$store.state.userAddress

      this.getUploadedFiles();
    },
  
    methods: {
        // Funzione per ottenere i file caricati su IPFS
        async getUploadedHash() {

            let provider, contract; 

            try {
            provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
            contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);
                
            // Ottieni i dati caricati
            const hashes = await contract.getVerifiedData();
            console.log("Verified IPFS Hashes:", hashes.length);

            this.hashList = hashes;

            } catch (error) {
            console.error("Errore nel ottenere File:", error);
            }

        },

        async getUploadedFiles() {
            await this.getUploadedHash();

            if (this.hashList.length === 0) {
                console.log("Nessun file trovato");
                this.fileList = [];
                return;
            }

            // Imposta il provider e il contratto una sola volta
            const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
            const contract = new ethers.Contract(this.contractAddress, DataStorage.abi, provider);

            const files = await Promise.all(
                this.hashList.map(async (indexIpfsHash) => {
                    try {
                    // Recupera la struttura dati dei blocchi da IPFS
                    const stream = client.cat(indexIpfsHash);
                    let indexData = new Uint8Array();
                    for await (const chunk of stream) {
                        indexData = new Uint8Array([...indexData, ...chunk]);
                    }

                    const indexJson = JSON.parse(new TextDecoder().decode(indexData));
                    const blockHashes = indexJson.blocks; // Array di CID dei blocchi
                    console.log("Block Hashes:", blockHashes);
                    
                    // Recupera la chiave AES con la quale è stato criptato il file
                    //const encryptedKey = await contract.getEncryptedKey(indexIpfsHash, this.userAddress);
                    //console.log("GET Encrypted Key:", encryptedKey);
                    const encryptedKey = this.encryptionKey;

                    // Recupera e verifica ogni blocco
                    let signatureError = ''
                    let decryptedFileParts = [];
                    for (const blockHash of blockHashes) {
                        const blockStream = client.cat(blockHash);
                        let blockData = new Uint8Array();
                        for await (const chunk of blockStream) {
                        blockData = new Uint8Array([...blockData, ...chunk]);
                        }

                        const blockJson = JSON.parse(new TextDecoder().decode(blockData));
                        const encryptedBlock = blockJson.block;
                        const signature = blockJson.signature;

                        console.log("ENCRYPTED BLOCK: ", encryptedBlock)

                        // Verifica la firma del blocco
                        // Calcola l'hash (digest) del blocco cifrato
                        const computedHash = await this.computeSHA256(encryptedBlock);
                        console.log("COMPUTED FILE DIGEST: ", computedHash);
                        // Ottieni l'indirizzo (chiave pubblica) originale di chi ha firmato
                        const recoveredSigner = ethers.utils.verifyMessage(computedHash, signature);
                        console.log("RECOVERED SIGNER ADDRESS: ", recoveredSigner);
                        // Recupera l'indirizzo (chiave pubblica) dell'utente che ha caricato tale hash
                        const userAddress = await contract.getOwnerAddress(indexIpfsHash);
                        console.log("USER ADDRESS: ", userAddress)

                        const isValid = recoveredSigner === userAddress;
                        console.log(`Blocco ${blockHash} - Firma valida?`, isValid);

                        if (!isValid) {
                        console.warn(`Blocco ${blockHash} ha una firma non valida!`);
                        return null;
                        }

                        if (isValid) {
                        console.log("La firma è valida. Il file è autentico.");
                        } else {
                        console.log("Firma non valida. Il file potrebbe essere stato manomesso.");
                        signatureError = 'Attenzione! Il file potrebbe essere stato manomesso.';
                        }
                        
                        // Decripta il blocco
                        const decryptedBlock = this.decryptBlock(encryptedBlock, encryptedKey);
                        decryptedFileParts.push(decryptedBlock);
                        console.log("DECRYPTED BLOCK")
                        console.log(decryptedBlock)
                    }

                    // Ricostruire il file completo
                    const completeFile = new Uint8Array(decryptedFileParts.reduce((acc, part) => [...acc, ...part], []));
                    const blob = new Blob([completeFile], { type: "application/octet-stream" });

                    return { hash: indexIpfsHash, url: URL.createObjectURL(blob), signatureError: signatureError };

                    } catch (error) {
                    console.error(`Errore nel download del file IPFS con hash ${indexIpfsHash}:`, error);
                    return null;
                    }
                })
            );

            this.fileList = files.filter(file => file !== null);
            
            return;

        },

        // Funzione per calcolare SHA-256 del file
        async computeSHA256(input) {
            if (input instanceof Blob) {
                input = await input.arrayBuffer(); // Converte Blob in ArrayBuffer
            }

            const buffer = new Uint8Array(input);
            const hash = ethers.utils.keccak256(buffer); // Calcola l'hash
            return hash;
        },

        decryptBlock(encryptedBase64, key) {
            try {

                // Decripta usando AES e la chiave fornita
                const decryptedBytes = CryptoJS.AES.decrypt(encryptedBase64, key);

                // Verifica se la decrittografia ha prodotto dei dati
                if (!decryptedBytes || !decryptedBytes.words) {
                throw new Error("Decryption failed. Check your key and data format.");
                }
                const decryptedBase64 = CryptoJS.enc.Utf8.stringify(decryptedBytes);

                const byteCharacters = atob(decryptedBase64);
                const byteNumbers = new Array(byteCharacters.length).fill(0).map((_, i) => byteCharacters.charCodeAt(i));
                const decryptedBlock = new Uint8Array(byteNumbers);

                return decryptedBlock;
            } catch (error) {
                console.error("Decryption error:", error);
                throw error;
            }
        },

        // Funzione per preparazione del file al download
        async prepareDownload(file) {
            const cleanedData = await this.getFileContent(file);
            if (!cleanedData) {
                alert("Errore nella pulizia del file!");
                return;
            }

            // Converti i dati in stringa JSON formattata
            const formattedJson = JSON.stringify(cleanedData, null, 2);

            // Crea un Blob con il contenuto trasformato
            const blob = new Blob([formattedJson], { type: "application/json" });

            // Crea un URL temporaneo per il download
            this.processedFileUrl = URL.createObjectURL(blob);

            // Simula un click per avviare il download immediato
            setTimeout(() => {
                const link = document.createElement("a");
                link.href = this.processedFileUrl;
                link.download = "file.json"; // Nome del file scaricato
                document.body.appendChild(link);
                link.click();
                document.body.removeChild(link);
            }, 100);
        },

        // Recupera il contenuto del file e trasforma in Json corretto
        async getFileContent(file) {
            
            try {
                // Recupera il contenuto del file dal Blob URL
                const response = await fetch(file.url);
                const fileText  = await response.text();

                // Il contenuto può presentare caratteri speciali alla file
                console.log("Contenuto del file:", fileText);

                // Elimina eventuali caratteri extra (se presenti)
                /*
                const cleanFileText = fileText.split('')
                .filter(c => c.charCodeAt(0) >= 32 || c.charCodeAt(0) === 9) // Mantiene solo caratteri visibili e tabulazione
                .join('');
                
                console.log("Contenuto del file CLEANED:", cleanFileText);
                */

                // Parsing in Json
                try {
                const parsedData = JSON.parse(fileText);
                return parsedData;
                } catch (error) {
                console.error("Errore durante il parsing del file JSON:", error);
                return null;
                }
            } catch (error) {
                console.error("Errore nel leggere il contenuto del file:", error);
                return null;
            }

        },


    }
};
</script>
  
<style scoped>
.file-item {
  display: flex;
  align-items: center;
  gap: 30px; /* Distanza tra gli elementi */
  margin-top: 5px;
}
.file-item:hover {
  background-color: rgb(238, 235, 235);
}

a {
  cursor: pointer;
}
  
</style>