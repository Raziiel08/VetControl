<script setup>
import { ArrowLeft, Plus } from "lucide-vue-next";
import { ref, onMounted } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "@/supabase";
import { validarClave } from "@/utils/valicom";
import { useUsuario } from "@/composables/useUsuario";

const enrutador = useRouter();
const nuevaClave = ref("");
const confirmarClave = ref("");
const { correo: usuarioCorreo, cargar } = useUsuario();
const cargando = ref(false);
const mensaje = ref("");
const exitoso = ref(false);

onMounted(() => {
  cargar();
});

async function cambiarClave() {
  mensaje.value = "";
  exitoso.value = false;

  const validacionClave = validarClave(nuevaClave.value);
  if (!validacionClave.valido) {
    mensaje.value = validacionClave.error;
    return;
  }

  if (nuevaClave.value !== confirmarClave.value) {
    mensaje.value = "Las contraseñas no coinciden";
    return;
  }

  try {
    cargando.value = true;

    const { error } = await supabase.auth.updateUser({
      password: nuevaClave.value,
    });

    if (error) throw error;

    exitoso.value = true;
    mensaje.value = "Contraseña actualizada correctamente. Redirigiendo...";
    nuevaClave.value = "";
    confirmarClave.value = "";

    setTimeout(() => {
      enrutador.push("/");
    }, 2000);
  } catch (error) {
    mensaje.value = error.message || "Error al cambiar la contraseña";
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

      <h1>Cambiar contraseña</h1>
      <p class="subtitulo-acceso" v-if="usuarioCorreo">
        Actualizá la contraseña de <strong>{{ usuarioCorreo }}</strong>
      </p>

      <form @submit.prevent="cambiarClave">
        <label>
          Nueva contraseña
          <input
            type="password"
            v-model="nuevaClave"
            required
            autocomplete="new-password"
            placeholder="Mínimo 6 caracteres"
          />
        </label>

        <label>
          Confirmar nueva contraseña
          <input
            type="password"
            v-model="confirmarClave"
            required
            autocomplete="new-password"
            placeholder="Repetí tu nueva contraseña"
          />
        </label>

        <button
          type="submit"
          class="boton-principal boton-acceso"
          :disabled="cargando"
        >
          {{ cargando ? "Actualizando..." : "Cambiar contraseña" }}
        </button>
      </form>

      <p
        v-if="mensaje"
        class="mensaje-acceso"
        :class="{ exito: exitoso, error: !exitoso }"
      >
        {{ mensaje }}
      </p>

      <p class="enlace-acceso">
        <router-link to="/"><ArrowLeft /> Volver al inicio</router-link>
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
.subtitulo-acceso strong {
  color: var(--verde-oscuro);
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
