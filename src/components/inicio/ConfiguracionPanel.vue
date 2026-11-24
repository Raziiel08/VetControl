<script setup>
import { ref, onMounted } from "vue";
import { Lock } from "lucide-vue-next";
import { supabase } from "@/supabase";
import { useUsuario } from "@/composables/useUsuario";
import { useToast } from "@/composables/useToast";

const { correo: usuarioCorreo, esAdministrador } = useUsuario();
const { notificar } = useToast();

const nombre = ref("");
const telefono = ref("");
const direccion = ref("");
const horarios = ref({
  lunes_viernes: "09:00 - 18:00",
  sabados: "09:00 - 13:00",
  domingos: "Cerrado",
});
const horariosDisponibles = ref(false);
const codigoInvitacion = ref("");

const HORAS = [];
for (let h = 0; h < 24; h++) {
  for (const m of [0, 30]) {
    HORAS.push(`${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`);
  }
}

function esCerrado(dia) {
  return (
    String(horarios.value[dia] || "")
      .trim()
      .toLowerCase() === "cerrado"
  );
}

function horaInicio(dia) {
  const v = horarios.value[dia] || "";
  if (esCerrado(dia)) return "09:00";
  const partes = String(v).split("-");
  return (partes[0] || "09:00").trim() || "09:00";
}

function horaFin(dia) {
  const v = horarios.value[dia] || "";
  if (esCerrado(dia)) return "18:00";
  const partes = String(v).split("-");
  return (partes[1] || "18:00").trim() || "18:00";
}

function establecerCierre(dia, valor) {
  if (valor) {
    horarios.value[dia] = "Cerrado";
  } else {
    horarios.value[dia] = `${horaInicio(dia)} - ${horaFin(dia)}`;
    if (horarios.value[dia] === "Cerrado - Cerrado")
      horarios.value[dia] = "09:00 - 18:00";
  }
}

function establecerHora(dia, cual, valor) {
  if (esCerrado(dia)) return;
  const ini = cual === "inicio" ? valor : horaInicio(dia);
  const fin = cual === "fin" ? valor : horaFin(dia);
  horarios.value[dia] = `${ini} - ${fin}`;
}
const cargando = ref(false);
const guardando = ref(false);

onMounted(() => {
  cargar();
});

function aplicarDatos(data) {
  nombre.value = data.nombre || "";
  telefono.value = data.telefono || "";
  direccion.value = data.direccion || "";
  codigoInvitacion.value = data.codigo_invitacion || "";
  if (data.horarios && typeof data.horarios === "object") {
    horarios.value = { ...horarios.value, ...data.horarios };
  }
}

async function cargar() {
  cargando.value = true;
  try {
    const { data: veterinariaId, error: errorId } = await supabase.rpc(
      "obtener_mi_veterinaria_id",
    );
    if (errorId) throw errorId;
    if (!veterinariaId) return;

    const conHorarios = await supabase
      .from("veterinarias")
      .select("nombre, telefono, direccion, horarios, codigo_invitacion")
      .eq("id", veterinariaId)
      .maybeSingle();

    if (!conHorarios.error) {
      horariosDisponibles.value = true;
      if (conHorarios.data) aplicarDatos(conHorarios.data);
      return;
    }

    const sinHorarios = await supabase
      .from("veterinarias")
      .select("nombre, telefono, direccion, codigo_invitacion")
      .eq("id", veterinariaId)
      .maybeSingle();

    if (!sinHorarios.error) {
      horariosDisponibles.value = false;
      if (sinHorarios.data) aplicarDatos(sinHorarios.data);
      return;
    }

    const basico = await supabase
      .from("veterinarias")
      .select("nombre, telefono, direccion")
      .eq("id", veterinariaId)
      .maybeSingle();

    if (basico.error) throw basico.error;
    horariosDisponibles.value = false;
    if (basico.data) aplicarDatos(basico.data);
  } catch {
    notificar("No se pudieron cargar los datos de la veterinaria");
  } finally {
    cargando.value = false;
  }
}

