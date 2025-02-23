import { createStore } from 'vuex'
import createPersistedState from 'vuex-persistedstate';

// Vuex: Manage User Session

export default createStore({
  state: {
    contractAddress: "0x5fbdb2315678afecb367f032d93f642f64180aa3", // Address of the Contract

    userAddress: null,   // Address of the User Logged
    userRole: null,      // Role of the User Logged
    ethBalance: null,    // ETH Balance of the User Logged

    status: null, // Status of the Crowdsensing
    chunkSize: null, // Chunk Size for Data Storage

    uploading: false, 
    searching: false, 

    k_enc: null,
    k_dec: null,
    
  },
  getters: {
    isLoggedIn: (state) => !!state.userAddress,
    isAdmin: (state) => state.userRole == "Admin",
    isVerifier: (state) => state.userRole == "Verifier",
    ethBalance: (state) => state.ethBalance,
    isClosed: (state) => state.status == "Closed",
    uploading: (state) => state.uploading,
    searching: (state) => state.searching,
  },
  mutations: {
    SET_USER_ADDRESS(state, userAddress) {
      state.userAddress = userAddress
    },
    SET_USER_ROLE(state, userRole) {
      state.userRole = userRole
    },
    SET_ETH_BALANCE(state, ethBalance) {
      state.ethBalance = ethBalance
    },
    SET_STATUS(state, status) {
      state.status = status
    },
    SET_CHUNK_SIZE(state, chunkSize) {
      state.chunkSize = chunkSize
    },
    SET_UPLOADING(state, uploading) {
      state.uploading = uploading
    },
    SET_SEARCHING(state, searching) {
      state.searching = searching
    },
    SET_K_ENC(state, k_enc) {
      state.k_enc = k_enc
    },
    SET_K_DEC(state, k_dec) {
      state.k_dec = k_dec
    },
    
  },
  actions: {
  },
  modules: {
  },
  // automatically save data in local storage and get it when app restart
  // so if page is refreshed, the user session data are obtained from localstorage
  plugins: [createPersistedState()]
})
