<script setup>
import {
  ArrowLeft,
  Check,
  ClipboardList,
  Home,
  LogOut,
  Package,
  Pencil,
  Plus,
  RefreshCw,
  Tag,
  TriangleAlert,
  X,
} from "lucide-vue-next";
import { onMounted, onUnmounted, ref, computed } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "@/supabase";
import { useUsuario } from "@/composables/useUsuario";
import { traducirError } from "@/utils/errores";

const enrutador = useRouter();

const {
  correo: usuarioCorreo,
  inicial: usuarioInicial,
  etiquetaRol,
  esAdministrador,
  cargar,
  cerrarSesion: salir,
} = useUsuario();

const productos = ref([]);
const nombre = ref("");
const descripcion = ref("");
const precio = ref("");
const stock = ref(0);
const activo = ref(true);
const archivoImagen = ref(null);
const vistaPrevia = ref("");
const imagenUrlExistente = ref("");
const imagenRutaExistente = ref("");
const inputImagen = ref(null);
const productoEditandoId = ref(null);
const cargando = ref(false);
const mensaje = ref("");
const errorMensaje = ref("");
const cerrandoSesion = ref(false);

const puedeEliminar = esAdministrador;

const busqueda = ref("");
const filtroEstado = ref("todos");
const orden = ref("recientes");

const productosFiltrados = computed(() => {
  const texto = busqueda.value.trim().toLowerCase();

  const lista = productos.value.filter((p) => {
    if (filtroEstado.value === "activos" && !p.activo) return false;
    if (filtroEstado.value === "inactivos" && p.activo) return false;
    if (texto && !p.nombre.toLowerCase().includes(texto)) return false;
    return true;
  });

  const copia = [...lista];
  switch (orden.value) {
    case "nombre":
      copia.sort((a, b) => a.nombre.localeCompare(b.nombre, "es"));
      break;
    case "precio":
      copia.sort((a, b) => Number(a.precio) - Number(b.precio));
      break;
    case "stock":
      copia.sort((a, b) => a.stock - b.stock);
      break;
    case "estado":
      copia.sort((a, b) => Number(b.activo) - Number(a.activo));
      break;
    default:
      copia.sort((a, b) => new Date(b.creado_en) - new Date(a.creado_en));
  }
  return copia;
});

async function cerrarSesion() {
  try {
    cerrandoSesion.value = true;
    await salir();
    enrutador.push("/login");
  } catch (error) {
    alert(error.message);
  } finally {
    cerrandoSesion.value = false;
  }
}

async function cargarProductos(limpiarMensaje = true) {
  cargando.value = true;
  errorMensaje.value = "";
  if (limpiarMensaje) mensaje.value = "";

  const { data, error } = await supabase
    .from("productos")
    .select("*")
    .order("creado_en", { ascending: false });

  if (error) {
    errorMensaje.value = traducirError(error.message);
  } else {
    productos.value = data || [];
  }
  cargando.value = false;
}

const movimientos = ref([]);
const movimientosDisponibles = ref(false);
const mostrarMovimiento = ref(false);
const guardandoMovimiento = ref(false);
const errorMovimiento = ref("");
const movimiento = ref({
  productoId: "",
  tipo: "Entrada",
  cantidad: 1,
  precioUnitario: "",
  motivo: "",
});

async function cargarMovimientos() {
  const { data, error } = await supabase
    .from("movimientos_stock")
    .select(
      "id, tipo, cantidad, precio_unitario, motivo, creado_en, producto:productos(nombre)",
    )
    .order("creado_en", { ascending: false })
    .limit(20);

  if (error) {
    movimientosDisponibles.value = false;
    movimientos.value = [];
    return;
  }
  movimientosDisponibles.value = true;
  movimientos.value = data || [];
}

const pedidos = ref([]);
const cargandoPedidos = ref(false);
let canalPedidos = null;

async function cargarPedidos() {
  cargandoPedidos.value = true;
  const { data, error } = await supabase
    .from('pedidos')
    .select('id, total, estado, creado_en, cliente:clientes(nombre_completo, email), detalles:pedido_detalles(cantidad, precio_unitario, producto:productos(nombre))')
    .order('creado_en', { ascending: false })
    .limit(30);
  if (!error) pedidos.value = data || [];
  cargandoPedidos.value = false;
}

async function cambiarEstadoPedido(pedido, nuevoEstado) {
  const { data, error } = await supabase
    .from('pedidos')
    .update({ estado: nuevoEstado })
    .eq('id', pedido.id)
    .select('id, estado')
    .single();
  if (error) { alert(traducirError(error.message)); return; }
  pedido.estado = data.estado;
}