async function copiarCodigo() {
  if (!codigoInvitacion.value) return;
  try {
    await navigator.clipboard.writeText(codigoInvitacion.value);
    notificar("Código copiado");
  } catch {
    notificar(`El código es ${codigoInvitacion.value}`);
  }
}

async function guardar() {
  if (!nombre.value.trim()) {
    notificar("El nombre de la veterinaria es obligatorio");
    return;
  }
  if (telefono.value.trim() && !/^[0-9 +()-]+$/.test(telefono.value.trim())) {
    notificar("El teléfono solo puede tener números");
    return;
  }
  for (const dia of ["lunes_viernes", "sabados", "domingos"]) {
    if (!esCerrado(dia) && horaInicio(dia) >= horaFin(dia)) {
      notificar("La hora de apertura debe ser menor a la de cierre.");
      return;
    }
  }

  guardando.value = true;
  try {
    const { data: veterinariaId, error: errorId } = await supabase.rpc(
      "obtener_mi_veterinaria_id",
    );
    if (errorId) throw errorId;
    if (!veterinariaId)
      throw new Error("Tu cuenta no tiene una veterinaria asociada.");

    const cambios = {
      nombre: nombre.value.trim(),
      telefono: telefono.value.trim(),
      direccion: direccion.value.trim(),
    };
    if (horariosDisponibles.value) {
      cambios.horarios = {
        lunes_viernes: horarios.value.lunes_viernes.trim(),
        sabados: horarios.value.sabados.trim(),
        domingos: horarios.value.domingos.trim(),
      };
    }

    let { error } = await supabase
      .from("veterinarias")
      .update(cambios)
      .eq("id", veterinariaId);

    if (error && String(error.message || "").includes("horarios")) {
      horariosDisponibles.value = false;
      delete cambios.horarios;
      ({ error } = await supabase
        .from("veterinarias")
        .update(cambios)
        .eq("id", veterinariaId));
    }

    if (error) throw error;
    notificar("Cambios guardados");
  } catch (e) {
    notificar(
      String(e.message || "").includes("row-level security")
        ? "No tenés permiso para hacer esta acción."
        : e.message || "No se pudieron guardar los cambios",
    );
  } finally {
    guardando.value = false;
  }
}
</script>

