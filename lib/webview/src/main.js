import { createApp } from 'vue'
import VueVirtualScroller from 'vue-virtual-scroller'
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css'
import './themes/tokens.css'
import './style.css'
import App from './App.vue'

const app = createApp(App)
app.use(VueVirtualScroller)
app.mount('#app')
