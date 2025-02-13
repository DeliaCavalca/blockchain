const { defineConfig } = require('@vue/cli-service');

module.exports = defineConfig({
  transpileDependencies: true,

  devServer: {
    host: '0.0.0.0', // Accetta connessioni da tutte le interfacce di rete
    port: 8081, // Porta su cui esegui il server di sviluppo
    client: {
      webSocketURL: 'ws://localhost:8081/ws', // Forza l'URL del WebSocket
    },
    allowedHosts: 'all', // Consenti connessioni da qualsiasi dominio (utile in sviluppo)
  },

  
});
