<script setup>
import { Activity, ArrowRight, CalendarDays, Check, CheckCheck, Clock, MoreHorizontal, Plus, Stethoscope, Syringe, TriangleAlert, X } from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { supabase } from '@/supabase'
import { useToast } from '@/composables/useToast'
import { traducirError } from '@/utils/errores'
import { isoLocal, primerDiaDelMes, sumarDias } from '@/utils/fechas'

const emit = defineEmits(['navigate'])

const { notify } = useToast()

// Fecha real del día: antes estaba escrita a mano en el HTML.
const fechaLarga = new Intl.DateTimeFormat('es-AR', {
  weekday: 'long',
  day: 'numeric',
  month: 'long',
  year: 'numeric',
})
  .format(new Date())
  .replace(/,/g, '')

const fechaHoy = fechaLarga.toUpperCase()
const fechaDia = fechaLarga.charAt(0).toUpperCase() + fechaLarga.slice(1)

// ---- Datos reales de la tabla `turnos` -----------------------------------
const hoyISO = isoLocal()
const turnos = ref([])        // turnos de la semana en curso
const mascotas = ref([])      // para el formulario de nuevo turno
const servicios = ref([])     // para el formulario de nuevo turno
const vacunasProximas = ref([]) // alertas (si la tabla existe)
const controlesVencidos = ref(0)
const consultasMes = ref(0)
const turnosAyer = ref(0)
const cargando = ref(true)
const vista = ref('lista')    // 'lista' | 'semana'

// ---- Modal de nuevo turno -------------------------------------------------
const showNuevo = ref(false)
const guardando = ref(false)
const errorForm = ref('')
const form = ref({ mascotaId: '', servicioId: '', fecha: hoyISO, hora: '09:00', motivo: '' })

// ---- Menú de acciones por turno -------------------------------------------
const menuAbierto = ref(null)
const turnoEnAccion = ref(null)

const LUNES = (() => {
  const d = new Date()
  const dia = d.getDay() // 0 domingo .. 6 sábado
  const correccion = dia === 0 ? -6 : 1 - dia
  d.setDate(d.getDate() + correccion)
  return isoLocal(d)
})()

const DOMINGO = sumarDias(LUNES, 6)

const turnosHoy = computed(() =>
  turnos.value.filter((t) => t.fecha === hoyISO && t.estado !== 'Cancelado')
)

const pendientesHoy = computed(
  () => turnosHoy.value.filter((t) => t.estado === 'Pendiente').length
)

// Turnos agrupados por día para la vista de semana
const turnosPorDia = computed(() => {
  const mapa = new Map()
  for (const t of [...turnos.value].sort((a, b) => a.hora_inicio.localeCompare(b.hora_inicio))) {
    if (!mapa.has(t.fecha)) mapa.set(t.fecha, [])
    mapa.get(t.fecha).push(t)
  }
  return [...mapa.entries()].map(([fecha, lista]) => ({ fecha, turnos: lista }))
})

function etiquetaDia(iso) {
  if (iso === hoyISO) return 'Hoy'
  const f = new Date(iso + 'T12:00:00')
  return new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', month: 'short' }).format(f)
}

function colorEstado(estado) {
  if (estado === 'Confirmado' || estado === 'Atendido') return 'green'
  if (estado === 'Cancelado') return 'red'
  return 'yellow'
}

// Hora de fin calculada a partir de la duración del servicio elegido
const horaFin = computed(() => {
  const servicio = servicios.value.find((s) => s.id === form.value.servicioId)
  const duracion = servicio?.duracion_minutos || 30
  const [h, m] = form.value.hora.split(':').map(Number)
  const total = h * 60 + m + duracion
  return `${String(Math.floor(total / 60) % 24).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`
})

