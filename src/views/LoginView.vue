<script setup>
import { Eye, EyeOff, Plus } from "lucide-vue-next";
import { ref } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "@/supabase";
import { validarCorreo, validarClave } from "@/utils/valicom";

const enrutador = useRouter();
const correo = ref("");
const clave = ref("");
const mostrarClave = ref(false);
const cargando = ref(false);
const mensaje = ref("");
const inicioExitoso = ref(false);

async function iniciarSesion() {
  mensaje.value = "";
  inicioExitoso.value = false;

  const validacionCorreo = validarCorreo(correo.value);
  if (!validacionCorreo.valido) {
    mensaje.value = validacionCorreo.error;
    return;
  }

  const validacionClave = validarClave(clave.value);
  if (!validacionClave.valido) {
    mensaje.value = validacionClave.error;
    return;
  }

  try {
    cargando.value = true;

    const { error } = await supabase.auth.signInWithPassword({
      email: validacionCorreo.correo,
      password: clave.value,
    });

    if (error) throw error;

    inicioExitoso.value = true;
    mensaje.value = "Inicio de sesión exitoso";
    correo.value = "";
    clave.value = "";
    enrutador.push("/inicio");
  } catch (error) {
    if (error.message === "Invalid login credentials") {
      mensaje.value = "El correo o la contraseña son incorrectos.";
    } else if (error.message === "Email not confirmed") {
      mensaje.value = "Primero tenés que confirmar tu correo electrónico.";
    } else {
      mensaje.value = error.message || "Error al iniciar sesión";
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

      <h1>Iniciá sesión</h1>
      <p class="subtitulo-acceso">
        Accedé a tu cuenta para gestionar tu veterinaria.
      </p>

      <form @submit.prevent="iniciarSesion">
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
              autocomplete="current-password"
              placeholder="••••••••"
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
          {{ cargando ? "Iniciando sesión..." : "Iniciar sesión" }}
        </button>
      </form>

      <p
        v-if="mensaje"
        class="mensaje-acceso"
        :class="{ exito: inicioExitoso, error: !inicioExitoso }"
      >
        {{ mensaje }}
      </p>

      <p class="enlace-acceso">
        ¿No tenés cuenta? <router-link to="/registro">Registrate</router-link>
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
