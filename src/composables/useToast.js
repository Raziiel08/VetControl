import { ref } from "vue";

const mensaje = ref("");
let temporizador = null;

export function useToast() {
  function notificar(texto) {
    mensaje.value = texto;
    window.clearTimeout(temporizador);
    temporizador = window.setTimeout(() => {
      mensaje.value = "";
    }, 2600);
  }

  function ocultar() {
    window.clearTimeout(temporizador);
    mensaje.value = "";
  }

  return { mensaje, notificar, ocultar };
}
