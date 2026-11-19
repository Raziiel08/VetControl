<script setup>
import { Eye, EyeOff, Plus } from "lucide-vue-next";
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "@/supabase";
import {
  validarCorreo,
  validarClave,
  esDominioConocido,
} from "@/utils/valicom";

const enrutador = useRouter();
const nombreVeterinaria = ref("");
const correo = ref("");
const clave = ref("");
const confirmarClave = ref("");
const cargando = ref(false);
const mensaje = ref("");
const registroExitoso = ref(false);
const mostrarClave = ref(false);
const tipoCuenta = ref("veterinaria");
const esCliente = computed(() => tipoCuenta.value === "cliente");
const esInvitado = computed(() => tipoCuenta.value === "veterinario");
const codigoInvitacion = ref("");

async function registrarse() {
  mensaje.value = "";
  registroExitoso.value = false;

  if (
    !esCliente.value &&
    !esInvitado.value &&
    nombreVeterinaria.value.trim().length < 3
  ) {
    mensaje.value = "Ingresá el nombre de tu veterinaria (mínimo 3 caracteres)";
    return;
  }

  if (esInvitado.value && codigoInvitacion.value.trim().length < 4) {
    mensaje.value =
      "Ingresá el código de invitación que te dio tu veterinaria.";
    return;
  }

  const validacionCorreo = validarCorreo(correo.value);
  if (!validacionCorreo.valido) {
    mensaje.value = validacionCorreo.error;
    return;
  }
  if (esCliente.value && !esDominioConocido(validacionCorreo.correo)) {
    mensaje.value =
      "Usá un correo real (gmail, hotmail, outlook, yahoo, etc.).";
    return;
  }

  const validacionClave = validarClave(clave.value);
  if (!validacionClave.valido) {
    mensaje.value = validacionClave.error;
    return;
  }

  if (clave.value !== confirmarClave.value) {
    mensaje.value = "Las contraseñas no coinciden";
    return;
  }

  try {
    cargando.value = true;

    if (esInvitado.value) {
      const { data: codigoValido, error: errorCodigo } = await supabase.rpc(
        "validar_codigo_invitacion",
        { p_codigo: codigoInvitacion.value.trim() },
      );
      if (errorCodigo) throw errorCodigo;
      if (!codigoValido) {
        mensaje.value =
          "Ese código de invitación no es válido. Pedile uno a tu veterinaria.";
        return;
      }
    }

    const metadatos = esCliente.value
      ? { rol: "cliente" }
      : esInvitado.value
        ? { codigo_invitacion: codigoInvitacion.value.trim().toUpperCase() }
        : { nombre_veterinaria: nombreVeterinaria.value.trim() };

    const { data, error } = await supabase.auth.signUp({
      email: validacionCorreo.correo,
      password: clave.value,
      options: { data: metadatos },
    });

    if (error) throw error;

    registroExitoso.value = true;

    if (data?.session) {
      mensaje.value = "¡Cuenta creada con éxito! Entrando...";
      setTimeout(() => {
        enrutador.push("/inicio");
      }, 1000);
    } else {
      mensaje.value = "¡Cuenta creada! Ya podés iniciar sesión.";
      setTimeout(() => {
        enrutador.push("/login");
      }, 1500);
    }
    correo.value = "";
    clave.value = "";
    confirmarClave.value = "";
    codigoInvitacion.value = "";
  } catch (error) {
    const mensajeError = (error?.message || "").toLowerCase();
    if (
      mensajeError.includes("código de invitación") ||
      mensajeError.includes("codigo de invitacion")
    ) {
      mensaje.value =
        "Ese código de invitación no es válido. Pedile uno a tu veterinaria.";
    } else if (
      mensajeError.includes("database error saving new user") &&
      esInvitado.value
    ) {
      mensaje.value =
        "No se pudo unir a la veterinaria con ese código. Pedile uno nuevo a tu veterinaria.";
    } else if (mensajeError.includes("database error saving new user")) {
      mensaje.value =
        "No encontramos un cliente con ese correo. Pedí el alta en tu veterinaria y volvé a intentar.";
    } else if (
      mensajeError.includes("already registered") ||
      mensajeError.includes("already been registered")
    ) {
      mensaje.value = "Ese correo ya tiene una cuenta. Iniciá sesión.";
    } else if (mensajeError.includes("password")) {
      mensaje.value = "La contraseña no es válida. Usá al menos 6 caracteres.";
    } else {
      mensaje.value = error?.message || "Error al registrarse";
    }
  } finally {
    cargando.value = false;
  }
}
</script>

