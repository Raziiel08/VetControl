<script setup>
import { ref, onMounted } from 'vue'
import { Lock } from 'lucide-vue-next'
import { supabase } from '@/supabase'
import { useUsuario } from '@/composables/useUsuario'
import { useToast } from '@/composables/useToast'

const { email: usuarioEmail } = useUsuario()
const { notify } = useToast()

// Datos de la veterinaria: se leen de la tabla y se guardan con Update.
// El RLS garantiza que cada usuario solo vea/escriba la suya.
const nombre = ref('')
const telefono = ref('')
const direccion = ref('')
// Horarios de atención: columna jsonb `horarios` de veterinarias.
// Arranca en `false`: se activa recién cuando la consulta con la columna
// funciona (si la base todavía no tiene la etapa 8, queda en modo lectura).
const horarios = ref({ lunes_viernes: '09:00 - 18:00', sabados: '09:00 - 13:00', domingos: 'Cerrado' })
const horariosDisponibles = ref(false)
const cargando = ref(false)
const guardando = ref(false)

onMounted(() => {
  cargar()
})

function aplicarDatos(data) {
  nombre.value = data.nombre || ''
  telefono.value = data.telefono || ''
  direccion.value = data.direccion || ''
  if (data.horarios && typeof data.horarios === 'object') {
    horarios.value = { ...horarios.value, ...data.horarios }
  }
}

async function cargar() {
  cargando.value = true
  try {
    // 1) Se intenta con la columna nueva `horarios`.
    const conHorarios = await supabase
      .from('veterinarias')
      .select('nombre, telefono, direccion, horarios')
      .limit(1)
      .maybeSingle()

    if (!conHorarios.error) {
      horariosDisponibles.value = true
      if (conHorarios.data) aplicarDatos(conHorarios.data)
      return
    }

    // 2) Si la columna todavía no existe en la base, se cargan los datos
    //    básicos y la edición de horarios queda deshabilitada.
    const sinHorarios = await supabase
      .from('veterinarias')
      .select('nombre, telefono, direccion')
      .limit(1)
      .maybeSingle()

    if (sinHorarios.error) throw sinHorarios.error
    horariosDisponibles.value = false
    if (sinHorarios.data) aplicarDatos(sinHorarios.data)
  } catch {
    notify('No se pudieron cargar los datos de la veterinaria')
  } finally {
    cargando.value = false
  }
}

async function guardar() {
  if (!nombre.value.trim()) {
    notify('El nombre de la veterinaria es obligatorio')
    return
  }

  guardando.value = true
  try {
    const { data: veterinariaId, error: errorId } = await supabase.rpc('obtener_mi_veterinaria_id')
    if (errorId) throw errorId
    if (!veterinariaId) throw new Error('Tu cuenta no tiene una veterinaria asociada.')

    const cambios = {
      nombre: nombre.value.trim(),
      telefono: telefono.value.trim(),
      direccion: direccion.value.trim(),
    }
    // Los horarios solo se envían si la columna existe en la base
    if (horariosDisponibles.value) {
      cambios.horarios = {
        lunes_viernes: horarios.value.lunes_viernes.trim(),
        sabados: horarios.value.sabados.trim(),
        domingos: horarios.value.domingos.trim(),
      }
    }

    let { error } = await supabase
      .from('veterinarias')
      .update(cambios)
      .eq('id', veterinariaId)

    // Si la columna `horarios` todavía no existe, se reintenta sin ella.
    if (error && String(error.message || '').includes('horarios')) {
      horariosDisponibles.value = false
      delete cambios.horarios
      ;({ error } = await supabase.from('veterinarias').update(cambios).eq('id', veterinariaId))
    }

    if (error) throw error
    notify('Cambios guardados')
  } catch (e) {
    notify(
      String(e.message || '').includes('row-level security')
        ? 'No tenés permiso para hacer esta acción.'
        : e.message || 'No se pudieron guardar los cambios'
    )
  } finally {
    guardando.value = false
  }
}
</script>

<template>
        <section class="page-content">
          <div class="page-heading"><div><p class="eyebrow">PREFERENCIAS</p><h1>Configuración</h1><p class="muted">Mantené actualizada la información de tu veterinaria.</p></div><button class="primary-button" :disabled="guardando || cargando" @click="guardar">{{ guardando ? 'Guardando...' : 'Guardar cambios' }}</button></div>
          <div class="settings-grid">
            <div class="panel settings-card"><h2>Datos de la veterinaria</h2><label>Nombre de la veterinaria<input v-model="nombre" :disabled="cargando" maxlength="120" placeholder="Nombre de tu veterinaria" /></label><label>Teléfono de contacto<input v-model="telefono" :disabled="cargando" maxlength="40" placeholder="011 4567-8901" /></label><label>Dirección<input v-model="direccion" :disabled="cargando" maxlength="160" placeholder="Calle y número" /></label></div>
            <div class="panel settings-card"><h2>Horarios de atención</h2><template v-if="horariosDisponibles"><label>Lunes a viernes<input v-model="horarios.lunes_viernes" :disabled="cargando" maxlength="60" placeholder="09:00 - 18:00" /></label><label>Sábados<input v-model="horarios.sabados" :disabled="cargando" maxlength="60" placeholder="09:00 - 13:00" /></label><label>Domingos<input v-model="horarios.domingos" :disabled="cargando" maxlength="60" placeholder="Cerrado" /></label></template><template v-else><div class="hours-row"><span>Lunes a viernes</span><strong>09:00 — 18:00</strong></div><div class="hours-row"><span>Sábados</span><strong>09:00 — 13:00</strong></div><div class="hours-row"><span>Domingos</span><strong class="muted">Cerrado</strong></div><p class="muted" style="margin-top: 10px;">Aplicá el archivo database.sql para poder editar los horarios.</p></template></div>
          </div>
          <div class="settings-security">
            <div class="panel settings-card">
              <h2>Seguridad de la cuenta</h2>
              <p class="muted" style="margin-bottom: 14px;">Gestioná la seguridad de tu cuenta.</p>
              <div class="security-info">
                <span>Correo: <strong>{{ usuarioEmail }}</strong></span>
              </div>
              <router-link to="/cambiar-clave" class="outline-button"><Lock /> Cambiar contraseña</router-link>
            </div>
          </div>
        </section>
</template>
