<script setup>
import { ArrowRight, Pencil, Plus, Search, Stethoscope, TriangleAlert, X } from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { supabase } from '@/supabase'
import { useToast } from '@/composables/useToast'
import { traducirError } from '@/utils/errores'
import { isoLocal } from '@/utils/fechas'

const emit = defineEmits(['navigate'])
const { notify } = useToast()

const consultas = ref([])
const mascotas = ref([])
const cargando = ref(true)
const busqueda = ref('')

// ---- Modal de alta / edición ----------------------------------------------
const showForm = ref(false)
const guardando = ref(false)
const errorForm = ref('')
const editandoId = ref(null)
const form = ref(vacio())

function vacio() {
  return {
    mascota_id: '',
    motivo: '',
    sintomas: '',
    diagnostico: '',
    tratamiento: '',
    peso_actual_kg: '',
    proximo_control: '',
  }
}

const consultasFiltradas = computed(() => {
  const texto = busqueda.value.trim().toLowerCase()
  const lista = [...consultas.value].sort((a, b) => new Date(b.fecha) - new Date(a.fecha))
  if (!texto) return lista
  return lista.filter(
    (c) =>
      (c.mascota?.nombre || '').toLowerCase().includes(texto) ||
      (c.motivo || '').toLowerCase().includes(texto) ||
      (c.diagnostico || '').toLowerCase().includes(texto)
  )
})

