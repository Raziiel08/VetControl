<script setup>
import {
  Activity,
  ArrowRight,
  CalendarDays,
  Check,
  CheckCheck,
  Clock,
  MoreHorizontal,
  Plus,
  Stethoscope,
  Syringe,
  TriangleAlert,
  X,
} from "lucide-vue-next";
import { computed, nextTick, onMounted, ref } from "vue";
import { supabase } from "@/supabase";
import { useToast } from "@/composables/useToast";
import { traducirError } from "@/utils/errores";
import { isoLocal, primerDiaDelMes, sumarDias } from "@/utils/fechas";

const emit = defineEmits(["navegar"]);

const { notificar } = useToast();

const fechaLarga = new Intl.DateTimeFormat("es-AR", {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
})
  .format(new Date())
  .replace(/,/g, "");

const fechaHoy = fechaLarga.toUpperCase();
const fechaDia = fechaLarga.charAt(0).toUpperCase() + fechaLarga.slice(1);

const hoyISO = isoLocal();
const turnos = ref([]);
const mascotas = ref([]);
const servicios = ref([]);
const vacunasProximas = ref([]);
const controlesVencidos = ref(0);
const consultasMes = ref(0);
const turnosAyer = ref(0);
const cargando = ref(true);
const vista = ref("lista");
const soloPendientes = ref(false);
const panelAgenda = ref(null);

const mostrarNuevo = ref(false);
const guardando = ref(false);
const errorFormulario = ref("");
const formulario = ref({
  mascotaId: "",
  servicioId: "",
  fecha: hoyISO,
  hora: "09:00",
  motivo: "",
});

const menuAbierto = ref(null);
const turnoEnAccion = ref(null);

const LUNES = (() => {
  const d = new Date();
  const dia = d.getDay();
  const correccion = dia === 0 ? -6 : 1 - dia;
  d.setDate(d.getDate() + correccion);
  return isoLocal(d);
})();

const DOMINGO = sumarDias(LUNES, 6);

const turnosHoy = computed(() =>
  turnos.value.filter((t) => t.fecha === hoyISO && t.estado !== "Cancelado"),
);

const pendientesHoy = computed(
  () => turnosHoy.value.filter((t) => t.estado === "Pendiente").length,
);

const turnosPendientesHoy = computed(() =>
  turnosHoy.value.filter((t) => t.estado === "Pendiente"),
);

const turnosLista = computed(() =>
  soloPendientes.value ? turnosPendientesHoy.value : turnosHoy.value,
);

const turnosPorDia = computed(() => {
  const mapa = new Map();
  for (const t of [...turnos.value].sort((a, b) =>
    a.hora_inicio.localeCompare(b.hora_inicio),
  )) {
    if (!mapa.has(t.fecha)) mapa.set(t.fecha, []);
    mapa.get(t.fecha).push(t);
  }
  return [...mapa.entries()].map(([fecha, lista]) => ({
    fecha,
    turnos: lista,
  }));
});

function etiquetaDia(iso) {
  if (iso === hoyISO) return "Hoy";
  const f = new Date(iso + "T12:00:00");
  return new Intl.DateTimeFormat("es-AR", {
    weekday: "long",
    day: "numeric",
    month: "short",
  }).format(f);
}

function colorEstado(estado) {
  if (estado === "Confirmado" || estado === "Atendido") return "verde";
  if (estado === "Cancelado") return "rojo";
  return "amarillo";
}