async function cargar() {
  cargando.value = true
  try {
    const desdeISO = LUNES
    const hastaISO = DOMINGO

    const [turnosRes, mascotasRes, serviciosRes, consultasRes, ayerRes] = await Promise.all([
      supabase
        .from('turnos')
        .select(
          'id, fecha, hora_inicio, hora_fin, estado, motivo, mascota:mascotas(id, nombre, cliente_id, clientes(nombre_completo)), servicio:servicios(id, nombre)'
        )
        .gte('fecha', desdeISO)
        .lte('fecha', hastaISO)
        .order('hora_inicio'),
      supabase.from('mascotas').select('id, nombre, especie, raza, fecha_nacimiento').order('nombre'),
      supabase.from('servicios').select('id, nombre, duracion_minutos').eq('activo', true).order('nombre'),
      supabase
        .from('consultas')
        .select('id', { count: 'exact', head: true })
        .gte('fecha', primerDiaDelMes()),
      supabase
        .from('turnos')
        .select('id', { count: 'exact', head: true })
        .eq('fecha', sumarDias(hoyISO, -1)),
    ])

    if (turnosRes.error) throw turnosRes.error
    turnos.value = turnosRes.data || []
    if (!mascotasRes.error) mascotas.value = mascotasRes.data || []
    if (!serviciosRes.error) servicios.value = serviciosRes.data || []
    if (!consultasRes.error) consultasMes.value = consultasRes.count || 0
    if (!ayerRes.error) turnosAyer.value = ayerRes.count || 0

    // Alertas: la tabla `vacunas` recién se crea en la etapa 8, por eso se
    // tolera su ausencia sin romper toda la pantalla.
    const [vacunasRes, controlesRes] = await Promise.all([
      supabase
        .from('vacunas')
        .select('id, fecha_proxima, nombre, mascota:mascotas(nombre)')
        .not('fecha_proxima', 'is', null)
        .gte('fecha_proxima', hoyISO)
        .order('fecha_proxima')
        .limit(3),
      supabase
        .from('consultas')
        .select('id', { count: 'exact', head: true })
        .not('proximo_control', 'is', null)
        .lte('proximo_control', hoyISO),
    ])
    if (!vacunasRes.error) vacunasProximas.value = vacunasRes.data || []
    if (!controlesRes.error) controlesVencidos.value = controlesRes.count || 0
  } catch (e) {
    notify(traducirError(e.message))
  } finally {
    cargando.value = false
  }
}

function abrirNuevo() {
  errorForm.value = ''
  form.value = { mascotaId: '', servicioId: '', fecha: hoyISO, hora: '09:00', motivo: '' }
  showNuevo.value = true
}

async function guardarTurno() {
  errorForm.value = ''
  if (!form.value.mascotaId) return (errorForm.value = 'Elegí una mascota.')
  if (!form.value.servicioId) return (errorForm.value = 'Elegí un servicio.')
  if (!form.value.fecha) return (errorForm.value = 'Elegí una fecha.')

  guardando.value = true
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc('obtener_mi_veterinaria_id')
    if (errVet) throw errVet
    const { data: { user } } = await supabase.auth.getUser()

    const { error } = await supabase.from('turnos').insert({
      veterinaria_id: veterinariaId,
      mascota_id: form.value.mascotaId,
      servicio_id: form.value.servicioId,
      veterinario_id: user?.id ?? null,
      fecha: form.value.fecha,
      hora_inicio: form.value.hora,
      hora_fin: horaFin.value,
      estado: 'Pendiente',
      motivo: form.value.motivo.trim() || null,
    })
    if (error) throw error

    showNuevo.value = false
    notify('Turno creado correctamente')
    await cargar()
  } catch (e) {
    errorForm.value = traducirError(e.message)
  } finally {
    guardando.value = false
  }
}

function alternarMenu(turno) {
  menuAbierto.value = menuAbierto.value === turno.id ? null : turno.id
}

async function cambiarEstado(turno, estado) {
  turnoEnAccion.value = turno.id
  try {
    const { data, error } = await supabase
      .from('turnos')
      .update({ estado })
      .eq('id', turno.id)
      .select('id')
    if (error) throw error
    if (!data?.length) throw new Error('No tenés permiso para modificar este turno.')
    notify(`Turno ${estado.toLowerCase()}`)
    await cargar()
  } catch (e) {
    notify(traducirError(e.message))
  } finally {
    turnoEnAccion.value = null
    menuAbierto.value = null
  }
}