<template>
  <div class="pagina-acceso">
    <div class="tarjeta-acceso">
      <div class="marca-acceso">
        <span class="icono-marca"><Plus /></span>
        <div>
          <span class="texto-marca-acceso"
            ><strong>Vet</strong><b>Control</b></span
          >
          <small>Gestión veterinaria simple</small>
        </div>
      </div>

      <h1>Crear cuenta</h1>
      <p class="subtitulo-acceso">
        Registrate para comenzar a gestionar tu veterinaria.
      </p>

      <form @submit.prevent="registrarse">
        <fieldset class="tipo-cuenta">
          <legend>¿Qué tipo de cuenta necesitás?</legend>
          <label
            class="tipo-opcion"
            :class="{ activa: !esCliente && !esInvitado }"
          >
            <input type="radio" value="veterinaria" v-model="tipoCuenta" />
            <span>
              <strong>Creo una veterinaria</strong>
              <small>Soy el administrador de la clínica</small>
            </span>
          </label>
          <label class="tipo-opcion" :class="{ activa: esInvitado }">
            <input type="radio" value="veterinario" v-model="tipoCuenta" />
            <span>
              <strong>Me invitaron</strong>
              <small>Me uno como veterinario a una clínica</small>
            </span>
          </label>
          <label class="tipo-opcion" :class="{ activa: esCliente }">
            <input type="radio" value="cliente" v-model="tipoCuenta" />
            <span>
              <strong>Soy cliente</strong>
              <small>Vinculo mi cuenta con mi ficha</small>
            </span>
          </label>
        </fieldset>

        <label v-if="esInvitado">
          Código de invitación
          <input
            type="text"
            v-model="codigoInvitacion"
            required
            maxlength="8"
            placeholder="Ej: A1B2C3D4"
            @input="
              codigoInvitacion = codigoInvitacion
                .toUpperCase()
                .replace(/[^A-Z0-9]/g, '')
            "
          />
        </label>

        <label v-else-if="!esCliente">
          Nombre de la veterinaria
          <input
            type="text"
            v-model="nombreVeterinaria"
            required
            maxlength="120"
            placeholder="Ej: Veterinaria San Roque"
          />
        </label>

        <p v-if="esInvitado" class="ayuda-acceso">
          Pedile el código al administrador de tu veterinaria. Lo encuentra en
          Configuración → Código de invitación. Con ese código vas a entrar como
          veterinario a su clínica.
        </p>
        <p v-else-if="esCliente" class="ayuda-acceso">
          Usá el mismo correo con el que te dieron de alta en la veterinaria. Si
          todavía no estás dado de alta, pedile el alta a tu veterinaria
          primero.
        </p>

        <label>
          Correo electrónico
          <input
            type="email"
            v-model="correo"
            required
            autocomplete="email"
            placeholder="tu@correo.com"
          />
        </label>

        <div class="campo-clave">
          <label>
            Contraseña
            <input
              :type="mostrarClave ? 'text' : 'password'"
              v-model="clave"
              required
              autocomplete="new-password"
              placeholder="Mínimo 6 caracteres"
            />
          </label>
          <button
            type="button"
            class="alternar-clave"
            @click="mostrarClave = !mostrarClave"
            :aria-label="
              mostrarClave ? 'Ocultar contraseña' : 'Mostrar contraseña'
            "
          >
            <Eye v-if="!mostrarClave" />
            <EyeOff v-else />
          </button>
        </div>

        <div class="campo-clave">
          <label>
            Confirmar contraseña
            <input
              :type="mostrarClave ? 'text' : 'password'"
              v-model="confirmarClave"
              required
              autocomplete="new-password"
              placeholder="Repetí tu contraseña"
            />
          </label>
          <button
            type="button"
            class="alternar-clave"
            @click="mostrarClave = !mostrarClave"
            :aria-label="
              mostrarClave ? 'Ocultar contraseña' : 'Mostrar contraseña'
            "
          >
            <Eye v-if="!mostrarClave" />
            <EyeOff v-else />
          </button>
        </div>

        <button
          type="submit"
          class="boton-principal boton-acceso"
          :disabled="cargando"
        >
          {{ cargando ? "Registrando..." : "Crear cuenta" }}
        </button>
      </form>

      <p
        v-if="mensaje"
        class="mensaje-acceso"
        :class="{ exito: registroExitoso, error: !registroExitoso }"
      >
        {{ mensaje }}
      </p>

      <p class="enlace-acceso">
        ¿Ya tenés cuenta? <router-link to="/login">Iniciá sesión</router-link>
      </p>
    </div>
  </div>
