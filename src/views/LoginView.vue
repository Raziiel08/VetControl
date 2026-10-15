<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/supabase'
import { validarEmail, validarPassword } from '@/utils/valicom'

const router = useRouter()
const correo = ref('')
const clave = ref('')
const cargando = ref(false)
const mensaje = ref('')
const inicioExitoso = ref(false)

async function iniciarSesion() {
  mensaje.value = ''
  inicioExitoso.value = false

  const validacionEmail = validarEmail(correo.value)
  if (!validacionEmail.valido) {
    mensaje.value = validacionEmail.error
    return
  }

  const validacionPass = validarPassword(clave.value)
  if (!validacionPass.valido) {
    mensaje.value = validacionPass.error
    return
  }

  try {
    cargando.value = true

    const { error } = await supabase.auth.signInWithPassword({
      email: validacionEmail.email,
      password: clave.value,
    })

    if (error) throw error

    inicioExitoso.value = true
    mensaje.value = 'Inicio de sesión exitoso'
    correo.value = ''
    clave.value = ''
    router.push('/inicio')
  } catch (error) {
    if (error.message === 'Invalid login credentials') {
      mensaje.value = 'El correo o la contraseña son incorrectos.'
    } else if (error.message === 'Email not confirmed') {
      mensaje.value = 'Primero tenés que confirmar tu correo electrónico.'
    } else {
      mensaje.value = error.message || 'Error al iniciar sesión'
    }
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <div class="auth-brand">
        <span class="brand-mark">✚</span>
        <div>
          <span class="auth-brand-text"><strong>Vet</strong><b>Control</b></span>
          <small>Gestión veterinaria simple</small>
        </div>
      </div>

      <h1>Iniciá sesión</h1>
      <p class="auth-subtitle">Accedé a tu cuenta para gestionar tu veterinaria.</p>

      <form @submit.prevent="iniciarSesion">
        <label>
          Correo electrónico
          <input type="email" v-model="correo" required autocomplete="email" placeholder="tu@correo.com" />
        </label>

        <label>
          Contraseña
          <input type="password" v-model="clave" required autocomplete="current-password" placeholder="••••••••" />
        </label>

        <button type="submit" class="primary-button auth-submit" :disabled="cargando">
          {{ cargando ? 'Iniciando sesión...' : 'Iniciar sesión' }}
        </button>
      </form>

      <p v-if="mensaje" class="auth-message" :class="{ exito: inicioExitoso, error: !inicioExitoso }">
        {{ mensaje }}
      </p>

      <p class="auth-link">
        ¿No tenés cuenta? <router-link to="/registro">Registrate</router-link>
      </p>
    </div>
  </div>
</template>

<style scoped>
.auth-page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 20px;
  background: linear-gradient(135deg, #f5f8f4 0%, #e7f5da 100%);
}
.auth-card {
  width: min(100%, 420px);
  padding: 40px;
  background: #fff;
  border-radius: 16px;
  border: 1px solid var(--line);
  box-shadow: 0 8px 30px rgba(27, 94, 58, 0.08);
}
.auth-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 32px;
}
.auth-brand-text strong,
.auth-brand-text b {
  font-size: 22px;
  letter-spacing: -0.8px;
}
.auth-brand-text strong { color: var(--green-dark); }
.auth-brand-text b { color: var(--green); }
.auth-brand small {
  display: block;
  color: var(--muted);
  font-size: 10px;
  font-weight: 600;
}
.auth-card h1 {
  color: var(--green-dark);
  font-size: 24px;
  font-weight: 800;
  letter-spacing: -0.5px;
  margin-bottom: 6px;
}
.auth-subtitle {
  color: var(--muted);
  font-size: 13px;
  margin-bottom: 28px;
}
.auth-card label {
  display: block;
  margin-bottom: 18px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 700;
}
.auth-card input {
  display: block;
  width: 100%;
  margin-top: 6px;
  padding: 12px 14px;
  border: 1px solid var(--line);
  border-radius: 8px;
  outline: none;
  color: var(--ink);
  background: #fbfcfb;
  font-size: 13px;
  transition: border-color 0.2s;
}
.auth-card input:focus {
  border-color: var(--green);
  box-shadow: 0 0 0 3px rgba(91, 174, 74, 0.1);
}
.auth-submit {
  width: 100%;
  margin-top: 6px;
  padding: 13px;
  font-size: 13px;
}
.auth-submit:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.auth-message {
  margin-top: 18px;
  padding: 11px 14px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 600;
  text-align: center;
}
.auth-message.exito {
  color: #438538;
  background: #ebf7e4;
}
.auth-message.error {
  color: #ae5757;
  background: #fbeaea;
}
.auth-link {
  margin-top: 22px;
  text-align: center;
  color: var(--muted);
  font-size: 12px;
}
.auth-link a {
  color: var(--green);
  font-weight: 700;
  text-decoration: none;
}
.auth-link a:hover {
  text-decoration: underline;
}
</style>
