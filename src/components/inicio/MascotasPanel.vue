<script setup>
import { ArrowRight, ChevronDown, PawPrint, Pencil, Plus, Search, Syringe, TriangleAlert, X } from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { supabase } from '@/supabase'
import { useToast } from '@/composables/useToast'
import { traducirError } from '@/utils/errores'
import { isoLocal } from '@/utils/fechas'

const emit = defineEmits(['navigate'])
const { notify } = useToast()

const ESPECIES = ['Perro', 'Gato', 'Ave', 'Conejo', 'Otro']

const pets = ref([])
const clientes = ref([])
const vacunas = ref([]) // vacunas de la mascota abierta en la ficha
const cargando = ref(true)
const busqueda = ref('')

// ---- Modal de alta / edición ----------------------------------------------
const showForm = ref(false)
const guardando = ref(false)
const errorForm = ref('')
const editandoId = ref(null)
const form = ref(vacio())

// ---- Ficha de la mascota ---------------------------------------------------
const showFicha = ref(false)
const ficha = ref(null)

function vacio() {
  return {
    nombre: '',
    especie: 'Perro',
    raza: '',
    sexo: '',
    fecha_nacimiento: '',
    peso_kg: '',
    alergias: '',
    observaciones: '',
    cliente_id: '',
  }
}

