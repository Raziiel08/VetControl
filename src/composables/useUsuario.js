import { computed, ref } from "vue";
import { supabase } from "@/supabase";

const correo = ref("");
const rol = ref("");
const cargando = ref(false);
const cargado = ref(false);

const ETIQUETAS_ROL = {
  admin_veterinaria: "Administrador/a",
  veterinario: "Veterinario/a",
  cliente: "Cliente",
};

let cargaEnCurso = null;

export function useUsuario() {
  const inicial = computed(() =>
    correo.value ? correo.value.charAt(0).toUpperCase() : "U",
  );
  const etiquetaRol = computed(
    () => ETIQUETAS_ROL[rol.value] || "Sin rol asignado",
  );
  const esAdministrador = computed(() => rol.value === "admin_veterinaria");
  const esEquipo = computed(
    () => rol.value === "admin_veterinaria" || rol.value === "veterinario",
  );

  async function cargar() {
    if (cargado.value) return;
    if (cargaEnCurso) return cargaEnCurso;

    cargaEnCurso = (async () => {
      cargando.value = true;
      try {
        const {
          data: { user: usuario },
        } = await supabase.auth.getUser();

        correo.value = usuario?.email || "";

        const { data: rolObtenido, error } =
          await supabase.rpc("obtener_mi_rol");
        if (!error) rol.value = rolObtenido || "";
        else rol.value = "";

        cargado.value = true;
      } catch {
        correo.value = "";
        rol.value = "";
      } finally {
        cargando.value = false;
        cargaEnCurso = null;
      }
    })();

    return cargaEnCurso;
  }

  async function cerrarSesion() {
    const { error } = await supabase.auth.signOut();
    limpiar();
    if (error) throw error;
  }

  function limpiar() {
    correo.value = "";
    rol.value = "";
    cargado.value = false;
  }

  return {
    correo,
    rol,
    inicial,
    etiquetaRol,
    esAdministrador,
    esEquipo,
    cargando,
    cargado,
    cargar,
    cerrarSesion,
    limpiar,
  };
}
