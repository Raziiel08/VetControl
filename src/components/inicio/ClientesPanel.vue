<script setup>
import {
  Pencil,
  Plus,
  Search,
  Trash2,
  TriangleAlert,
  Users,
  X,
} from "lucide-vue-next";
import { computed, onMounted, ref } from "vue";
import { supabase } from "@/supabase";
import { useToast } from "@/composables/useToast";
import { traducirError } from "@/utils/errores";
import { validarCorreo, esDominioConocido } from "@/utils/valicom";

const { notificar } = useToast();

const clientes = ref([]);
const cargando = ref(true);
const busqueda = ref("");

const mostrarFormulario = ref(false);
const guardando = ref(false);
const errorFormulario = ref("");
const editandoId = ref(null);
const formulario = ref(vacio());

function vacio() {
  return {
    nombre_completo: "",
    telefono: "",
    email: "",
    direccion: "",
    dni: "",
  };
}

const clientesFiltrados = computed(() => {
  const texto = busqueda.value.trim().toLowerCase();
  if (!texto) return clientes.value;
  return clientes.value.filter(
    (c) =>
      c.nombre_completo.toLowerCase().includes(texto) ||
      (c.telefono || "").includes(texto) ||
      (c.email || "").toLowerCase().includes(texto),
  );
});

