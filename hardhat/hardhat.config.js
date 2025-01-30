require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks: {
    hardhat: {
      chainId: 1337,
    },
    localhost: {
      url: "http://127.0.0.1:8545", // Assicurati che il nodo Hardhat stia ascoltando su questa porta
      chainId: 1337, // ChainId predefinito per Hardhat
    }
  },
};