function iniciales(nombre = '?') {
  return nombre
    .split(' ')
    .map((n) => n[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function fechaCorta(iso) {
  if (!iso) return ''
  return new Intl.DateTimeFormat('es-AR', { day: '2-digit', month: 'short', year: 'numeric' }).format(
    new Date(iso)
  )
}

// Una consulta está "pendiente" si tiene próximo control vencido
function estadoDe(consulta) {
  if (!consulta.proximo_control) return { texto: 'Completada', color: 'green' }
  const hoy = isoLocal()
  if (consulta.proximo_control < hoy) return { texto: 'Control vencido', color: 'red' }
  return { texto: 'Completada', color: 'green' }
}

async function cargar() {
  cargando.value = true
  try {
    const [consultasRes, mascotasRes] = await Promise.all([
      supabase
        .from('consultas')
        .select('id, fecha, motivo, sintomas, diagnostico, tratamiento, peso_actual_kg, proximo_control, mascota_id, mascota:mascotas(nombre, clientes(nombre_completo))')
        .order('fecha', { ascending: false })
        .limit(100),
      supabase.from('mascotas').select('id, nombre, clientes(nombre_completo)').order('nombre'),
    ])
    if (consultasRes.error) throw consultasRes.error
    consultas.value = consultasRes.data || []
    if (!mascotasRes.error) mascotas.value = mascotasRes.data || []
  } catch (e) {
    notify(traducirError(e.message))
  } finally {
    cargando.value = false
  }
}

function abrirFormulario(consulta = null) {
  errorForm.value = ''
  editandoId.value = consulta?.id ?? null
  form.value = consulta
    ? {
        mascota_id: consulta.mascota_id,
        motivo: consulta.motivo || '',
        sintomas: consulta.sintomas || '',
        diagnostico: consulta.diagnostico || '',
        tratamiento: consulta.tratamiento || '',
        peso_actual_kg: consulta.peso_actual_kg ?? '',
        proximo_control: consulta.proximo_control || '',
      }
    : vacio()
  showForm.value = true
}

async function guardar() {
  errorForm.value = ''
  if (!form.value.mascota_id) return (errorForm.value = 'Elegí la mascota.')
  if (!form.value.motivo.trim()) return (errorForm.value = 'El motivo es obligatorio.')
  if (!form.value.diagnostico.trim()) return (errorForm.value = 'El diagnóstico es obligatorio.')
  if (!form.value.tratamiento.trim()) return (errorForm.value = 'El tratamiento es obligatorio.')

  guardando.value = true
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc('obtener_mi_veterinaria_id')
    if (errVet) throw errVet
    const { data: { user } } = await supabase.auth.getUser()

    const datos = {
      mascota_id: form.value.mascota_id,
      motivo: form.value.motivo.trim(),
      sintomas: form.value.sintomas.trim() || null,
      diagnostico: form.value.diagnostico.trim(),
      tratamiento: form.value.tratamiento.trim(),
      peso_actual_kg: form.value.peso_actual_kg === '' ? null : Number(form.value.peso_actual_kg),
      proximo_control: form.value.proximo_control || null,
    }

    let error
    if (editandoId.value) {
      const { data, error: errUpd } = await supabase
        .from('consultas')
        .update(datos)
        .eq('id', editandoId.value)
        .select('id')
      error = errUpd
      if (!error && !data?.length) error = { message: 'No tenés permiso para modificar esta consulta.' }
    } else {
      ;({ error } = await supabase.from('consultas').insert({
        ...datos,
        veterinaria_id: veterinariaId,
        veterinario_id: user?.id ?? null,
      }))
    }
    if (error) throw error

    showForm.value = false
    notify(editandoId.value ? 'Consulta actualizada' : 'Consulta registrada')
    await cargar()
  } catch (e) {
    errorForm.value = traducirError(e.message)
  } finally {
    guardando.value = false
  }
}

onMounted(cargar)
</script>

<template>
  <section class="page-content">
    <div class="page-heading">
      <div>
        <p class="eyebrow">HISTORIAL CLÍNICO</p>
        <h1>Consultas</h1>
        <p class="muted">Últimas consultas registradas y pendientes.</p>
      </div>
      <button class="primary-button" @click="abrirFormulario()"><Plus /> Nueva consulta</button>
    </div>

    <div class="toolbar">
      <label class="search">
        <span><Search /></span>
        <input v-model="busqueda" placeholder="Buscar por mascota, motivo o diagnóstico" />
      </label>
    </div>

    <div class="panel consultation-list">
      <div v-if="cargando" class="empty-state"><p>Cargando consultas...</p></div>

      <div v-else-if="!consultas.length" class="empty-state">
        <span class="empty-icon"><Stethoscope /></span>
        <strong>No hay consultas registradas</strong>
        <p>Registrá la primera con “Nueva consulta”.</p>
        <button
          v-if="!mascotas.length"
          class="text-button"
          style="margin-top: 8px;"
          @click="emit('navigate', 'pets')"
        >
          Primero registrá una mascota <ArrowRight />
        </button>
      </div>

      <div v-else-if="!consultasFiltradas.length" class="empty-state">
        <p>No hay consultas que coincidan con la búsqueda.</p>
      </div>

      <div
        v-for="item in consultasFiltradas"
        :key="item.id"
        class="consultation-row"
      >
        <span class="pet-avatar">{{ iniciales(item.mascota?.nombre) }}</span>
        <div>
          <strong>{{ item.mascota?.nombre || 'Mascota' }}</strong>
          <p>
            {{ item.motivo }}
            <template v-if="item.mascota?.clientes?.nombre_completo">
              · {{ item.mascota.clientes.nombre_completo }}
            </template>
          </p>
        </div>
        <small>{{ fechaCorta(item.fecha) }}</small>
        <b class="status" :class="estadoDe(item).color">{{ estadoDe(item).texto }}</b>
        <button class="text-button" @click="abrirFormulario(item)">
          Editar <ArrowRight />
        </button>
      </div>
    </div>

    <!-- Modal: alta / edición -->
    <div v-if="showForm" class="modal-backdrop" @click.self="showForm = false">
      <section class="booking-modal">
        <button class="modal-close" aria-label="Cerrar" @click="showForm = false"><X /></button>
        <p class="eyebrow">{{ editandoId ? 'MODIFICACIÓN' : 'NUEVA' }}</p>
        <h2>{{ editandoId ? 'Editar consulta' : 'Registrar consulta' }}</h2>
        <p class="muted">Historial clínico de la mascota.</p>

        <div v-if="!mascotas.length" class="modal-note" style="margin-top: 16px;">
          Primero necesitás registrar una mascota.
          <button class="text-button" style="margin-left: 6px;" @click="showForm = false; emit('navigate', 'pets')">
            Ir a Mascotas <ArrowRight />
          </button>
        </div>

        <form v-else class="modal-form" @submit.prevent="guardar">
          <label>
            Mascota *
            <select v-model="form.mascota_id">
              <option value="" disabled>Elegí una mascota</option>
              <option v-for="m in mascotas" :key="m.id" :value="m.id">
                {{ m.nombre }}<template v-if="m.clientes"> · {{ m.clientes.nombre_completo }}</template>
              </option>
            </select>
          </label>

          <label>
            Motivo de la consulta *
            <input v-model="form.motivo" type="text" maxlength="160" placeholder="Ej: control general" />
          </label>

          <label>
            Síntomas
            <textarea v-model="form.sintomas" rows="2" maxlength="500" placeholder="Ej: tos, apatía..."></textarea>
          </label>

          <label>
            Diagnóstico *
            <textarea v-model="form.diagnostico" rows="2" maxlength="500" placeholder="Ej: infección leve"></textarea>
          </label>

          <label>
            Tratamiento *
            <textarea v-model="form.tratamiento" rows="2" maxlength="500" placeholder="Ej: antibiótico 7 días"></textarea>
          </label>

          <div class="fila">
            <label>
              Peso actual (kg)
              <input v-model="form.peso_actual_kg" type="number" min="0" step="0.1" placeholder="Ej: 12.5" />
            </label>
            <label>
              Próximo control
              <input v-model="form.proximo_control" type="date" />
            </label>
          </div>

          <p v-if="errorForm" class="modal-error"><TriangleAlert /> {{ errorForm }}</p>

          <div class="modal-actions">
            <button type="button" class="outline-button" @click="showForm = false">Cancelar</button>
            <button type="submit" class="primary-button" :disabled="guardando">
              <Plus /> {{ guardando ? 'Guardando...' : editandoId ? 'Guardar cambios' : 'Registrar consulta' }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </section>
</template>
