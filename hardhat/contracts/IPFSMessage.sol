// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract IPFSMessage {
    struct Message {
        string ipfsHash;
        address sender;
    }

    Message[] public messages;

    event MessageStored(string ipfsHash, address sender);

    function storeMessage(string memory _ipfsHash) public {
        messages.push(Message(_ipfsHash, msg.sender));
        emit MessageStored(_ipfsHash, msg.sender);
    }

    function getMessages() public view returns (Message[] memory) {
        return messages;
    }
}
