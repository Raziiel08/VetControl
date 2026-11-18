import { ref } from 'vue'

/**
 * Mensaje flotante (toast) compartido por todas las vistas.
 * El componente ToastMessage se renderiza una sola vez en App.vue.
 */
const mensaje = ref('')
let temporizador = null

export function useToast() {
  function notify(texto) {
    mensaje.value = texto
    window.clearTimeout(temporizador)
    temporizador = window.setTimeout(() => {
      mensaje.value = ''
    }, 2600)
  }

  function ocultar() {
    window.clearTimeout(temporizador)
    mensaje.value = ''
  }

  return { mensaje, notify, ocultar }
}