function iniciales(nombre = "?") {
  return nombre
    .split(" ")
    .map((n) => n[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

function limpiarNombre() {
  formulario.value.nombre_completo = formulario.value.nombre_completo.replace(
    /[^\p{L}\p{M}\s]/gu,
    "",
  );
}

async function cargar() {
  cargando.value = true;
  try {
    const { data, error } = await supabase
      .from("clientes")
      .select(
        "id, nombre_completo, telefono, email, direccion, dni, mascotas(id, nombre)",
      )
      .order("nombre_completo");
    if (error) throw error;
    clientes.value = data || [];
  } catch (e) {
    notificar(traducirError(e.message));
  } finally {
    cargando.value = false;
  }
}

function abrirFormulario(cliente = null) {
  errorFormulario.value = "";
  editandoId.value = cliente?.id ?? null;
  formulario.value = cliente
    ? {
        nombre_completo: cliente.nombre_completo,
        telefono: cliente.telefono || "",
        email: cliente.email || "",
        direccion: cliente.direccion || "",
        dni: cliente.dni || "",
      }
    : vacio();
  mostrarFormulario.value = true;
}

async function guardar() {
  errorFormulario.value = "";
  if (!formulario.value.nombre_completo.trim())
    return (errorFormulario.value = "El nombre es obligatorio.");
  const nombre = formulario.value.nombre_completo.trim().replace(/\s+/g, " ");
  if (!/^[\p{L}\p{M}]+(?:\s+[\p{L}\p{M}]+)*$/u.test(nombre)) {
    return (errorFormulario.value =
      "El nombre y apellido solo pueden tener letras y espacios.");
  }
  formulario.value.nombre_completo = nombre;
  if (!formulario.value.telefono.trim())
    return (errorFormulario.value = "El teléfono es obligatorio.");
  if (!/^[0-9 +()\-]+$/.test(formulario.value.telefono.trim())) {
    return (errorFormulario.value =
      "El teléfono solo puede tener números, espacios, +, - y paréntesis.");
  }
  if (formulario.value.telefono.trim().length > 15) {
    return (errorFormulario.value =
      "El teléfono no puede tener más de 15 caracteres.");
  }
  if (!formulario.value.direccion.trim())
    return (errorFormulario.value = "La dirección es obligatoria.");
  if (!formulario.value.dni.trim())
    return (errorFormulario.value = "El DNI es obligatorio.");
  if (!/^[0-9]{8}$/.test(formulario.value.dni.trim())) {
    return (errorFormulario.value = "El DNI debe tener 8 dígitos.");
  }
  if (formulario.value.email.trim()) {
    const validacionCorreo = validarCorreo(formulario.value.email);
    if (!validacionCorreo.valido)
      return (errorFormulario.value = validacionCorreo.error);
    if (!esDominioConocido(validacionCorreo.correo)) {
      return (errorFormulario.value =
        "Usá un correo real (gmail, hotmail, outlook, yahoo, etc.).");
    }
    formulario.value.email = validacionCorreo.correo;
  }

  const dni = formulario.value.dni.trim();
  const correo = formulario.value.email.trim().toLowerCase();
  const otroCliente = (cliente) =>
    !editandoId.value || cliente.id !== editandoId.value;

  if (
    clientes.value.some((c) => otroCliente(c) && (c.dni || "").trim() === dni)
  ) {
    return (errorFormulario.value = "Ya existe un cliente con ese DNI.");
  }
  if (
    correo &&
    clientes.value.some(
      (c) => otroCliente(c) && (c.email || "").trim().toLowerCase() === correo,
    )
  ) {
    return (errorFormulario.value =
      "Ya existe un cliente con ese correo electrónico.");
  }

  guardando.value = true;
  try {
    const condiciones = [`dni.eq.${dni}`];
    if (correo) condiciones.push(`email.ilike.${correo}`);
    const { data: existentes, error: errExistentes } = await supabase
      .from("clientes")
      .select("id, dni, email")
      .or(condiciones.join(","));
    if (errExistentes) throw errExistentes;
    const duplicado = existentes?.find(
      (c) => !editandoId.value || c.id !== editandoId.value,
    );
    if (duplicado) {
      errorFormulario.value =
        (duplicado.dni || "").trim() === dni
          ? "Ya existe un cliente con ese DNI."
          : "Ya existe un cliente con ese correo electrónico.";
      return;
    }

    const { data: veterinariaId, error: errVet } = await supabase.rpc(
      "obtener_mi_veterinaria_id",
    );
    if (errVet) throw errVet;

    const datos = {
      nombre_completo: formulario.value.nombre_completo.trim(),
      telefono: formulario.value.telefono.trim(),
      email: formulario.value.email.trim() || null,
      direccion: formulario.value.direccion.trim() || null,
      dni: formulario.value.dni.trim() || null,
    };

    let error;
    if (editandoId.value) {
      const { data, error: errUpd } = await supabase
        .from("clientes")
        .update(datos)
        .eq("id", editandoId.value)
        .select("id");
      error = errUpd;
      if (!error && !data?.length)
        error = { message: "No tenés permiso para modificar este cliente." };
    } else {
      ({ error } = await supabase
        .from("clientes")
        .insert({ ...datos, veterinaria_id: veterinariaId }));
    }
    if (error) throw error;

    mostrarFormulario.value = false;
    notificar(editandoId.value ? "Cliente actualizado" : "Cliente registrado");
    await cargar();
  } catch (e) {
    errorFormulario.value = traducirError(e.message);
  } finally {
    guardando.value = false;
  }
}

async function eliminarCliente(cliente) {
  const mascotas = cliente.mascotas?.length || 0;
  const aviso =
    mascotas > 0
      ? `¿Querés eliminar a ${cliente.nombre_completo}? Se van a borrar también sus ${mascotas} mascota(s) y todo su historial.`
      : `¿Querés eliminar a ${cliente.nombre_completo}?`;
  if (!window.confirm(aviso)) return;

  cargando.value = true;
  try {
    const { data: filasBorradas, error } = await supabase
      .from("clientes")
      .delete()
      .eq("id", cliente.id)
      .select("id");

    if (error) throw error;

    if (!filasBorradas?.length) {
      notificar("No tenés permiso para eliminar este cliente.");
      return;
    }

    notificar("Cliente eliminado");
    await cargar();
  } catch (e) {
    notificar(traducirError(e.message));
  } finally {
    cargando.value = false;
  }
}

onMounted(cargar);
</script>

<template>
  <section class="contenido-pagina">
    <div class="encabezado-pagina">
      <div>
        <p class="sobretitulo">AGENDA Y CONTACTOS</p>
        <h1>Clientes</h1>
        <p class="texto-atenuado">Gestioná dueños y sus mascotas asociadas.</p>
      </div>
      <button class="boton-principal" @click="abrirFormulario()">
        <Plus /> Agregar cliente
      </button>
    </div>

    <div class="barra-herramientas">
      <label class="campo-busqueda">
        <span><Search /></span>
        <input
          v-model="busqueda"
          placeholder="Buscar cliente por nombre, teléfono o email"
        />
      </label>
    </div>

    <div v-if="cargando" class="estado-vacio panel">
      <p>Cargando clientes...</p>
    </div>

    <div v-else-if="!clientes.length" class="estado-vacio panel">
      <span class="icono-vacio"><Users /></span>
      <strong>Todavía no hay clientes registrados</strong>
      <p>Registrá al primer dueño con “Agregar cliente”.</p>
    </div>

    <div v-else-if="!clientesFiltrados.length" class="estado-vacio panel">
      <p>No hay clientes que coincidan con la búsqueda.</p>
    </div>

    <div v-else class="tarjetas-cliente">
      <div
        v-for="cliente in clientesFiltrados"
        :key="cliente.id"
        class="panel tarjeta-cliente"
      >
        <span class="avatar-cliente">{{
          iniciales(cliente.nombre_completo)
        }}</span>
        <div>
          <h3>{{ cliente.nombre_completo }}</h3>
          <p>
            {{ cliente.telefono
            }}<template v-if="cliente.email"> · {{ cliente.email }}</template>
          </p>
          <small>
            {{ cliente.mascotas?.length || 0 }}
            {{ cliente.mascotas?.length === 1 ? "mascota" : "mascotas" }}
          </small>
        </div>
        <button
          class="menu-fila"
          :aria-label="'Editar ' + cliente.nombre_completo"
          @click="abrirFormulario(cliente)"
        >
          <Pencil />
        </button>
        <button
          class="menu-fila eliminar"
          :aria-label="'Eliminar ' + cliente.nombre_completo"
          @click="eliminarCliente(cliente)"
          style="margin-left: 6px; color: #ae5757"
        >
          <Trash2 />
        </button>
      </div>
    </div>

    <div
      v-if="mostrarFormulario"
      class="fondo-modal"
      @click.self="mostrarFormulario = false"
    >
      <section class="ventana-reserva">
        <button
          class="cerrar-modal"
          aria-label="Cerrar"
          @click="mostrarFormulario = false"
        >
          <X />
        </button>
        <p class="sobretitulo">{{ editandoId ? "MODIFICACIÓN" : "ALTA" }}</p>
        <h2>{{ editandoId ? "Editar cliente" : "Nuevo cliente" }}</h2>
        <p class="texto-atenuado">
          Datos de contacto del dueño de las mascotas.
        </p>

        <form class="formulario-modal" @submit.prevent="guardar">
          <label>
            Nombre y apellido *
            <input
              v-model="formulario.nombre_completo"
              type="text"
              maxlength="120"
              placeholder="Ej: Martín López"
              @input="limpiarNombre"
            />
          </label>

          <div class="fila">
            <label>
              Teléfono *
              <input
                v-model="formulario.telefono"
                type="tel"
                inputmode="numeric"
                maxlength="15"
                placeholder="Ej: 11 4567 8901"
                @input="
                  formulario.telefono = formulario.telefono
                    .replace(/[^0-9 +()\-]/g, '')
                    .slice(0, 15)
                "
              />
            </label>
            <label>
              DNI *
              <input
                v-model="formulario.dni"
                type="text"
                inputmode="numeric"
                maxlength="8"
                minlength="8"
                required
                placeholder="Ej: 30123456"
                @input="
                  formulario.dni = formulario.dni
                    .replace(/[^0-9]/g, '')
                    .slice(0, 8)
                "
              />
            </label>
          </div>

          <label>
            Correo electrónico
            <input
              v-model="formulario.email"
              type="email"
              maxlength="120"
              placeholder="Ej: martin@email.com"
            />
          </label>

          <label>
            Dirección *
            <input
              v-model="formulario.direccion"
              type="text"
              maxlength="160"
              required
              placeholder="Ej: Av. Siempreviva 742"
            />
          </label>

          <p v-if="editandoId" class="nota-modal">
            El correo se usa para vincular la cuenta del cliente con su portal.
          </p>

          <p v-if="errorFormulario" class="error-modal">
            <TriangleAlert /> {{ errorFormulario }}
          </p>

          <div class="acciones-modal">
            <button
              type="button"
              class="boton-contorno"
              @click="mostrarFormulario = false"
            >
              Cancelar
            </button>
            <button type="submit" class="boton-principal" :disabled="guardando">
              <Plus />
              {{
                guardando
                  ? "Guardando..."
                  : editandoId
                    ? "Guardar cambios"
                    : "Registrar cliente"
              }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </section>
</template>