function abrirMovimiento() {
  errorMovimiento.value = "";
  movimiento.value = {
    productoId: productos.value[0]?.id || "",
    tipo: "Entrada",
    cantidad: 1,
    precioUnitario: "",
    motivo: "",
  };
  mostrarMovimiento.value = true;
}

async function registrarMovimiento() {
  errorMovimiento.value = "";
  const cantidad = Number(movimiento.value.cantidad);
  if (!movimiento.value.productoId) {
    errorMovimiento.value = "Elegí un producto.";
    return;
  }
  if (!Number.isInteger(cantidad) || cantidad <= 0) {
    errorMovimiento.value =
      "La cantidad debe ser un número entero mayor a cero.";
    return;
  }

  guardandoMovimiento.value = true;
  try {
    const veterinariaId = await obtenerVeterinariaId();
    const { error } = await supabase.from("movimientos_stock").insert({
      veterinaria_id: veterinariaId,
      producto_id: movimiento.value.productoId,
      tipo: movimiento.value.tipo,
      cantidad,
      precio_unitario:
        movimiento.value.precioUnitario === ""
          ? null
          : Number(movimiento.value.precioUnitario),
      motivo: movimiento.value.motivo.trim() || null,
    });
    if (error) throw error;

    mostrarMovimiento.value = false;
    mensaje.value = "Movimiento registrado y stock actualizado.";
    await Promise.all([cargarProductos(false), cargarMovimientos()]);
  } catch (error) {
    errorMovimiento.value = traducirError(error.message);
  } finally {
    guardandoMovimiento.value = false;
  }
}

function fechaMovimiento(iso) {
  return new Intl.DateTimeFormat("es-AR", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(iso));
}

function seleccionarImagen(evento) {
  errorMensaje.value = "";
  const archivo = evento.target.files?.[0];
  if (!archivo) {
    archivoImagen.value = null;
    vistaPrevia.value = "";
    return;
  }

  const tiposPermitidos = ["image/jpeg", "image/png", "image/webp"];
  if (!tiposPermitidos.includes(archivo.type)) {
    errorMensaje.value = "La imagen debe ser JPG, PNG o WEBP.";
    evento.target.value = "";
    return;
  }

  if (archivo.size > 5 * 1024 * 1024) {
    errorMensaje.value = "La imagen no puede superar los 5 MB.";
    evento.target.value = "";
    return;
  }

  if (vistaPrevia.value) URL.revokeObjectURL(vistaPrevia.value);
  archivoImagen.value = archivo;
  vistaPrevia.value = URL.createObjectURL(archivo);
}

async function subirImagen(veterinariaId) {
  if (!archivoImagen.value) return null;

  if (!veterinariaId) {
    throw new Error("No hay un usuario autenticado.");
  }

  const extension = archivoImagen.value.name.split(".").pop().toLowerCase();
  const ruta = `${veterinariaId}/${crypto.randomUUID()}.${extension}`;

  const { error: errorSubida } = await supabase.storage
    .from("productos")
    .upload(ruta, archivoImagen.value, {
      cacheControl: "3600",
      upsert: false,
    });

  if (errorSubida) throw errorSubida;

  const { data } = supabase.storage.from("productos").getPublicUrl(ruta);

  return {
    url: data.publicUrl,
    ruta,
  };
}

async function obtenerVeterinariaId() {
  const { data, error } = await supabase.rpc("obtener_mi_veterinaria_id");
  if (error) throw error;
  if (!data) {
    throw new Error("Tu cuenta no está asociada a ninguna veterinaria.");
  }
  return data;
}

