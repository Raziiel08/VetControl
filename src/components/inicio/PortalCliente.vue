<script setup>
import {
  ArrowLeft,
  ArrowRight,
  CalendarDays,
  Check,
  Clock,
  Hand,
  Home,
  Info,
  LogOut,
  Menu,
  Package,
  PawPrint,
  Plus,
  ShoppingBag,
  ShoppingCart,
  Stethoscope,
  Syringe,
  TriangleAlert,
  X,
} from "lucide-vue-next";
import { computed, onMounted, onUnmounted, ref } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "@/supabase";
import { useUsuario } from "@/composables/useUsuario";
import { useToast } from "@/composables/useToast";
import { traducirError } from "@/utils/errores";
import { isoLocal } from "@/utils/fechas";

const enrutador = useRouter();
const {
  correo: usuarioCorreo,
  inicial: usuarioInicial,
  cerrarSesion: salir,
} = useUsuario();
const { notificar } = useToast();

const vistaCliente = ref("inicio");
const mostrarReserva = ref(false);
const pasoReserva = ref(1);
const menuMovil = ref(false);

const productosTienda = ref([]);
const carrito = ref([]);
const pedidosCliente = ref([]);
const cargandoProductos = ref(false);
const confirmandoCompra = ref(false);
const mostrarCarrito = ref(false);

const clienteId = ref(null);
const nombreCliente = ref("");
const mascotas = ref([]);
const turnos = ref([]);
const servicios = ref([]);
const consultasMascota = ref([]);
const vacunasMascota = ref([]);
const cargando = ref(true);
const vinculando = ref(false);
const errorPortal = ref("");
let canalPedidos = null;

const mascotaSeleccionadaId = ref("");

const guardando = ref(false);
const errorReserva = ref("");
const reserva = ref({
  mascotaId: "",
  servicioId: "",
  fecha: "",
  hora: "09:00",
});

const hoyISO = isoLocal();

const HORARIOS = [
  "09:00",
  "09:30",
  "10:00",
  "10:30",
  "11:00",
  "11:30",
  "12:00",
  "15:00",
  "15:30",
  "16:00",
  "16:30",
  "17:00",
];

const mascotaSeleccionada = computed(
  () =>
    mascotas.value.find((m) => m.id === mascotaSeleccionadaId.value) || null,
);

const proximoTurno = computed(() => {
  const futuros = turnos.value
    .filter((t) => t.fecha >= hoyISO && t.estado !== "Cancelado")
    .sort((a, b) =>
      (a.fecha + a.hora_inicio).localeCompare(b.fecha + b.hora_inicio),
    );
  return futuros[0] || null;
});

const turnosFuturos = computed(() =>
  turnos.value
    .filter((t) => t.fecha >= hoyISO && t.estado !== "Cancelado")
    .sort((a, b) =>
      (a.fecha + a.hora_inicio).localeCompare(b.fecha + b.hora_inicio),
    ),
);

const turnosPasados = computed(() =>
  turnos.value
    .filter((t) => t.fecha < hoyISO || t.estado === "Cancelado")
    .sort((a, b) =>
      (b.fecha + b.hora_inicio).localeCompare(a.fecha + a.hora_inicio),
    ),
);

const totalCarrito = computed(() =>
  carrito.value.reduce(
    (suma, item) => suma + Number(item.precio) * item.cantidad,
    0,
  ),
);

const unidadesCarrito = computed(() =>
  carrito.value.reduce((suma, item) => suma + item.cantidad, 0),
);

