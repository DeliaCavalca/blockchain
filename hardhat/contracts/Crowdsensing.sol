// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdsensing {

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



    // Evento ascoltato dall'Admin: User ha intenzione di caricare dati
    event UserEnrolled(address indexed user, string publicKey);
    // Evento ascoltato dallo User: l'Admin gli ha inviato la chiave per cifrare i dati
    event KeySent(address indexed user, string encryptedKey);
    // Evento ascoltato dal Verifier: ci sono dati da validare
    event VerificationRequested(string ipfsHash);
    // Evento ascoltato dall'Admin: Verifier ha intenzione di validare dati
    event VerifierEnrolled(address indexed user, string publicKey);
    
    // Chiave pubblica dell'utente che vuole caricare un file su IPFS
    mapping(address => string) public userPublicKeys;
    // Chiave per la codifica dei dati
    mapping(address => string) public encryptedKeys;
    // Chiave pubblica del Verifier che vuole validare i dati
    mapping(address => string) public verifierPublicKeys;


    // Mappature per memorizzare i dati degli utenti e dei verificatori
    mapping(string => mapping(address => uint256)) public filePayments;
    mapping(string => string) public encryptedData;
    mapping(string => address) public dataOwners;
    mapping(string => bool) public dataVerified; // true se il dato è valido, false se non è ancora stato validato o se non è valido
    mapping(string => bool) public dataVerifiedNotValid; // true se il dato è stato verificato e non è valido

    // Lista degli hash caricati
    string[] public uploadedHashes;

    // Parametri della campagna e tariffe
    uint256 public uploadFee = 0.1 ether; // Tariffa di caricamento dati
    uint256 public verifyFee = 1.0 ether; // Tariffa di ricompensa validazione dati al Verificatore
    uint256 public minimumParticipants = 10; // Numero minimo di partecipazioni per chiudere la campagna
    uint256 public verifiedCount = 0; // Numero di dati validatati (dati validi)

    uint256 public chunkSize = 256; // Dimensione dei blocchi in cui suddividere i dati

    // Stato della campagna
    string public campaignStatus = "Ongoing";

    // Eventi per tracciare l'upload e la verifica
    event DataUploaded(address indexed user, string ipfsHash);
    event DataVerified(string ipfsHash, bool isValid);
    event CampaignClosed(string status);
    event CampaignOpen(string status);


    // Metodo eseguito quando viene fatto il deploy del contratto
    // Assegna i ruoli agli account generati da Hardhat
    // Imposta il fondo iniziale del contratto
    constructor(address[] memory _accounts) payable {
        require(msg.value == 10 ether, "Contract must be deployed with 10 ETH");
        
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
    // Attualmente NON viene passata la chiave, viene passata una stringa vuota
    function uploadData(string memory ipfsHash, string memory encryptionKey) public payable {
        require(msg.value == uploadFee, "Please pay the correct upload fee");
        require(bytes(encryptedData[ipfsHash]).length == 0, "Data already uploaded");

        encryptedData[ipfsHash] = encryptionKey; // Salva la chiave di cifratura
        dataOwners[ipfsHash] = msg.sender; // Memorizza chi è il proprietario dei dati
        filePayments[ipfsHash][msg.sender] += msg.value; // Associa l'importo specifico al file

        uploadedHashes.push(ipfsHash); // Aggiunge l'hash alla lista

        emit DataUploaded(msg.sender, ipfsHash);

    }

    // Funzione per l'invio della chiave pubblica da parte dell'utente
    function uploadPublicKey(string memory publicKey) public {
        
        // Salva la chiave pubblica dell'utente
        userPublicKeys[msg.sender] = publicKey;

        emit UserEnrolled(msg.sender, publicKey);
    }

    // Funzione per l'invio della chiave pubblica da parte del Verifier
    function uploadVerifierPublicKey(string memory publicKey) public {
        
        // Salva la chiave pubblica del Verifier
        verifierPublicKeys[msg.sender] = publicKey;

        emit VerifierEnrolled(msg.sender, publicKey);
    }

    function getUserPublicKey(address user) public view returns (string memory) {
        return userPublicKeys[user];
    }

    // Funzione per l'invio della chiave per cifrare i dati
    function sendEncryptedKey(address user, string memory encryptedKey) public {
        encryptedKeys[user] = encryptedKey;
        emit KeySent(user, encryptedKey);
    }

    // Funzione per ottenere l'indirizzo del proprietario dei dati
    function getOwnerAddress(string memory ipfsHash) public view returns (address) {
        // Restituisce l'indirizzo del proprietario associato all'hash IPFS
        return dataOwners[ipfsHash];
    }

    // Funzione per ottenere tutti i dati caricati
    function getAllData() public view returns (string[] memory, address[] memory, bool[] memory, bool[] memory) {
        uint256 total = uploadedHashes.length;

        address[] memory owners = new address[](total);
        bool[] memory verified = new bool[](total);
        bool[] memory notValid = new bool[](total);

        for (uint256 i = 0; i < total; i++) {
            string memory hash = uploadedHashes[i];
            owners[i] = dataOwners[hash];
            verified[i] = dataVerified[hash];
            notValid[i] = dataVerifiedNotValid[hash];
        }

        return (uploadedHashes, owners, verified, notValid);
    }

    // Funzione per ottenere la chiave di cifratura di un dato
    function getEncryptedKey(string memory ipfsHash, address verifier) public view returns (string memory) {
        require((users[verifier].role == Role.Verifier)||(users[verifier].role == Role.Admin), "Only verifiers/admin can get the keys");
        return encryptedData[ipfsHash];
    }

    // Funzione per ottenere gli Hash dei dati da validare
    function getUnverifiedData() public view returns (string[] memory) {
        uint256 count = 0;
        
        // Conta quanti dati non sono stati verificati
        for (uint256 i = 0; i < uploadedHashes.length; i++) {
            if (!dataVerified[uploadedHashes[i]] && !dataVerifiedNotValid[uploadedHashes[i]]) {
                count++;
            }
        }

        // Crea un array della dimensione giusta
        string[] memory unverifiedHashes = new string[](count);
        uint256 index = 0;

        // Riempie l'array con gli hash non verificati
        for (uint256 i = 0; i < uploadedHashes.length; i++) {
            if (!dataVerified[uploadedHashes[i]] && !dataVerifiedNotValid[uploadedHashes[i]]) {
                unverifiedHashes[index] = uploadedHashes[i];
                index++;
            }
        }

        return unverifiedHashes;
    }

    // Emette un Evento VerificationRequested per ogni dato da validare
    function requestVerificationForUnverifiedData() public {
        for (uint256 i = 0; i < uploadedHashes.length; i++) {
            if (!dataVerified[uploadedHashes[i]] && !dataVerifiedNotValid[uploadedHashes[i]]) {
                emit VerificationRequested(uploadedHashes[i]);
            }
        }
    }

    // Funzione per ottenere gli Hash dei dati validati
    function getVerifiedData() public view returns (string[] memory) {
        uint256 count = 0;
        
        // Conta quanti dati sono stati verificati
        for (uint256 i = 0; i < uploadedHashes.length; i++) {
            if (dataVerified[uploadedHashes[i]]) {
                count++;
            } 
        }

        // Crea un array della dimensione giusta
        string[] memory verifiedHashes = new string[](count);
        uint256 index = 0;

        // Riempie l'array con gli hash verificati
        for (uint256 i = 0; i < uploadedHashes.length; i++) {
            if (dataVerified[uploadedHashes[i]]) {
                verifiedHashes[index] = uploadedHashes[i];
                index++;
            }
        }

        return verifiedHashes;
    }


    // Funzione per la verifica dei dati da parte dei verificatori
    // Controlla se raggiunto il numero minimo di dati verificati: se sì, Chiusura campagna
    function verifyData(string memory ipfsHash, bool validationResult) public {
        
        // Verifica che l'utente sia un verificatore
        require(users[msg.sender].role == Role.Verifier, "Only verifiers can verify data");

        //require(bytes(encryptedData[ipfsHash]).length != 0, "Data not found");
        
        // Verifica se il verificatore ha fornito la chiave corretta
        //bool isValid = keccak256(abi.encodePacked(encryptionKey)) == keccak256(abi.encodePacked(encryptedData[ipfsHash]));

        // validationResult = risultato della validazione del contenuto del file

        // Ricompensa al verificatore
        rewardVerifier(msg.sender);

        if (validationResult) {
            dataVerified[ipfsHash] = true;
            verifiedCount++;
            emit DataVerified(ipfsHash, true);
            
            // Rimborso dell'utente che ha effettuato il caricamento dati
            rewardUser(dataOwners[ipfsHash], ipfsHash);

            if (verifiedCount >= minimumParticipants) {
                closeCampaign();
            }
        } else {
            dataVerified[ipfsHash] = false;
            dataVerifiedNotValid[ipfsHash] = true;
            emit DataVerified(ipfsHash, false);
        }
    }

    // Funzione per chiudere la campagna quando si raggiunge il numero minimo di verifiche
    function closeCampaign() private {
        campaignStatus = "Closed";
        emit CampaignClosed("Campaign has been closed due to reaching minimum verification threshold.");
    }
    // Funzione per aprire la campagna quando si modifica il numero minimo di verifiche
    function openCampaign() private {
        campaignStatus = "Ongoing";
        emit CampaignOpen("Campaign has been open.");
    }

    // Funzione per premiare l'utente che ha caricato i dati verificati
    function rewardUser(address user, string memory ipfsHash) private {
        // Verifica se a tale utente spetta un rimborso per tale file
        uint256 amount = filePayments[ipfsHash][user];
        require(amount > 0, "No funds to reward");
        filePayments[ipfsHash][user] = 0; // Resetta il pagamento prima del trasferimento per sicurezza

        // Rimborso dell'utente
        // Trasferimento ETH con `call`
        (bool success, ) = payable(user).call{value: amount}("");
        require(success, "Transfer to user failed");
    }

    // Funzione per premiare il verificatore in seguito alla validazione di un dato
    function rewardVerifier(address verifier) private {
        // Verifica che sia un Verificatore
        require(users[verifier].role == Role.Verifier, "Only verifiers can be rewarded for Validation Data");
        // Verifica che il contratto abbia abbastanza Ether per pagare la ricompensa
        require(address(this).balance >= verifyFee, "Not enough balance in contract to reward verifier");

        // Trasferimento della ricompensa al Verificatore
        // Trasferimento ETH con `call`
        (bool success, ) = payable(verifier).call{value: verifyFee}("");
        require(success, "Transfer to verifier failed");
    }

    // Restituisce i fondi del contratto
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Funzione per permettere all'Admin di depositare fondi nel contratto
    function depositFunds() public payable {
        require(users[msg.sender].role == Role.Admin, "Only the Admin can deposit funds");
    }

    // Funzione per ottenere lo stato della campagna
    function getCampaignStatus() public view returns (string memory) {
        return campaignStatus;
    }

    // Funzione per ottenere il numero di hash caricati
    function getUploadedCount() public view returns (uint256) {
        return uploadedHashes.length;
    }

    // Funzione per ottenere il chunk size
    function getChunkSize() public view returns (uint256) {
        return chunkSize;
    }

    // Restituisce il numero minimo di partecipanti
    function getNumPartecipants() public view returns (uint256) {
        return minimumParticipants;
    }

    // Funzione per permettere all'Admin di modificare il numero minimo di partecipanti
    function setMinimumParticipants(uint256 newMinimum) public {
        require(users[msg.sender].role == Role.Admin, "Only the Admin can change the minimum participants");
        
        // Modifica il valore del numero minimo di partecipanti
        minimumParticipants = newMinimum;

        // Verifica se la campagna deve essere chiusa
        if (verifiedCount >= minimumParticipants) {
            closeCampaign();
        }

        // Verifica se la campagna deve essere aperta
        if (verifiedCount < minimumParticipants) {
            openCampaign();
        }
    }

}