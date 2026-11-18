<script setup>
import { ArrowLeft, ArrowRight, CalendarDays, Check, Clock, Hand, Home, Info, LogOut, Menu, PawPrint, Plus, Search, Stethoscope, Syringe, TriangleAlert, X } from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/supabase'
import { useUsuario } from '@/composables/useUsuario'
import { useToast } from '@/composables/useToast'
import { traducirError } from '@/utils/errores'
import { isoLocal } from '@/utils/fechas'

const router = useRouter()
const { email: usuarioEmail, inicial: usuarioInicial, cerrarSesion: salir } = useUsuario()
const { notify } = useToast()

const clientView = ref('home')
const showBooking = ref(false)
const bookingStep = ref(1)
const menuMovil = ref(false)

// ---- Datos reales ----------------------------------------------------------
const clienteId = ref(null)
const mascotas = ref([])
const turnos = ref([])
const servicios = ref([])
const consultasMascota = ref([]) // consultas de la mascota abierta
const vacunasMascota = ref([])   // vacunas de la mascota abierta
const cargando = ref(true)
const vinculando = ref(false)
const errorPortal = ref('')

const selectedPetId = ref('')

// ---- Reserva ---------------------------------------------------------------
const guardando = ref(false)
const errorReserva = ref('')
const reserva = ref({ mascotaId: '', servicioId: '', fecha: '', hora: '09:00' })

const hoyISO = isoLocal()

const HORARIOS = ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30', '12:00', '15:00', '15:30', '16:00', '16:30', '17:00']

const selectedPet = computed(() => mascotas.value.find((m) => m.id === selectedPetId.value) || null)

const proximoTurno = computed(() => {
  const futuros = turnos.value
    .filter((t) => t.fecha >= hoyISO && t.estado !== 'Cancelado')
    .sort((a, b) => (a.fecha + a.hora_inicio).localeCompare(b.fecha + b.hora_inicio))
  return futuros[0] || null
})

const turnosFuturos = computed(() =>
  turnos.value
    .filter((t) => t.fecha >= hoyISO && t.estado !== 'Cancelado')
    .sort((a, b) => (a.fecha + a.hora_inicio).localeCompare(b.fecha + b.hora_inicio))
)

const turnosPasados = computed(() =>
  turnos.value
    .filter((t) => t.fecha < hoyISO || t.estado === 'Cancelado')
    .sort((a, b) => (b.fecha + b.hora_inicio).localeCompare(a.fecha + a.hora_inicio))
)