function iniciales(nombre = "?") {
  return nombre
    .split(" ")
    .map((n) => n[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

function edadDe(fechaNacimiento) {
  if (!fechaNacimiento) return "";
  const nacimiento = new Date(fechaNacimiento + "T12:00:00");
  const anios = Math.floor(
    (Date.now() - nacimiento.getTime()) / (365.25 * 24 * 3600 * 1000),
  );
  if (anios < 1) {
    const meses = Math.max(
      1,
      Math.floor((Date.now() - nacimiento.getTime()) / (30 * 24 * 3600 * 1000)),
    );
    return `${meses} ${meses === 1 ? "mes" : "meses"}`;
  }
  return `${anios} ${anios === 1 ? "año" : "años"}`;
}

function colorEstado(estado) {
  if (
    estado === "Confirmado" ||
    estado === "Atendido" ||
    estado === "Entregado"
  )
    return "verde";
  if (estado === "Cancelado") return "rojo";
  return "amarillo";
}

function fechaLarga(iso) {
  if (!iso) return "";
  const fecha = new Date(iso + "T12:00:00");
  if (isNaN(fecha.getTime())) return String(iso);
  return new Intl.DateTimeFormat("es-AR", {
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(fecha);
}

function mesCorto(iso) {
  if (!iso) return "";
  return new Intl.DateTimeFormat("es-AR", { month: "short" })
    .format(new Date(iso + "T12:00:00"))
    .replace(".", "")
    .toUpperCase();
}

const horaFinTurno = computed(() => {
  const servicio = servicios.value.find(
    (s) => s.id === reserva.value.servicioId,
  );
  const duracion = servicio?.duracion_minutos || 30;
  const [h, m] = reserva.value.hora.split(":").map(Number);
  const minutosTotales = h * 60 + m + duracion;
  return `${String(Math.floor(minutosTotales / 60) % 24).padStart(2, "0")}:${String(minutosTotales % 60).padStart(2, "0")}`;
});

async function cargar() {
  cargando.value = true;
  errorPortal.value = "";
  try {
    let id = null;
    const { data: rpcVincular, error: errVincular } = await supabase.rpc(
      "vincular_mi_cliente",
    );
    if (!errVincular) {
      id = rpcVincular;
    } else {
      const { data: rpcObtener, error: errObtener } = await supabase.rpc(
        "obtener_mi_cliente_id",
      );
      if (!errObtener) id = rpcObtener;
    }

    if (!id) {
      const {
        data: { user: usuario },
      } = await supabase.auth.getUser();
      const { data: fila, error: errFila } = await supabase
        .from("clientes")
        .select("id")
        .eq("email", usuario?.email || "")
        .limit(1)
        .maybeSingle();
      if (!errFila) id = fila?.id ?? null;
    }

    clienteId.value = id;
    nombreCliente.value = "";

    if (!id) {
      mascotas.value = [];
      turnos.value = [];
      suscribirPedidos(null);
      return;
    }
    suscribirPedidos(id);

    const { data: filaCliente, error: errCliente } = await supabase
      .from("clientes")
      .select("nombre_completo, veterinaria_id")
      .eq("id", id)
      .limit(1)
      .maybeSingle();
    if (!errCliente) nombreCliente.value = filaCliente?.nombre_completo || "";
    const veterinariaCliente = filaCliente?.veterinaria_id || null;

    let consultaServicios = supabase
      .from("servicios")
      .select("id, nombre, descripcion, duracion_minutos")
      .eq("activo", true)
      .order("nombre");
    if (veterinariaCliente)
      consultaServicios = consultaServicios.eq(
        "veterinaria_id",
        veterinariaCliente,
      );

    const [mascotasRes, serviciosRes] = await Promise.all([
      supabase
        .from("mascotas")
        .select(
          "id, nombre, especie, raza, fecha_nacimiento, peso_kg, alergias, observaciones",
        )
        .eq("cliente_id", id)
        .order("nombre"),
      consultaServicios,
    ]);
    if (mascotasRes.error) throw mascotasRes.error;
    mascotas.value = mascotasRes.data || [];
    if (!serviciosRes.error) servicios.value = serviciosRes.data || [];

    if (mascotas.value.length) {
      const ids = mascotas.value.map((m) => m.id);
      const { data, error } = await supabase
        .from("turnos")
        .select(
          "id, fecha, hora_inicio, hora_fin, estado, motivo, mascota_id, servicio:servicios(nombre, duracion_minutos), mascotas(nombre)",
        )
        .in("mascota_id", ids)
        .order("fecha", { ascending: false })
        .limit(50);
      if (!error) turnos.value = data || [];
    } else {
      turnos.value = [];
    }

    await Promise.all([cargarProductos(), cargarPedidos()]);
  } catch (e) {
    errorPortal.value = traducirError(e.message);
  } finally {
    cargando.value = false;
  }
}

async function vincularCuenta() {
  vinculando.value = true;
  try {
    const { data, error } = await supabase.rpc("vincular_mi_cliente");
    if (error) throw error;
    if (!data) {
      notificar(
        "No encontramos un cliente con tu correo. Pedí el alta en tu veterinaria.",
      );
      return;
    }
    notificar("Cuenta vinculada correctamente");
    await cargar();
  } catch (e) {
    notificar(traducirError(e.message));
  } finally {
    vinculando.value = false;
  }
}

function verFicha(mascota) {
  mascotaSeleccionadaId.value = mascota.id;
  vistaCliente.value = "historial-mascota";
  cargarHistorial(mascota.id);
}

function irAMascotas() {
  if (!mascotaSeleccionadaId.value && mascotas.value.length) {
    mascotaSeleccionadaId.value = mascotas.value[0].id;
    cargarHistorial(mascotas.value[0].id);
  }
  vistaCliente.value = "historial-mascota";
}

async function cargarHistorial(mascotaId) {
  consultasMascota.value = [];
  vacunasMascota.value = [];
  const [consultasRes, vacunasRes] = await Promise.all([
    supabase
      .from("consultas")
      .select("id, fecha, motivo, diagnostico, tratamiento, proximo_control")
      .eq("mascota_id", mascotaId)
      .order("fecha", { ascending: false })
      .limit(10),
    supabase
      .from("vacunas")
      .select("id, nombre, dosis, fecha_aplicacion, fecha_proxima")
      .eq("mascota_id", mascotaId)
      .order("fecha_aplicacion", { ascending: false })
      .limit(10),
  ]);
  if (!consultasRes.error) consultasMascota.value = consultasRes.data || [];
  if (!vacunasRes.error) vacunasMascota.value = vacunasRes.data || [];
}

function abrirReserva(mascota = null) {
  errorReserva.value = "";
  reserva.value = {
    mascotaId:
      mascota?.id || mascotaSeleccionadaId.value || mascotas.value[0]?.id || "",
    servicioId: servicios.value[0]?.id || "",
    fecha: hoyISO,
    hora: "09:00",
  };
  pasoReserva.value = 1;
  mostrarReserva.value = true;
}

function siguientePasoReserva() {
  errorReserva.value = "";
  if (pasoReserva.value === 1 && !reserva.value.servicioId) {
    errorReserva.value = "Elegí un servicio.";
    return;
  }
  if (pasoReserva.value === 2) {
    if (!reserva.value.mascotaId) {
      errorReserva.value = "Elegí tu mascota.";
      return;
    }
    if (!reserva.value.fecha) {
      errorReserva.value = "Elegí una fecha.";
      return;
    }
  }
  if (pasoReserva.value < 3) {
    pasoReserva.value += 1;
    return;
  }
  guardarReserva();
}

async function guardarReserva() {
  guardando.value = true;
  errorReserva.value = "";
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc(
      "obtener_mi_veterinaria_id",
    );
    if (errVet) throw errVet;

    const { error } = await supabase.from("turnos").insert({
      veterinaria_id: veterinariaId,
      mascota_id: reserva.value.mascotaId,
      servicio_id: reserva.value.servicioId,
      fecha: reserva.value.fecha,
      hora_inicio: reserva.value.hora,
      hora_fin: horaFinTurno.value,
      estado: "Pendiente",
    });
    if (error) throw error;

    mostrarReserva.value = false;
    vistaCliente.value = "turnos";
    notificar("Turno solicitado correctamente");
    await cargar();
  } catch (e) {
    pasoReserva.value = 2;
    errorReserva.value = traducirError(e.message);
  } finally {
    guardando.value = false;
  }
}

async function cancelarTurno(turno) {
  if (!window.confirm("¿Querés cancelar este turno?")) return;
  try {
    const { data, error } = await supabase
      .from("turnos")
      .update({ estado: "Cancelado" })
      .eq("id", turno.id)
      .select("id");
    if (error) throw error;
    if (!data?.length)
      throw new Error("No tenés permiso para cancelar este turno.");
    notificar("Turno cancelado");
    await cargar();
  } catch (e) {
    notificar(traducirError(e.message));
  }
}

async function cargarProductos() {
  cargandoProductos.value = true;
  const { data, error } = await supabase
    .from("productos")
    .select("id, nombre, descripcion, precio, stock, activo, imagen_url")
    .eq("activo", true)
    .order("nombre");
  if (!error) productosTienda.value = data || [];
  cargandoProductos.value = false;
}

async function cargarPedidos() {
  const { data, error } = await supabase
    .from("pedidos")
    .select(
      "id, total, estado, creado_en, detalles:pedido_detalles(cantidad, precio_unitario, producto:productos(nombre))",
    )
    .order("creado_en", { ascending: false })
    .limit(10);
  if (!error) pedidosCliente.value = data || [];
}

function suscribirPedidos(clienteIdPedido) {
  if (canalPedidos) {
    supabase.removeChannel(canalPedidos);
  }
  if (!clienteIdPedido) return;

  canalPedidos = supabase
    .channel(`pedidos-cliente-${clienteIdPedido}`)
    .on(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table: "pedidos",
        filter: `cliente_id=eq.${clienteIdPedido}`,
      },
      cargarPedidos,
    )
    .subscribe();
}

function agregarAlCarrito(producto) {
  const existente = carrito.value.find((i) => i.producto_id === producto.id);
  if (existente) {
    if (existente.cantidad >= producto.stock) {
      notificar(`Solo hay ${producto.stock} unidades de ${producto.nombre}`);
      return;
    }
    existente.cantidad += 1;
    return;
  }
  carrito.value.push({
    producto_id: producto.id,
    nombre: producto.nombre,
    precio: Number(producto.precio),
    stock: producto.stock,
    cantidad: 1,
  });
}

function cambiarCantidad(item, delta) {
  const nueva = item.cantidad + delta;
  if (nueva < 1) {
    quitarDelCarrito(item);
    return;
  }
  if (nueva > item.stock) {
    notificar(`Solo hay ${item.stock} unidades de ${item.nombre}`);
    return;
  }
  item.cantidad = nueva;
}

function quitarDelCarrito(item) {
  carrito.value = carrito.value.filter(
    (i) => i.producto_id !== item.producto_id,
  );
}

async function confirmarCompra() {
  if (!carrito.value.length) return;
  confirmandoCompra.value = true;
  try {
    const items = carrito.value.map((i) => ({
      producto_id: i.producto_id,
      cantidad: i.cantidad,
    }));
    const { data, error } = await supabase.rpc("registrar_compra", {
      p_items: items,
    });
    if (error) throw error;

    carrito.value = [];
    mostrarCarrito.value = false;
    notificar("Compra realizada correctamente. Retiralo en la veterinaria.");
    await Promise.all([cargarProductos(), cargarPedidos()]);
  } catch (e) {
    notificar(traducirError(e.message));
    await cargarProductos();
  } finally {
    confirmandoCompra.value = false;
  }
}

async function cerrarSesion() {
  try {
    await salir();
  } finally {
    enrutador.push("/login");
  }
}

function actualizarAlReactivar() {
  if (document.visibilityState === "visible") {
    cargar();
  }
}

onMounted(() => {
  cargar();
  document.addEventListener("visibilitychange", actualizarAlReactivar);
});

onUnmounted(() => {
  document.removeEventListener("visibilitychange", actualizarAlReactivar);
  if (canalPedidos) supabase.removeChannel(canalPedidos);
});

defineExpose({
  abrirMenu: () => {
    menuMovil.value = true;
  },
});
</script>

<template>
  <div class="distribucion-cliente">
    <aside class="barra-cliente">
      <div class="perfil-cliente">
        <div class="avatar">{{ usuarioInicial }}</div>
        <div>
          <strong>{{ usuarioCorreo || "Usuario" }}</strong>
          <small>Cuenta personal</small>
        </div>
      </div>
      <nav>
        <button
          :class="{ activo: vistaCliente === 'inicio' }"
          @click="vistaCliente = 'inicio'"
        >
          <Home /> <span>Inicio</span>
        </button>
        <button
          :class="{ activo: vistaCliente === 'historial-mascota' }"
          @click="irAMascotas()"
        >
          <PawPrint /> <span>Mis mascotas</span>
        </button>
        <button
          :class="{ activo: vistaCliente === 'turnos' }"
          @click="vistaCliente = 'turnos'"
        >
          <CalendarDays /> <span>Mis turnos</span>
        </button>
        <button
          :class="{ activo: vistaCliente === 'productos' }"
          @click="vistaCliente = 'productos'"
        >
          <ShoppingBag /> <span>Tienda</span>
        </button>
      </nav>
      <button class="cerrar-sesion" @click="cerrarSesion()">
        <LogOut /> <span>Cerrar sesión</span>
      </button>
    </aside>

    <main class="contenido-cliente">
      <div class="encabezado-movil-cliente">
        <nav class="navegacion-movil-cliente">
          <button
            :class="{ activo: vistaCliente === 'inicio' }"
            @click="vistaCliente = 'inicio'"
          >
            <Home /> <span>Inicio</span>
          </button>
          <button
            :class="{ activo: vistaCliente === 'historial-mascota' }"
            @click="irAMascotas()"
          >
            <PawPrint /> <span>Mis mascotas</span>
          </button>
          <button
            :class="{ activo: vistaCliente === 'turnos' }"
            @click="vistaCliente = 'turnos'"
          >
            <CalendarDays /> <span>Mis turnos</span>
          </button>
          <button
            :class="{ activo: vistaCliente === 'productos' }"
            @click="vistaCliente = 'productos'"
          >
            <ShoppingBag /> <span>Tienda</span>
          </button>
        </nav>
        <button
          class="boton-menu-cliente"
          aria-label="Abrir menú de cuenta"
          @click="menuMovil = true"
        >
          <Menu />
        </button>
      </div>

      <div v-if="menuMovil" class="fondo-cajon" @click.self="menuMovil = false">
        <aside class="barra-cliente cajon">
          <button
            class="cerrar-cajon"
            aria-label="Cerrar menú"
            @click="menuMovil = false"
          >
            <X />
          </button>
          <div class="perfil-cliente">
            <div class="avatar">{{ usuarioInicial }}</div>
            <div>
              <strong>{{ usuarioCorreo || "Usuario" }}</strong>
              <small>Cuenta personal</small>
            </div>
          </div>
          <nav>
            <button
              :class="{ activo: vistaCliente === 'inicio' }"
              @click="
                vistaCliente = 'inicio';
                menuMovil = false;
              "
            >
              <Home /> <span>Inicio</span>
            </button>
            <button
              :class="{ activo: vistaCliente === 'historial-mascota' }"
              @click="
                irAMascotas();
                menuMovil = false;
              "
            >
              <PawPrint /> <span>Mis mascotas</span>
            </button>
            <button
              :class="{ activo: vistaCliente === 'turnos' }"
              @click="
                vistaCliente = 'turnos';
                menuMovil = false;
              "
            >
              <CalendarDays /> <span>Mis turnos</span>
            </button>
            <button
              :class="{ activo: vistaCliente === 'productos' }"
              @click="
                vistaCliente = 'productos';
                menuMovil = false;
              "
            >
              <ShoppingBag /> <span>Tienda</span>
            </button>
          </nav>
          <button class="cerrar-sesion" @click="cerrarSesion()">
            <LogOut /> <span>Cerrar sesión</span>
          </button>
        </aside>
      </div>

      <section v-if="cargando" class="pagina-cliente">
        <div class="estado-vacio"><p>Cargando tu portal...</p></div>
      </section>

      <section v-else-if="!clienteId" class="pagina-cliente">
        <div class="banner-bienvenida">
          <div>
            <p class="sobretitulo">PORTAL DEL CLIENTE</p>
            <h1>
              Hola <span><Hand /></span>
            </h1>
            <p>Todo el cuidado de tus mascotas, en un solo lugar.</p>
          </div>
          <span class="marca-banner"><Plus /></span>
        </div>
        <div class="panel estado-vacio">
          <span class="icono-vacio"><Info /></span>
          <strong>Tu cuenta todavía no está vinculada a una ficha</strong>
          <p>
            Si ya sos cliente de una veterinaria, vinculá tu cuenta para ver tus
            mascotas y turnos. Si no, pedile el alta a tu veterinaria.
          </p>
          <button
            class="boton-principal"
            style="margin-top: 12px"
            :disabled="vinculando"
            @click="vincularCuenta"
          >
            <Check /> {{ vinculando ? "Vinculando..." : "Vincular mi cuenta" }}
          </button>
        </div>
      </section>

      <section v-else-if="vistaCliente === 'inicio'" class="pagina-cliente">
        <div class="banner-bienvenida">
          <div>
            <p class="sobretitulo">PORTAL DEL CLIENTE</p>
            <h1>
              Hola{{ nombreCliente ? `, ${nombreCliente}` : "" }}
              <span><Hand /></span>
            </h1>
            <p>Todo el cuidado de tus mascotas, en un solo lugar.</p>
          </div>
          <span class="marca-banner"><Plus /></span>
        </div>

        <div class="encabezado-pagina encabezado-cliente">
          <div>
            <h2>Mis mascotas</h2>
            <p class="texto-atenuado">
              Elegí una mascota para consultar su historia.
            </p>
          </div>
        </div>

        <div v-if="!mascotas.length" class="panel estado-vacio">
          <span class="icono-vacio"><PawPrint /></span>
          <strong>No tenés mascotas registradas</strong>
          <p>
            Pedile a tu veterinaria que cargue tus mascotas para verlas acá.
          </p>
        </div>

        <div v-else class="tarjetas-mascota">
          <button
            v-for="mascota in mascotas"
            :key="mascota.id"
            class="tarjeta-mascota"
            @click="verFicha(mascota)"
          >
            <span class="avatar-mascota-grande lima">{{
              iniciales(mascota.nombre)
            }}</span>
            <span>
              <strong>{{ mascota.nombre }}</strong>
              <small>
                {{ mascota.especie
                }}<template v-if="mascota.raza"> · {{ mascota.raza }}</template>
                <template v-if="mascota.fecha_nacimiento">
                  · {{ edadDe(mascota.fecha_nacimiento) }}</template
                >
              </small>
              <em><Clock /> Ver ficha completa</em>
            </span>
            <b><ArrowRight /></b>
          </button>
        </div>

        <div class="columnas-cliente">
          <div>
            <div class="titulo-seccion">
              <h2>Próximo turno</h2>
              <button class="boton-texto" @click="vistaCliente = 'turnos'">
                Ver todos <ArrowRight />
              </button>
            </div>

            <div v-if="proximoTurno" class="panel proximo-turno">
              <div class="bloque-fecha">
                <strong>{{ proximoTurno.fecha.slice(8, 10) }}</strong>
                <small>{{ mesCorto(proximoTurno.fecha) }}</small>
              </div>
              <div>
                <strong>{{ proximoTurno.servicio?.nombre || "Turno" }}</strong>
                <p>
                  {{ proximoTurno.mascotas?.nombre || "Tu mascota" }} ·
                  {{ fechaLarga(proximoTurno.fecha) }} a las
                  {{ proximoTurno.hora_inicio.slice(0, 5) }}
                </p>
                <span
                  class="estado"
                  :class="colorEstado(proximoTurno.estado)"
                  >{{ proximoTurno.estado }}</span
                >
              </div>
              <button
                v-if="
                  proximoTurno.estado === 'Pendiente' ||
                  proximoTurno.estado === 'Confirmado'
                "
                class="menu-fila"
                aria-label="Cancelar turno"
                @click="cancelarTurno(proximoTurno)"
              >
                <X />
              </button>
            </div>

            <div v-else class="panel estado-vacio">
              <p>No tenés turnos próximos.</p>
              <button
                class="boton-texto"
                style="margin-top: 6px"
                @click="abrirReserva()"
              >
                Reservar uno <ArrowRight />
              </button>
            </div>
          </div>
        </div>
      </section>

      <section
        v-else-if="vistaCliente === 'historial-mascota'"
        class="pagina-cliente"
      >
        <button class="enlace-volver" @click="vistaCliente = 'inicio'">
          <ArrowLeft /> Volver a mis mascotas
        </button>

        <div v-if="mascotaSeleccionada" class="encabezado-perfil-mascota">
          <span class="avatar-mascota-grande lima">{{
            iniciales(mascotaSeleccionada.nombre)
          }}</span>
          <div>
            <p class="sobretitulo">FICHA DE MASCOTA</p>
            <h1>{{ mascotaSeleccionada.nombre }}</h1>
            <p class="texto-atenuado">
              {{ mascotaSeleccionada.especie
              }}<template v-if="mascotaSeleccionada.raza">
                · {{ mascotaSeleccionada.raza }}</template
              >
              <template v-if="mascotaSeleccionada.fecha_nacimiento">
                · {{ edadDe(mascotaSeleccionada.fecha_nacimiento) }}</template
              >
              <template v-if="mascotaSeleccionada.peso_kg">
                · {{ mascotaSeleccionada.peso_kg }} kg</template
              >
            </p>
          </div>
          <button
            class="boton-principal"
            @click="abrirReserva(mascotaSeleccionada)"
          >
            <Plus /> Reservar turno
          </button>
        </div>

        <div v-else class="panel estado-vacio">
          <span class="icono-vacio"><PawPrint /></span>
          <strong>Elegí una mascota</strong>
          <p>
            Tocá “Mis mascotas” en el menú y seleccioná el paciente que querés
            ver.
          </p>
        </div>

        <template v-if="mascotaSeleccionada">
          <div
            v-if="mascotaSeleccionada.alergias"
            class="error-modal"
            style="background: #fff4d3; color: #ad7615; margin-bottom: 14px"
          >
            <TriangleAlert /> Alergias: {{ mascotaSeleccionada.alergias }}
          </div>
          <p
            v-if="mascotaSeleccionada.observaciones"
            class="nota-modal"
            style="margin-bottom: 14px"
          >
            {{ mascotaSeleccionada.observaciones }}
          </p>

          <div class="cuadricula-historial">
            <div class="panel">
              <div class="encabezado-panel">
                <h2>Vacunas</h2>
                <span class="insignia-conteo">{{ vacunasMascota.length }}</span>
              </div>
              <div v-if="!vacunasMascota.length" class="estado-vacio">
                <p>Sin vacunas cargadas.</p>
              </div>
              <div
                v-for="v in vacunasMascota"
                :key="v.id"
                class="elemento-historial"
                :class="{
                  pendiente: v.fecha_proxima && v.fecha_proxima < hoyISO,
                }"
              >
                <span><Syringe /></span>
                <div>
                  <strong>{{ v.nombre }}</strong>
                  <p>Aplicada {{ fechaLarga(v.fecha_aplicacion) }}</p>
                  <b v-if="v.fecha_proxima"
                    >Próxima: {{ fechaLarga(v.fecha_proxima) }}</b
                  >
                </div>
              </div>
            </div>

            <div class="panel">
              <div class="encabezado-panel">
                <h2>Últimas consultas</h2>
                <span class="insignia-conteo">{{
                  consultasMascota.length
                }}</span>
              </div>
              <div v-if="!consultasMascota.length" class="estado-vacio">
                <p>Sin consultas registradas.</p>
              </div>
              <div
                v-for="c in consultasMascota"
                :key="c.id"
                class="elemento-historial"
              >
                <span><Stethoscope /></span>
                <div>
                  <strong>{{ c.motivo }}</strong>
                  <p>{{ fechaLarga(c.fecha) }}</p>
                  <b class="correcto">{{ c.diagnostico }}</b>
                </div>
              </div>
            </div>
          </div>
        </template>
      </section>

      <section
        v-else-if="vistaCliente === 'productos'"
        class="pagina-cliente"
      >
        <div class="encabezado-pagina encabezado-cliente">
          <div>
            <p class="sobretitulo">TIENDA</p>
            <h1>Productos</h1>
            <p class="texto-atenuado">
              Comprá lo que tengas disponible en tu veterinaria.
            </p>
          </div>
          <button
            class="boton-principal"
            :disabled="!carrito.length"
            @click="mostrarCarrito = true"
          >
            <ShoppingCart />
            Ver carrito
            <span class="insignia-conteo">{{ unidadesCarrito }}</span>
          </button>
        </div>

        <div v-if="cargandoProductos" class="panel estado-vacio">
          <p>Cargando productos...</p>
        </div>

        <div v-else-if="!productosTienda.length" class="panel estado-vacio">
          <span class="icono-vacio"><ShoppingBag /></span>
          <strong>No hay productos disponibles</strong>
          <p>Consultá en tu veterinaria los productos que tenemos para vos.</p>
        </div>

        <div v-else class="cuadricula-productos-cliente">
          <article
            v-for="producto in productosTienda"
            :key="producto.id"
            class="tarjeta-producto-cliente"
          >
            <div
              v-if="producto.imagen_url"
              class="imagen-producto-cliente"
              :style="{ backgroundImage: `url(${producto.imagen_url})` }"
            ></div>
            <div v-else class="imagen-producto-cliente sin-imagen">
              <Package />
            </div>
            <div class="datos-producto-cliente">
              <strong>{{ producto.nombre }}</strong>
              <p v-if="producto.descripcion">{{ producto.descripcion }}</p>
              <b>${{ Number(producto.precio).toFixed(2) }}</b>
              <small :class="{ agotado: producto.stock <= 0 }">
                {{
                  producto.stock > 0
                    ? `${producto.stock} disponibles`
                    : "Sin stock"
                }}
              </small>
            </div>
            <button
              class="boton-contorno"
              :disabled="producto.stock <= 0"
              @click="agregarAlCarrito(producto)"
            >
              <Plus />
              {{
                carrito.find((i) => i.producto_id === producto.id)
                  ? "Agregado"
                  : producto.stock <= 0
                    ? "Sin stock"
                    : "Agregar"
              }}
            </button>
          </article>
        </div>

        <div class="titulo-seccion" style="margin-top: 30px">
          <h2>Mis compras</h2>
        </div>
        <div v-if="!pedidosCliente.length" class="panel estado-vacio">
          <p>Todavía no hiciste ninguna compra.</p>
        </div>
        <div v-else class="panel lista-reservas">
          <div
            v-for="pedido in pedidosCliente"
            :key="pedido.id"
            class="elemento-reserva"
          >
            <div class="bloque-fecha">
              <strong>{{ pedido.creado_en.slice(8, 10) }}</strong>
              <small>{{ mesCorto(pedido.creado_en.slice(0, 10)) }}</small>
            </div>
            <div>
              <strong>${{ Number(pedido.total).toFixed(2) }}</strong>
              <p>
                {{
                  pedido.detalles
                    .map(
                      (d) => `${d.cantidad} × ${d.producto?.nombre || "producto"}`,
                    )
                    .join(", ")
                }}
              </p>
            </div>
            <span class="estado" :class="colorEstado(pedido.estado)">{{
              pedido.estado
            }}</span>
            <span></span>
          </div>
        </div>
      </section>

      <section v-else class="pagina-cliente">
        <div class="encabezado-pagina">
          <div>
            <p class="sobretitulo">RESERVAS</p>
            <h1>Mis turnos</h1>
            <p class="texto-atenuado">
              Consultá tus turnos próximos y anteriores.
            </p>
          </div>
          <button class="boton-principal" @click="abrirReserva()">
            <Plus /> Reservar turno
          </button>
        </div>

        <div v-if="!turnos.length" class="panel estado-vacio">
          <span class="icono-vacio"><CalendarDays /></span>
          <strong>No tenés turnos</strong>
          <p>Reservá tu primer turno con el botón de arriba.</p>
        </div>

        <template v-else>
          <div v-if="turnosFuturos.length" class="panel lista-reservas">
            <div
              v-for="turno in turnosFuturos"
              :key="turno.id"
              class="elemento-reserva"
            >
              <div class="bloque-fecha">
                <strong>{{ turno.fecha.slice(8, 10) }}</strong>
                <small>{{ mesCorto(turno.fecha) }}</small>
              </div>
              <div>
                <strong>{{ turno.servicio?.nombre || "Turno" }}</strong>
                <p>
                  {{ turno.mascotas?.nombre || "Tu mascota" }} ·
                  {{ turno.hora_inicio.slice(0, 5) }}
                  <template v-if="turno.motivo"> · {{ turno.motivo }}</template>
                </p>
              </div>
              <span class="estado" :class="colorEstado(turno.estado)">{{
                turno.estado
              }}</span>
              <button
                v-if="
                  turno.estado === 'Pendiente' || turno.estado === 'Confirmado'
                "
                class="menu-fila"
                :aria-label="'Cancelar turno del ' + turno.fecha"
                @click="cancelarTurno(turno)"
              >
                <X />
              </button>
            </div>
          </div>

          <div v-if="turnosPasados.length" style="margin-top: 22px">
            <div class="titulo-seccion"><h2>Anteriores</h2></div>
            <div class="panel lista-reservas" style="margin-top: 10px">
              <div
                v-for="turno in turnosPasados"
                :key="turno.id"
                class="elemento-reserva"
                style="opacity: 0.72"
              >
                <div class="bloque-fecha">
                  <strong>{{ turno.fecha.slice(8, 10) }}</strong>
                  <small>{{ mesCorto(turno.fecha) }}</small>
                </div>
                <div>
                  <strong>{{ turno.servicio?.nombre || "Turno" }}</strong>
                  <p>
                    {{ turno.mascotas?.nombre || "Tu mascota" }} ·
                    {{ turno.hora_inicio.slice(0, 5) }}
                  </p>
                </div>
                <span class="estado" :class="colorEstado(turno.estado)">{{
                  turno.estado
                }}</span>
                <span></span>
              </div>
            </div>
          </div>
        </template>
      </section>
    </main>

    <div
      v-if="mostrarReserva"
      class="fondo-modal"
      @click.self="mostrarReserva = false"
    >
      <section class="ventana-reserva">
        <button
          class="cerrar-modal"
          aria-label="Cerrar"
          @click="mostrarReserva = false"
        >
          <X />
        </button>
        <div class="progreso-modal">
          <span
            :class="{ completado: pasoReserva >= 1, activo: pasoReserva === 1 }"
            >1</span
          ><i></i>
          <span
            :class="{ completado: pasoReserva >= 2, activo: pasoReserva === 2 }"
            >2</span
          ><i></i>
          <span
            :class="{ completado: pasoReserva >= 3, activo: pasoReserva === 3 }"
            >3</span
          >
        </div>
        <p class="sobretitulo">RESERVAR TURNO</p>
        <h2>
          {{
            pasoReserva === 1
              ? "¿Qué necesitás para tu mascota?"
              : pasoReserva === 2
                ? "Elegí fecha y horario"
                : "Revisá tu solicitud"
          }}
        </h2>
        <p class="texto-atenuado">Paso {{ pasoReserva }} de 3</p>

        <div v-if="pasoReserva === 1" class="opciones-servicio">
          <div v-if="!servicios.length" class="nota-modal">
            Todavía no hay servicios disponibles para reservar.
          </div>
          <button
            v-for="s in servicios"
            :key="s.id"
            class="opcion-servicio"
            :class="{ seleccionado: reserva.servicioId === s.id }"
            @click="reserva.servicioId = s.id"
          >
            <span>
              <Syringe
                v-if="(s.nombre || '').toLowerCase().includes('vacun')"
              />
              <Clock
                v-else-if="(s.nombre || '').toLowerCase().includes('control')"
              />
              <Stethoscope v-else />
            </span>
            <span>
              <strong>{{ s.nombre }}</strong>
              <small>{{
                s.descripcion || `${s.duracion_minutos} minutos`
              }}</small>
            </span>
            <b v-if="reserva.servicioId === s.id"><Check /></b>
          </button>
        </div>

        <div v-else-if="pasoReserva === 2" class="selector-fecha">
          <label>
            Mascota
            <select v-model="reserva.mascotaId">
              <option value="" disabled>Elegí tu mascota</option>
              <option v-for="m in mascotas" :key="m.id" :value="m.id">
                {{ m.nombre }}
              </option>
            </select>
          </label>
          <label>
            Fecha
            <input v-model="reserva.fecha" type="date" :min="hoyISO" />
          </label>
          <div class="etiqueta-hora">Horarios disponibles</div>
          <div class="opciones-hora">
            <button
              v-for="hora in HORARIOS"
              :key="hora"
              :class="{ seleccionado: reserva.hora === hora }"
              @click="reserva.hora = hora"
            >
              {{ hora }}
            </button>
          </div>
        </div>

        <div v-else class="resumen-solicitud">
          <div>
            <span>Mascota</span>
            <strong>{{
              mascotas.find((m) => m.id === reserva.mascotaId)?.nombre || "—"
            }}</strong>
          </div>
          <div>
            <span>Servicio</span>
            <strong>{{
              servicios.find((s) => s.id === reserva.servicioId)?.nombre || "—"
            }}</strong>
          </div>
          <div>
            <span>Fecha y hora</span>
            <strong
              >{{ fechaLarga(reserva.fecha) }} · {{ reserva.hora }} —
              {{ horaFinTurno }}</strong
            >
          </div>
          <div class="nota-exito">
            <Check /> Vas a recibir la confirmación por correo.
          </div>
        </div>

        <p v-if="errorReserva" class="error-modal" style="margin-top: 14px">
          <TriangleAlert /> {{ errorReserva }}
        </p>

        <div class="acciones-modal">
          <button
            class="boton-contorno"
            @click="pasoReserva > 1 ? pasoReserva-- : (mostrarReserva = false)"
          >
            {{ pasoReserva > 1 ? "Atrás" : "Cancelar" }}
          </button>
          <button
            class="boton-principal"
            :disabled="guardando"
            @click="siguientePasoReserva"
          >
            {{
              pasoReserva === 3
                ? guardando
                  ? "Enviando..."
                  : "Solicitar turno"
                : "Continuar"
            }}
            <ArrowRight />
          </button>
        </div>
      </section>
    </div>

    <div
      v-if="mostrarCarrito"
      class="fondo-modal"
      @click.self="mostrarCarrito = false"
    >
      <section class="ventana-reserva">
        <button
          class="cerrar-modal"
          aria-label="Cerrar"
          @click="mostrarCarrito = false"
        >
          <X />
        </button>
        <p class="sobretitulo">TU CARRITO</p>
        <h2>Revisá tu compra</h2>

        <div v-if="!carrito.length" class="nota-modal">
          Tu carrito está vacío. Agregá productos desde la tienda.
        </div>

        <div v-else class="lista-carrito">
          <div v-for="item in carrito" :key="item.producto_id" class="fila-carrito">
            <div class="datos-fila-carrito">
              <strong>{{ item.nombre }}</strong>
              <p>${{ item.precio.toFixed(2) }} c/u</p>
            </div>
            <div class="control-cantidad">
              <button
                aria-label="Restar"
                @click="cambiarCantidad(item, -1)"
              >
                −
              </button>
              <span>{{ item.cantidad }}</span>
              <button
                aria-label="Sumar"
                :disabled="item.cantidad >= item.stock"
                @click="cambiarCantidad(item, 1)"
              >
                +
              </button>
            </div>
            <b>${{ (item.precio * item.cantidad).toFixed(2) }}</b>
            <button
              class="menu-fila"
              :aria-label="'Quitar ' + item.nombre"
              @click="quitarDelCarrito(item)"
            >
              <X />
            </button>
          </div>

          <div class="total-carrito">
            <span>Total</span>
            <strong>${{ totalCarrito.toFixed(2) }}</strong>
          </div>

          <p class="nota-modal">
            El stock se descuenta al confirmar. Retiralo en la veterinaria.
          </p>
        </div>

        <div class="acciones-modal">
          <button class="boton-contorno" @click="mostrarCarrito = false">
            Seguir comprando
          </button>
          <button
            class="boton-principal"
            :disabled="confirmandoCompra || !carrito.length"
            @click="confirmarCompra"
          >
            {{
              confirmandoCompra ? "Procesando..." : "Confirmar compra"
            }}
            <Check />
          </button>
        </div>
      </section>
    </div>
  </div>
</template>