async function guardarProducto() {
  errorMensaje.value = "";
  mensaje.value = "";

  if (!nombre.value.trim()) {
    errorMensaje.value = "El nombre es obligatorio.";
    return;
  }

  if (precio.value === "" || Number(precio.value) < 0) {
    errorMensaje.value = "Ingresá un precio válido.";
    return;
  }

  if (Number(stock.value) < 0) {
    errorMensaje.value = "El stock no puede ser negativo.";
    return;
  }

  cargando.value = true;
  let nuevaImagen;

  try {
    const veterinariaId = await obtenerVeterinariaId();

    nuevaImagen = await subirImagen(veterinariaId);

    const datosProducto = {
      nombre: nombre.value.trim(),
      descripcion: descripcion.value.trim() || null,
      precio: Number(precio.value),
      stock: Number(stock.value),
      activo: activo.value,
      imagen_url: nuevaImagen?.url ?? imagenUrlExistente.value,
      imagen_ruta: nuevaImagen?.ruta ?? imagenRutaExistente.value,
    };

    let error;

    if (productoEditandoId.value) {
      const { data: filasEditadas, error: errorEdicion } = await supabase
        .from("productos")
        .update(datosProducto)
        .eq("id", productoEditandoId.value)
        .select("id");

      error = errorEdicion;
      if (!error && !filasEditadas?.length) {
        error = { message: "No tenés permiso para modificar este producto." };
      }
    } else {
      ({ error } = await supabase
        .from("productos")
        .insert({ ...datosProducto, veterinaria_id: veterinariaId }));
    }

    if (error) {
      if (nuevaImagen?.ruta) {
        await supabase.storage.from("productos").remove([nuevaImagen.ruta]);
      }
      throw error;
    }

    if (
      productoEditandoId.value &&
      nuevaImagen?.ruta &&
      imagenRutaExistente.value
    ) {
      await supabase.storage
        .from("productos")
        .remove([imagenRutaExistente.value]);
    }

    mensaje.value = productoEditandoId.value
      ? "Producto actualizado correctamente."
      : "Producto creado correctamente.";

    limpiarFormulario();
    await cargarProductos(false);
  } catch (error) {
    errorMensaje.value = traducirError(error.message);
  } finally {
    cargando.value = false;
  }
}

function editarProducto(producto) {
  productoEditandoId.value = producto.id;
  nombre.value = producto.nombre;
  descripcion.value = producto.descripcion ?? "";
  precio.value = producto.precio;
  stock.value = producto.stock;
  activo.value = producto.activo;
  imagenUrlExistente.value = producto.imagen_url ?? "";
  imagenRutaExistente.value = producto.imagen_ruta ?? "";
  archivoImagen.value = null;
  vistaPrevia.value = "";
  if (inputImagen.value) inputImagen.value.value = "";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

async function eliminarProducto(producto) {
  const confirmado = window.confirm(
    `¿Querés eliminar el producto "${producto.nombre}"?`,
  );
  if (!confirmado) return;

  cargando.value = true;
  errorMensaje.value = "";
  mensaje.value = "";

  const { data: filasBorradas, error } = await supabase
    .from("productos")
    .delete()
    .eq("id", producto.id)
    .select("id");

  if (error) {
    errorMensaje.value = traducirError(error.message);
    cargando.value = false;
    return;
  }

  if (!filasBorradas?.length) {
    errorMensaje.value = "No tenés permiso para eliminar productos.";
    cargando.value = false;
    return;
  }

  if (producto.imagen_ruta) {
    const { error: errorImagen } = await supabase.storage
      .from("productos")
      .remove([producto.imagen_ruta]);

    if (errorImagen) {
      errorMensaje.value =
        "El producto se eliminó, pero no se pudo borrar su imagen.";
    }
  }

  if (!errorMensaje.value) mensaje.value = "Producto eliminado correctamente.";
  if (productoEditandoId.value === producto.id) limpiarFormulario();
  await cargarProductos(false);
  cargando.value = false;
}

function limpiarFormulario() {
  nombre.value = "";
  descripcion.value = "";
  precio.value = "";
  stock.value = 0;
  activo.value = true;
  productoEditandoId.value = null;
  archivoImagen.value = null;
  imagenUrlExistente.value = "";
  imagenRutaExistente.value = "";
  if (vistaPrevia.value) URL.revokeObjectURL(vistaPrevia.value);
  vistaPrevia.value = "";
  if (inputImagen.value) inputImagen.value.value = "";
}

function cancelarEdicion() {
  limpiarFormulario();
  mensaje.value = "";
  errorMensaje.value = "";
}

function suscribirPedidos() {
  if (canalPedidos) {
    supabase.removeChannel(canalPedidos);
  }

  canalPedidos = supabase
    .channel("pedidos-administracion")
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "pedidos" },
      cargarPedidos,
    )
    .subscribe();
}

function actualizarAlReactivar() {
  if (document.visibilityState === "visible") {
    cargarPedidos();
  }
}

onMounted(() => {
  cargar();
  cargarProductos();
  cargarMovimientos();
  cargarPedidos();
  suscribirPedidos();
  document.addEventListener("visibilitychange", actualizarAlReactivar);
});

onUnmounted(() => {
  document.removeEventListener("visibilitychange", actualizarAlReactivar);
  if (canalPedidos) supabase.removeChannel(canalPedidos);
});
</script>

