import { computed, ref } from 'vue'
import { supabase } from '@/supabase'

/**
 * Estado del usuario logueado compartido por todas las vistas.
 * Se carga una sola vez y queda en memoria hasta cerrar sesión.
 */
const email = ref('')
const rol = ref('')
const cargando = ref(false)
const cargado = ref(false)

const ETIQUETAS_ROL = {
  admin_veterinaria: 'Administrador/a',
  veterinario: 'Veterinario/a',
  cliente: 'Cliente',
}

let cargaEnCurso = null

export function useUsuario() {
  const inicial = computed(() => (email.value ? email.value.charAt(0).toUpperCase() : 'U'))
  const etiquetaRol = computed(() => ETIQUETAS_ROL[rol.value] || 'Sin rol asignado')
  const esAdmin = computed(() => rol.value === 'admin_veterinaria')
  const esStaff = computed(() => rol.value === 'admin_veterinaria' || rol.value === 'veterinario')

  async function cargar() {
    if (cargado.value) return
    if (cargaEnCurso) return cargaEnCurso

    cargaEnCurso = (async () => {
      cargando.value = true
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser()

        email.value = user?.email || ''

        // El rol se lee de la base, no de lo que muestra la pantalla
        const { data: rolObtenido, error } = await supabase.rpc('obtener_mi_rol')
        if (!error) rol.value = rolObtenido || ''
        else rol.value = ''

        cargado.value = true
      } catch {
        email.value = ''
        rol.value = ''
      } finally {
        cargando.value = false
        cargaEnCurso = null
      }
    })()

    return cargaEnCurso
  }

  async function cerrarSesion() {
    const { error } = await supabase.auth.signOut()
    limpiar()
    if (error) throw error
  }

  function limpiar() {
    email.value = ''
    rol.value = ''
    cargado.value = false
  }

  return {
    email,
    rol,
    inicial,
    etiquetaRol,
    esAdmin,
    esStaff,
    cargando,
    cargado,
    cargar,
    cerrarSesion,
    limpiar,
  }
}
