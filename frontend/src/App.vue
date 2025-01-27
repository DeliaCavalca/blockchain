<template>
  <div id="app">
    <h1>My Vue.js App</h1>
    <DataUploader />
    <DataVerifier />
  </div>
</template>

<script>
import DataUploader from './components/DataUploader.vue';
import DataVerifier from './components/DataVerifier.vue';

export default {
  name: 'App',
  components: {
    DataUploader,
    DataVerifier
  }
};
</script>