const petsFiltradas = computed(() => {
  const texto = busqueda.value.trim().toLowerCase()
  if (!texto) return pets.value
  return pets.value.filter(
    (p) =>
      p.nombre.toLowerCase().includes(texto) ||
      (p.clientes?.nombre_completo || '').toLowerCase().includes(texto)
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

function edadDe(fechaNacimiento) {
  if (!fechaNacimiento) return 'Sin registrar'
  const nacimiento = new Date(fechaNacimiento + 'T12:00:00')
  const anios = Math.floor((Date.now() - nacimiento.getTime()) / (365.25 * 24 * 3600 * 1000))
  if (anios < 1) {
    const meses = Math.max(1, Math.floor((Date.now() - nacimiento.getTime()) / (30 * 24 * 3600 * 1000)))
    return `${meses} ${meses === 1 ? 'mes' : 'meses'}`
  }
  return `${anios} ${anios === 1 ? 'año' : 'años'}`
}

// Estado médico derivado de las vacunas: si no hay datos se muestra "Sin registro"
function estadoMedico(pet) {
  const deLaMascota = vacunas.value.filter((v) => v.mascota_id === pet.id)
  if (!deLaMascota.length) return { texto: 'Sin registro', color: 'yellow' }
  const hoy = isoLocal()
  if (deLaMascota.some((v) => v.fecha_proxima && v.fecha_proxima < hoy)) {
    return { texto: 'Vacuna vencida', color: 'red' }
  }
  const proximas = deLaMascota.filter((v) => v.fecha_proxima)
  if (proximas.length) return { texto: 'Vacunas al día', color: 'green' }
  return { texto: 'Sin próximas vacunas', color: 'yellow' }
}

async function cargar() {
  cargando.value = true
  try {
    const [mascotasRes, clientesRes, vacunasRes] = await Promise.all([
      supabase
        .from('mascotas')
        .select('id, nombre, especie, raza, sexo, fecha_nacimiento, peso_kg, alergias, observaciones, cliente_id, clientes(nombre_completo)')
        .order('nombre'),
      supabase.from('clientes').select('id, nombre_completo').order('nombre_completo'),
      supabase.from('vacunas').select('id, mascota_id, nombre, fecha_aplicacion, fecha_proxima, dosis'),
    ])
    if (mascotasRes.error) throw mascotasRes.error
    pets.value = mascotasRes.data || []
    if (!clientesRes.error) clientes.value = clientesRes.data || []
    if (!vacunasRes.error) vacunas.value = vacunasRes.data || []
  } catch (e) {
    notify(traducirError(e.message))
  } finally {
    cargando.value = false
  }
}

function abrirFormulario(pet = null) {
  errorForm.value = ''
  editandoId.value = pet?.id ?? null
  form.value = pet
    ? {
        nombre: pet.nombre,
        especie: pet.especie,
        raza: pet.raza || '',
        sexo: pet.sexo || '',
        fecha_nacimiento: pet.fecha_nacimiento || '',
        peso_kg: pet.peso_kg ?? '',
        alergias: pet.alergias || '',
        observaciones: pet.observaciones || '',
        cliente_id: pet.cliente_id || '',
      }
    : vacio()
  showForm.value = true
}

async function guardar() {
  errorForm.value = ''
  if (!form.value.nombre.trim()) return (errorForm.value = 'El nombre es obligatorio.')
  if (!form.value.cliente_id) return (errorForm.value = 'Elegí el dueño de la mascota.')

  guardando.value = true
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc('obtener_mi_veterinaria_id')
    if (errVet) throw errVet

    const datos = {
      nombre: form.value.nombre.trim(),
      especie: form.value.especie,
      raza: form.value.raza.trim() || null,
      sexo: form.value.sexo || null,
      fecha_nacimiento: form.value.fecha_nacimiento || null,
      peso_kg: form.value.peso_kg === '' ? null : Number(form.value.peso_kg),
      alergias: form.value.alergias.trim() || null,
      observaciones: form.value.observaciones.trim() || null,
      cliente_id: form.value.cliente_id,
    }

    let error
    if (editandoId.value) {
      const { data, error: errUpd } = await supabase
        .from('mascotas')
        .update(datos)
        .eq('id', editandoId.value)
        .select('id')
      error = errUpd
      if (!error && !data?.length) error = { message: 'No tenés permiso para modificar esta mascota.' }
    } else {
      ;({ error } = await supabase.from('mascotas').insert({ ...datos, veterinaria_id: veterinariaId }))
    }
    if (error) throw error

    showForm.value = false
    notify(editandoId.value ? 'Mascota actualizada' : 'Mascota registrada')
    await cargar()
  } catch (e) {
    errorForm.value = traducirError(e.message)
  } finally {
    guardando.value = false
  }
}

async function abrirFicha(pet) {
  ficha.value = pet
  showFicha.value = true
  // Las vacunas se cargan al abrir la ficha: la tabla puede no existir todavía
  const { data, error } = await supabase
    .from('vacunas')
    .select('id, nombre, dosis, fecha_aplicacion, fecha_proxima, notas')
    .eq('mascota_id', pet.id)
    .order('fecha_aplicacion', { ascending: false })
  if (!error) vacunas.value = [...vacunas.value.filter((v) => v.mascota_id !== pet.id), ...(data || [])]
}

function irAClientes() {
  emit('navigate', 'clients')
}

onMounted(cargar)
</script>

<template>
  <section class="page-content">
    <div class="page-heading">
      <div>
        <p class="eyebrow">REGISTRO DE PACIENTES</p>
        <h1>Mascotas</h1>
        <p class="muted">Accedé rápido a la ficha médica de cada paciente.</p>
      </div>
      <button class="primary-button" @click="abrirFormulario()"><Plus /> Agregar mascota</button>
    </div>

    <div class="toolbar">
      <label class="search">
        <span><Search /></span>
        <input v-model="busqueda" placeholder="Buscar por nombre o dueño" />
      </label>
      <button class="filter-button" @click="busqueda = ''">Limpiar <span><ChevronDown /></span></button>
    </div>

    <div class="pet-table panel">
      <div class="table-header">
        <span>MASCOTA</span><span>DUEÑO</span><span>EDAD</span><span>ESTADO MÉDICO</span><span></span>
      </div>

      <div v-if="cargando" class="empty-state"><p>Cargando mascotas...</p></div>

      <div v-else-if="!pets.length" class="empty-state">
        <span class="empty-icon"><PawPrint /></span>
        <strong>Todavía no hay mascotas registradas</strong>
        <p>Registrá la primera con “Agregar mascota”.</p>
        <button
          v-if="!clientes.length"
          class="text-button"
          style="margin-top: 8px;"
          @click="irAClientes"
        >
          Primero cargá un dueño <ArrowRight />
        </button>
      </div>

      <div v-else-if="!petsFiltradas.length" class="empty-state">
        <p>No hay mascotas que coincidan con la búsqueda.</p>
      </div>

      <button
        v-for="pet in petsFiltradas"
        :key="pet.id"
        class="pet-row"
        @click="abrirFicha(pet)"
      >
        <div class="pet-cell">
          <span class="pet-avatar">{{ iniciales(pet.nombre) }}</span>
          <span>
            <strong>{{ pet.nombre }}</strong>
            <small>{{ pet.especie }}<template v-if="pet.raza"> · {{ pet.raza }}</template></small>
          </span>
        </div>
        <span>{{ pet.clientes?.nombre_completo || 'Sin dueño' }}</span>
        <span>{{ edadDe(pet.fecha_nacimiento) }}</span>
        <span>
          <b class="status" :class="estadoMedico(pet).color">{{ estadoMedico(pet).texto }}</b>
        </span>
        <span class="arrow"><ArrowRight /></span>
      </button>
    </div>

    <!-- Modal: alta / edición -->
    <div v-if="showForm" class="modal-backdrop" @click.self="showForm = false">
      <section class="booking-modal">
        <button class="modal-close" aria-label="Cerrar" @click="showForm = false"><X /></button>
        <p class="eyebrow">{{ editandoId ? 'MODIFICACIÓN' : 'ALTA' }}</p>
        <h2>{{ editandoId ? 'Editar mascota' : 'Nueva mascota' }}</h2>
        <p class="muted">Completá los datos del paciente.</p>

        <div v-if="!clientes.length" class="modal-note" style="margin-top: 16px;">
          Primero necesitás registrar al dueño.
          <button class="text-button" style="margin-left: 6px;" @click="showForm = false; irAClientes()">
            Ir a Clientes <ArrowRight />
          </button>
        </div>

        <form v-else class="modal-form" @submit.prevent="guardar">
          <div class="fila">
            <label>
              Nombre *
              <input v-model="form.nombre" type="text" maxlength="80" placeholder="Ej: Luna" />
            </label>
            <label>
              Especie *
              <select v-model="form.especie">
                <option v-for="e in ESPECIES" :key="e" :value="e">{{ e }}</option>
              </select>
            </label>
          </div>

          <div class="fila">
            <label>
              Raza
              <input v-model="form.raza" type="text" maxlength="80" placeholder="Ej: Golden retriever" />
            </label>
            <label>
              Sexo
              <select v-model="form.sexo">
                <option value="">Sin informar</option>
                <option value="Macho">Macho</option>
                <option value="Hembra">Hembra</option>
              </select>
            </label>
          </div>

          <div class="fila">
            <label>
              Fecha de nacimiento
              <input v-model="form.fecha_nacimiento" type="date" />
            </label>
            <label>
              Peso (kg)
              <input v-model="form.peso_kg" type="number" min="0" step="0.1" placeholder="Ej: 12.5" />
            </label>
          </div>

          <label>
            Dueño *
            <select v-model="form.cliente_id">
              <option value="" disabled>Elegí un cliente</option>
              <option v-for="c in clientes" :key="c.id" :value="c.id">{{ c.nombre_completo }}</option>
            </select>
          </label>

          <label>
            Alergias
            <input v-model="form.alergias" type="text" maxlength="200" placeholder="Ej: polen, ciertos alimentos" />
          </label>

          <label>
            Observaciones
            <textarea v-model="form.observaciones" rows="2" maxlength="500" placeholder="Notas de la ficha..."></textarea>
          </label>

          <p v-if="errorForm" class="modal-error"><TriangleAlert /> {{ errorForm }}</p>

          <div class="modal-actions">
            <button type="button" class="outline-button" @click="showForm = false">Cancelar</button>
            <button type="submit" class="primary-button" :disabled="guardando">
              <Plus /> {{ guardando ? 'Guardando...' : editandoId ? 'Guardar cambios' : 'Registrar mascota' }}
            </button>
          </div>
        </form>
      </section>
    </div>

    <!-- Modal: ficha -->
    <div v-if="showFicha && ficha" class="modal-backdrop" @click.self="showFicha = false">
      <section class="booking-modal">
        <button class="modal-close" aria-label="Cerrar" @click="showFicha = false"><X /></button>
        <div class="pet-profile-header" style="margin-top: 4px;">
          <span class="large-pet-avatar lime">{{ iniciales(ficha.nombre) }}</span>
          <div>
            <p class="eyebrow">FICHA DE MASCOTA</p>
            <h2>{{ ficha.nombre }}</h2>
            <p class="muted">
              {{ ficha.especie }}<template v-if="ficha.raza"> · {{ ficha.raza }}</template>
              · {{ edadDe(ficha.fecha_nacimiento) }}
              <template v-if="ficha.peso_kg"> · {{ ficha.peso_kg }} kg</template>
            </p>
          </div>
        </div>

        <div class="ficha-datos">
          <div><span>Dueño</span><strong>{{ ficha.clientes?.nombre_completo || 'Sin dueño' }}</strong></div>
          <div><span>Sexo</span><strong>{{ ficha.sexo || 'Sin informar' }}</strong></div>
          <div><span>Estado</span><strong>{{ estadoMedico(ficha).texto }}</strong></div>
        </div>

        <div v-if="ficha.alergias" class="modal-error" style="background: #fff4d3; color: #ad7615;">
          <TriangleAlert /> Alergias: {{ ficha.alergias }}
        </div>
        <p v-if="ficha.observaciones" class="modal-note">{{ ficha.observaciones }}</p>

        <div class="ficha-seccion">
          <h3><Syringe /> Vacunas</h3>
          <div v-if="!vacunas.filter((v) => v.mascota_id === ficha.id).length" class="modal-note">
            Sin vacunas cargadas para esta mascota.
          </div>
          <div
            v-for="v in vacunas.filter((v) => v.mascota_id === ficha.id)"
            :key="v.id"
            class="vacuna-fila"
          >
            <strong>{{ v.nombre }}</strong>
            <small>
              Aplicada {{ v.fecha_aplicacion }}
              <template v-if="v.fecha_proxima"> · próxima {{ v.fecha_proxima }}</template>
            </small>
          </div>
        </div>

        <div class="modal-actions">
          <button class="outline-button" @click="showFicha = false; abrirFormulario(ficha)">
            <Pencil /> Editar
          </button>
          <button class="primary-button" @click="showFicha = false">
            <X /> Cerrar
          </button>
        </div>
      </section>
    </div>
  </section>
</template>

<style scoped>
.ficha-datos {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin: 16px 0 12px;
}
.ficha-datos > div {
  padding: 9px 11px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #fbfcfb;
}
.ficha-datos span { display: block; color: var(--muted); font-size: 10px; font-weight: 700; }
.ficha-datos strong { display: block; margin-top: 3px; color: var(--green-dark); font-size: 12px; }
.ficha-seccion { margin-top: 16px; }
.ficha-seccion h3 {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-bottom: 9px;
  color: var(--green-dark);
  font-size: 13px;
  font-weight: 800;
}
.vacuna-fila {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 9px 11px;
  border-top: 1px solid #eef1ee;
  font-size: 12px;
}
.vacuna-fila small { color: var(--muted); font-size: 10px; }
.modal-error svg, .modal-note svg { vertical-align: -2px; }
.modal-error { display: flex; align-items: center; gap: 6px; }
</style>
