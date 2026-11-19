<script setup>
import { ref, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useUsuario } from "@/composables/useUsuario";
import { useToast } from "@/composables/useToast";
import AgendaPanel from "@/components/inicio/AgendaPanel.vue";
import MascotasPanel from "@/components/inicio/MascotasPanel.vue";
import ClientesPanel from "@/components/inicio/ClientesPanel.vue";
import ConsultasPanel from "@/components/inicio/ConsultasPanel.vue";
import ConfiguracionPanel from "@/components/inicio/ConfiguracionPanel.vue";
import PortalCliente from "@/components/inicio/PortalCliente.vue";
import {
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
} from "lucide-vue-next";

const enrutador = useRouter();
const {
  correo: usuarioCorreo,
  inicial: usuarioInicial,
  etiquetaRol,
  esEquipo,
  esAdministrador,
  rol,
  cargar,
  cerrarSesion: salir,
} = useUsuario();
const { notificar } = useToast();

const modo = ref("panel");
const vistaPanel = ref("agenda");

const menuMovil = ref(false);
const menuCuenta = ref(false);
const portalRef = ref(null);

const clavePortal = ref(0);

const elementosMenu = [
  { id: "agenda", label: "Agenda", icon: CalendarDays },
  { id: "clientes", label: "Clientes", icon: Users },
  { id: "mascotas", label: "Mascotas", icon: PawPrint },
  { id: "consultas", label: "Consultas", icon: Stethoscope },
  { id: "productos", label: "Productos", icon: Tag },
  { id: "configuracion", label: "Configuración", icon: Settings },
];

onMounted(async () => {
  await cargar();
  if (rol.value && !esEquipo.value) {
    modo.value = "cliente";
    clavePortal.value += 1;
  }
});

function seleccionarVistaPanel(vista) {
  if (!esEquipo.value && vista !== "configuracion") {
    notificar("Esta sección es para el equipo de la veterinaria");
    return;
  }
  if (vista === "productos") {
    enrutador.push("/productos");
    return;
  }
  vistaPanel.value = vista;
  menuMovil.value = false;
  menuCuenta.value = false;
  if (vista === "agenda") window.scrollTo({ top: 0, behavior: "smooth" });
}

function abrirPortal() {
  modo.value = "cliente";
  menuMovil.value = false;
  menuCuenta.value = false;
  clavePortal.value += 1;
}

function abrirPanel() {
  modo.value = "panel";
}

async function cerrarSesion() {
  try {
    await salir();
  } finally {
    enrutador.push("/login");
  }
}
</script>

<template>
  <div class="contenedor-aplicacion">
    <header class="barra-superior">
      <button
        class="marca"
        aria-label="Ir al inicio"
        @click="
          abrirPanel();
          seleccionarVistaPanel('agenda');
        "
      >
        <span class="icono-marca"><Plus /></span>
        <span
          ><strong>Vet</strong><b>Control</b
          ><small>Gestión veterinaria simple</small></span
        >
      </button>

      <div v-if="false" class="selector-modo" aria-label="Cambiar flujo">
        <button
          v-if="esEquipo"
          :class="{ activo: modo === 'panel' }"
          @click="abrirPanel"
        >
          Panel veterinaria
        </button>
        <button :class="{ activo: modo === 'cliente' }" @click="abrirPortal">
          Portal cliente
        </button>
      </div>

      <div class="acciones-superiores">
        <button
          v-if="modo === 'cliente'"
          class="boton-menu-cliente-superior"
          aria-label="Abrir menú"
          @click="portalRef?.abrirMenu()"
        >
          <Menu />
        </button>

        <div class="avatar">{{ usuarioInicial }}</div>
        <span class="nombre-usuario"
          >{{ usuarioCorreo || "Usuario" }}
          <small>{{ etiquetaRol }}</small></span
        >
      </div>
    </header>

    <div v-if="modo === 'panel'" class="distribucion-panel">
      <aside class="barra-lateral">
        <p class="sobretitulo">MENÚ PRINCIPAL</p>
        <nav>
          <button
            v-for="item in elementosMenu"
            :key="item.id"
            :class="{ activo: item.id === vistaPanel }"
            @click="seleccionarVistaPanel(item.id)"
          >
            <span><component :is="item.icon" /></span>{{ item.label }}
          </button>
        </nav>

        <button class="cerrar-sesion" @click="cerrarSesion()">
          <LogOut /> <span>Cerrar sesión</span>
        </button>
      </aside>

      <main class="area-contenido">
        <div class="navegacion-movil-pagina">
          <button aria-label="Abrir menú" @click="menuMovil = true">
            <Menu />
          </button>
          <span>VetControl</span>
        </div>

        <AgendaPanel
          v-if="vistaPanel === 'agenda'"
          @navegar="seleccionarVistaPanel"
        />
        <MascotasPanel
          v-else-if="vistaPanel === 'mascotas'"
          @navegar="seleccionarVistaPanel"
        />
        <ClientesPanel
          v-else-if="vistaPanel === 'clientes'"
          @navegar="seleccionarVistaPanel"
        />
        <ConsultasPanel
          v-else-if="vistaPanel === 'consultas'"
          @navegar="seleccionarVistaPanel"
        />
        <ConfiguracionPanel v-else />
      </main>
    </div>

    <div
      v-if="menuMovil && modo === 'panel'"
      class="fondo-cajon"
      @click.self="menuMovil = false"
    >
      <aside class="barra-lateral cajon">
        <button
          class="cerrar-cajon"
          aria-label="Cerrar menú"
          @click="menuMovil = false"
        >
          <X />
        </button>
        <p class="sobretitulo">MENÚ PRINCIPAL</p>
        <nav>
          <button
            v-for="item in elementosMenu"
            :key="item.id"
            :class="{ activo: item.id === vistaPanel }"
            @click="seleccionarVistaPanel(item.id)"
          >
            <span><component :is="item.icon" /></span>{{ item.label }}
          </button>
        </nav>
        <button class="cerrar-sesion" @click="cerrarSesion()">
          <LogOut /> <span>Cerrar sesión</span>
        </button>
      </aside>
    </div>

    <PortalCliente
      v-if="modo === 'cliente'"
      :key="clavePortal"
      ref="portalRef"
    />
  </div>
</template>
