import "./assets/main.css";

import { createApp } from "vue";
import App from "./App.vue";
import enrutador from "./router";

const aplicacion = createApp(App);
aplicacion.use(enrutador);
aplicacion.mount("#app");
