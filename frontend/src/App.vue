<template>

  <!-- if user is NOT logged -->
  <div v-if="!isLoggedIn" class="m-0 p-0 row">
    <SignInBox />
  </div>



  <!-- if user is logged -->
  <div v-else>
    <h6 class="mt-5" style="font-weight: bold;">Crowdsensing App</h6>
    
    <!-- main container -->
    <div class="row mainBox">

      <!-- sx col -->
      <div class="m-0 p-0 d-none d-md-block col-md-2">
      </div>

      <!-- center col -->
      <div class="centerBox m-0 col-xs-12 col-sm-12 col-md-8">
        <router-view/>
      </div>

      <!-- dx col -->
      <div class="m-0 p-0 d-none d-md-block col-md-2">
      </div>

    </div>
  </div>

</template>

<script>
import { mapGetters } from 'vuex'

import SignInBox from './components/SignInBox.vue';

export default {
  name: 'App',
  
  components: {
    SignInBox,
  },

  data() {
    return {

    }
  },

  computed: {
    // check if the user is logged, using the getter defined in the store
    ...mapGetters(['isLoggedIn']),
  },

  methods: {

  }

};
</script>