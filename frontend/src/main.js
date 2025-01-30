import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import store from './store'

import axios from 'axios'
import VueAxios from 'vue-axios'

// import my personalized Bootstrap
import "./assets/myStyle.scss"

// initialize Vue App
const app = createApp(App)

// use plugins
app.use(store)
app.use(router)
app.use(VueAxios, axios)


// use app instance to mount to <div id="app">
// in public/index.html get div with id="app" and load content inside it
app.mount('#app')
