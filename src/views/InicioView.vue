<script setup>
import { computed, ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/supabase'

const router = useRouter()

const mode = ref('admin')
const adminView = ref('agenda')
const clientView = ref('home')
const selectedPet = ref('Luna')
const showBooking = ref(false)
const bookingStep = ref(1)
const bookingDate = ref('Mañana, 18 de junio')
const bookingTime = ref('10:30')
const toast = ref('')

const usuarioEmail = ref('')
const usuarioInicial = computed(() => {
  if (!usuarioEmail.value) return 'U'
  return usuarioEmail.value.charAt(0).toUpperCase()
})

onMounted(async () => {
  const { data: { user } } = await supabase.auth.getUser()
  if (user) {
    usuarioEmail.value = user.email
  }
})

async function cerrarSesion() {
  await supabase.auth.signOut()
  router.push('/login')
}

const navItems = [
  { id: 'agenda', label: 'Agenda', icon: '▦' },
  { id: 'clients', label: 'Clientes', icon: '♙' },
  { id: 'pets', label: 'Mascotas', icon: '♡' },
  { id: 'consultations', label: 'Consultas', icon: '＋' },
  { id: 'productos', label: 'Productos', icon: '🏷' },
  { id: 'settings', label: 'Configuración', icon: '⚙' },
]

const appointments = [
  { time: '09:00', pet: 'Milo', owner: 'Sofía Ramos', type: 'Consulta general', status: 'Confirmado', color: 'green' },
  { time: '10:30', pet: 'Luna', owner: 'Martín López', type: 'Vacunación', status: 'Pendiente', color: 'yellow' },
  { time: '12:00', pet: 'Rocky', owner: 'Ana Torres', type: 'Control', status: 'Confirmado', color: 'green' },
  { time: '15:30', pet: 'Nala', owner: 'Pablo Ruiz', type: 'Consulta general', status: 'Cancelado', color: 'red' },
]

const pets = [
  { name: 'Luna', species: 'Perra · Golden retriever', owner: 'Martín López', age: '4 años', initials: 'L' },
  { name: 'Milo', species: 'Gato · Mestizo', owner: 'Sofía Ramos', age: '2 años', initials: 'M' },
  { name: 'Rocky', species: 'Perro · Beagle', owner: 'Ana Torres', age: '6 años', initials: 'R' },
]

const pageTitle = computed(() => ({
  agenda: 'Agenda del día', clients: 'Clientes', pets: 'Mascotas', consultations: 'Consultas', settings: 'Configuración',
}[adminView.value] || 'Agenda del día'))

function selectAdminView(view) {
  if (view === 'productos') {
    router.push('/productos')
    return
  }
  adminView.value = view
  if (view === 'agenda') window.scrollTo({ top: 0, behavior: 'smooth' })
}

function notify(message) {
  toast.value = message
  window.setTimeout(() => { toast.value = '' }, 2600)
}

function openBooking() {
  showBooking.value = true
  bookingStep.value = 1
}

function nextBookingStep() {
  if (bookingStep.value < 3) bookingStep.value += 1
  else {
    showBooking.value = false
    clientView.value = 'confirmed'
    notify('Turno solicitado correctamente')
  }
}
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <button class="brand" aria-label="Ir al inicio" @click="mode = 'admin'; selectAdminView('agenda')">
        <span class="brand-mark">✚</span>
        <span><strong>Vet</strong><b>Control</b><small>Gestión veterinaria simple</small></span>
      </button>
      <div class="mode-switch" aria-label="Cambiar flujo">
        <button :class="{ active: mode === 'admin' }" @click="mode = 'admin'">Panel veterinaria</button>
        <button :class="{ active: mode === 'client' }" @click="mode = 'client'; clientView = 'home'">Portal cliente</button>
      </div>
      <div class="top-actions">
        <button class="icon-button" aria-label="Notificaciones">♢<i></i></button>
        <div class="avatar">{{ usuarioInicial }}</div>
        <span class="user-name">{{ usuarioEmail || 'Usuario' }} <small>Administrador/a</small></span>
      </div>
    </header>

    <div v-if="mode === 'admin'" class="admin-layout">
      <aside class="sidebar">
        <p class="eyebrow">MENÚ PRINCIPAL</p>
        <nav>
          <button v-for="item in navItems" :key="item.label" :class="{ active: item.id === adminView || (item.id === 'agenda' && adminView === 'agenda') }" @click="selectAdminView(item.id)"><span>{{ item.icon }}</span>{{ item.label }}</button>
        </nav>
        <div class="sidebar-help"><span class="help-icon">?</span><strong>¿Necesitás ayuda?</strong><small>Estamos para acompañarte</small><button @click="notify('Centro de ayuda próximamente')">Ver centro de ayuda</button></div>
        <button class="logout" @click="cerrarSesion()">↪ <span>Cerrar sesión</span></button>
      </aside>

      <main class="content-area">
        <div class="mobile-page-nav"><button>☰</button><span>VetControl</span><button>♙</button></div>
        <section v-if="adminView === 'agenda'" class="page-content">
          <div class="page-heading"><div><p class="eyebrow">MIÉRCOLES 18 DE JUNIO, 2025</p><h1>Agenda del día</h1><p class="muted">Revisá y organizá los turnos de hoy.</p></div><button class="primary-button" @click="notify('Nuevo turno listo para completar')">＋ Nuevo turno</button></div>
          <div class="metric-row"><div class="metric-card"><span class="metric-icon pale-green">▦</span><div><strong>8</strong><small>Turnos de hoy</small></div><em>+2 vs. ayer</em></div><div class="metric-card"><span class="metric-icon pale-yellow">◷</span><div><strong>3</strong><small>Pendientes</small></div><em class="orange">Requieren acción</em></div><div class="metric-card"><span class="metric-icon pale-blue">♧</span><div><strong>12</strong><small>Consultas este mes</small></div><em>+8% este mes</em></div></div>
          <div class="content-grid"><section class="panel schedule-panel"><div class="panel-header"><div><h2>Turnos de hoy</h2><p class="muted">Miércoles 18 de junio</p></div><div class="view-toggle"><button class="selected">Lista</button><button>Semana</button></div></div><div class="schedule-list"><div v-for="appointment in appointments" :key="appointment.time" class="appointment-row"><time>{{ appointment.time }}</time><div class="appointment-line" :class="appointment.color"></div><div class="appointment-info"><strong>{{ appointment.pet }} <span>· {{ appointment.type }}</span></strong><small>{{ appointment.owner }}</small></div><span class="status" :class="appointment.color">{{ appointment.status }}</span><button class="row-menu" @click="notify('Opciones de ' + appointment.pet)">•••</button></div></div><button class="text-button" @click="selectAdminView('consultations')">Ver todos los turnos <span>→</span></button></section><aside class="panel alerts-panel"><div class="panel-header"><div><h2>Para tener en cuenta</h2><p class="muted">Seguimiento de pacientes</p></div><span class="count-badge">3</span></div><div class="alert-item"><span class="alert-icon vaccine">✚</span><div><strong>Vacunas próximas a vencer</strong><small>Luna · Séxtuple · en 12 días</small><button @click="selectAdminView('pets')">Ver ficha →</button></div></div><div class="alert-item"><span class="alert-icon control">◷</span><div><strong>Controles pendientes</strong><small>2 mascotas requieren seguimiento</small><button @click="selectAdminView('pets')">Revisar →</button></div></div><div class="alert-item"><span class="alert-icon note">⌕</span><div><strong>Consulta sin completar</strong><small>Rocky · 12:00 de hoy</small><button @click="selectAdminView('consultations')">Completar →</button></div></div></aside></div>
        </section>

        <section v-else-if="adminView === 'pets'" class="page-content"><div class="page-heading"><div><p class="eyebrow">REGISTRO DE PACIENTES</p><h1>Mascotas</h1><p class="muted">Accedé rápido a la ficha médica de cada paciente.</p></div><button class="primary-button" @click="notify('Formulario de nueva mascota')">＋ Agregar mascota</button></div><div class="toolbar"><label class="search"><span>⌕</span><input placeholder="Buscar por nombre o dueño" /></label><button class="filter-button">Filtrar <span>⌄</span></button></div><div class="pet-table panel"><div class="table-header"><span>MASCOTA</span><span>DUEÑO</span><span>EDAD</span><span>ESTADO MÉDICO</span><span></span></div><button v-for="pet in pets" :key="pet.name" class="pet-row" @click="selectedPet = pet.name; notify('Ficha de ' + pet.name + ' abierta')"><div class="pet-cell"><span class="pet-avatar">{{ pet.initials }}</span><span><strong>{{ pet.name }}</strong><small>{{ pet.species }}</small></span></div><span>{{ pet.owner }}</span><span>{{ pet.age }}</span><span><b class="status green">Al día</b></span><span class="arrow">→</span></button></div></section>

        <section v-else-if="adminView === 'clients'" class="page-content"><div class="page-heading"><div><p class="eyebrow">AGENDA Y CONTACTOS</p><h1>Clientes</h1><p class="muted">Gestioná dueños y sus mascotas asociadas.</p></div><button class="primary-button" @click="notify('Formulario de nuevo cliente')">＋ Agregar cliente</button></div><div class="toolbar"><label class="search"><span>⌕</span><input placeholder="Buscar cliente por nombre, teléfono o email" /></label></div><div class="client-cards"><div v-for="client in [{name:'Martín López', phone:'11 4567 8901', pets:'2 mascotas'}, {name:'Sofía Ramos', phone:'11 3478 2210', pets:'1 mascota'}, {name:'Ana Torres', phone:'11 6234 1112', pets:'3 mascotas'}]" :key="client.name" class="panel client-card"><span class="client-avatar">{{ client.name.split(' ').map(name => name[0]).join('') }}</span><div><h3>{{ client.name }}</h3><p>{{ client.phone }}</p><small>{{ client.pets }}</small></div><button class="row-menu">•••</button></div></div></section>

        <section v-else-if="adminView === 'consultations'" class="page-content"><div class="page-heading"><div><p class="eyebrow">HISTORIAL CLÍNICO</p><h1>Consultas</h1><p class="muted">Últimas consultas registradas y pendientes.</p></div><button class="primary-button" @click="notify('Seleccioná una mascota para registrar')">＋ Nueva consulta</button></div><div class="panel consultation-list"><div v-for="item in [{pet:'Rocky', detail:'Control general · pendiente de completar', date:'Hoy, 12:00', state:'Pendiente'}, {pet:'Luna', detail:'Vacunación séxtuple · Dra. María', date:'12 Jun 2025', state:'Completada'}, {pet:'Milo', detail:'Consulta general · Dra. María', date:'04 Jun 2025', state:'Completada'}]" :key="item.pet" class="consultation-row"><span class="pet-avatar">{{ item.pet[0] }}</span><div><strong>{{ item.pet }}</strong><p>{{ item.detail }}</p></div><small>{{ item.date }}</small><b class="status" :class="item.state === 'Pendiente' ? 'yellow' : 'green'">{{ item.state }}</b><button class="text-button" @click="notify('Editando consulta de ' + item.pet)">Abrir →</button></div></div></section>

        <section v-else class="page-content">
          <div class="page-heading"><div><p class="eyebrow">PREFERENCIAS</p><h1>Configuración</h1><p class="muted">Mantené actualizada la información de tu veterinaria.</p></div><button class="primary-button" @click="notify('Cambios guardados')">Guardar cambios</button></div>
          <div class="settings-grid">
            <div class="panel settings-card"><h2>Datos de la veterinaria</h2><label>Nombre de la veterinaria<input value="VetControl Centro" /></label><label>Teléfono de contacto<input value="11 4567 8901" /></label><label>Dirección<input value="Av. Siempre Viva 123" /></label></div>
            <div class="panel settings-card"><h2>Horarios de atención</h2><div class="hours-row"><span>Lunes a viernes</span><strong>09:00 — 18:00</strong><button>Editar</button></div><div class="hours-row"><span>Sábados</span><strong>09:00 — 13:00</strong><button>Editar</button></div><div class="hours-row"><span>Domingos</span><strong class="muted">Cerrado</strong><button>Editar</button></div></div>
          </div>
          <div class="settings-security">
            <div class="panel settings-card">
              <h2>Seguridad de la cuenta</h2>
              <p class="muted" style="margin-bottom: 14px;">Gestioná la seguridad de tu cuenta.</p>
              <div class="security-info">
                <span>Correo: <strong>{{ usuarioEmail }}</strong></span>
              </div>
              <router-link to="/cambiar-clave" class="outline-button">🔒 Cambiar contraseña</router-link>
            </div>
          </div>
        </section>
      </main>
    </div>

    <div v-else class="client-layout"><aside class="client-rail"><button class="brand client-brand"><span class="brand-mark">✚</span><span><strong>Vet</strong><b>Control</b></span></button><div class="client-profile"><div class="avatar">{{ usuarioInicial }}</div><div><strong>{{ usuarioEmail || 'Usuario' }}</strong><small>Cuenta personal</small></div></div><nav><button :class="{active: clientView === 'home'}" @click="clientView = 'home'">⌂ <span>Inicio</span></button><button :class="{active: clientView === 'pet-history'}" @click="clientView = 'pet-history'">♡ <span>Mis mascotas</span></button><button :class="{active: clientView === 'appointments'}" @click="clientView = 'appointments'">▦ <span>Mis turnos</span></button></nav><button class="logout" @click="cerrarSesion()">↪ <span>Cerrar sesión</span></button></aside><main class="client-main"><div class="client-mobile-header"><button class="brand"><span class="brand-mark">✚</span><span><strong>Vet</strong><b>Control</b></span></button><button>☰</button></div><section v-if="clientView === 'home'" class="client-page"><div class="welcome-banner"><div><p class="eyebrow">PORTAL DEL CLIENTE</p><h1>Hola <span>👋</span></h1><p>Todo el cuidado de tus mascotas, en un solo lugar.</p></div><span class="banner-mark">✚</span></div><div class="page-heading client-heading"><div><h2>Mis mascotas</h2><p class="muted">Elegí una mascota para consultar su historia.</p></div><button class="outline-button" @click="notify('Formulario de nueva mascota')">＋ Agregar mascota</button></div><div class="pet-cards"><button v-for="pet in [{name:'Luna', type:'Golden retriever · 4 años', next:'Vacuna en 12 días', color:'lime'}, {name:'Milo', type:'Mestizo · 2 años', next:'Todo al día', color:'blue'}]" :key="pet.name" class="pet-card" @click="selectedPet = pet.name; clientView = 'pet-history'"><span class="large-pet-avatar" :class="pet.color">{{ pet.name[0] }}</span><span><strong>{{ pet.name }}</strong><small>{{ pet.type }}</small><em :class="pet.next.includes('12') ? 'warning' : ''">◷ {{ pet.next }}</em></span><b>→</b></button></div><div class="client-columns"><div><div class="section-title"><h2>Próximo turno</h2><button class="text-button" @click="clientView = 'appointments'">Ver todos →</button></div><div class="panel next-appointment"><div class="date-block"><strong>18</strong><small>JUN</small></div><div><strong>Vacunación anual</strong><p>Luna · Miércoles 18 de junio a las 10:30</p><span class="status yellow">Pendiente de confirmación</span></div><button class="row-menu">•••</button></div></div><div><div class="section-title"><h2>Acciones rápidas</h2></div><div class="quick-actions"><button @click="openBooking"><span>＋</span><strong>Reservar turno</strong><small>Elegí día y horario</small></button><button @click="clientView = 'pet-history'"><span>⌕</span><strong>Ver historial</strong><small>Consultas y vacunas</small></button></div></div></div></section><section v-else-if="clientView === 'pet-history'" class="client-page"><button class="back-link" @click="clientView = 'home'">← Volver a mis mascotas</button><div class="pet-profile-header"><span class="large-pet-avatar lime">L</span><div><p class="eyebrow">FICHA DE MASCOTA</p><h1>{{ selectedPet }}</h1><p class="muted">Golden retriever · 4 años · 24 kg</p></div><button class="primary-button" @click="openBooking">＋ Reservar turno</button></div><div class="history-tabs"><button class="active">Resumen</button><button>Consultas</button><button>Vacunas</button></div><div class="history-grid"><div class="panel"><div class="panel-header"><h2>Próximos controles</h2><span class="count-badge">1</span></div><div class="timeline-item pending"><span>◷</span><div><strong>Vacuna séxtuple</strong><p>Próxima dosis recomendada</p><b>Vence en 12 días</b></div></div></div><div class="panel"><div class="panel-header"><h2>Últimas consultas</h2><button class="text-button">Ver historial →</button></div><div class="timeline-item"><span>＋</span><div><strong>Control general</strong><p>12 de marzo, 2025 · Dra. María V.</p><b class="ok">Sin observaciones</b></div></div><div class="timeline-item"><span>✚</span><div><strong>Vacuna antirrábica</strong><p>08 de enero, 2025</p><b class="ok">Aplicada</b></div></div></div></div></section><section v-else class="client-page"><div class="page-heading"><div><p class="eyebrow">RESERVAS</p><h1>Mis turnos</h1><p class="muted">Consultá tus turnos próximos y anteriores.</p></div><button class="primary-button" @click="openBooking">＋ Reservar turno</button></div><div class="panel booking-list"><div class="booking-item"><div class="date-block"><strong>18</strong><small>JUN</small></div><div><strong>Vacunación anual</strong><p>Luna · 10:30 · VetControl Centro</p></div><span class="status yellow">Pendiente</span><button class="row-menu">•••</button></div></div></section></main></div>

    <div v-if="showBooking" class="modal-backdrop" @click.self="showBooking = false"><section class="booking-modal"><button class="modal-close" @click="showBooking = false">×</button><div class="modal-progress"><span :class="{done: bookingStep >= 1, active: bookingStep === 1}">1</span><i></i><span :class="{done: bookingStep >= 2, active: bookingStep === 2}">2</span><i></i><span :class="{done: bookingStep >= 3, active: bookingStep === 3}">3</span></div><p class="eyebrow">RESERVAR TURNO</p><h2>{{ bookingStep === 1 ? '¿Qué necesitás para tu mascota?' : bookingStep === 2 ? 'Elegí fecha y horario' : 'Revisá tu solicitud' }}</h2><p class="muted">Paso {{ bookingStep }} de 3</p><div v-if="bookingStep === 1" class="service-options"><button class="service-option selected"><span>＋</span><strong>Consulta general</strong><small>Revisión y seguimiento</small><b>✓</b></button><button class="service-option"><span>✚</span><strong>Vacunación</strong><small>Aplicación de vacunas</small></button><button class="service-option"><span>◷</span><strong>Control</strong><small>Seguimiento de tratamiento</small></button></div><div v-else-if="bookingStep === 2" class="date-picker"><label>Mascota<select><option>Luna</option><option>Milo</option></select></label><label>Fecha<input v-model="bookingDate" /></label><div class="time-label">Horarios disponibles</div><div class="time-options"><button v-for="time in ['09:00','10:30','12:00','15:30']" :key="time" :class="{selected: bookingTime === time}" @click="bookingTime = time">{{ time }}</button></div><div class="conflict-note">ⓘ Este horario aún está disponible. Te confirmaremos el turno por email.</div></div><div v-else class="request-summary"><div><span>Mascota</span><strong>Luna</strong></div><div><span>Servicio</span><strong>Consulta general</strong></div><div><span>Fecha y hora</span><strong>{{ bookingDate }} · {{ bookingTime }}</strong></div><div class="success-note">✓ No hay turnos que se solapen en este horario.</div></div><div class="modal-actions"><button class="outline-button" @click="bookingStep > 1 ? bookingStep-- : showBooking = false">{{ bookingStep > 1 ? 'Atrás' : 'Cancelar' }}</button><button class="primary-button" @click="nextBookingStep">{{ bookingStep === 3 ? 'Solicitar turno' : 'Continuar' }} →</button></div></section></div>
    <transition name="toast"><div v-if="toast" class="toast-message">✓ {{ toast }}</div></transition>
  </div>
</template>
