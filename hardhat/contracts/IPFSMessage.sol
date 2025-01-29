// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IPFSMessage {

    // Ruoli per gli User
    enum Role { User, Verifier, Admin }
    
    // Struttura di User
    struct User {
        Role role; // Ruolo dell'utente
    }

    // Mappatura per associare l'indirizzo dell'utente al suo stato
    mapping(address => User) public users;

    // Array per tenere traccia degli indirizzi degli utenti
    address[] public userAddresses;


    // Mappature per memorizzare i dati degli utenti e dei verificatori
    mapping(address => uint256) public userPayments;
    mapping(string => string) public encryptedData;
    mapping(string => address) public dataOwners;
    mapping(string => bool) public dataVerified;

    // Lista degli hash caricati
    string[] public uploadedHashes;

    // Parametri della campagna e tariffe
    uint256 public uploadFee = 0.1 ether; // Tariffa di caricamento dati
    uint256 public minimumParticipants = 10; // Numero minimo di partecipazioni per chiudere la campagna
    uint256 public verifiedCount = 0;

    // Stato della campagna
    string public campaignStatus = "Ongoing";

    // Eventi per tracciare l'upload e la verifica
    event DataUploaded(address indexed user, string ipfsHash);
    event DataVerified(string ipfsHash, bool isValid);
    event CampaignClosed(string status);


    // Metodo eseguito quando viene fatto il deploy del contratto
    // Assegna i ruoli agli account generati da Hardhat
    constructor(address[] memory _accounts) {
        
        // Admin
        users[_accounts[0]] = User({ role: Role.Admin });
        
        // Verifiers
        for (uint256 i = 1; i < 5; i++) {
            users[_accounts[i]] = User({ role: Role.Verifier });
        }

        // Users
        for (uint256 i = 5; i < _accounts.length; i++) {
            users[_accounts[i]] = User({ role: Role.User });
        }

        // Salva gli indirizzi degli utenti
        for (uint256 i = 0; i < _accounts.length; i++) {
            userAddresses.push(_accounts[i]);
        }

    }

    // Funzione per ottenere la lista di tutti gli utenti
    function getAllUsers() public view returns (address[] memory) {
        return userAddresses;
    }

    // Funzione per ottenere il ruolo di un utente dato il suo indirizzo
    function getUserRole(address userAddress) public view returns (Role) {
        return users[userAddress].role;
    }


    // Funzione per caricare i dati su IPFS
    function uploadData(string memory ipfsHash, string memory encryptionKey) public payable {
        require(msg.value == uploadFee, "Please pay the correct upload fee");
        require(bytes(encryptedData[ipfsHash]).length == 0, "Data already uploaded");

        encryptedData[ipfsHash] = encryptionKey; // Salva la chiave di cifratura
        dataOwners[ipfsHash] = msg.sender; // Memorizza chi è il proprietario dei dati
        userPayments[msg.sender] += msg.value;

        uploadedHashes.push(ipfsHash); // Aggiunge l'hash alla lista
        emit DataUploaded(msg.sender, ipfsHash);
    }

    // Funzione per ottenere tutti i dati caricati
    function getAllData() public view returns (string[] memory, address[] memory, bool[] memory) {
        uint256 total = uploadedHashes.length;

        address[] memory owners = new address[](total);
        bool[] memory verified = new bool[](total);

        for (uint256 i = 0; i < total; i++) {
            string memory hash = uploadedHashes[i];
            owners[i] = dataOwners[hash];
            verified[i] = dataVerified[hash];
        }

        return (uploadedHashes, owners, verified);
    }

    // Funzione per ottenere la chiave di cifratura di un dato
    function getEncryptedKey(string memory ipfsHash) public view returns (string memory) {
        return encryptedData[ipfsHash];
    }

    // Funzione per ottenere gli Hash dei dati da validare
    function getUnverifiedData() public view returns (string[] memory) {
        uint256 count = 0;
        
        // Conta quanti dati non sono stati verificati
        for (uint256 i = 0; i < uploadedHashes.length; i++) {
            if (!dataVerified[uploadedHashes[i]]) {
                count++;
            }
        }

        // Crea un array della dimensione giusta
        string[] memory unverifiedHashes = new string[](count);
        uint256 index = 0;

        // Riempie l'array con gli hash non verificati
        for (uint256 i = 0; i < uploadedHashes.length; i++) {
            if (!dataVerified[uploadedHashes[i]]) {
                unverifiedHashes[index] = uploadedHashes[i];
                index++;
            }
        }

        return unverifiedHashes;
    }


    // Funzione per la verifica dei dati da parte dei verificatori
    // Controlla se raggiunto il numero minimo di dati verificati: se sì, Chiusura campagna
    function verifyData(string memory ipfsHash, string memory encryptionKey) public {
        // Verifica che l'utente sia un verificatore
        require(users[msg.sender].role == Role.Verifier, "Only verifiers can verify data");

        require(bytes(encryptedData[ipfsHash]).length != 0, "Data not found");
        
        // Simulazione della verifica dei dati: il verificatore deve fornire la chiave corretta
        bool isValid = keccak256(abi.encodePacked(encryptionKey)) == keccak256(abi.encodePacked(encryptedData[ipfsHash]));

        if (isValid) {
            dataVerified[ipfsHash] = true;
            verifiedCount++;
            emit DataVerified(ipfsHash, true);
            
            // Rimborso immediato dell'utente
            rewardUser(dataOwners[ipfsHash]);

            if (verifiedCount >= minimumParticipants) {
                closeCampaign();
            }
        } else {
            emit DataVerified(ipfsHash, false);
        }
    }

    // Funzione per chiudere la campagna quando si raggiunge il numero minimo di verifiche
    function closeCampaign() private {
        campaignStatus = "Closed";
        emit CampaignClosed("Campaign has been closed due to reaching minimum verification threshold.");
    }

    // Funzione per premiare l'utente che ha caricato i dati verificati
    function rewardUser(address user) private {
        uint256 amount = userPayments[user];
        require(amount > 0, "No funds to reward");
        userPayments[user] = 0; // Resetta il pagamento prima del trasferimento per sicurezza
        payable(user).transfer(amount); // Rimborsa l'utente
    }

    // Funzione per ottenere lo stato della campagna
    function getCampaignStatus() public view returns (string memory) {
        return campaignStatus;
    }

    // Funzione per ottenere il numero di hash caricati
    function getUploadedCount() public view returns (uint256) {
        return uploadedHashes.length;
    }
}