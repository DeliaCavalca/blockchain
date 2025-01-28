import { createStore } from 'vuex'
import createPersistedState from 'vuex-persistedstate';

// Vuex: Manage User Session

export default createStore({
  state: {
    contractAddress: "0x5fbdb2315678afecb367f032d93f642f64180aa3", // Address of the Contract

    userAddress: null,   // Address of the User Logged
    userRole: null,      // Role of the User Logged
    ethBalance: null,    // ETH Balance of the User Logged

    
  },
  getters: {
    isLoggedIn: (state) => !!state.userAddress,
    isAdmin: (state) => state.userRole == "Admin",
    isVerifier: (state) => state.userRole == "Verifier",
    ethBalance: (state) => state.ethBalance,
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
    
  },
  actions: {
  },
  modules: {
  },
  // automatically save data in local storage and get it when app restart
  // so if page is refreshed, the user session data are obtained from localstorage
  plugins: [createPersistedState()]
})
