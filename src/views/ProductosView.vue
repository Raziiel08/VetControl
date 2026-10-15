<script setup>
import { onMounted, ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/supabase'

const router = useRouter()

// Datos del usuario
const usuarioEmail = ref('')
const usuarioInicial = computed(() => {
  if (!usuarioEmail.value) return 'U'
  return usuarioEmail.value.charAt(0).toUpperCase()
})

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

async function cargarUsuario() {
  const { data: { user } } = await supabase.auth.getUser()
  if (user) {
    usuarioEmail.value = user.email
  }
}

async function cerrarSesion() {
  try {
    cerrandoSesion.value = true
    await supabase.auth.signOut()
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
    errorMensaje.value = error.message
  } else {
    productos.value = data || []
  }
  cargando.value = false
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

async function subirImagen() {
  if (!archivoImagen.value) return null

  const {
    data: { user },
    error: errorUsuario,
  } = await supabase.auth.getUser()

  if (errorUsuario || !user) {
    throw new Error('No hay un usuario autenticado.')
  }

  const extension = archivoImagen.value.name.split('.').pop().toLowerCase()
  const ruta = `${user.id}/${crypto.randomUUID()}.${extension}`

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
    nuevaImagen = await subirImagen()

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
      ;({ error } = await supabase
        .from('productos')
        .update(datosProducto)
        .eq('id', productoEditandoId.value))
    } else {
      ;({ error } = await supabase.from('productos').insert(datosProducto))
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
    errorMensaje.value = error.message
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

  const { error } = await supabase
    .from('productos')
    .delete()
    .eq('id', producto.id)

  if (error) {
    errorMensaje.value = error.message
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
  cargarUsuario()
  cargarProductos()
})
</script>

<template>
  <div class="app-shell">
    <!-- Barra superior coherente con VetControl -->
    <header class="topbar">
      <router-link to="/inicio" class="brand" aria-label="Ir al panel principal">
        <span class="brand-mark">✚</span>
        <span><strong>Vet</strong><b>Control</b><small>Gestión veterinaria simple</small></span>
      </router-link>

      <div class="top-nav-links">
        <router-link to="/inicio" class="nav-pill">
          ⌂ Volver a Agenda / Pacientes
        </router-link>
        <span class="nav-pill active">
          🏷️ Productos y Farmacia
        </span>
      </div>

      <div class="top-actions">
        <div class="avatar">{{ usuarioInicial }}</div>
        <span class="user-name">{{ usuarioEmail || 'Usuario' }} <small>Administrador/a</small></span>
        <button class="logout-btn" :disabled="cerrandoSesion" @click="cerrarSesion">
          {{ cerrandoSesion ? '...' : '↪ Salir' }}
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
          ← Volver a Agenda
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
                {{ vistaPrevia ? '✓ Nueva foto seleccionada' : 'Foto actual guardada' }}
              </span>
            </div>

            <label class="check-label">
              <input v-model="activo" type="checkbox" />
              <span>Producto activo (disponible para venta)</span>
            </label>

            <!-- Mensajes de feedback -->
            <p v-if="errorMensaje" class="feedback-msg error">⚠ {{ errorMensaje }}</p>
            <p v-if="mensaje" class="feedback-msg exito">✓ {{ mensaje }}</p>

            <div class="form-actions">
              <button type="submit" class="primary-button" :disabled="cargando">
                {{
                  cargando
                    ? 'Guardando...'
                    : productoEditandoId
                    ? 'Actualizar producto'
                    : '＋ Guardar producto'
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
              <span class="count-pill">{{ productos.length }} productos</span>
              <button class="outline-button refresh-btn" :disabled="cargando" @click="cargarProductos">
                ⟳ Actualizar
              </button>
            </div>
          </div>

          <div v-if="cargando && !productos.length" class="empty-state">
            <p>Cargando productos desde Supabase...</p>
          </div>

          <div v-else-if="!productos.length" class="empty-state">
            <span class="empty-icon">📦</span>
            <p>Todavía no agregaste ningún producto.</p>
            <small class="muted">Completá el formulario para registrar medicamentos o alimentos.</small>
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
                <tr v-for="prod in productos" :key="prod.id">
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
                        ✎ Editar
                      </button>
                      <button class="action-btn delete" @click="eliminarProducto(prod)" title="Eliminar producto">
                        ✕ Eliminar
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </main>
  </div>
</template>

<style scoped>
.productos-layout {
  max-width: 1300px;
  margin: 0 auto;
  padding: 30px 35px 60px;
}

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

@media (max-width: 900px) {
  .productos-grid {
    grid-template-columns: 1fr;
  }
}
</style>
