<script setup>
import { ArrowLeft, Check, ClipboardList, Home, LogOut, Package, Pencil, Plus, RefreshCw, Tag, TriangleAlert, X } from 'lucide-vue-next'
import { onMounted, ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/supabase'
import { useUsuario } from '@/composables/useUsuario'
import { traducirError } from '@/utils/errores'

const router = useRouter()

// Datos del usuario (email y rol) compartidos con el resto de las vistas
const {
  email: usuarioEmail,
  inicial: usuarioInicial,
  etiquetaRol,
  esAdmin,
  cargar,
  cerrarSesion: salir,
} = useUsuario()

// Variables del ABM
const productos = ref([])
const nombre = ref('')
const descripcion = ref('')
const precio = ref('')
const stock = ref(0)
const activo = ref(true)
const archivoImagen = ref(null)
const vistaPrevia = ref('')
const imagenUrlExistente = ref('')
const imagenRutaExistente = ref('')
const inputImagen = ref(null)
const productoEditandoId = ref(null)
const cargando = ref(false)
const mensaje = ref('')
const errorMensaje = ref('')
const cerrandoSesion = ref(false)

// Rol y permisos (el rol se lee de la base, no de lo que muestra la pantalla)
const puedeEliminar = esAdmin

// Búsqueda, filtro y orden del listado
const busqueda = ref('')
const filtroEstado = ref('todos')
const orden = ref('recientes')

const productosFiltrados = computed(() => {
  const texto = busqueda.value.trim().toLowerCase()

  const lista = productos.value.filter((p) => {
    if (filtroEstado.value === 'activos' && !p.activo) return false
    if (filtroEstado.value === 'inactivos' && p.activo) return false
    if (texto && !p.nombre.toLowerCase().includes(texto)) return false
    return true
  })

  const copia = [...lista]
  switch (orden.value) {
    case 'nombre':
      copia.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'))
      break
    case 'precio':
      copia.sort((a, b) => Number(a.precio) - Number(b.precio))
      break
    case 'stock':
      copia.sort((a, b) => a.stock - b.stock)
      break
    case 'estado':
      copia.sort((a, b) => Number(b.activo) - Number(a.activo))
      break
    default:
      copia.sort((a, b) => new Date(b.creado_en) - new Date(a.creado_en))
  }
  return copia
})

async function cerrarSesion() {
  try {
    cerrandoSesion.value = true
    await salir()
    router.push('/login')
  } catch (error) {
    alert(error.message)
  } finally {
    cerrandoSesion.value = false
  }
}

async function cargarProductos(limpiarMensaje = true) {
  cargando.value = true
  errorMensaje.value = ''
  if (limpiarMensaje) mensaje.value = ''

  const { data, error } = await supabase
    .from('productos')
    .select('*')
    .order('creado_en', { ascending: false })

  if (error) {
    errorMensaje.value = traducirError(error.message)
  } else {
    productos.value = data || []
  }
  cargando.value = false
}

// ---- Movimientos de stock -------------------------------------------------
// Cada alta dispara el trigger `aplicar_movimiento_stock`, que actualiza el
// stock del producto y nunca permite que quede negativo.
const movimientos = ref([])
const movimientosDisponibles = ref(false)
const showMovimiento = ref(false)
const guardandoMovimiento = ref(false)
const errorMovimiento = ref('')
const movimiento = ref({ productoId: '', tipo: 'Entrada', cantidad: 1, precioUnitario: '', motivo: '' })

async function cargarMovimientos() {
  const { data, error } = await supabase
    .from('movimientos_stock')
    .select('id, tipo, cantidad, precio_unitario, motivo, creado_en, producto:productos(nombre)')
    .order('creado_en', { ascending: false })
    .limit(20)

  if (error) {
    // La tabla se crea en la etapa 8: si todavía no está, se oculta el módulo
    movimientosDisponibles.value = false
    movimientos.value = []
    return
  }
  movimientosDisponibles.value = true
  movimientos.value = data || []
}

function abrirMovimiento() {
  errorMovimiento.value = ''
  movimiento.value = {
    productoId: productos.value[0]?.id || '',
    tipo: 'Entrada',
    cantidad: 1,
    precioUnitario: '',
    motivo: '',
  }
  showMovimiento.value = true
}

async function registrarMovimiento() {
  errorMovimiento.value = ''
  const cantidad = Number(movimiento.value.cantidad)
  if (!movimiento.value.productoId) {
    errorMovimiento.value = 'Elegí un producto.'
    return
  }
  if (! Number.isInteger(cantidad) || cantidad <= 0) {
    errorMovimiento.value = 'La cantidad debe ser un número entero mayor a cero.'
    return
  }

  guardandoMovimiento.value = true
  try {
    const veterinariaId = await obtenerVeterinariaId()
    const { error } = await supabase.from('movimientos_stock').insert({
      veterinaria_id: veterinariaId,
      producto_id: movimiento.value.productoId,
      tipo: movimiento.value.tipo,
      cantidad,
      precio_unitario:
        movimiento.value.precioUnitario === '' ? null : Number(movimiento.value.precioUnitario),
      motivo: movimiento.value.motivo.trim() || null,
    })
    if (error) throw error

    showMovimiento.value = false
    mensaje.value = 'Movimiento registrado y stock actualizado.'
    await Promise.all([cargarProductos(false), cargarMovimientos()])
  } catch (error) {
    errorMovimiento.value = traducirError(error.message)
  } finally {
    guardandoMovimiento.value = false
  }
}

function fechaMovimiento(iso) {
  return new Intl.DateTimeFormat('es-AR', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(iso))
}

function seleccionarImagen(evento) {
  errorMensaje.value = ''
  const archivo = evento.target.files?.[0]
  if (!archivo) {
    archivoImagen.value = null
    vistaPrevia.value = ''
    return
  }

  const tiposPermitidos = ['image/jpeg', 'image/png', 'image/webp']
  if (!tiposPermitidos.includes(archivo.type)) {
    errorMensaje.value = 'La imagen debe ser JPG, PNG o WEBP.'
    evento.target.value = ''
    return
  }

  if (archivo.size > 5 * 1024 * 1024) {
    errorMensaje.value = 'La imagen no puede superar los 5 MB.'
    evento.target.value = ''
    return
  }

  if (vistaPrevia.value) URL.revokeObjectURL(vistaPrevia.value)
  archivoImagen.value = archivo
  vistaPrevia.value = URL.createObjectURL(archivo)
}

// Sube la imagen a <veterinaria_id>/<archivo>: las políticas de Storage solo
// permiten escribir dentro de la carpeta de la veterinaria del usuario.
async function subirImagen(veterinariaId) {
  if (!archivoImagen.value) return null

  if (!veterinariaId) {
    throw new Error('No hay un usuario autenticado.')
  }

  const extension = archivoImagen.value.name.split('.').pop().toLowerCase()
  const ruta = `${veterinariaId}/${crypto.randomUUID()}.${extension}`

  const { error: errorSubida } = await supabase.storage
    .from('productos')
    .upload(ruta, archivoImagen.value, {
      cacheControl: '3600',
      upsert: false,
    })

  if (errorSubida) throw errorSubida

  const { data } = supabase.storage.from('productos').getPublicUrl(ruta)

  return {
    url: data.publicUrl,
    ruta,
  }
}

// Devuelve el id de la veterinaria a la que pertenece el usuario logueado
// (se obtiene de su perfil, nunca del formulario).
async function obtenerVeterinariaId() {
  const { data, error } = await supabase.rpc('obtener_mi_veterinaria_id')
  if (error) throw error
  if (!data) {
    throw new Error('Tu cuenta no está asociada a ninguna veterinaria.')
  }
  return data
}

async function guardarProducto() {
  errorMensaje.value = ''
  mensaje.value = ''

  if (!nombre.value.trim()) {
    errorMensaje.value = 'El nombre es obligatorio.'
    return
  }

  if (precio.value === '' || Number(precio.value) < 0) {
    errorMensaje.value = 'Ingresá un precio válido.'
    return
  }

  if (Number(stock.value) < 0) {
    errorMensaje.value = 'El stock no puede ser negativo.'
    return
  }

  if (!productoEditandoId.value && !archivoImagen.value) {
    errorMensaje.value = 'Seleccioná una imagen para el producto.'
    return
  }

  cargando.value = true
  let nuevaImagen

  try {
    // Se resuelve antes de subir la imagen para no dejar archivos huérfanos
    // si la cuenta no tiene veterinaria asociada.
    const veterinariaId = await obtenerVeterinariaId()

    nuevaImagen = await subirImagen(veterinariaId)

    const datosProducto = {
      nombre: nombre.value.trim(),
      descripcion: descripcion.value.trim() || null,
      precio: Number(precio.value),
      stock: Number(stock.value),
      activo: activo.value,
      imagen_url: nuevaImagen?.url ?? imagenUrlExistente.value,
      imagen_ruta: nuevaImagen?.ruta ?? imagenRutaExistente.value,
    }

    let error

    if (productoEditandoId.value) {
      const { data: filasEditadas, error: errorEdicion } = await supabase
        .from('productos')
        .update(datosProducto)
        .eq('id', productoEditandoId.value)
        .select('id')

      error = errorEdicion
      // Si la base no devuelve filas, la política no permitió el cambio
      if (!error && !filasEditadas?.length) {
        error = { message: 'No tenés permiso para modificar este producto.' }
      }
    } else {
      ;({ error } = await supabase
        .from('productos')
        .insert({ ...datosProducto, veterinaria_id: veterinariaId }))
    }

    if (error) {
      if (nuevaImagen?.ruta) {
        await supabase.storage.from('productos').remove([nuevaImagen.ruta])
      }
      throw error
    }

    if (
      productoEditandoId.value &&
      nuevaImagen?.ruta &&
      imagenRutaExistente.value
    ) {
      await supabase.storage
        .from('productos')
        .remove([imagenRutaExistente.value])
    }

    mensaje.value = productoEditandoId.value
      ? 'Producto actualizado correctamente.'
      : 'Producto creado correctamente.'

    limpiarFormulario()
    await cargarProductos(false)
  } catch (error) {
    errorMensaje.value = traducirError(error.message)
  } finally {
    cargando.value = false
  }
}

function editarProducto(producto) {
  productoEditandoId.value = producto.id
  nombre.value = producto.nombre
  descripcion.value = producto.descripcion ?? ''
  precio.value = producto.precio
  stock.value = producto.stock
  activo.value = producto.activo
  imagenUrlExistente.value = producto.imagen_url ?? ''
  imagenRutaExistente.value = producto.imagen_ruta ?? ''
  archivoImagen.value = null
  vistaPrevia.value = ''
  if (inputImagen.value) inputImagen.value.value = ''
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

async function eliminarProducto(producto) {
  const confirmado = window.confirm(
    `¿Querés eliminar el producto "${producto.nombre}"?`
  )
  if (!confirmado) return

  cargando.value = true
  errorMensaje.value = ''
  mensaje.value = ''

  const { data: filasBorradas, error } = await supabase
    .from('productos')
    .delete()
    .eq('id', producto.id)
    .select('id')

  if (error) {
    errorMensaje.value = traducirError(error.message)
    cargando.value = false
    return
  }

  // Si no se borró ninguna fila, la política no lo permitió (por ejemplo, un veterinario)
  if (!filasBorradas?.length) {
    errorMensaje.value = 'No tenés permiso para eliminar productos.'
    cargando.value = false
    return
  }

  if (producto.imagen_ruta) {
    const { error: errorImagen } = await supabase.storage
      .from('productos')
      .remove([producto.imagen_ruta])

    if (errorImagen) {
      errorMensaje.value =
        'El producto se eliminó, pero no se pudo borrar su imagen.'
    }
  }

  if (!errorMensaje.value) mensaje.value = 'Producto eliminado correctamente.'
  if (productoEditandoId.value === producto.id) limpiarFormulario()
  await cargarProductos(false)
  cargando.value = false
}

function limpiarFormulario() {
  nombre.value = ''
  descripcion.value = ''
  precio.value = ''
  stock.value = 0
  activo.value = true
  productoEditandoId.value = null
  archivoImagen.value = null
  imagenUrlExistente.value = ''
  imagenRutaExistente.value = ''
  if (vistaPrevia.value) URL.revokeObjectURL(vistaPrevia.value)
  vistaPrevia.value = ''
  if (inputImagen.value) inputImagen.value.value = ''
}

function cancelarEdicion() {
  limpiarFormulario()
  mensaje.value = ''
  errorMensaje.value = ''
}

onMounted(() => {
  cargar()
  cargarProductos()
  cargarMovimientos()
})
</script>

<template>
  <div class="app-shell">
    <!-- Barra superior coherente con VetControl -->
    <header class="topbar">
      <router-link to="/inicio" class="brand" aria-label="Ir al panel principal">
        <span class="brand-mark"><Plus /></span>
        <span><strong>Vet</strong><b>Control</b><small>Gestión veterinaria simple</small></span>
      </router-link>

      <div class="top-nav-links">
        <router-link to="/inicio" class="nav-pill">
          <Home /> Volver a Agenda / Pacientes
        </router-link>
        <span class="nav-pill active">
          <Tag /> Productos y Farmacia
        </span>
      </div>

      <div class="top-actions">
        <div class="avatar">{{ usuarioInicial }}</div>
        <span class="user-name">{{ usuarioEmail || 'Usuario' }} <small>{{ etiquetaRol }}</small></span>
        <button class="logout-btn" :disabled="cerrandoSesion" @click="cerrarSesion">
          <LogOut v-if="!cerrandoSesion" /> {{ cerrandoSesion ? '...' : 'Salir' }}
        </button>
      </div>
    </header>

    <!-- Contenido principal -->
    <main class="page-content productos-layout">
      <div class="page-heading">
        <div>
          <p class="eyebrow">FARMACIA Y PET SHOP</p>
          <h1>Gestión de Productos</h1>
          <p class="muted">Administrá el inventario, medicamentos, vacunas y accesorios de la veterinaria.</p>
        </div>
        <router-link to="/inicio" class="outline-button">
          <ArrowLeft /> Volver a Agenda
        </router-link>
      </div>

      <div class="productos-grid">
        <!-- Panel de Formulario (Alta y Modificación) -->
        <section class="panel form-panel">
          <div class="panel-header">
            <div>
              <p class="eyebrow">{{ productoEditandoId ? 'MODIFICACIÓN' : 'ALTA' }}</p>
              <h2>{{ productoEditandoId ? 'Editar producto' : 'Nuevo producto' }}</h2>
            </div>
            <span v-if="productoEditandoId" class="badge-edit">Modo edición</span>
          </div>
          <p class="panel-subtitle">Completá los datos y subí una fotografía (JPG, PNG o WEBP).</p>

          <form class="producto-form" @submit.prevent="guardarProducto">
            <label>
              Nombre del producto *
              <input v-model="nombre" type="text" maxlength="120" placeholder="Ej: Pipeta Antipulgas Perros" required />
            </label>

            <label>
              Descripción
              <textarea v-model="descripcion" rows="3" placeholder="Detalles, dosis o presentación del producto..."></textarea>
            </label>

            <div class="fila-dos-columnas">
              <label>
                Precio ($) *
                <input v-model="precio" type="number" min="0" step="0.01" placeholder="0.00" required />
              </label>

              <label>
                Stock disponible *
                <input v-model="stock" type="number" min="0" step="1" required />
              </label>
            </div>

            <label class="file-label">
              Foto del producto {{ productoEditandoId ? '(opcional para cambiar)' : '*' }}
              <input
                ref="inputImagen"
                type="file"
                accept="image/jpeg,image/png,image/webp"
                @change="seleccionarImagen"
              />
              <small class="muted">Formatos: JPG, PNG, WEBP. Máximo 5 MB.</small>
            </label>

            <!-- Vista previa de imagen -->
            <div v-if="vistaPrevia || imagenUrlExistente" class="preview-box">
              <img
                :src="vistaPrevia || imagenUrlExistente"
                alt="Vista previa del producto"
                class="img-preview"
              />
              <span class="preview-tag">
                <Check v-if="vistaPrevia" /> {{ vistaPrevia ? 'Nueva foto seleccionada' : 'Foto actual guardada' }}
              </span>
            </div>

            <label class="check-label">
              <input v-model="activo" type="checkbox" />
              <span>Producto activo (disponible para venta)</span>
            </label>

            <!-- Mensajes de feedback -->
            <p v-if="errorMensaje" class="feedback-msg error"><TriangleAlert /> {{ errorMensaje }}</p>
            <p v-if="mensaje" class="feedback-msg exito"><Check /> {{ mensaje }}</p>

            <div class="form-actions">
              <button type="submit" class="primary-button" :disabled="cargando">
                <Plus v-if="!cargando && !productoEditandoId" />
                {{
                  cargando
                    ? 'Guardando...'
                    : productoEditandoId
                    ? 'Actualizar producto'
                    : 'Guardar producto'
                }}
              </button>
              <button
                v-if="productoEditandoId"
                type="button"
                class="outline-button"
                @click="cancelarEdicion"
              >
                Cancelar
              </button>
            </div>
          </form>
        </section>

        <!-- Panel de Listado de Productos -->
        <section class="panel list-panel">
          <div class="panel-header">
            <div>
              <p class="eyebrow">INVENTARIO</p>
              <h2>Listado de productos</h2>
            </div>
            <div class="list-actions">
              <span class="count-pill">{{ productosFiltrados.length }} de {{ productos.length }}</span>
              <button class="outline-button refresh-btn" :disabled="cargando" @click="cargarProductos">
                <RefreshCw /> Actualizar
              </button>
            </div>
          </div>

          <div v-if="productos.length" class="toolbar">
            <input
              v-model="busqueda"
              type="search"
              class="toolbar-search"
              placeholder="Buscar por nombre..."
              aria-label="Buscar producto por nombre"
            />
            <select v-model="filtroEstado" class="toolbar-select" aria-label="Filtrar por estado">
              <option value="todos">Todos los estados</option>
              <option value="activos">Solo activos</option>
              <option value="inactivos">Solo inactivos</option>
            </select>
            <select v-model="orden" class="toolbar-select" aria-label="Ordenar por">
              <option value="recientes">Más recientes</option>
              <option value="nombre">Nombre (A-Z)</option>
              <option value="precio">Precio (menor a mayor)</option>
              <option value="stock">Stock (menor a mayor)</option>
              <option value="estado">Estado (activos primero)</option>
            </select>
          </div>

          <div v-if="cargando && !productos.length" class="empty-state">
            <p>Cargando productos desde Supabase...</p>
          </div>

          <div v-else-if="!productos.length" class="empty-state">
            <span class="empty-icon"><Package /></span>
            <p>Todavía no agregaste ningún producto.</p>
            <small class="muted">Completá el formulario para registrar medicamentos o alimentos.</small>
          </div>

          <div v-else-if="!productosFiltrados.length" class="empty-state">
            <p>No hay productos que coincidan con la búsqueda o el filtro.</p>
          </div>

          <div v-else class="table-responsive">
            <table class="productos-table">
              <thead>
                <tr>
                  <th>FOTO</th>
                  <th>PRODUCTO</th>
                  <th>PRECIO</th>
                  <th>STOCK</th>
                  <th>ESTADO</th>
                  <th style="text-align: right;">ACCIONES</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="prod in productosFiltrados" :key="prod.id">
                  <td>
                    <img
                      v-if="prod.imagen_url"
                      :src="prod.imagen_url"
                      :alt="prod.nombre"
                      class="thumb-img"
                    />
                    <div v-else class="no-img-box">Sin foto</div>
                  </td>
                  <td>
                    <strong class="prod-title">{{ prod.nombre }}</strong>
                    <small class="prod-desc">{{ prod.descripcion || 'Sin descripción' }}</small>
                  </td>
                  <td class="prod-price">${{ Number(prod.precio).toFixed(2) }}</td>
                  <td>
                    <span :class="['stock-badge', prod.stock === 0 ? 'stock-cero' : 'stock-ok']">
                      {{ prod.stock }} un.
                    </span>
                  </td>
                  <td>
                    <span :class="['status', prod.activo ? 'green' : 'red']">
                      {{ prod.activo ? 'Activo' : 'Inactivo' }}
                    </span>
                  </td>
                  <td style="text-align: right;">
                    <div class="row-actions">
                      <button class="action-btn edit" @click="editarProducto(prod)" title="Editar producto">
                        <Pencil /> Editar
                      </button>
                      <button v-if="puedeEliminar" class="action-btn delete" @click="eliminarProducto(prod)" title="Eliminar producto">
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

      <!-- Movimientos de stock: entradas, salidas y ventas -->
      <section class="panel movimientos-panel">
        <div class="panel-header">
          <div>
            <p class="eyebrow">INVENTARIO</p>
            <h2>Movimientos de stock</h2>
            <p class="muted">Las entradas suman unidades; las salidas y ventas las descuentan.</p>
          </div>
          <button v-if="movimientosDisponibles" class="primary-button" @click="abrirMovimiento">
            <Plus /> Registrar movimiento
          </button>
        </div>

        <div v-if="!movimientosDisponibles" class="empty-state">
          <span class="empty-icon"><ClipboardList /></span>
          <strong>Los movimientos de stock todavía no están disponibles</strong>
          <p>Aplicá el archivo database.sql en Supabase para habilitar esta sección.</p>
        </div>

        <div v-else-if="!movimientos.length" class="empty-state">
          <span class="empty-icon"><ClipboardList /></span>
          <strong>No hay movimientos registrados</strong>
          <p>Registrá una entrada, salida o venta para actualizar el stock automáticamente.</p>
        </div>

        <div v-else class="table-responsive">
          <table class="productos-table">
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
                <td><strong class="prod-title">{{ mov.producto?.nombre || 'Producto' }}</strong></td>
                <td>
                  <span class="status" :class="mov.tipo === 'Entrada' ? 'green' : 'yellow'">
                    {{ mov.tipo }}
                  </span>
                </td>
                <td>{{ mov.tipo === 'Entrada' ? '+' : '−' }}{{ mov.cantidad }}</td>
                <td>{{ mov.precio_unitario == null ? '—' : `$${Number(mov.precio_unitario).toFixed(2)}` }}</td>
                <td class="prod-desc">{{ mov.motivo || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </main>

    <!-- Modal: registrar movimiento de stock -->
    <div v-if="showMovimiento" class="modal-backdrop" @click.self="showMovimiento = false">
      <section class="booking-modal">
        <button class="modal-close" aria-label="Cerrar" @click="showMovimiento = false"><X /></button>
        <p class="eyebrow">INVENTARIO</p>
        <h2>Registrar movimiento</h2>
        <p class="muted">El stock se actualiza automáticamente al guardar.</p>

        <form class="modal-form" @submit.prevent="registrarMovimiento">
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
              <option value="Entrada">Entrada (suma stock)</option>
              <option value="Salida">Salida (descuenta stock)</option>
              <option value="Venta">Venta (descuenta stock)</option>
            </select>
          </label>

          <div class="fila">
            <label>
              Cantidad
              <input v-model="movimiento.cantidad" type="number" min="1" step="1" required />
            </label>
            <label>
              Precio unitario (opcional)
              <input v-model="movimiento.precioUnitario" type="number" min="0" step="0.01" placeholder="0.00" />
            </label>
          </div>

          <label>
            Motivo (opcional)
            <input v-model="movimiento.motivo" type="text" maxlength="160" placeholder="Ej: compra a proveedor" />
          </label>

          <p v-if="errorMovimiento" class="modal-error"><TriangleAlert /> {{ errorMovimiento }}</p>

          <div class="modal-actions">
            <button type="button" class="outline-button" @click="showMovimiento = false">Cancelar</button>
            <button type="submit" class="primary-button" :disabled="guardandoMovimiento">
              <Plus /> {{ guardandoMovimiento ? 'Guardando...' : 'Registrar' }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </div>
</template>

<style scoped>
.productos-layout {
  max-width: 1300px;
  margin: 0 auto;
  padding: 30px 35px 60px;
}

.movimientos-panel { margin-top: 22px; padding-bottom: 4px; }
.movimientos-panel .panel-header { padding: 20px 22px; }
.movimientos-panel .empty-state { padding: 30px 20px; }
.movimientos-panel table { width: 100%; }

.top-nav-links {
  display: flex;
  align-items: center;
  gap: 10px;
}

.nav-pill {
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 700;
  text-decoration: none;
  color: var(--muted);
  background: #f0f4ef;
  transition: all 0.2s;
}

.nav-pill:hover {
  color: var(--green-dark);
  background: #e3ebd2;
}

.nav-pill.active {
  color: var(--green-dark);
  background: #e7f5da;
}

.logout-btn {
  padding: 6px 12px;
  font-size: 11px;
  font-weight: 700;
  color: var(--muted);
  border: 1px solid var(--line);
  border-radius: 6px;
  background: #fff;
  cursor: pointer;
}

.logout-btn:hover {
  color: #bf5b5b;
  border-color: #f0c3c3;
}

.productos-grid {
  display: grid;
  grid-template-columns: minmax(320px, 420px) minmax(0, 1fr);
  gap: 24px;
  align-items: start;
}

.form-panel, .list-panel {
  padding: 24px;
}

.panel-subtitle {
  color: var(--muted);
  font-size: 12px;
  margin-top: 4px;
  margin-bottom: 20px;
}

.badge-edit {
  padding: 3px 9px;
  border-radius: 12px;
  font-size: 10px;
  font-weight: 800;
  color: #ad7615;
  background: #fff4d3;
}

.producto-form {
  display: grid;
  gap: 15px;
}

.producto-form label {
  display: block;
  font-size: 11px;
  font-weight: 700;
  color: var(--muted);
}

.producto-form input[type="text"],
.producto-form input[type="number"],
.producto-form textarea {
  display: block;
  width: 100%;
  margin-top: 6px;
  padding: 10px 12px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #fbfcfb;
  color: var(--ink);
  font-size: 13px;
  outline: none;
  font-family: inherit;
  transition: border-color 0.2s;
}

.producto-form input:focus,
.producto-form textarea:focus {
  border-color: var(--green);
  box-shadow: 0 0 0 3px rgba(91, 174, 74, 0.12);
}

.fila-dos-columnas {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.file-label input[type="file"] {
  display: block;
  width: 100%;
  margin-top: 6px;
  padding: 8px;
  font-size: 11px;
  background: #fbfcfb;
  border: 1px dashed var(--line);
  border-radius: 8px;
}

.preview-box {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px;
  border-radius: 8px;
  background: #f7faf6;
  border: 1px solid var(--line);
}

.img-preview {
  width: 60px;
  height: 60px;
  object-fit: cover;
  border-radius: 6px;
  border: 1px solid var(--line);
}

.preview-tag {
  font-size: 11px;
  font-weight: 700;
  color: var(--green-dark);
}

.check-label {
  display: flex !important;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  margin-top: 5px;
  color: var(--ink) !important;
  font-size: 12px !important;
}

.check-label input {
  width: 16px;
  height: 16px;
  accent-color: var(--green);
}

.feedback-msg {
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: 700;
}

.feedback-msg.exito {
  color: #438538;
  background: #ebf7e4;
}

.feedback-msg.error {
  color: #ae5757;
  background: #fbeaea;
}

.form-actions {
  display: flex;
  gap: 10px;
  margin-top: 8px;
}

.list-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.count-pill {
  padding: 4px 10px;
  font-size: 11px;
  font-weight: 800;
  color: var(--green-dark);
  background: #e5f3d9;
  border-radius: 12px;
}

.refresh-btn {
  padding: 6px 12px;
  font-size: 11px;
}

.empty-state {
  text-align: center;
  padding: 48px 20px;
  color: var(--muted);
}

.empty-icon {
  font-size: 38px;
  display: block;
  margin-bottom: 10px;
}

.table-responsive {
  overflow-x: auto;
  margin-top: 16px;
}

.productos-table {
  width: 100%;
  border-collapse: collapse;
  text-align: left;
  font-size: 12px;
}

.productos-table th {
  padding: 12px 14px;
  color: #97a29a;
  background: #f8faf7;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.6px;
  border-bottom: 1px solid var(--line);
}

.productos-table td {
  padding: 14px;
  border-bottom: 1px solid #eef1ee;
  vertical-align: middle;
}

.productos-table tr:hover {
  background: #fbfdfa;
}

.thumb-img {
  width: 48px;
  height: 48px;
  object-fit: cover;
  border-radius: 8px;
  border: 1px solid var(--line);
}

.no-img-box {
  width: 48px;
  height: 48px;
  display: grid;
  place-items: center;
  border-radius: 8px;
  background: #f0f4ef;
  color: var(--muted);
  font-size: 9px;
  font-weight: 700;
  text-align: center;
}

.prod-title {
  display: block;
  font-size: 13px;
  color: var(--green-dark);
}

.prod-desc {
  display: block;
  color: var(--muted);
  font-size: 11px;
  max-width: 260px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.prod-price {
  font-weight: 800;
  color: var(--green-dark);
  font-size: 13px;
}

.stock-badge {
  display: inline-block;
  padding: 3px 8px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 700;
}

.stock-badge.stock-ok {
  background: #eef7eb;
  color: #387c2f;
}

.stock-badge.stock-cero {
  background: #fbeaea;
  color: #ae5757;
}

.row-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.action-btn {
  padding: 6px 10px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
  border: 1px solid transparent;
}

.action-btn.edit {
  color: var(--green-dark);
  background: #eef7eb;
  border-color: #d2e7ca;
}

.action-btn.edit:hover {
  background: #e2f2da;
}

.action-btn.delete {
  color: #ae5757;
  background: #fbeaea;
  border-color: #f4d3d3;
}

.action-btn.delete:hover {
  background: #f7dada;
}

.toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 16px;
}

.toolbar-search {
  flex: 1 1 220px;
  padding: 9px 12px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #fbfcfb;
  font-size: 13px;
  font-family: inherit;
  color: var(--ink);
}

.toolbar-select {
  padding: 9px 10px;
  border: 1px solid var(--line);
  border-radius: 8px;
  background: #fbfcfb;
  font-size: 12px;
  font-family: inherit;
  color: var(--ink);
}

@media (max-width: 900px) {
  .productos-grid {
    grid-template-columns: 1fr;
  }
}
</style>