function iniciales(nombre = '?') {
  return nombre
    .split(' ')
    .map((n) => n[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()
}

function edadDe(fechaNacimiento) {
  if (!fechaNacimiento) return ''
  const nacimiento = new Date(fechaNacimiento + 'T12:00:00')
  const anios = Math.floor((Date.now() - nacimiento.getTime()) / (365.25 * 24 * 3600 * 1000))
  if (anios < 1) {
    const meses = Math.max(1, Math.floor((Date.now() - nacimiento.getTime()) / (30 * 24 * 3600 * 1000)))
    return `${meses} ${meses === 1 ? 'mes' : 'meses'}`
  }
  return `${anios} ${anios === 1 ? 'año' : 'años'}`
}

function colorEstado(estado) {
  if (estado === 'Confirmado' || estado === 'Atendido') return 'green'
  if (estado === 'Cancelado') return 'red'
  return 'yellow'
}

function fechaLarga(iso) {
  if (!iso) return ''
  return new Intl.DateTimeFormat('es-AR', { day: 'numeric', month: 'long', year: 'numeric' }).format(
    new Date(iso + 'T12:00:00')
  )
}

function mesCorto(iso) {
  if (!iso) return ''
  return new Intl.DateTimeFormat('es-AR', { month: 'short' })
    .format(new Date(iso + 'T12:00:00'))
    .replace('.', '')
    .toUpperCase()
}

// Hora de fin según la duración del servicio
const horaFinReserva = computed(() => {
  const servicio = servicios.value.find((s) => s.id === reserva.value.servicioId)
  const duracion = servicio?.duracion_minutos || 30
  const [h, m] = reserva.value.hora.split(':').map(Number)
  const total = h * 60 + m + duracion
  return `${String(Math.floor(total / 60) % 24).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`
})

async function cargar() {
  cargando.value = true
  errorPortal.value = ''
  try {
    // 1) Resolver el cliente vinculado a esta cuenta. Primero se intenta la
    //    función que además vincula; si no existe todavía en la base, se
    //    consulta por el id y, en último caso, se muestra un mensaje claro.
    let id = null
    const { data: rpcVincular, error: errVincular } = await supabase.rpc('vincular_mi_cliente')
    if (!errVincular) {
      id = rpcVincular
    } else {
      const { data: rpcObtener, error: errObtener } = await supabase.rpc('obtener_mi_cliente_id')
      if (!errObtener) id = rpcObtener
    }

    if (!id) {
      const { data: { user } } = await supabase.auth.getUser()
      const { data: fila, error: errFila } = await supabase
        .from('clientes')
        .select('id')
        .eq('email', user?.email || '')
        .limit(1)
        .maybeSingle()
      if (!errFila) id = fila?.id ?? null
    }

    clienteId.value = id

    if (!id) {
      mascotas.value = []
      turnos.value = []
      return
    }

    // 2) Mascotas del dueño y servicios activos
    const [mascotasRes, serviciosRes] = await Promise.all([
      supabase
        .from('mascotas')
        .select('id, nombre, especie, raza, fecha_nacimiento, peso_kg, alergias, observaciones')
        .eq('cliente_id', id)
        .order('nombre'),
      supabase.from('servicios').select('id, nombre, descripcion, duracion_minutos').eq('activo', true).order('nombre'),
    ])
    if (mascotasRes.error) throw mascotasRes.error
    mascotas.value = mascotasRes.data || []
    if (!serviciosRes.error) servicios.value = serviciosRes.data || []

    // 3) Turnos de esas mascotas
    if (mascotas.value.length) {
      const ids = mascotas.value.map((m) => m.id)
      const { data, error } = await supabase
        .from('turnos')
        .select('id, fecha, hora_inicio, hora_fin, estado, motivo, mascota_id, servicio:servicios(nombre, duracion_minutos), mascotas(nombre)')
        .in('mascota_id', ids)
        .order('fecha', { ascending: false })
        .limit(50)
      if (!error) turnos.value = data || []
    } else {
      turnos.value = []
    }
  } catch (e) {
    errorPortal.value = traducirError(e.message)
  } finally {
    cargando.value = false
  }
}

// Vincula la cuenta con la ficha del cliente (botón del estado vacío)
async function vincularCuenta() {
  vinculando.value = true
  try {
    const { data, error } = await supabase.rpc('vincular_mi_cliente')
    if (error) throw error
    if (!data) {
      notify('No encontramos un cliente con tu correo. Pedí el alta en tu veterinaria.')
      return
    }
    notify('Cuenta vinculada correctamente')
    await cargar()
  } catch (e) {
    notify(traducirError(e.message))
  } finally {
    vinculando.value = false
  }
}

function verFicha(pet) {
  selectedPetId.value = pet.id
  clientView.value = 'pet-history'
  cargarHistorial(pet.id)
}

async function cargarHistorial(mascotaId) {
  consultasMascota.value = []
  vacunasMascota.value = []
  const [consultasRes, vacunasRes] = await Promise.all([
    supabase
      .from('consultas')
      .select('id, fecha, motivo, diagnostico, tratamiento, proximo_control')
      .eq('mascota_id', mascotaId)
      .order('fecha', { ascending: false })
      .limit(10),
    supabase
      .from('vacunas')
      .select('id, nombre, dosis, fecha_aplicacion, fecha_proxima')
      .eq('mascota_id', mascotaId)
      .order('fecha_aplicacion', { ascending: false })
      .limit(10),
  ])
  if (!consultasRes.error) consultasMascota.value = consultasRes.data || []
  if (!vacunasRes.error) vacunasMascota.value = vacunasRes.data || []
}

function openBooking(pet = null) {
  errorReserva.value = ''
  reserva.value = {
    mascotaId: pet?.id || selectedPetId.value || mascotas.value[0]?.id || '',
    servicioId: servicios.value[0]?.id || '',
    fecha: hoyISO,
    hora: '09:00',
  }
  bookingStep.value = 1
  showBooking.value = true
}

function nextBookingStep() {
  errorReserva.value = ''
  if (bookingStep.value === 1 && !reserva.value.servicioId) {
    errorReserva.value = 'Elegí un servicio.'
    return
  }
  if (bookingStep.value === 2) {
    if (!reserva.value.mascotaId) {
      errorReserva.value = 'Elegí tu mascota.'
      return
    }
    if (!reserva.value.fecha) {
      errorReserva.value = 'Elegí una fecha.'
      return
    }
  }
  if (bookingStep.value < 3) {
    bookingStep.value += 1
    return
  }
  guardarReserva()
}

async function guardarReserva() {
  guardando.value = true
  errorReserva.value = ''
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc('obtener_mi_veterinaria_id')
    if (errVet) throw errVet

    const { error } = await supabase.from('turnos').insert({
      veterinaria_id: veterinariaId,
      mascota_id: reserva.value.mascotaId,
      servicio_id: reserva.value.servicioId,
      fecha: reserva.value.fecha,
      hora_inicio: reserva.value.hora,
      hora_fin: horaFinReserva.value,
      estado: 'Pendiente',
    })
    if (error) throw error

    showBooking.value = false
    clientView.value = 'appointments'
    notify('Turno solicitado correctamente')
    await cargar()
  } catch (e) {
    // Se vuelve al paso 2 para elegir otro horario si hay conflicto
    bookingStep.value = 2
    errorReserva.value = traducirError(e.message)
  } finally {
    guardando.value = false
  }
}

async function cancelarTurno(turno) {
  if (!window.confirm('¿Querés cancelar este turno?')) return
  try {
    const { data, error } = await supabase
      .from('turnos')
      .update({ estado: 'Cancelado' })
      .eq('id', turno.id)
      .select('id')
    if (error) throw error
    if (!data?.length) throw new Error('No tenés permiso para cancelar este turno.')
    notify('Turno cancelado')
    await cargar()
  } catch (e) {
    notify(traducirError(e.message))
  }
}

async function cerrarSesion() {
  try {
    await salir()
  } finally {
    router.push('/login')
  }
}

onMounted(cargar)
</script>

<template>
  <div class="client-layout">
    <aside class="client-rail">
      <button class="brand client-brand">
        <span class="brand-mark"><Plus /></span>
        <span><strong>Vet</strong><b>Control</b></span>
      </button>
      <div class="client-profile">
        <div class="avatar">{{ usuarioInicial }}</div>
        <div>
          <strong>{{ usuarioEmail || 'Usuario' }}</strong>
          <small>Cuenta personal</small>
        </div>
      </div>
      <nav>
        <button :class="{ active: clientView === 'home' }" @click="clientView = 'home'">
          <Home /> <span>Inicio</span>
        </button>
        <button :class="{ active: clientView === 'pet-history' }" @click="clientView = 'pet-history'">
          <PawPrint /> <span>Mis mascotas</span>
        </button>
        <button :class="{ active: clientView === 'appointments' }" @click="clientView = 'appointments'">
          <CalendarDays /> <span>Mis turnos</span>
        </button>
      </nav>
      <button class="logout" @click="cerrarSesion()"><LogOut /> <span>Cerrar sesión</span></button>
    </aside>

    <main class="client-main">
      <div class="client-mobile-header">
        <button class="brand">
          <span class="brand-mark"><Plus /></span>
          <span><strong>Vet</strong><b>Control</b></span>
        </button>
        <button aria-label="Menú" @click="menuMovil = true"><Menu /></button>
      </div>

      <!-- Cajón de navegación en pantallas chicas -->
      <div v-if="menuMovil" class="drawer-backdrop" @click.self="menuMovil = false">
        <aside class="client-rail drawer">
          <button class="drawer-close" aria-label="Cerrar menú" @click="menuMovil = false"><X /></button>
          <div class="client-profile">
            <div class="avatar">{{ usuarioInicial }}</div>
            <div>
              <strong>{{ usuarioEmail || 'Usuario' }}</strong>
              <small>Cuenta personal</small>
            </div>
          </div>
          <nav>
            <button :class="{ active: clientView === 'home' }" @click="clientView = 'home'; menuMovil = false">
              <Home /> <span>Inicio</span>
            </button>
            <button :class="{ active: clientView === 'pet-history' }" @click="clientView = 'pet-history'; menuMovil = false">
              <PawPrint /> <span>Mis mascotas</span>
            </button>
            <button :class="{ active: clientView === 'appointments' }" @click="clientView = 'appointments'; menuMovil = false">
              <CalendarDays /> <span>Mis turnos</span>
            </button>
          </nav>
          <button class="logout" @click="cerrarSesion()"><LogOut /> <span>Cerrar sesión</span></button>
        </aside>
      </div>

      <!-- Estado: cargando -->
      <section v-if="cargando" class="client-page">
        <div class="empty-state"><p>Cargando tu portal...</p></div>
      </section>

      <!-- Estado: cuenta sin vincular a una ficha de cliente -->
      <section v-else-if="!clienteId" class="client-page">
        <div class="welcome-banner">
          <div>
            <p class="eyebrow">PORTAL DEL CLIENTE</p>
            <h1>Hola <span><Hand /></span></h1>
            <p>Todo el cuidado de tus mascotas, en un solo lugar.</p>
          </div>
          <span class="banner-mark"><Plus /></span>
        </div>
        <div class="panel empty-state">
          <span class="empty-icon"><Info /></span>
          <strong>Tu cuenta todavía no está vinculada a una ficha</strong>
          <p>
            Si ya sos cliente de una veterinaria, vinculá tu cuenta para ver tus mascotas y turnos.
            Si no, pedile el alta a tu veterinaria.
          </p>
          <button class="primary-button" style="margin-top: 12px;" :disabled="vinculando" @click="vincularCuenta">
            <Check /> {{ vinculando ? 'Vinculando...' : 'Vincular mi cuenta' }}
          </button>
        </div>
      </section>

      <!-- Inicio -->
      <section v-else-if="clientView === 'home'" class="client-page">
        <div class="welcome-banner">
          <div>
            <p class="eyebrow">PORTAL DEL CLIENTE</p>
            <h1>Hola <span><Hand /></span></h1>
            <p>Todo el cuidado de tus mascotas, en un solo lugar.</p>
          </div>
          <span class="banner-mark"><Plus /></span>
        </div>

        <div class="page-heading client-heading">
          <div>
            <h2>Mis mascotas</h2>
            <p class="muted">Elegí una mascota para consultar su historia.</p>
          </div>
        </div>

        <div v-if="!mascotas.length" class="panel empty-state">
          <span class="empty-icon"><PawPrint /></span>
          <strong>No tenés mascotas registradas</strong>
          <p>Pedile a tu veterinaria que cargue tus mascotas para verlas acá.</p>
        </div>

        <div v-else class="pet-cards">
          <button
            v-for="pet in mascotas"
            :key="pet.id"
            class="pet-card"
            @click="verFicha(pet)"
          >
            <span class="large-pet-avatar lime">{{ iniciales(pet.nombre) }}</span>
            <span>
              <strong>{{ pet.nombre }}</strong>
              <small>
                {{ pet.especie }}<template v-if="pet.raza"> · {{ pet.raza }}</template>
                <template v-if="pet.fecha_nacimiento"> · {{ edadDe(pet.fecha_nacimiento) }}</template>
              </small>
              <em><Clock /> Ver ficha completa</em>
            </span>
            <b><ArrowRight /></b>
          </button>
        </div>

        <div class="client-columns">
          <div>
            <div class="section-title">
              <h2>Próximo turno</h2>
              <button class="text-button" @click="clientView = 'appointments'">
                Ver todos <ArrowRight />
              </button>
            </div>

            <div v-if="proximoTurno" class="panel next-appointment">
              <div class="date-block">
                <strong>{{ proximoTurno.fecha.slice(8, 10) }}</strong>
                <small>{{ mesCorto(proximoTurno.fecha) }}</small>
              </div>
              <div>
                <strong>{{ proximoTurno.servicio?.nombre || 'Turno' }}</strong>
                <p>
                  {{ proximoTurno.mascotas?.nombre || 'Tu mascota' }} · {{ fechaLarga(proximoTurno.fecha) }}
                  a las {{ proximoTurno.hora_inicio.slice(0, 5) }}
                </p>
                <span class="status" :class="colorEstado(proximoTurno.estado)">{{ proximoTurno.estado }}</span>
              </div>
              <button
                v-if="proximoTurno.estado === 'Pendiente' || proximoTurno.estado === 'Confirmado'"
                class="row-menu"
                aria-label="Cancelar turno"
                @click="cancelarTurno(proximoTurno)"
              >
                <X />
              </button>
            </div>

            <div v-else class="panel empty-state">
              <p>No tenés turnos próximos.</p>
              <button class="text-button" style="margin-top: 6px;" @click="openBooking()">
                Reservar uno <ArrowRight />
              </button>
            </div>
          </div>

          <div>
            <div class="section-title"><h2>Acciones rápidas</h2></div>
            <div class="quick-actions">
              <button @click="openBooking()">
                <span><Plus /></span>
                <strong>Reservar turno</strong>
                <small>Elegí día y horario</small>
              </button>
              <button @click="mascotas.length ? verFicha(mascotas[0]) : notify('Todavía no tenés mascotas cargadas')">
                <span><Search /></span>
                <strong>Ver historial</strong>
                <small>Consultas y vacunas</small>
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Ficha de la mascota -->
      <section v-else-if="clientView === 'pet-history'" class="client-page">
        <button class="back-link" @click="clientView = 'home'">
          <ArrowLeft /> Volver a mis mascotas
        </button>

        <div v-if="selectedPet" class="pet-profile-header">
          <span class="large-pet-avatar lime">{{ iniciales(selectedPet.nombre) }}</span>
          <div>
            <p class="eyebrow">FICHA DE MASCOTA</p>
            <h1>{{ selectedPet.nombre }}</h1>
            <p class="muted">
              {{ selectedPet.especie }}<template v-if="selectedPet.raza"> · {{ selectedPet.raza }}</template>
              <template v-if="selectedPet.fecha_nacimiento"> · {{ edadDe(selectedPet.fecha_nacimiento) }}</template>
              <template v-if="selectedPet.peso_kg"> · {{ selectedPet.peso_kg }} kg</template>
            </p>
          </div>
          <button class="primary-button" @click="openBooking(selectedPet)">
            <Plus /> Reservar turno
          </button>
        </div>

        <div v-else class="panel empty-state">
          <span class="empty-icon"><PawPrint /></span>
          <strong>Elegí una mascota</strong>
          <p>Volvé a “Mis mascotas” y seleccioná el paciente que querés ver.</p>
        </div>

        <template v-if="selectedPet">
          <div v-if="selectedPet.alergias" class="modal-error" style="background: #fff4d3; color: #ad7615; margin-bottom: 14px;">
            <TriangleAlert /> Alergias: {{ selectedPet.alergias }}
          </div>
          <p v-if="selectedPet.observaciones" class="modal-note" style="margin-bottom: 14px;">
            {{ selectedPet.observaciones }}
          </p>

          <div class="history-grid">
            <div class="panel">
              <div class="panel-header">
                <h2>Vacunas</h2>
                <span class="count-badge">{{ vacunasMascota.length }}</span>
              </div>
              <div v-if="!vacunasMascota.length" class="empty-state">
                <p>Sin vacunas cargadas.</p>
              </div>
              <div v-for="v in vacunasMascota" :key="v.id" class="timeline-item" :class="{ pending: v.fecha_proxima && v.fecha_proxima < hoyISO }">
                <span><Syringe /></span>
                <div>
                  <strong>{{ v.nombre }}</strong>
                  <p>Aplicada {{ fechaLarga(v.fecha_aplicacion) }}</p>
                  <b v-if="v.fecha_proxima">Próxima: {{ fechaLarga(v.fecha_proxima) }}</b>
                </div>
              </div>
            </div>

            <div class="panel">
              <div class="panel-header">
                <h2>Últimas consultas</h2>
                <span class="count-badge">{{ consultasMascota.length }}</span>
              </div>
              <div v-if="!consultasMascota.length" class="empty-state">
                <p>Sin consultas registradas.</p>
              </div>
              <div v-for="c in consultasMascota" :key="c.id" class="timeline-item">
                <span><Stethoscope /></span>
                <div>
                  <strong>{{ c.motivo }}</strong>
                  <p>{{ fechaLarga(c.fecha) }}</p>
                  <b class="ok">{{ c.diagnostico }}</b>
                </div>
              </div>
            </div>
          </div>
        </template>
      </section>

      <!-- Mis turnos -->
      <section v-else class="client-page">
        <div class="page-heading">
          <div>
            <p class="eyebrow">RESERVAS</p>
            <h1>Mis turnos</h1>
            <p class="muted">Consultá tus turnos próximos y anteriores.</p>
          </div>
          <button class="primary-button" @click="openBooking()"><Plus /> Reservar turno</button>
        </div>

        <div v-if="!turnos.length" class="panel empty-state">
          <span class="empty-icon"><CalendarDays /></span>
          <strong>No tenés turnos</strong>
          <p>Reservá tu primer turno con el botón de arriba.</p>
        </div>

        <template v-else>
          <div v-if="turnosFuturos.length" class="panel booking-list">
            <div v-for="turno in turnosFuturos" :key="turno.id" class="booking-item">
              <div class="date-block">
                <strong>{{ turno.fecha.slice(8, 10) }}</strong>
                <small>{{ mesCorto(turno.fecha) }}</small>
              </div>
              <div>
                <strong>{{ turno.servicio?.nombre || 'Turno' }}</strong>
                <p>
                  {{ turno.mascotas?.nombre || 'Tu mascota' }} · {{ turno.hora_inicio.slice(0, 5) }}
                  <template v-if="turno.motivo"> · {{ turno.motivo }}</template>
                </p>
              </div>
              <span class="status" :class="colorEstado(turno.estado)">{{ turno.estado }}</span>
              <button
                v-if="turno.estado === 'Pendiente' || turno.estado === 'Confirmado'"
                class="row-menu"
                :aria-label="'Cancelar turno del ' + turno.fecha"
                @click="cancelarTurno(turno)"
              >
                <X />
              </button>
            </div>
          </div>

          <div v-if="turnosPasados.length" style="margin-top: 22px;">
            <div class="section-title"><h2>Anteriores</h2></div>
            <div class="panel booking-list" style="margin-top: 10px;">
              <div v-for="turno in turnosPasados" :key="turno.id" class="booking-item" style="opacity: .72;">
                <div class="date-block">
                  <strong>{{ turno.fecha.slice(8, 10) }}</strong>
                  <small>{{ mesCorto(turno.fecha) }}</small>
                </div>
                <div>
                  <strong>{{ turno.servicio?.nombre || 'Turno' }}</strong>
                  <p>{{ turno.mascotas?.nombre || 'Tu mascota' }} · {{ turno.hora_inicio.slice(0, 5) }}</p>
                </div>
                <span class="status" :class="colorEstado(turno.estado)">{{ turno.estado }}</span>
                <span></span>
              </div>
            </div>
          </div>
        </template>
      </section>
    </main>

    <!-- Modal de reserva en 3 pasos -->
    <div v-if="showBooking" class="modal-backdrop" @click.self="showBooking = false">
      <section class="booking-modal">
        <button class="modal-close" aria-label="Cerrar" @click="showBooking = false"><X /></button>
        <div class="modal-progress">
          <span :class="{ done: bookingStep >= 1, active: bookingStep === 1 }">1</span><i></i>
          <span :class="{ done: bookingStep >= 2, active: bookingStep === 2 }">2</span><i></i>
          <span :class="{ done: bookingStep >= 3, active: bookingStep === 3 }">3</span>
        </div>
        <p class="eyebrow">RESERVAR TURNO</p>
        <h2>
          {{ bookingStep === 1 ? '¿Qué necesitás para tu mascota?' : bookingStep === 2 ? 'Elegí fecha y horario' : 'Revisá tu solicitud' }}
        </h2>
        <p class="muted">Paso {{ bookingStep }} de 3</p>

        <div v-if="bookingStep === 1" class="service-options">
          <div v-if="!servicios.length" class="modal-note">
            Todavía no hay servicios disponibles para reservar.
          </div>
          <button
            v-for="s in servicios"
            :key="s.id"
            class="service-option"
            :class="{ selected: reserva.servicioId === s.id }"
            @click="reserva.servicioId = s.id"
          >
            <span>
              <Syringe v-if="(s.nombre || '').toLowerCase().includes('vacun')" />
              <Clock v-else-if="(s.nombre || '').toLowerCase().includes('control')" />
              <Stethoscope v-else />
            </span>
            <span>
              <strong>{{ s.nombre }}</strong>
              <small>{{ s.descripcion || `${s.duracion_minutos} minutos` }}</small>
            </span>
            <b v-if="reserva.servicioId === s.id"><Check /></b>
          </button>
        </div>

        <div v-else-if="bookingStep === 2" class="date-picker">
          <label>
            Mascota
            <select v-model="reserva.mascotaId">
              <option value="" disabled>Elegí tu mascota</option>
              <option v-for="m in mascotas" :key="m.id" :value="m.id">{{ m.nombre }}</option>
            </select>
          </label>
          <label>
            Fecha
            <input v-model="reserva.fecha" type="date" :min="hoyISO" />
          </label>
          <div class="time-label">Horarios disponibles</div>
          <div class="time-options">
            <button
              v-for="time in HORARIOS"
              :key="time"
              :class="{ selected: reserva.hora === time }"
              @click="reserva.hora = time"
            >
              {{ time }}
            </button>
          </div>
          <div class="conflict-note">
            <Info /> Te confirmaremos el turno por correo. Si el horario está ocupado te avisamos al continuar.
          </div>
        </div>

        <div v-else class="request-summary">
          <div>
            <span>Mascota</span>
            <strong>{{ mascotas.find((m) => m.id === reserva.mascotaId)?.nombre || '—' }}</strong>
          </div>
          <div>
            <span>Servicio</span>
            <strong>{{ servicios.find((s) => s.id === reserva.servicioId)?.nombre || '—' }}</strong>
          </div>
          <div>
            <span>Fecha y hora</span>
            <strong>{{ fechaLarga(reserva.fecha) }} · {{ reserva.hora }} — {{ horaFinReserva }}</strong>
          </div>
          <div class="success-note">
            <Check /> Vas a recibir la confirmación por correo.
          </div>
        </div>

        <p v-if="errorReserva" class="modal-error" style="margin-top: 14px;">
          <TriangleAlert /> {{ errorReserva }}
        </p>

        <div class="modal-actions">
          <button class="outline-button" @click="bookingStep > 1 ? bookingStep-- : (showBooking = false)">
            {{ bookingStep > 1 ? 'Atrás' : 'Cancelar' }}
          </button>
          <button class="primary-button" :disabled="guardando" @click="nextBookingStep">
            {{ bookingStep === 3 ? (guardando ? 'Enviando...' : 'Solicitar turno') : 'Continuar' }}
            <ArrowRight />
          </button>
        </div>
      </section>
    </div>
  </div>
</template>