// Si todavía no hay servicios cargados, crea los tres básicos de una vez.
async function crearServiciosBasicos() {
  guardando.value = true
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc('obtener_mi_veterinaria_id')
    if (errVet) throw errVet
    const { error } = await supabase.from('servicios').insert([
      { veterinaria_id: veterinariaId, nombre: 'Consulta general', descripcion: 'Revisión y seguimiento', duracion_minutos: 30, precio: 0 },
      { veterinaria_id: veterinariaId, nombre: 'Vacunación', descripcion: 'Aplicación de vacunas', duracion_minutos: 20, precio: 0 },
      { veterinaria_id: veterinariaId, nombre: 'Control', descripcion: 'Seguimiento de tratamiento', duracion_minutos: 20, precio: 0 },
    ])
    if (error) throw error
    notify('Servicios básicos creados')
    await cargar()
  } catch (e) {
    notify(traducirError(e.message))
  } finally {
    guardando.value = false
  }
}

function selectAdminView(vista) {
  emit('navigate', vista)
}

onMounted(cargar)
</script>

<template>
  <section class="page-content">
    <div class="page-heading">
      <div>
        <p class="eyebrow">{{ fechaHoy }}</p>
        <h1>Agenda del día</h1>
        <p class="muted">Revisá y organizá los turnos de hoy.</p>
      </div>
      <button class="primary-button" @click="abrirNuevo"><Plus /> Nuevo turno</button>
    </div>

    <div class="metric-row">
      <div class="metric-card">
        <span class="metric-icon pale-green"><CalendarDays /></span>
        <div>
          <strong>{{ turnosHoy.length }}</strong>
          <small>Turnos de hoy</small>
        </div>
        <em :class="{ orange: turnosHoy.length - turnosAyer < 0 }">
          {{ turnosHoy.length - turnosAyer >= 0 ? '+' : '' }}{{ turnosHoy.length - turnosAyer }} vs. ayer
        </em>
      </div>
      <div class="metric-card">
        <span class="metric-icon pale-yellow"><Clock /></span>
        <div>
          <strong>{{ pendientesHoy }}</strong>
          <small>Pendientes</small>
        </div>
        <em class="orange">{{ pendientesHoy ? 'Requieren acción' : 'Todo confirmado' }}</em>
      </div>
      <div class="metric-card">
        <span class="metric-icon pale-blue"><Activity /></span>
        <div>
          <strong>{{ consultasMes }}</strong>
          <small>Consultas este mes</small>
        </div>
        <em>Actualizado</em>
      </div>
    </div>

    <div class="content-grid">
      <section class="panel schedule-panel">
        <div class="panel-header">
          <div>
            <h2>{{ vista === 'lista' ? 'Turnos de hoy' : 'Semana en curso' }}</h2>
            <p class="muted">{{ vista === 'lista' ? fechaDia : `Del ${LUNES.split('-').reverse().slice(0, 2).join('/')} al ${DOMINGO.split('-').reverse().slice(0, 2).join('/')}` }}</p>
          </div>
          <div class="view-toggle">
            <button :class="{ selected: vista === 'lista' }" @click="vista = 'lista'">Lista</button>
            <button :class="{ selected: vista === 'semana' }" @click="vista = 'semana'">Semana</button>
          </div>
        </div>

        <div v-if="cargando" class="empty-state"><p>Cargando agenda...</p></div>

        <div v-else-if="vista === 'lista' && !turnosHoy.length" class="empty-state">
          <span class="empty-icon"><CalendarDays /></span>
          <strong>No hay turnos para hoy</strong>
          <p>Creá el primero con el botón “Nuevo turno”.</p>
        </div>

        <div v-else-if="vista === 'semana' && !turnos.length" class="empty-state">
          <span class="empty-icon"><CalendarDays /></span>
          <strong>Sin turnos esta semana</strong>
          <p>Los turnos que crees van a aparecer acá.</p>
        </div>

        <div v-else-if="vista === 'lista'" class="schedule-list">
          <div
            v-for="appointment in [...turnosHoy].sort((a, b) => a.hora_inicio.localeCompare(b.hora_inicio))"
            :key="appointment.id"
            class="appointment-row"
          >
            <time>{{ appointment.hora_inicio.slice(0, 5) }}</time>
            <div class="appointment-line" :class="colorEstado(appointment.estado)"></div>
            <div class="appointment-info">
              <strong>
                {{ appointment.mascota?.nombre || 'Mascota' }}
                <span>· {{ appointment.servicio?.nombre || 'Sin servicio' }}</span>
              </strong>
              <small>
                {{ appointment.mascota?.clientes?.nombre_completo || 'Sin dueño' }}
                <template v-if="appointment.motivo"> · {{ appointment.motivo }}</template>
              </small>
            </div>
            <span class="status" :class="colorEstado(appointment.estado)">{{ appointment.estado }}</span>
            <button
              class="row-menu"
              :aria-label="'Acciones de ' + (appointment.mascota?.nombre || 'turno')"
              @click.stop="alternarMenu(appointment)"
            >
              <MoreHorizontal />
            </button>
            <div v-if="menuAbierto === appointment.id" class="turno-menu">
              <button
                v-if="appointment.estado === 'Pendiente'"
                :disabled="turnoEnAccion === appointment.id"
                @click="cambiarEstado(appointment, 'Confirmado')"
              >
                <Check /> Confirmar
              </button>
              <button
                v-if="appointment.estado !== 'Atendido' && appointment.estado !== 'Cancelado'"
                :disabled="turnoEnAccion === appointment.id"
                @click="cambiarEstado(appointment, 'Atendido')"
              >
                <CheckCheck /> Marcar atendido
              </button>
              <button
                v-if="appointment.estado !== 'Cancelado'"
                class="rojo"
                :disabled="turnoEnAccion === appointment.id"
                @click="cambiarEstado(appointment, 'Cancelado')"
              >
                <X /> Cancelar turno
              </button>
            </div>
          </div>
        </div>

        <div v-else class="week-days">
          <div v-for="dia in turnosPorDia" :key="dia.fecha" class="week-day">
            <h3 :class="{ hoy: dia.fecha === hoyISO }">{{ etiquetaDia(dia.fecha) }}</h3>
            <div
              v-for="appointment in dia.turnos"
              :key="appointment.id"
              class="appointment-row"
            >
              <time>{{ appointment.hora_inicio.slice(0, 5) }}</time>
              <div class="appointment-line" :class="colorEstado(appointment.estado)"></div>
              <div class="appointment-info">
                <strong>
                  {{ appointment.mascota?.nombre || 'Mascota' }}
                  <span>· {{ appointment.servicio?.nombre || 'Sin servicio' }}</span>
                </strong>
                <small>{{ appointment.mascota?.clientes?.nombre_completo || 'Sin dueño' }}</small>
              </div>
              <span class="status" :class="colorEstado(appointment.estado)">{{ appointment.estado }}</span>
              <span></span>
            </div>
          </div>
        </div>

        <button class="text-button" @click="selectAdminView('consultations')">
          Ver consultas <span><ArrowRight /></span>
        </button>
      </section>

      <aside class="panel alerts-panel">
        <div class="panel-header">
          <div>
            <h2>Para tener en cuenta</h2>
            <p class="muted">Seguimiento de pacientes</p>
          </div>
          <span class="count-badge">{{ vacunasProximas.length + (pendientesHoy ? 1 : 0) + (controlesVencidos ? 1 : 0) }}</span>
        </div>

        <div v-for="vacuna in vacunasProximas" :key="vacuna.id" class="alert-item">
          <span class="alert-icon vaccine"><Syringe /></span>
          <div>
            <strong>Vacuna próxima a vencer</strong>
            <small>{{ vacuna.mascota?.nombre || 'Paciente' }} · {{ vacuna.nombre }}</small>
            <button @click="selectAdminView('pets')">Ver ficha <ArrowRight /></button>
          </div>
        </div>

        <div v-if="pendientesHoy" class="alert-item">
          <span class="alert-icon control"><Clock /></span>
          <div>
            <strong>Turnos pendientes de confirmar</strong>
            <small>{{ pendientesHoy }} {{ pendientesHoy === 1 ? 'turno requiere' : 'turnos requieren' }} acción</small>
            <button @click="vista = 'lista'">Revisar <ArrowRight /></button>
          </div>
        </div>

        <div v-if="controlesVencidos" class="alert-item">
          <span class="alert-icon note"><Stethoscope /></span>
          <div>
            <strong>Controles vencidos</strong>
            <small>{{ controlesVencidos }} {{ controlesVencidos === 1 ? 'control vencido' : 'controles vencidos' }}</small>
            <button @click="selectAdminView('consultations')">Ver consultas <ArrowRight /></button>
          </div>
        </div>

        <div v-if="!vacunasProximas.length && !pendientesHoy && !controlesVencidos" class="empty-state">
          <span class="empty-icon"><Check /></span>
          <strong>Sin novedades</strong>
          <p>No hay alertas pendientes por ahora.</p>
        </div>
      </aside>
    </div>

    <!-- Modal: nuevo turno -->
    <div v-if="showNuevo" class="modal-backdrop" @click.self="showNuevo = false">
      <section class="booking-modal">
        <button class="modal-close" aria-label="Cerrar" @click="showNuevo = false"><X /></button>
        <p class="eyebrow">NUEVO TURNO</p>
        <h2>Reservar un turno</h2>
        <p class="muted">Elegí la mascota, el servicio y el horario.</p>

        <div v-if="!mascotas.length" class="modal-note" style="margin-top: 16px;">
          Todavía no hay mascotas registradas.
          <button class="text-button" style="margin-left: 6px;" @click="showNuevo = false; selectAdminView('pets')">
            Ir a Mascotas <ArrowRight />
          </button>
        </div>

        <div v-else-if="!servicios.length" class="modal-note" style="margin-top: 16px;">
          Todavía no hay servicios cargados.
          <button class="text-button" style="margin-left: 6px;" :disabled="guardando" @click="crearServiciosBasicos">
            Crear servicios básicos
          </button>
        </div>

        <form v-else class="modal-form" @submit.prevent="guardarTurno">
          <label>
            Mascota
            <select v-model="form.mascotaId">
              <option value="" disabled>Elegí una mascota</option>
              <option v-for="m in mascotas" :key="m.id" :value="m.id">
                {{ m.nombre }} · {{ m.especie }}<template v-if="m.raza"> · {{ m.raza }}</template>
              </option>
            </select>
          </label>

          <label>
            Servicio
            <select v-model="form.servicioId">
              <option value="" disabled>Elegí un servicio</option>
              <option v-for="s in servicios" :key="s.id" :value="s.id">
                {{ s.nombre }} ({{ s.duracion_minutos }} min)
              </option>
            </select>
          </label>

          <div class="fila">
            <label>
              Fecha
              <input v-model="form.fecha" type="date" />
            </label>
            <label>
              Hora de inicio
              <input v-model="form.hora" type="time" step="900" />
            </label>
          </div>

          <label>
            Motivo (opcional)
            <input v-model="form.motivo" type="text" maxlength="160" placeholder="Ej: control anual" />
          </label>

          <p v-if="form.servicioId" class="modal-note">
            El turno durará {{ servicios.find((s) => s.id === form.servicioId)?.duracion_minutos || 30 }} minutos
            (de {{ form.hora }} a {{ horaFin }}).
          </p>

          <p v-if="errorForm" class="modal-error"><TriangleAlert /> {{ errorForm }}</p>

          <div class="modal-actions">
            <button type="button" class="outline-button" @click="showNuevo = false">Cancelar</button>
            <button type="submit" class="primary-button" :disabled="guardando">
              <Plus /> {{ guardando ? 'Guardando...' : 'Crear turno' }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </section>
</template>

<style scoped>
.turno-menu {
  position: absolute;
  right: 14px;
  z-index: 3;
  display: grid;
  gap: 3px;
  min-width: 185px;
  padding: 7px;
  border: 1px solid var(--line);
  border-radius: 9px;
  background: #fff;
  box-shadow: 0 12px 30px #143b2725;
}
.turno-menu button {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 9px;
  border-radius: 6px;
  color: var(--ink);
  font-size: 11px;
  font-weight: 700;
  text-align: left;
}
.turno-menu button:hover:not(:disabled) { background: #eff8e9; }
.turno-menu button.rojo { color: #ae5757; }
.turno-menu button.rojo:hover:not(:disabled) { background: #fbeaea; }
.turno-menu button:disabled { opacity: .5; cursor: default; }
.appointment-row { position: relative; }

.week-days { display: grid; gap: 16px; margin: 18px 0 9px; }
.week-day h3 {
  padding: 7px 11px;
  border-radius: 7px;
  color: var(--muted);
  background: #f8faf7;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: .7px;
  text-transform: uppercase;
}
.week-day h3.hoy { color: var(--green-dark); background: #eff8e9; }
.week-day .appointment-row:first-of-type { border-top: 0; }
</style>
