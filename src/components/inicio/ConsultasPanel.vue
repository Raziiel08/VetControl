<script setup>
import {
  ArrowRight,
  Pencil,
  Plus,
  Search,
  Stethoscope,
  TriangleAlert,
  X,
} from "lucide-vue-next";
import { computed, onMounted, ref } from "vue";
import { supabase } from "@/supabase";
import { useToast } from "@/composables/useToast";
import { traducirError } from "@/utils/errores";
import { isoLocal } from "@/utils/fechas";

const emit = defineEmits(["navegar"]);
const { notificar } = useToast();

const consultas = ref([]);
const mascotas = ref([]);
const cargando = ref(true);
const busqueda = ref("");

const mostrarFormulario = ref(false);
const guardando = ref(false);
const errorFormulario = ref("");
const editandoId = ref(null);
const formulario = ref(vacio());

function vacio() {
  return {
    mascota_id: "",
    motivo: "",
    sintomas: "",
    diagnostico: "",
    tratamiento: "",
    peso_actual_kg: "",
    proximo_control: "",
  };
}

const consultasFiltradas = computed(() => {
  const texto = busqueda.value.trim().toLowerCase();
  const lista = [...consultas.value].sort(
    (a, b) => new Date(b.fecha) - new Date(a.fecha),
  );
  if (!texto) return lista;
  return lista.filter(
    (c) =>
      (c.mascota?.nombre || "").toLowerCase().includes(texto) ||
      (c.motivo || "").toLowerCase().includes(texto) ||
      (c.diagnostico || "").toLowerCase().includes(texto),
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

function fechaCorta(iso) {
  if (!iso) return "";
  return new Intl.DateTimeFormat("es-AR", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(new Date(iso));
}

function estadoDe(consulta) {
  if (!consulta.proximo_control) return { texto: "Completada", color: "verde" };
  const hoy = isoLocal();
  if (consulta.proximo_control < hoy)
    return { texto: "Control vencido", color: "rojo" };
  return { texto: "Completada", color: "verde" };
}

async function cargar() {
  cargando.value = true;
  try {
    const [consultasRes, mascotasRes] = await Promise.all([
      supabase
        .from("consultas")
        .select(
          "id, fecha, motivo, sintomas, diagnostico, tratamiento, peso_actual_kg, proximo_control, mascota_id, mascota:mascotas(nombre, clientes(nombre_completo))",
        )
        .order("fecha", { ascending: false })
        .limit(100),
      supabase
        .from("mascotas")
        .select("id, nombre, clientes(nombre_completo)")
        .order("nombre"),
    ]);
    if (consultasRes.error) throw consultasRes.error;
    consultas.value = consultasRes.data || [];
    if (!mascotasRes.error) mascotas.value = mascotasRes.data || [];
  } catch (e) {
    notificar(traducirError(e.message));
  } finally {
    cargando.value = false;
  }
}

function abrirFormulario(consulta = null) {
  errorFormulario.value = "";
  editandoId.value = consulta?.id ?? null;
  formulario.value = consulta
    ? {
        mascota_id: consulta.mascota_id,
        motivo: consulta.motivo || "",
        sintomas: consulta.sintomas || "",
        diagnostico: consulta.diagnostico || "",
        tratamiento: consulta.tratamiento || "",
        peso_actual_kg: consulta.peso_actual_kg ?? "",
        proximo_control: consulta.proximo_control || "",
      }
    : vacio();
  mostrarFormulario.value = true;
}

async function guardar() {
  errorFormulario.value = "";
  if (!formulario.value.mascota_id)
    return (errorFormulario.value = "Elegí la mascota.");
  if (!formulario.value.motivo.trim())
    return (errorFormulario.value = "El motivo es obligatorio.");
  if (!formulario.value.diagnostico.trim())
    return (errorFormulario.value = "El diagnóstico es obligatorio.");
  if (!formulario.value.tratamiento.trim())
    return (errorFormulario.value = "El tratamiento es obligatorio.");

  guardando.value = true;
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc(
      "obtener_mi_veterinaria_id",
    );
    if (errVet) throw errVet;
    const {
      data: { user: usuario },
    } = await supabase.auth.getUser();

    const datos = {
      mascota_id: formulario.value.mascota_id,
      motivo: formulario.value.motivo.trim(),
      sintomas: formulario.value.sintomas.trim() || null,
      diagnostico: formulario.value.diagnostico.trim(),
      tratamiento: formulario.value.tratamiento.trim(),
      peso_actual_kg:
        formulario.value.peso_actual_kg === ""
          ? null
          : Number(formulario.value.peso_actual_kg),
      proximo_control: formulario.value.proximo_control || null,
    };

    let error;
    if (editandoId.value) {
      const { data, error: errUpd } = await supabase
        .from("consultas")
        .update(datos)
        .eq("id", editandoId.value)
        .select("id");
      error = errUpd;
      if (!error && !data?.length)
        error = { message: "No tenés permiso para modificar esta consulta." };
    } else {
      ({ error } = await supabase.from("consultas").insert({
        ...datos,
        veterinaria_id: veterinariaId,
        veterinario_id: usuario?.id ?? null,
      }));
    }
    if (error) throw error;

    mostrarFormulario.value = false;
    notificar(
      editandoId.value ? "Consulta actualizada" : "Consulta registrada",
    );
    await cargar();
  } catch (e) {
    errorFormulario.value = traducirError(e.message);
  } finally {
    guardando.value = false;
  }
}

onMounted(cargar);
</script>

<template>
  <section class="contenido-pagina">
    <div class="encabezado-pagina">
      <div>
        <p class="sobretitulo">HISTORIAL CLÍNICO</p>
        <h1>Consultas</h1>
        <p class="texto-atenuado">
          Últimas consultas registradas y pendientes.
        </p>
      </div>
      <button class="boton-principal" @click="abrirFormulario()">
        <Plus /> Nueva consulta
      </button>
    </div>

    <div class="barra-herramientas">
      <label class="campo-busqueda">
        <span><Search /></span>
        <input
          v-model="busqueda"
          placeholder="Buscar por mascota, motivo o diagnóstico"
        />
      </label>
    </div>

    <div class="panel lista-consultas">
      <div v-if="cargando" class="estado-vacio">
        <p>Cargando consultas...</p>
      </div>

      <div v-else-if="!consultas.length" class="estado-vacio">
        <span class="icono-vacio"><Stethoscope /></span>
        <strong>No hay consultas registradas</strong>
        <p>Registrá la primera con “Nueva consulta”.</p>
        <button
          v-if="!mascotas.length"
          class="boton-texto"
          style="margin-top: 8px"
          @click="emit('navegar', 'mascotas')"
        >
          Primero registrá una mascota <ArrowRight />
        </button>
      </div>

      <div v-else-if="!consultasFiltradas.length" class="estado-vacio">
        <p>No hay consultas que coincidan con la búsqueda.</p>
      </div>

      <div
        v-for="item in consultasFiltradas"
        :key="item.id"
        class="fila-consulta"
      >
        <span class="avatar-mascota">{{
          iniciales(item.mascota?.nombre)
        }}</span>
        <div>
          <strong>{{ item.mascota?.nombre || "Mascota" }}</strong>
          <p>
            {{ item.motivo }}
            <template v-if="item.mascota?.clientes?.nombre_completo">
              · {{ item.mascota.clientes.nombre_completo }}
            </template>
          </p>
        </div>
        <small>{{ fechaCorta(item.fecha) }}</small>
        <b class="estado" :class="estadoDe(item).color">{{
          estadoDe(item).texto
        }}</b>
        <button class="boton-texto" @click="abrirFormulario(item)">
          Editar <ArrowRight />
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
        <p class="sobretitulo">{{ editandoId ? "MODIFICACIÓN" : "NUEVA" }}</p>
        <h2>{{ editandoId ? "Editar consulta" : "Registrar consulta" }}</h2>
        <p class="texto-atenuado">Historial clínico de la mascota.</p>

        <div
          v-if="!mascotas.length"
          class="nota-modal"
          style="margin-top: 16px"
        >
          Primero necesitás registrar una mascota.
          <button
            class="boton-texto"
            style="margin-left: 6px"
            @click="
              mostrarFormulario = false;
              emit('navegar', 'mascotas');
            "
          >
            Ir a Mascotas <ArrowRight />
          </button>
        </div>

        <form v-else class="formulario-modal" @submit.prevent="guardar">
          <label>
            Mascota *
            <select v-model="formulario.mascota_id">
              <option value="" disabled>Elegí una mascota</option>
              <option v-for="m in mascotas" :key="m.id" :value="m.id">
                {{ m.nombre
                }}<template v-if="m.clientes">
                  · {{ m.clientes.nombre_completo }}</template
                >
              </option>
            </select>
          </label>

          <label>
            Motivo de la consulta *
            <input
              v-model="formulario.motivo"
              type="text"
              maxlength="160"
              placeholder="Ej: control general"
            />
          </label>

          <label>
            Síntomas
            <textarea
              v-model="formulario.sintomas"
              rows="2"
              maxlength="500"
              placeholder="Ej: tos, apatía..."
            ></textarea>
          </label>

          <label>
            Diagnóstico *
            <textarea
              v-model="formulario.diagnostico"
              rows="2"
              maxlength="500"
              placeholder="Ej: infección leve"
            ></textarea>
          </label>

          <label>
            Tratamiento *
            <textarea
              v-model="formulario.tratamiento"
              rows="2"
              maxlength="500"
              placeholder="Ej: antibiótico 7 días"
            ></textarea>
          </label>

          <div class="fila">
            <label>
              Peso actual (kg)
              <input
                v-model="formulario.peso_actual_kg"
                type="number"
                min="0"
                step="0.1"
                placeholder="Ej: 12.5"
              />
            </label>
            <label>
              Próximo control
              <input v-model="formulario.proximo_control" type="date" />
            </label>
          </div>

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
                    : "Registrar consulta"
              }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </section>
</template>
