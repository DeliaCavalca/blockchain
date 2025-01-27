// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IPFSMessage {
    // Mappature per memorizzare i dati degli utenti e dei verificatori
    mapping(address => uint256) public userPayments;
    mapping(bytes32 => string) public encryptedData;
    mapping(bytes32 => address) public dataOwners;
    mapping(bytes32 => bool) public dataVerified;

    // Lista degli hash caricati
    bytes32[] public uploadedHashes;

    // Parametri della campagna e tariffe
    uint256 public uploadFee = 0.1 ether; // Tariffa di caricamento dati
    uint256 public minimumParticipants = 5; // Numero minimo di partecipazioni per chiudere la campagna
    uint256 public verifiedCount = 0;

    // Stato della campagna
    string public campaignStatus = "Ongoing";

    // Eventi per tracciare l'upload e la verifica
    event DataUploaded(address indexed user, bytes32 ipfsHash);
    event DataVerified(bytes32 ipfsHash, bool isValid);
    event CampaignClosed(string status);

    // Funzione per caricare i dati su IPFS
    function uploadData(bytes32 ipfsHash, string memory encryptionKey) public payable {
        require(msg.value == uploadFee, "Please pay the correct upload fee");
        require(bytes(encryptedData[ipfsHash]).length == 0, "Data already uploaded");

        encryptedData[ipfsHash] = encryptionKey; // Salva la chiave di cifratura
        dataOwners[ipfsHash] = msg.sender; // Memorizza chi è il proprietario dei dati
        userPayments[msg.sender] += msg.value;

        uploadedHashes.push(ipfsHash); // Aggiunge l'hash alla lista
        emit DataUploaded(msg.sender, ipfsHash);
    }

    // Funzione per ottenere tutti i dati caricati
    function getAllData() public view returns (bytes32[] memory, address[] memory, bool[] memory) {
        uint256 total = uploadedHashes.length;

        address[] memory owners = new address[](total);
        bool[] memory verified = new bool[](total);

        for (uint256 i = 0; i < total; i++) {
            bytes32 hash = uploadedHashes[i];
            owners[i] = dataOwners[hash];
            verified[i] = dataVerified[hash];
        }

        return (uploadedHashes, owners, verified);
    }

    // Funzione per ottenere la chiave di cifratura di un dato
    function getData(bytes32 ipfsHash) public view returns (string memory) {
        return encryptedData[ipfsHash];
    }

    // Funzione per la verifica dei dati da parte dei verificatori
    function verifyData(bytes32 ipfsHash, string memory encryptionKey) public {
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