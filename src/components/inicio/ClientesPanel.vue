<script setup>
import { Pencil, Plus, Search, TriangleAlert, Users, X } from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { supabase } from '@/supabase'
import { useToast } from '@/composables/useToast'
import { traducirError } from '@/utils/errores'

const { notify } = useToast()

const clients = ref([])
const cargando = ref(true)
const busqueda = ref('')

// ---- Modal de alta / edición ----------------------------------------------
const showForm = ref(false)
const guardando = ref(false)
const errorForm = ref('')
const editandoId = ref(null)
const form = ref(vacio())

function vacio() {
  return { nombre_completo: '', telefono: '', email: '', direccion: '', dni: '' }
}

const clientsFiltrados = computed(() => {
  const texto = busqueda.value.trim().toLowerCase()
  if (!texto) return clients.value
  return clients.value.filter(
    (c) =>
      c.nombre_completo.toLowerCase().includes(texto) ||
      (c.telefono || '').includes(texto) ||
      (c.email || '').toLowerCase().includes(texto)
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

async function cargar() {
  cargando.value = true
  try {
    const { data, error } = await supabase
      .from('clientes')
      .select('id, nombre_completo, telefono, email, direccion, dni, mascotas(id, nombre)')
      .order('nombre_completo')
    if (error) throw error
    clients.value = data || []
  } catch (e) {
    notify(traducirError(e.message))
  } finally {
    cargando.value = false
  }
}

function abrirFormulario(cliente = null) {
  errorForm.value = ''
  editandoId.value = cliente?.id ?? null
  form.value = cliente
    ? {
        nombre_completo: cliente.nombre_completo,
        telefono: cliente.telefono || '',
        email: cliente.email || '',
        direccion: cliente.direccion || '',
        dni: cliente.dni || '',
      }
    : vacio()
  showForm.value = true
}

async function guardar() {
  errorForm.value = ''
  if (!form.value.nombre_completo.trim()) return (errorForm.value = 'El nombre es obligatorio.')
  if (!form.value.telefono.trim()) return (errorForm.value = 'El teléfono es obligatorio.')
  if (form.value.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.value.email)) {
    return (errorForm.value = 'El correo electrónico no es válido.')
  }

  guardando.value = true
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc('obtener_mi_veterinaria_id')
    if (errVet) throw errVet

    const datos = {
      nombre_completo: form.value.nombre_completo.trim(),
      telefono: form.value.telefono.trim(),
      email: form.value.email.trim() || null,
      direccion: form.value.direccion.trim() || null,
      dni: form.value.dni.trim() || null,
    }

    let error
    if (editandoId.value) {
      const { data, error: errUpd } = await supabase
        .from('clientes')
        .update(datos)
        .eq('id', editandoId.value)
        .select('id')
      error = errUpd
      if (!error && !data?.length) error = { message: 'No tenés permiso para modificar este cliente.' }
    } else {
      ;({ error } = await supabase.from('clientes').insert({ ...datos, veterinaria_id: veterinariaId }))
    }
    if (error) throw error

    showForm.value = false
    notify(editandoId.value ? 'Cliente actualizado' : 'Cliente registrado')
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
        <p class="eyebrow">AGENDA Y CONTACTOS</p>
        <h1>Clientes</h1>
        <p class="muted">Gestioná dueños y sus mascotas asociadas.</p>
      </div>
      <button class="primary-button" @click="abrirFormulario()"><Plus /> Agregar cliente</button>
    </div>

    <div class="toolbar">
      <label class="search">
        <span><Search /></span>
        <input v-model="busqueda" placeholder="Buscar cliente por nombre, teléfono o email" />
      </label>
    </div>

    <div v-if="cargando" class="empty-state panel"><p>Cargando clientes...</p></div>

    <div v-else-if="!clients.length" class="empty-state panel">
      <span class="empty-icon"><Users /></span>
      <strong>Todavía no hay clientes registrados</strong>
      <p>Registrá al primer dueño con “Agregar cliente”.</p>
    </div>

    <div v-else-if="!clientsFiltrados.length" class="empty-state panel">
      <p>No hay clientes que coincidan con la búsqueda.</p>
    </div>

    <div v-else class="client-cards">
      <div v-for="client in clientsFiltrados" :key="client.id" class="panel client-card">
        <span class="client-avatar">{{ iniciales(client.nombre_completo) }}</span>
        <div>
          <h3>{{ client.nombre_completo }}</h3>
          <p>{{ client.telefono }}<template v-if="client.email"> · {{ client.email }}</template></p>
          <small>
            {{ client.mascotas?.length || 0 }}
            {{ client.mascotas?.length === 1 ? 'mascota' : 'mascotas' }}
          </small>
        </div>
        <button
          class="row-menu"
          :aria-label="'Editar ' + client.nombre_completo"
          @click="abrirFormulario(client)"
        >
          <Pencil />
        </button>
      </div>
    </div>

    <!-- Modal: alta / edición -->
    <div v-if="showForm" class="modal-backdrop" @click.self="showForm = false">
      <section class="booking-modal">
        <button class="modal-close" aria-label="Cerrar" @click="showForm = false"><X /></button>
        <p class="eyebrow">{{ editandoId ? 'MODIFICACIÓN' : 'ALTA' }}</p>
        <h2>{{ editandoId ? 'Editar cliente' : 'Nuevo cliente' }}</h2>
        <p class="muted">Datos de contacto del dueño de las mascotas.</p>

        <form class="modal-form" @submit.prevent="guardar">
          <label>
            Nombre y apellido *
            <input v-model="form.nombre_completo" type="text" maxlength="120" placeholder="Ej: Martín López" />
          </label>

          <div class="fila">
            <label>
              Teléfono *
              <input v-model="form.telefono" type="tel" maxlength="40" placeholder="Ej: 11 4567 8901" />
            </label>
            <label>
              DNI
              <input v-model="form.dni" type="text" maxlength="20" placeholder="Ej: 30.123.456" />
            </label>
          </div>

          <label>
            Correo electrónico
            <input v-model="form.email" type="email" maxlength="120" placeholder="Ej: martin@email.com" />
          </label>

          <label>
            Dirección
            <input v-model="form.direccion" type="text" maxlength="160" placeholder="Ej: Av. Siempreviva 742" />
          </label>

          <p v-if="editandoId" class="modal-note">
            El correo se usa para vincular la cuenta del cliente con su portal.
          </p>

          <p v-if="errorForm" class="modal-error"><TriangleAlert /> {{ errorForm }}</p>

          <div class="modal-actions">
            <button type="button" class="outline-button" @click="showForm = false">Cancelar</button>
            <button type="submit" class="primary-button" :disabled="guardando">
              <Plus /> {{ guardando ? 'Guardando...' : editandoId ? 'Guardar cambios' : 'Registrar cliente' }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </section>
</template>