<template>
  <section class="contenido-pagina">
    <div class="encabezado-pagina">
      <div>
        <p class="sobretitulo">PREFERENCIAS</p>
        <h1>Configuración</h1>
        <p class="texto-atenuado">
          Mantené actualizada la información de tu veterinaria.
        </p>
      </div>
      <button
        class="boton-principal"
        :disabled="guardando || cargando"
        @click="guardar"
      >
        {{ guardando ? "Guardando..." : "Guardar cambios" }}
      </button>
    </div>
    <div class="cuadricula-configuracion">
      <div class="panel tarjeta-configuracion">
        <h2>Datos de la veterinaria</h2>
        <label
          >Nombre de la veterinaria<input
            v-model="nombre"
            :disabled="cargando"
            maxlength="120"
            placeholder="Nombre de tu veterinaria" /></label
        ><label
          >Teléfono de contacto<input
            v-model="telefono"
            :disabled="cargando"
            maxlength="15"
            placeholder="011 45678901"
            inputmode="numeric"
            @input="telefono = telefono.replace(/[^0-9 ]/g, '')" /></label
        ><label
          >Dirección<input
            v-model="direccion"
            :disabled="cargando"
            maxlength="160"
            placeholder="Calle y número"
        /></label>
      </div>
      <div class="panel tarjeta-configuracion">
        <h2>Horarios de atención</h2>
        <template v-if="horariosDisponibles">
          <div
            v-for="dia in ['lunes_viernes', 'sabados', 'domingos']"
            :key="dia"
            class="horario-fila"
          >
            <span class="horario-nombre">{{
              dia === "lunes_viernes"
                ? "Lunes a viernes"
                : dia === "sabados"
                  ? "Sábados"
                  : "Domingos"
            }}</span>
            <label class="horario-cerrado">
              <input
                type="checkbox"
                :checked="esCerrado(dia)"
                @change="establecerCierre(dia, $event.target.checked)"
                :disabled="cargando"
              />
              Cerrado
            </label>
            <select
              :value="horaInicio(dia)"
              :disabled="cargando || esCerrado(dia)"
              @change="establecerHora(dia, 'inicio', $event.target.value)"
              class="horario-select"
            >
              <option v-for="h in HORAS" :key="'i' + dia + h" :value="h">
                {{ h }}
              </option>
            </select>
            <span class="horario-sep">a</span>
            <select
              :value="horaFin(dia)"
              :disabled="cargando || esCerrado(dia)"
              @change="establecerHora(dia, 'fin', $event.target.value)"
              class="horario-select"
            >
              <option v-for="h in HORAS" :key="'f' + dia + h" :value="h">
                {{ h }}
              </option>
            </select>
          </div> </template
        ><template v-else
          ><div class="fila-horario">
            <span>Lunes a viernes</span><strong>09:00 — 18:00</strong>
          </div>
          <div class="fila-horario">
            <span>Sábados</span><strong>09:00 — 13:00</strong>
          </div>
          <div class="fila-horario">
            <span>Domingos</span><strong class="texto-atenuado">Cerrado</strong>
          </div>
          <p class="texto-atenuado" style="margin-top: 10px">
            Aplicá el archivo supabase/vet.sql para poder editar los horarios.
          </p></template
        >
      </div>
    </div>
    <div class="seguridad-configuracion">
      <div class="panel tarjeta-configuracion">
        <h2>Seguridad de la cuenta</h2>
        <p class="texto-atenuado" style="margin-bottom: 14px">
          Gestioná la seguridad de tu cuenta.
        </p>
        <div class="informacion-seguridad">
          <span
            >Correo: <strong>{{ usuarioCorreo }}</strong></span
          >
        </div>
        <router-link to="/cambiar-clave" class="boton-contorno"
          ><Lock /> Cambiar contraseña</router-link
        >
      </div>
      <div v-if="esAdministrador" class="panel tarjeta-configuracion">
        <h2>Código de invitación</h2>
        <p class="texto-atenuado" style="margin-bottom: 14px">
          Compartilo con quienes quieras sumar como veterinarios a esta clínica.
          Con ese código se registran y entran a tu veterinaria.
        </p>
        <div class="codigo-invitacion">
          <strong>{{ codigoInvitacion || "Sin código" }}</strong>
          <button
            type="button"
            class="boton-contorno"
            :disabled="!codigoInvitacion"
            @click="copiarCodigo"
          >
            Copiar
          </button>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.horario-fila {
  display: grid;
  grid-template-columns: 1.4fr auto 1fr auto 1fr;
  gap: 8px;
  align-items: center;
  margin-bottom: 10px;
}
.horario-nombre {
  font-size: 12px;
  font-weight: 700;
  color: var(--verde-oscuro);
}
.horario-cerrado {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  color: var(--atenuado);
  margin-bottom: 0 !important;
}
.horario-cerrado input {
  width: auto !important;
  margin-top: 0 !important;
}
.horario-select {
  padding: 8px 10px;
  border: 1px solid var(--borde);
  border-radius: 8px;
  background: #fbfcfb;
  font-size: 12px;
}
.horario-sep {
  text-align: center;
  color: var(--atenuado);
  font-size: 12px;
}
.codigo-invitacion {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border: 1px dashed var(--verde);
  border-radius: 8px;
  background: #f2f9f0;
}
.codigo-invitacion strong {
  color: var(--verde-oscuro);
  font-size: 18px;
  letter-spacing: 2px;
}
</style>