<template>
  <div class="contenedor-aplicacion">
    <header class="barra-superior">
      <router-link
        to="/inicio"
        class="marca"
        aria-label="Ir al panel principal"
      >
        <span class="icono-marca"><Plus /></span>
        <span
          ><strong>Vet</strong><b>Control</b
          ><small>Gestión veterinaria simple</small></span
        >
      </router-link>

      <div class="enlaces-menu-superior">
        <router-link to="/inicio" class="pestana-navegacion">
          <Home /> Volver a Agenda / Pacientes
        </router-link>
        <span class="pestana-navegacion activo">
          <Tag /> Productos y Farmacia
        </span>
      </div>

      <div class="acciones-superiores">
        <div class="avatar">{{ usuarioInicial }}</div>
        <span class="nombre-usuario"
          >{{ usuarioCorreo || "Usuario" }}
          <small>{{ etiquetaRol }}</small></span
        >
        <button
          class="boton-cerrar-sesion"
          :disabled="cerrandoSesion"
          @click="cerrarSesion"
        >
          <LogOut v-if="!cerrandoSesion" />
          {{ cerrandoSesion ? "..." : "Salir" }}
        </button>
      </div>
    </header>

    <main class="contenido-pagina distribucion-productos">
      <div class="encabezado-pagina">
        <div>
          <p class="sobretitulo">FARMACIA Y PET SHOP</p>
          <h1>Gestión de Productos</h1>
          <p class="texto-atenuado">
            Administrá el inventario, medicamentos, vacunas y accesorios de la
            veterinaria.
          </p>
        </div>
        <router-link to="/inicio" class="boton-contorno">
          <ArrowLeft /> Volver a Agenda
        </router-link>
      </div>

      <div class="cuadricula-productos">
        <section class="panel panel-formulario">
          <div class="encabezado-panel">
            <div>
              <p class="sobretitulo">
                {{ productoEditandoId ? "MODIFICACIÓN" : "ALTA" }}
              </p>
              <h2>
                {{ productoEditandoId ? "Editar producto" : "Nuevo producto" }}
              </h2>
            </div>
            <span v-if="productoEditandoId" class="etiqueta-edicion"
              >Modo edición</span
            >
          </div>
          <p class="subtitulo-panel">
            Completá los datos y subí una fotografía (JPG, PNG o WEBP).
          </p>

          <form class="formulario-producto" @submit.prevent="guardarProducto">
            <label>
              Nombre del producto *
              <input
                v-model="nombre"
                type="text"
                maxlength="120"
                placeholder="Ej: Pipeta Antipulgas Perros"
                required
              />
            </label>

            <label>
              Descripción
              <textarea
                v-model="descripcion"
                rows="3"
                placeholder="Detalles, dosis o presentación del producto..."
              ></textarea>
            </label>

            <div class="fila-dos-columnas">
              <label>
                Precio ($) *
                <input
                  v-model="precio"
                  type="text"
                  inputmode="decimal"
                  maxlength="12"
                  placeholder="0.00"
                  required
                  @input="
                    precio = precio
                      .replace(/[^0-9.]/g, '')
                      .replace(/(\..*)\./g, '$1')
                  "
                />
              </label>

              <label>
                Stock disponible *
                <input
                  v-model="stock"
                  type="text"
                  inputmode="numeric"
                  maxlength="6"
                  required
                  @input="stock = stock.replace(/[^0-9]/g, '')"
                />
              </label>
            </div>

            <label class="etiqueta-archivo">
              Foto del producto (opcional)
              <input
                ref="inputImagen"
                type="file"
                accept="image/jpeg,image/png,image/webp"
                @change="seleccionarImagen"
              />
              <small class="texto-atenuado"
                >Formatos: JPG, PNG, WEBP. Máximo 5 MB.</small
              >
            </label>

            <div
              v-if="vistaPrevia || imagenUrlExistente"
              class="caja-vista-previa"
            >
              <img
                :src="vistaPrevia || imagenUrlExistente"
                alt="Vista previa del producto"
                class="vista-previa-imagen"
              />
              <span class="etiqueta-vista-previa">
                <Check v-if="vistaPrevia" />
                {{
                  vistaPrevia
                    ? "Nueva foto seleccionada"
                    : "Foto actual guardada"
                }}
              </span>
            </div>

            <label class="etiqueta-casilla">
              <input v-model="activo" type="checkbox" />
              <span>Producto activo (disponible para venta)</span>
            </label>

            <p v-if="errorMensaje" class="mensaje-estado error">
              <TriangleAlert /> {{ errorMensaje }}
            </p>
            <p v-if="mensaje" class="mensaje-estado exito">
              <Check /> {{ mensaje }}
            </p>

            <div class="acciones-formulario">
              <button
                type="submit"
                class="boton-principal"
                :disabled="cargando"
              >
                <Plus v-if="!cargando && !productoEditandoId" />
                {{
                  cargando
                    ? "Guardando..."
                    : productoEditandoId
                      ? "Actualizar producto"
                      : "Guardar producto"
                }}
              </button>
              <button
                v-if="productoEditandoId"
                type="button"
                class="boton-contorno"
                @click="cancelarEdicion"
              >
                Cancelar
              </button>
            </div>
          </form>
        </section>

        <section class="panel panel-lista">
          <div class="encabezado-panel">
            <div>
              <p class="sobretitulo">INVENTARIO</p>
              <h2>Listado de productos</h2>
            </div>
            <div class="acciones-lista">
              <span class="pastilla-conteo"
                >{{ productosFiltrados.length }} de {{ productos.length }}</span
              >
              <button
                class="boton-contorno boton-actualizar"
                :disabled="cargando"
                @click="cargarProductos"
              >
                <RefreshCw /> Actualizar
              </button>
            </div>
          </div>

          <div v-if="productos.length" class="barra-herramientas">
            <input
              v-model="busqueda"
              type="search"
              class="buscador-barra"
              placeholder="Buscar por nombre..."
              aria-label="Buscar producto por nombre"
            />
            <select
              v-model="filtroEstado"
              class="selector-barra"
              aria-label="Filtrar por estado"
            >
              <option value="todos">Todos los estados</option>
              <option value="activos">Solo activos</option>
              <option value="inactivos">Solo inactivos</option>
            </select>
            <select
              v-model="orden"
              class="selector-barra"
              aria-label="Ordenar por"
            >
              <option value="recientes">Más recientes</option>
              <option value="nombre">Nombre (A-Z)</option>
              <option value="precio">Precio (menor a mayor)</option>
              <option value="stock">Stock (menor a mayor)</option>
              <option value="estado">Estado (activos primero)</option>
            </select>
          </div>

          <div v-if="cargando && !productos.length" class="estado-vacio">
            <p>Cargando productos desde Supabase...</p>
          </div>

          <div v-else-if="!productos.length" class="estado-vacio">
            <span class="icono-vacio"><Package /></span>
            <p>Todavía no agregaste ningún producto.</p>
            <small class="texto-atenuado"
              >Completá el formulario para registrar medicamentos o
              alimentos.</small
            >
          </div>

          <div v-else-if="!productosFiltrados.length" class="estado-vacio">
            <p>No hay productos que coincidan con la búsqueda o el filtro.</p>
          </div>

          <div v-else class="tabla-adaptable">
            <table class="tabla-productos">
              <thead>
                <tr>
                  <th>FOTO</th>
                  <th>PRODUCTO</th>
                  <th>PRECIO</th>
                  <th>STOCK</th>
                  <th>ESTADO</th>
                  <th style="text-align: right">ACCIONES</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="prod in productosFiltrados" :key="prod.id">
                  <td>
                    <img
                      v-if="prod.imagen_url"
                      :src="prod.imagen_url"
                      :alt="prod.nombre"
                      class="imagen-miniatura"
                    />
                    <div v-else class="caja-sin-imagen">Sin foto</div>
                  </td>
                  <td>
                    <strong class="titulo-producto">{{ prod.nombre }}</strong>
                    <small class="descripcion-producto">{{
                      prod.descripcion || "Sin descripción"
                    }}</small>
                  </td>
                  <td class="precio-producto">
                    ${{ Number(prod.precio).toFixed(2) }}
                  </td>
                  <td>
                    <span
                      :class="[
                        'etiqueta-stock',
                        prod.stock === 0 ? 'stock-cero' : 'stock-correcto',
                      ]"
                    >
                      {{ prod.stock }} un.
                    </span>
                  </td>
                  <td>
                    <span :class="['estado', prod.activo ? 'verde' : 'rojo']">
                      {{ prod.activo ? "Activo" : "Inactivo" }}
                    </span>
                  </td>
                  <td style="text-align: right">
                    <div class="acciones-fila">
                      <button
                        class="boton-accion editar"
                        @click="editarProducto(prod)"
                        title="Editar producto"
                      >
                        <Pencil /> Editar
                      </button>
                      <button
                        v-if="puedeEliminar"
                        class="boton-accion eliminar"
                        @click="eliminarProducto(prod)"
                        title="Eliminar producto"
                      >
                        <X /> Eliminar
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>

      <section class="panel movimientos-panel">
        <div class="encabezado-panel">
          <div>
            <p class="sobretitulo">INVENTARIO</p>
            <h2>Movimientos de stock</h2>
            <p class="texto-atenuado">
              Las entradas suman unidades; las salidas y ventas las descuentan.
            </p>
          </div>
          <button
            v-if="movimientosDisponibles"
            class="boton-principal"
            @click="abrirMovimiento"
          >
            <Plus /> Registrar movimiento
          </button>
        </div>

        <div v-if="!movimientosDisponibles" class="estado-vacio">
          <span class="icono-vacio"><ClipboardList /></span>
          <strong>Los movimientos de stock todavía no están disponibles</strong>
          <p>
            Aplicá el archivo database.sql en Supabase para habilitar esta
            sección.
          </p>
        </div>

        <div v-else-if="!movimientos.length" class="estado-vacio">
          <span class="icono-vacio"><ClipboardList /></span>
          <strong>No hay movimientos registrados</strong>
          <p>
            Registrá una entrada, salida o venta para actualizar el stock
            automáticamente.
          </p>
        </div>

        <div v-else class="tabla-adaptable">
          <table class="tabla-productos">
            <thead>
              <tr>
                <th>FECHA</th>
                <th>PRODUCTO</th>
                <th>TIPO</th>
                <th>CANTIDAD</th>
                <th>PRECIO UNIT.</th>
                <th>MOTIVO</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="mov in movimientos" :key="mov.id">
                <td>{{ fechaMovimiento(mov.creado_en) }}</td>
                <td>
                  <strong class="titulo-producto">{{
                    mov.producto?.nombre || "Producto"
                  }}</strong>
                </td>
                <td>
                  <span
                    class="estado"
                    :class="mov.tipo === 'Entrada' ? 'verde' : 'amarillo'"
                  >
                    {{ mov.tipo }}
                  </span>
                </td>
                <td>
                  {{ mov.tipo === "Entrada" ? "+" : " - " }}{{ mov.cantidad }}
                </td>
                <td>
                  {{
                    mov.precio_unitario == null
                      ? "—"
                      : `$${Number(mov.precio_unitario).toFixed(2)}`
                  }}
                </td>
                <td>{{ mov.motivo || "—" }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="panel movimientos-panel">
        <div class="encabezado-panel">
          <div>
            <p class="sobretitulo">VENTAS</p>
            <h2>Pedidos de clientes</h2>
            <p class="texto-atenuado">
              Compras realizadas desde el portal del cliente.
            </p>
          </div>
        </div>

        <div v-if="cargandoPedidos" class="estado-vacio">
          <p>Cargando pedidos...</p>
        </div>

        <div v-else-if="!pedidos.length" class="estado-vacio">
          <span class="icono-vacio"><ClipboardList /></span>
          <strong>No hay pedidos registrados</strong>
        </div>

        <div v-else class="tabla-adaptable">
          <table class="tabla-productos">
            <thead>
              <tr>
                <th>FECHA</th>
                <th>CLIENTE</th>
                <th>PRODUCTOS</th>
                <th>TOTAL</th>
                <th>ESTADO</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="pedido in pedidos" :key="pedido.id">
                <td>{{ fechaMovimiento(pedido.creado_en) }}</td>
                <td>
                  <strong class="titulo-producto">{{
                    pedido.cliente?.nombre_completo || "Cliente"
                  }}</strong>
                  <small class="descripcion-producto">{{
                    pedido.cliente?.email || ""
                  }}</small>
                </td>
                <td>
                  <small class="descripcion-producto">{{
                    pedido.detalles
                      .map((d) => `${d.cantidad} × ${d.producto?.nombre}`)
                      .join(", ")
                  }}</small>
                </td>
                <td>${{ Number(pedido.total).toFixed(2) }}</td>
                <td>
                  <select
                    :value="pedido.estado"
                    @change="cambiarEstadoPedido(pedido, $event.target.value)"
                  >
                    <option value="Pendiente">Pendiente</option>
                    <option value="Confirmado">Confirmado</option>
                    <option value="Entregado">Entregado</option>
                    <option value="Cancelado">Cancelado</option>
                  </select>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </main>

    <div
      v-if="mostrarMovimiento"
      class="fondo-modal"
      @click.self="mostrarMovimiento = false"
    >
      <section class="ventana-reserva">
        <button
          class="cerrar-modal"
          aria-label="Cerrar"
          @click="mostrarMovimiento = false"
        >
          <X />
        </button>
        <p class="sobretitulo">INVENTARIO</p>
        <h2>Registrar movimiento</h2>
        <p class="texto-atenuado">
          El stock se actualiza automáticamente al guardar.
        </p>

        <form class="formulario-modal" @submit.prevent="registrarMovimiento">
          <label>
            Producto
            <select v-model="movimiento.productoId">
              <option value="" disabled>Elegí un producto</option>
              <option v-for="prod in productos" :key="prod.id" :value="prod.id">
                {{ prod.nombre }} ({{ prod.stock }} un.)
              </option>
            </select>
          </label>

          <label>
            Tipo de movimiento
            <select v-model="movimiento.tipo">
              <option value="Entrada">Entrada (compra a proveedor)</option>
              <option value="Salida">
                Salida (uso interno, merma o vencimiento)
              </option>
              <option value="Venta">Venta (a un cliente)</option>
            </select>
          </label>

          <div class="fila">
            <label>
              Cantidad
              <input
                v-model="movimiento.cantidad"
                type="text"
                inputmode="numeric"
                maxlength="6"
                required
                @input="
                  movimiento.cantidad = String(movimiento.cantidad).replace(
                    /[^0-9]/g,
                    '',
                  )
                "
              />
            </label>
            <label>
              Precio unitario (opcional)
              <input
                v-model="movimiento.precioUnitario"
                type="text"
                inputmode="decimal"
                maxlength="12"
                placeholder="0.00"
                @input="
                  movimiento.precioUnitario = String(movimiento.precioUnitario)
                    .replace(/[^0-9.]/g, '')
                    .replace(/(\..*)\./g, '$1')
                "
              />
            </label>
          </div>

          <label>
            Motivo (opcional)
            <input
              v-model="movimiento.motivo"
              type="text"
              maxlength="160"
              placeholder="Ej: compra a proveedor"
            />
          </label>

          <p v-if="errorMovimiento" class="error-modal">
            <TriangleAlert /> {{ errorMovimiento }}
          </p>

          <div class="acciones-modal">
            <button
              type="button"
              class="boton-contorno"
              @click="mostrarMovimiento = false"
            >
              Cancelar
            </button>
            <button
              type="submit"
              class="boton-principal"
              :disabled="guardandoMovimiento"
            >
              <Plus /> {{ guardandoMovimiento ? "Guardando..." : "Registrar" }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </div>
</template>

<style scoped>
.distribucion-productos {
  max-width: 1300px;
  margin: 0 auto;
  padding: 30px 35px 60px;
}

.movimientos-panel {
  margin-top: 22px;
  padding-bottom: 4px;
}
.movimientos-panel .encabezado-panel {
  padding: 20px 22px;
}
.movimientos-panel .estado-vacio {
  padding: 30px 20px;
}
.movimientos-panel table {
  width: 100%;
}

.enlaces-menu-superior {
  display: flex;
  align-items: center;
  gap: 10px;
}

.pestana-navegacion {
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 700;
  text-decoration: none;
  color: var(--atenuado);
  background: #f0f4ef;
  transition: all 0.2s;
}

.pestana-navegacion:hover {
  color: var(--verde-oscuro);
  background: #e3ebd2;
}

.pestana-navegacion.activo {
  color: var(--verde-oscuro);
  background: #e7f5da;
}

.boton-cerrar-sesion {
  padding: 6px 12px;
  font-size: 11px;
  font-weight: 700;
  color: var(--atenuado);
  border: 1px solid var(--borde);
  border-radius: 6px;
  background: #fff;
  cursor: pointer;
}

.boton-cerrar-sesion:hover {
  color: #bf5b5b;
  border-color: #f0c3c3;
}

.cuadricula-productos {
  display: grid;
  grid-template-columns: minmax(320px, 420px) minmax(0, 1fr);
  gap: 24px;
  align-items: start;
}

.panel-formulario,
.panel-lista {
  padding: 24px;
}

.subtitulo-panel {
  color: var(--atenuado);
  font-size: 12px;
  margin-top: 4px;
  margin-bottom: 20px;
}

.etiqueta-edicion {
  padding: 3px 9px;
  border-radius: 12px;
  font-size: 10px;
  font-weight: 800;
  color: #ad7615;
  background: #fff4d3;
}

.formulario-producto {
  display: grid;
  gap: 15px;
}

.formulario-producto label {
  display: block;
  font-size: 11px;
  font-weight: 700;
  color: var(--atenuado);
}

.formulario-producto input[type="text"],
.formulario-producto input[type="number"],
.formulario-producto textarea {
  display: block;
  width: 100%;
  margin-top: 6px;
  padding: 10px 12px;
  border: 1px solid var(--borde);
  border-radius: 8px;
  background: #fbfcfb;
  color: var(--tinta);
  font-size: 13px;
  outline: none;
  font-family: inherit;
  transition: border-color 0.2s;
}

.formulario-producto input:focus,
.formulario-producto textarea:focus {
  border-color: var(--verde);
  box-shadow: 0 0 0 3px rgba(91, 174, 74, 0.12);
}

.fila-dos-columnas {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.etiqueta-archivo input[type="file"] {
  display: block;
  width: 100%;
  margin-top: 6px;
  padding: 8px;
  font-size: 11px;
  background: #fbfcfb;
  border: 1px dashed var(--borde);
  border-radius: 8px;
}

.caja-vista-previa {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px;
  border-radius: 8px;
  background: #f7faf6;
  border: 1px solid var(--borde);
}

.vista-previa-imagen {
  width: 60px;
  height: 60px;
  object-fit: cover;
  border-radius: 6px;
  border: 1px solid var(--borde);
}

.etiqueta-vista-previa {
  font-size: 11px;
  font-weight: 700;
  color: var(--verde-oscuro);
}

.etiqueta-casilla {
  display: flex !important;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  margin-top: 5px;
  color: var(--tinta) !important;
  font-size: 12px !important;
}

.etiqueta-casilla input {
  width: 16px;
  height: 16px;
  accent-color: var(--verde);
}

.mensaje-estado {
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 700;
}

.mensaje-estado.exito {
  color: #438538;
  background: #ebf7e4;
}

.mensaje-estado.error {
  color: #ae5757;
  background: #fbeaea;
}

.acciones-formulario {
  display: flex;
  gap: 10px;
  margin-top: 8px;
}

.acciones-lista {
  display: flex;
  align-items: center;
  gap: 10px;
}

.pastilla-conteo {
  padding: 4px 10px;
  font-size: 11px;
  font-weight: 800;
  color: var(--verde-oscuro);
  background: #e5f3d9;
  border-radius: 12px;
}

.boton-actualizar {
  padding: 6px 12px;
  font-size: 11px;
}

.estado-vacio {
  text-align: center;
  padding: 48px 20px;
  color: var(--atenuado);
}

.icono-vacio {
  font-size: 38px;
  display: block;
  margin-bottom: 10px;
}

.tabla-adaptable {
  overflow-x: auto;
  margin-top: 16px;
}

.tabla-productos {
  width: 100%;
  border-collapse: collapse;
  text-align: left;
  font-size: 12px;
}

.tabla-productos th {
  padding: 12px 14px;
  color: #97a29a;
  background: #f8faf7;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.6px;
  border-bottom: 1px solid var(--borde);
}

.tabla-productos td {
  padding: 14px;
  border-bottom: 1px solid #eef1ee;
  vertical-align: middle;
}

.tabla-productos tr:hover {
  background: #fbfdfa;
}

.imagen-miniatura {
  width: 48px;
  height: 48px;
  object-fit: cover;
  border-radius: 8px;
  border: 1px solid var(--borde);
}

.caja-sin-imagen {
  width: 48px;
  height: 48px;
  display: grid;
  place-items: center;
  border-radius: 8px;
  background: #f0f4ef;
  color: var(--atenuado);
  font-size: 9px;
  font-weight: 700;
  text-align: center;
}

.titulo-producto {
  display: block;
  font-size: 13px;
  color: var(--verde-oscuro);
}

.descripcion-producto {
  display: block;
  color: var(--atenuado);
  font-size: 11px;
  max-width: 260px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.precio-producto {
  font-weight: 800;
  color: var(--verde-oscuro);
  font-size: 13px;
}

.etiqueta-stock {
  display: inline-block;
  padding: 3px 8px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 700;
}

.etiqueta-stock.stock-correcto {
  background: #eef7eb;
  color: #387c2f;
}

.etiqueta-stock.stock-cero {
  background: #fbeaea;
  color: #ae5757;
}

.acciones-fila {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.boton-accion {
  padding: 6px 10px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
  border: 1px solid transparent;
}

.boton-accion.editar {
  color: var(--verde-oscuro);
  background: #eef7eb;
  border-color: #d2e7ca;
}

.boton-accion.editar:hover {
  background: #e2f2da;
}

.boton-accion.eliminar {
  color: #ae5757;
  background: #fbeaea;
  border-color: #f4d3d3;
}

.boton-accion.eliminar:hover {
  background: #f7dada;
}

.barra-herramientas {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 16px;
}

.buscador-barra {
  flex: 1 1 220px;
  padding: 9px 12px;
  border: 1px solid var(--borde);
  border-radius: 8px;
  background: #fbfcfb;
  font-size: 13px;
  font-family: inherit;
  color: var(--tinta);
}

.selector-barra {
  padding: 9px 10px;
  border: 1px solid var(--borde);
  border-radius: 8px;
  background: #fbfcfb;
  font-size: 12px;
  font-family: inherit;
  color: var(--tinta);
}

@media (max-width: 900px) {
  .cuadricula-productos {
    grid-template-columns: 1fr;
  }
}
</style>