</template>

<style scoped>
.pagina-acceso {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 20px;
  background: linear-gradient(135deg, #f5f8f4 0%, #e7f5da 100%);
}
.tarjeta-acceso {
  width: min(100%, 420px);
  padding: 40px;
  background: #fff;
  border-radius: 16px;
  border: 1px solid var(--borde);
  box-shadow: 0 8px 30px rgba(27, 94, 58, 0.08);
}
.marca-acceso {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 32px;
}
.texto-marca-acceso strong,
.texto-marca-acceso b {
  font-size: 22px;
  letter-spacing: -0.8px;
}
.texto-marca-acceso strong {
  color: var(--verde-oscuro);
}
.texto-marca-acceso b {
  color: var(--verde);
}
.marca-acceso small {
  display: block;
  color: var(--atenuado);
  font-size: 10px;
  font-weight: 600;
}
.tarjeta-acceso h1 {
  color: var(--verde-oscuro);
  font-size: 24px;
  font-weight: 800;
  letter-spacing: -0.5px;
  margin-bottom: 6px;
}
.subtitulo-acceso {
  color: var(--atenuado);
  font-size: 13px;
  margin-bottom: 28px;
}
.tarjeta-acceso label {
  display: block;
  margin-bottom: 18px;
  color: var(--atenuado);
  font-size: 11px;
  font-weight: 700;
}
.tarjeta-acceso input {
  display: block;
  width: 100%;
  margin-top: 6px;
  padding: 12px 14px;
  border: 1px solid var(--borde);
  border-radius: 8px;
  outline: none;
  color: var(--tinta);
  background: #fbfcfb;
  font-size: 13px;
  transition: border-color 0.2s;
}
.tarjeta-acceso input:focus {
  border-color: var(--verde);
  box-shadow: 0 0 0 3px rgba(91, 174, 74, 0.1);
}
.campo-clave {
  position: relative;
  margin-top: 6px;
}
.campo-clave input {
  margin-top: 0;
  padding-right: 42px;
}
.alternar-clave {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: var(--atenuado);
  cursor: pointer;
  padding: 4px;
  display: flex;
  align-items: center;
}

.tipo-cuenta {
  margin: 0 0 18px;
  padding: 0;
  border: 0;
}
.tipo-cuenta legend {
  margin-bottom: 8px;
  color: var(--atenuado);
  font-size: 11px;
  font-weight: 700;
}
.tipo-opcion {
  display: flex !important;
  align-items: center;
  gap: 10px;
  margin-bottom: 8px !important;
  padding: 11px 12px;
  border: 1px solid var(--borde);
  border-radius: 8px;
  background: #fbfcfb;
  cursor: pointer;
  transition:
    border-color 0.2s,
    background 0.2s;
}
.tipo-opcion.activa {
  border-color: var(--verde);
  background: #f2f9f0;
}
.tipo-opcion input {
  width: auto !important;
  margin-top: 0 !important;
  accent-color: var(--verde);
}
.tipo-opcion span {
  display: block;
}
.tipo-opcion strong {
  display: block;
  color: var(--verde-oscuro);
  font-size: 12px;
}
.tipo-opcion small {
  display: block;
  margin-top: 2px;
  color: var(--atenuado);
  font-size: 10px;
  font-weight: 400;
}
.ayuda-acceso {
  margin: -6px 0 18px;
  padding: 10px 12px;
  border: 1px dashed var(--borde);
  border-radius: 8px;
  background: #fbfcfb;
  color: var(--atenuado);
  font-size: 11px;
  line-height: 1.5;
}
.boton-acceso {
  width: 100%;
  margin-top: 6px;
  padding: 13px;
  font-size: 13px;
}
.boton-acceso:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.mensaje-acceso {
  margin-top: 18px;
  padding: 11px 14px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  text-align: center;
}
.mensaje-acceso.exito {
  color: #438538;
  background: #ebf7e4;
}
.mensaje-acceso.error {
  color: #ae5757;
  background: #fbeaea;
}
.enlace-acceso {
  margin-top: 22px;
  text-align: center;
  color: var(--atenuado);
  font-size: 12px;
}
.enlace-acceso a {
  color: var(--verde);
  font-weight: 700;
  text-decoration: none;
}
.enlace-acceso a:hover {
  text-decoration: underline;
}
</style>