const horaFin = computed(() => {
  const servicio = servicios.value.find(
    (s) => s.id === formulario.value.servicioId,
  );
  const duracion = servicio?.duracion_minutos || 30;
  const [h, m] = formulario.value.hora.split(":").map(Number);
  const total = h * 60 + m + duracion;
  return `${String(Math.floor(total / 60) % 24).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
});

async function cargar() {
  cargando.value = true;
  try {
    const desdeISO = LUNES;
    const hastaISO = DOMINGO;

    const [turnosRes, mascotasRes, serviciosRes, consultasRes, ayerRes] =
      await Promise.all([
        supabase
          .from("turnos")
          .select(
            "id, fecha, hora_inicio, hora_fin, estado, motivo, mascota:mascotas(id, nombre, cliente_id, clientes(nombre_completo)), servicio:servicios(id, nombre)",
          )
          .gte("fecha", desdeISO)
          .lte("fecha", hastaISO)
          .order("hora_inicio"),
        supabase
          .from("mascotas")
          .select("id, nombre, especie, raza, fecha_nacimiento")
          .order("nombre"),
        supabase
          .from("servicios")
          .select("id, nombre, duracion_minutos")
          .eq("activo", true)
          .order("nombre"),
        supabase
          .from("consultas")
          .select("id", { count: "exact", head: true })
          .gte("fecha", primerDiaDelMes()),
        supabase
          .from("turnos")
          .select("id", { count: "exact", head: true })
          .eq("fecha", sumarDias(hoyISO, -1)),
      ]);

    if (turnosRes.error) throw turnosRes.error;
    turnos.value = turnosRes.data || [];
    if (!mascotasRes.error) mascotas.value = mascotasRes.data || [];
    if (!serviciosRes.error) servicios.value = serviciosRes.data || [];
    if (!consultasRes.error) consultasMes.value = consultasRes.count || 0;
    if (!ayerRes.error) turnosAyer.value = ayerRes.count || 0;

    const [vacunasRes, controlesRes] = await Promise.all([
      supabase
        .from("vacunas")
        .select("id, fecha_proxima, nombre, mascota:mascotas(nombre)")
        .not("fecha_proxima", "is", null)
        .gte("fecha_proxima", hoyISO)
        .order("fecha_proxima")
        .limit(3),
      supabase
        .from("consultas")
        .select("id", { count: "exact", head: true })
        .not("proximo_control", "is", null)
        .lte("proximo_control", hoyISO),
    ]);
    if (!vacunasRes.error) vacunasProximas.value = vacunasRes.data || [];
    if (!controlesRes.error) controlesVencidos.value = controlesRes.count || 0;
  } catch (e) {
    notificar(traducirError(e.message));
  } finally {
    cargando.value = false;
  }
}

function abrirNuevo() {
  errorFormulario.value = "";
  formulario.value = {
    mascotaId: "",
    servicioId: "",
    fecha: hoyISO,
    hora: "09:00",
    motivo: "",
  };
  mostrarNuevo.value = true;
}

async function guardarTurno() {
  errorFormulario.value = "";
  if (!formulario.value.mascotaId)
    return (errorFormulario.value = "Elegí una mascota.");
  if (!formulario.value.servicioId)
    return (errorFormulario.value = "Elegí un servicio.");
  if (!formulario.value.fecha)
    return (errorFormulario.value = "Elegí una fecha.");

  guardando.value = true;
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc(
      "obtener_mi_veterinaria_id",
    );
    if (errVet) throw errVet;
    const {
      data: { user: usuario },
    } = await supabase.auth.getUser();

    const { error } = await supabase.from("turnos").insert({
      veterinaria_id: veterinariaId,
      mascota_id: formulario.value.mascotaId,
      servicio_id: formulario.value.servicioId,
      veterinario_id: usuario?.id ?? null,
      fecha: formulario.value.fecha,
      hora_inicio: formulario.value.hora,
      hora_fin: horaFin.value,
      estado: "Pendiente",
      motivo: formulario.value.motivo.trim() || null,
    });
    if (error) throw error;

    mostrarNuevo.value = false;
    notificar("Turno creado correctamente");
    await cargar();
  } catch (e) {
    errorFormulario.value = traducirError(e.message);
  } finally {
    guardando.value = false;
  }
}

function alternarMenu(turno) {
  menuAbierto.value = menuAbierto.value === turno.id ? null : turno.id;
}

async function cambiarEstado(turno, estado) {
  turnoEnAccion.value = turno.id;
  try {
    const { data, error } = await supabase
      .from("turnos")
      .update({ estado })
      .eq("id", turno.id)
      .select("id");
    if (error) throw error;
    if (!data?.length)
      throw new Error("No tenés permiso para modificar este turno.");
    notificar(`Turno ${estado.toLowerCase()}`);
    await cargar();
  } catch (e) {
    notificar(traducirError(e.message));
  } finally {
    turnoEnAccion.value = null;
    menuAbierto.value = null;
  }
}

async function crearServiciosBasicos() {
  guardando.value = true;
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc(
      "obtener_mi_veterinaria_id",
    );
    if (errVet) throw errVet;
    const { error } = await supabase.from("servicios").insert([
      {
        veterinaria_id: veterinariaId,
        nombre: "Consulta general",
        descripcion: "Revisión y seguimiento",
        duracion_minutos: 30,
        precio: 0,
      },
      {
        veterinaria_id: veterinariaId,
        nombre: "Vacunación",
        descripcion: "Aplicación de vacunas",
        duracion_minutos: 20,
        precio: 0,
      },
      {
        veterinaria_id: veterinariaId,
        nombre: "Control",
        descripcion: "Seguimiento de tratamiento",
        duracion_minutos: 20,
        precio: 0,
      },
    ]);
    if (error) throw error;
    notificar("Servicios básicos creados");
    await cargar();
  } catch (e) {
    notificar(traducirError(e.message));
  } finally {
    guardando.value = false;
  }
}

function revisarPendientes() {
  vista.value = "lista";
  soloPendientes.value = true;
  nextTick(() => {
    panelAgenda.value?.scrollIntoView({ behavior: "smooth", block: "start" });
  });
}

function verTodosLosTurnos() {
  soloPendientes.value = false;
}

function cambiarVista(nuevaVista) {
  vista.value = nuevaVista;
  if (nuevaVista === "lista") soloPendientes.value = false;
}

function seleccionarVistaPanel(vista) {
  emit("navegar", vista);
}

onMounted(cargar);
</script>

<template>
  <section class="contenido-pagina">
    <div class="encabezado-pagina">
      <div>
        <p class="sobretitulo">{{ fechaHoy }}</p>
        <h1>Agenda del día</h1>
        <p class="texto-atenuado">Revisá y organizá los turnos de hoy.</p>
      </div>
      <button class="boton-principal" @click="abrirNuevo">
        <Plus /> Nuevo turno
      </button>
    </div>

    <div class="fila-metrica">
      <div class="tarjeta-metrica">
        <span class="icono-metrica verde-palido"><CalendarDays /></span>
        <div>
          <strong>{{ turnosHoy.length }}</strong>
          <small>Turnos de hoy</small>
        </div>
        <em :class="{ naranja: turnosHoy.length - turnosAyer < 0 }">
          {{ turnosHoy.length - turnosAyer >= 0 ? "+" : ""
          }}{{ turnosHoy.length - turnosAyer }} vs. ayer
        </em>
      </div>
      <div class="tarjeta-metrica">
        <span class="icono-metrica amarillo-palido"><Clock /></span>
        <div>
          <strong>{{ pendientesHoy }}</strong>
          <small>Pendientes</small>
        </div>
        <em class="naranja">{{
          pendientesHoy ? "Requieren acción" : "Todo confirmado"
        }}</em>
      </div>
      <div class="tarjeta-metrica">
        <span class="icono-metrica azul-palido"><Activity /></span>
        <div>
          <strong>{{ consultasMes }}</strong>
          <small>Consultas este mes</small>
        </div>
        <em>Actualizado</em>
      </div>
    </div>

    <div class="cuadricula-contenido">
      <section ref="panelAgenda" class="panel panel-agenda">
        <div class="encabezado-panel">
          <div>
            <h2>
              {{
                vista === "lista"
                  ? soloPendientes
                    ? "Turnos pendientes de confirmar"
                    : "Turnos de hoy"
                  : "Semana en curso"
              }}
            </h2>
            <p class="texto-atenuado">
              {{
                vista === "lista"
                  ? soloPendientes
                    ? `${pendientesHoy} ${pendientesHoy === 1 ? "turno requiere" : "turnos requieren"} confirmación`
                    : fechaDia
                  : `Del ${LUNES.split("-").reverse().slice(0, 2).join("/")} al ${DOMINGO.split("-").reverse().slice(0, 2).join("/")}`
              }}
            </p>
          </div>
          <div class="selector-vista">
            <button
              :class="{ seleccionado: vista === 'lista' }"
              @click="cambiarVista('lista')"
            >
              Lista
            </button>
            <button
              :class="{ seleccionado: vista === 'semana' }"
              @click="cambiarVista('semana')"
            >
              Semana
            </button>
          </div>
        </div>

        <div v-if="vista === 'lista' && soloPendientes" class="filtro-activo">
          <span>Mostrando solo pendientes</span>
          <button type="button" @click="verTodosLosTurnos">
            Ver todos <X />
          </button>
        </div>

        <div v-if="cargando" class="estado-vacio">
          <p>Cargando agenda...</p>
        </div>

        <div
          v-else-if="vista === 'lista' && !turnosLista.length"
          class="estado-vacio"
        >
          <span class="icono-vacio"><CalendarDays /></span>
          <strong>{{
            soloPendientes
              ? "No hay turnos pendientes"
              : "No hay turnos para hoy"
          }}</strong>
          <p v-if="soloPendientes">
            Ya revisaste todos los turnos pendientes de hoy.
          </p>
          <p v-else>Creá el primero con el botón “Nuevo turno”.</p>
        </div>

        <div
          v-else-if="vista === 'semana' && !turnos.length"
          class="estado-vacio"
        >
          <span class="icono-vacio"><CalendarDays /></span>
          <strong>Sin turnos esta semana</strong>
          <p>Los turnos que crees van a aparecer acá.</p>
        </div>

        <div v-else-if="vista === 'lista'" class="lista-agenda">
          <div
            v-for="turno in [...turnosLista].sort((a, b) =>
              a.hora_inicio.localeCompare(b.hora_inicio),
            )"
            :key="turno.id"
            class="fila-turno"
          >
            <time>{{ turno.hora_inicio.slice(0, 5) }}</time>
            <div class="linea-turno" :class="colorEstado(turno.estado)"></div>
            <div class="info-turno">
              <strong>
                {{ turno.mascota?.nombre || "Mascota" }}
                <span>· {{ turno.servicio?.nombre || "Sin servicio" }}</span>
              </strong>
              <small>
                {{ turno.mascota?.clientes?.nombre_completo || "Sin dueño" }}
                <template v-if="turno.motivo"> · {{ turno.motivo }}</template>
              </small>
            </div>
            <span class="estado" :class="colorEstado(turno.estado)">{{
              turno.estado
            }}</span>
            <button
              class="menu-fila"
              :aria-label="'Acciones de ' + (turno.mascota?.nombre || 'turno')"
              @click.stop="alternarMenu(turno)"
            >
              <MoreHorizontal />
            </button>
            <div v-if="menuAbierto === turno.id" class="menu-turno">
              <button
                v-if="turno.estado === 'Pendiente'"
                :disabled="turnoEnAccion === turno.id"
                @click="cambiarEstado(turno, 'Confirmado')"
              >
                <Check /> Confirmar
              </button>
              <button
                v-if="
                  turno.estado !== 'Atendido' && turno.estado !== 'Cancelado'
                "
                :disabled="turnoEnAccion === turno.id"
                @click="cambiarEstado(turno, 'Atendido')"
              >
                <CheckCheck /> Marcar atendido
              </button>
              <button
                v-if="turno.estado !== 'Cancelado'"
                class="rojo"
                :disabled="turnoEnAccion === turno.id"
                @click="cambiarEstado(turno, 'Cancelado')"
              >
                <X /> Cancelar turno
              </button>
            </div>
          </div>
        </div>

        <div v-else class="dias-semana">
          <div v-for="dia in turnosPorDia" :key="dia.fecha" class="dia-semana">
            <h3 :class="{ hoy: dia.fecha === hoyISO }">
              {{ etiquetaDia(dia.fecha) }}
            </h3>
            <div v-for="turno in dia.turnos" :key="turno.id" class="fila-turno">
              <time>{{ turno.hora_inicio.slice(0, 5) }}</time>
              <div class="linea-turno" :class="colorEstado(turno.estado)"></div>
              <div class="info-turno">
                <strong>
                  {{ turno.mascota?.nombre || "Mascota" }}
                  <span>· {{ turno.servicio?.nombre || "Sin servicio" }}</span>
                </strong>
                <small>{{
                  turno.mascota?.clientes?.nombre_completo || "Sin dueño"
                }}</small>
              </div>
              <span class="estado" :class="colorEstado(turno.estado)">{{
                turno.estado
              }}</span>
              <span></span>
            </div>
          </div>
        </div>

        <button class="boton-texto" @click="seleccionarVistaPanel('consultas')">
          Ver consultas <span><ArrowRight /></span>
        </button>
      </section>

      <aside class="panel panel-alertas">
        <div class="encabezado-panel">
          <div>
            <h2>Para tener en cuenta</h2>
            <p class="texto-atenuado">Seguimiento de pacientes</p>
          </div>
          <span class="insignia-conteo">{{
            vacunasProximas.length +
            (pendientesHoy ? 1 : 0) +
            (controlesVencidos ? 1 : 0)
          }}</span>
        </div>

        <div
          v-for="vacuna in vacunasProximas"
          :key="vacuna.id"
          class="fila-alerta"
        >
          <span class="icono-alerta vacuna"><Syringe /></span>
          <div>
            <strong>Vacuna próxima a vencer</strong>
            <small
              >{{ vacuna.mascota?.nombre || "Paciente" }} ·
              {{ vacuna.nombre }}</small
            >
            <button @click="seleccionarVistaPanel('mascotas')">
              Ver ficha <ArrowRight />
            </button>
          </div>
        </div>

        <div v-if="pendientesHoy" class="fila-alerta">
          <span class="icono-alerta control"><Clock /></span>
          <div>
            <strong>Turnos pendientes de confirmar</strong>
            <small
              >{{ pendientesHoy }}
              {{
                pendientesHoy === 1 ? "turno requiere" : "turnos requieren"
              }}
              acción</small
            >
            <button @click="revisarPendientes">Revisar <ArrowRight /></button>
          </div>
        </div>

        <div v-if="controlesVencidos" class="fila-alerta">
          <span class="icono-alerta nota"><Stethoscope /></span>
          <div>
            <strong>Controles vencidos</strong>
            <small
              >{{ controlesVencidos }}
              {{
                controlesVencidos === 1
                  ? "control vencido"
                  : "controles vencidos"
              }}</small
            >
            <button @click="seleccionarVistaPanel('consultas')">
              Ver consultas <ArrowRight />
            </button>
          </div>
        </div>

        <div
          v-if="!vacunasProximas.length && !pendientesHoy && !controlesVencidos"
          class="estado-vacio"
        >
          <span class="icono-vacio"><Check /></span>
          <strong>Sin novedades</strong>
          <p>No hay alertas pendientes por ahora.</p>
        </div>
      </aside>
    </div>

    <div
      v-if="mostrarNuevo"
      class="fondo-modal"
      @click.self="mostrarNuevo = false"
    >
      <section class="ventana-reserva">
        <button
          class="cerrar-modal"
          aria-label="Cerrar"
          @click="mostrarNuevo = false"
        >
          <X />
        </button>
        <p class="sobretitulo">NUEVO TURNO</p>
        <h2>Reservar un turno</h2>
        <p class="texto-atenuado">
          Elegí la mascota, el servicio y el horario.
        </p>

        <div
          v-if="!mascotas.length"
          class="nota-modal"
          style="margin-top: 16px"
        >
          Todavía no hay mascotas registradas.
          <button
            class="boton-texto"
            style="margin-left: 6px"
            @click="
              mostrarNuevo = false;
              seleccionarVistaPanel('mascotas');
            "
          >
            Ir a Mascotas <ArrowRight />
          </button>
        </div>

        <div
          v-else-if="!servicios.length"
          class="nota-modal"
          style="margin-top: 16px"
        >
          Todavía no hay servicios cargados.
          <button
            class="boton-texto"
            style="margin-left: 6px"
            :disabled="guardando"
            @click="crearServiciosBasicos"
          >
            Crear servicios básicos
          </button>
        </div>

        <form v-else class="formulario-modal" @submit.prevent="guardarTurno">
          <label>
            Mascota
            <select v-model="formulario.mascotaId">
              <option value="" disabled>Elegí una mascota</option>
              <option v-for="m in mascotas" :key="m.id" :value="m.id">
                {{ m.nombre }} · {{ m.especie
                }}<template v-if="m.raza"> · {{ m.raza }}</template>
              </option>
            </select>
          </label>

          <label>
            Servicio
            <select v-model="formulario.servicioId">
              <option value="" disabled>Elegí un servicio</option>
              <option v-for="s in servicios" :key="s.id" :value="s.id">
                {{ s.nombre }} ({{ s.duracion_minutos }} min)
              </option>
            </select>
          </label>

          <div class="fila">
            <label>
              Fecha
              <input v-model="formulario.fecha" type="date" />
            </label>
            <label>
              Hora de inicio
              <input v-model="formulario.hora" type="time" step="900" />
            </label>
          </div>

          <label>
            Motivo (opcional)
            <input
              v-model="formulario.motivo"
              type="text"
              maxlength="160"
              placeholder="Ej: control anual"
            />
          </label>

          <p v-if="formulario.servicioId" class="nota-modal">
            El turno durará
            {{
              servicios.find((s) => s.id === formulario.servicioId)
                ?.duracion_minutos || 30
            }}
            minutos (de {{ formulario.hora }} a {{ horaFin }}).
          </p>

          <p v-if="errorFormulario" class="error-modal">
            <TriangleAlert /> {{ errorFormulario }}
          </p>

          <div class="acciones-modal">
            <button
              type="button"
              class="boton-contorno"
              @click="mostrarNuevo = false"
            >
              Cancelar
            </button>
            <button type="submit" class="boton-principal" :disabled="guardando">
              <Plus /> {{ guardando ? "Guardando..." : "Crear turno" }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </section>
</template>

<style scoped>
.menu-turno {
  position: absolute;
  right: 14px;
  z-index: 3;
  display: grid;
  gap: 3px;
  min-width: 185px;
  padding: 7px;
  border: 1px solid var(--borde);
  border-radius: 9px;
  background: #fff;
  box-shadow: 0 12px 30px #143b2725;
}
.menu-turno button {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 9px;
  border-radius: 6px;
  color: var(--tinta);
  font-size: 11px;
  font-weight: 700;
  text-align: left;
}
.menu-turno button:hover:not(:disabled) {
  background: #eff8e9;
}
.menu-turno button.rojo {
  color: #ae5757;
}
.menu-turno button.rojo:hover:not(:disabled) {
  background: #fbeaea;
}
.menu-turno button:disabled {
  opacity: 0.5;
  cursor: default;
}
.fila-turno {
  position: relative;
}

.filtro-activo {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin: 12px 0 4px;
  padding: 8px 11px;
  border: 1px solid var(--borde);
  border-radius: 8px;
  background: #eff8e9;
  color: var(--verde-oscuro);
  font-size: 11px;
  font-weight: 700;
}
.filtro-activo button {
  display: flex;
  align-items: center;
  gap: 4px;
  border: 0;
  background: none;
  color: var(--verde-oscuro);
  font-size: 11px;
  font-weight: 800;
  cursor: pointer;
}
.filtro-activo button svg {
  width: 13px;
  height: 13px;
}
.filtro-activo button:hover {
  text-decoration: underline;
}

.dias-semana {
  display: grid;
  gap: 16px;
  margin: 18px 0 9px;
}
.dia-semana h3 {
  padding: 7px 11px;
  border-radius: 7px;
  color: var(--atenuado);
  background: #f8faf7;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.7px;
  text-transform: uppercase;
}
.dia-semana h3.hoy {
  color: var(--verde-oscuro);
  background: #eff8e9;
}
.dia-semana .fila-turno:first-of-type {
  border-top: 0;
}
</style>
