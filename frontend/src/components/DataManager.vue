<template>
    <div style="font-size: 13px; text-align: left;">
      
      
  
    </div>
  </template>
  
<script>
  
export default {
    name: 'DataManager',
    data() {
      return {
        contractAddress: null, // Indirizzo del Contratto
        userAddress: null, // Indirizzo dell'utente Ethereum
  
        
      };
    },
  
    created() {
        this.contractAddress = this.$store.state.contractAddress
        this.userAddress = this.$store.state.userAddress
    },
  
    methods: {
  
    }
};
</script>
  
<style scoped>

  
</style>