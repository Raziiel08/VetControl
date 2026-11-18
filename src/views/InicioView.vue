<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useUsuario } from '@/composables/useUsuario'
import { useToast } from '@/composables/useToast'
import AgendaPanel from '@/components/inicio/AgendaPanel.vue'
import MascotasPanel from '@/components/inicio/MascotasPanel.vue'
import ClientesPanel from '@/components/inicio/ClientesPanel.vue'
import ConsultasPanel from '@/components/inicio/ConsultasPanel.vue'
import ConfiguracionPanel from '@/components/inicio/ConfiguracionPanel.vue'
import PortalCliente from '@/components/inicio/PortalCliente.vue'
import {
  Bell,
  CalendarDays,
  CircleHelp,
  LogOut,
  Menu,
  PawPrint,
  Plus,
  Settings,
  Stethoscope,
  Tag,
  Users,
  X,
} from 'lucide-vue-next'

const router = useRouter()
const { email: usuarioEmail, inicial: usuarioInicial, etiquetaRol, esStaff, esAdmin, rol, cargar, cerrarSesion: salir } = useUsuario()
const { notify } = useToast()

// 'admin' = panel de la veterinaria, 'client' = portal del dueño de mascotas.
// El modo inicial sale del rol guardado en `perfiles`: si la cuenta es de un
// cliente, se abre directo en su portal.
const mode = ref('admin')
const adminView = ref('agenda')

// Cajón de navegación para pantallas chicas y menú de la cuenta
const menuMovil = ref(false)
const menuCuenta = ref(false)

// Al abrir el portal se reinicia (vuelve a su pantalla de inicio).
const portalKey = ref(0)

// El icono es el componente de lucide (antes eran glifos de texto)
const navItems = [
  { id: 'agenda', label: 'Agenda', icon: CalendarDays },
  { id: 'clients', label: 'Clientes', icon: Users },
  { id: 'pets', label: 'Mascotas', icon: PawPrint },
  { id: 'consultations', label: 'Consultas', icon: Stethoscope },
  { id: 'productos', label: 'Productos', icon: Tag },
  { id: 'settings', label: 'Configuración', icon: Settings },
]

onMounted(async () => {
  await cargar()
  // Rol real desde la base: un cliente nunca ve el panel de la veterinaria
  if (rol.value && !esStaff.value) {
    mode.value = 'client'
    portalKey.value += 1
  }
})

function selectAdminView(view) {
  if (!esStaff.value && view !== 'settings') {
    notify('Esta sección es para el equipo de la veterinaria')
    return
  }
  if (view === 'productos') {
    router.push('/productos')
    return
  }
  adminView.value = view
  menuMovil.value = false
  menuCuenta.value = false
  if (view === 'agenda') window.scrollTo({ top: 0, behavior: 'smooth' })
}

function abrirPortal() {
  mode.value = 'client'
  menuMovil.value = false
  menuCuenta.value = false
  portalKey.value += 1
}

function abrirPanel() {
  mode.value = 'admin'
}

async function cerrarSesion() {
  try {
    await salir()
  } finally {
    router.push('/login')
  }
}
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <button
        class="brand"
        aria-label="Ir al inicio"
        @click="abrirPanel(); selectAdminView('agenda')"
      >
        <span class="brand-mark"><Plus /></span>
        <span><strong>Vet</strong><b>Control</b><small>Gestión veterinaria simple</small></span>
      </button>

      <div class="mode-switch" aria-label="Cambiar flujo">
        <button v-if="esStaff" :class="{ active: mode === 'admin' }" @click="abrirPanel">
          Panel veterinaria
        </button>
        <button :class="{ active: mode === 'client' }" @click="abrirPortal">
          Portal cliente
        </button>
      </div>

      <div class="top-actions">
        <button class="icon-button" aria-label="Notificaciones" @click="notify('No tenés notificaciones nuevas')"><Bell /><i></i></button>
        <div class="avatar">{{ usuarioInicial }}</div>
        <span class="user-name">{{ usuarioEmail || 'Usuario' }} <small>{{ etiquetaRol }}</small></span>
        <button class="icon-button" aria-label="Mi cuenta" @click="menuCuenta = !menuCuenta"><Users /></button>
        <div v-if="menuCuenta" class="account-popover">
          <strong>{{ usuarioEmail || 'Usuario' }}</strong>
          <small>{{ etiquetaRol }}</small>
          <button @click="cerrarSesion()"><LogOut /> Cerrar sesión</button>
        </div>
      </div>
    </header>

    <div v-if="mode === 'admin'" class="admin-layout">
      <aside class="sidebar">
        <p class="eyebrow">MENÚ PRINCIPAL</p>
        <nav>
          <button
            v-for="item in navItems"
            :key="item.id"
            :class="{ active: item.id === adminView }"
            @click="selectAdminView(item.id)"
          >
            <span><component :is="item.icon" /></span>{{ item.label }}
          </button>
        </nav>

        <div class="sidebar-help">
          <span class="help-icon"><CircleHelp /></span>
          <strong>¿Necesitás ayuda?</strong>
          <small>Estamos para acompañarte</small>
          <button @click="notify('Centro de ayuda próximamente')">Ver centro de ayuda</button>
        </div>

        <button class="logout" @click="cerrarSesion()"><LogOut /> <span>Cerrar sesión</span></button>
      </aside>

      <main class="content-area">
        <div class="mobile-page-nav">
          <button aria-label="Abrir menú" @click="menuMovil = true"><Menu /></button>
          <span>VetControl</span>
          <button aria-label="Mi cuenta" @click="menuCuenta = !menuCuenta"><Users /></button>
        </div>

        <AgendaPanel v-if="adminView === 'agenda'" @navigate="selectAdminView" />
        <MascotasPanel v-else-if="adminView === 'pets'" @navigate="selectAdminView" />
        <ClientesPanel v-else-if="adminView === 'clients'" @navigate="selectAdminView" />
        <ConsultasPanel v-else-if="adminView === 'consultations'" @navigate="selectAdminView" />
        <ConfiguracionPanel v-else />
      </main>
    </div>

    <!-- Cajón de navegación en pantallas chicas -->
    <div v-if="menuMovil && mode === 'admin'" class="drawer-backdrop" @click.self="menuMovil = false">
      <aside class="sidebar drawer">
        <button class="drawer-close" aria-label="Cerrar menú" @click="menuMovil = false"><X /></button>
        <p class="eyebrow">MENÚ PRINCIPAL</p>
        <nav>
          <button
            v-for="item in navItems"
            :key="item.id"
            :class="{ active: item.id === adminView }"
            @click="selectAdminView(item.id)"
          >
            <span><component :is="item.icon" /></span>{{ item.label }}
          </button>
        </nav>
        <button class="logout" @click="cerrarSesion()"><LogOut /> <span>Cerrar sesión</span></button>
      </aside>
    </div>

    <PortalCliente v-if="mode === 'client'" :key="portalKey" />
  </div>
</template>
