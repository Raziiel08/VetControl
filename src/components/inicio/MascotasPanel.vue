<script setup>
import {
  ArrowRight,
  PawPrint,
  Pencil,
  Plus,
  Search,
  Syringe,
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

const ESPECIES = ["Perro", "Gato", "Ave", "Conejo", "Otro"];

const mascotas = ref([]);
const clientes = ref([]);
const vacunas = ref([]);
const cargando = ref(true);
const busqueda = ref("");

const mostrarFormulario = ref(false);
const guardando = ref(false);
const errorFormulario = ref("");
const editandoId = ref(null);
const formulario = ref(vacio());

const mostrarFicha = ref(false);
const ficha = ref(null);

const mostrarVacuna = ref(false);
const guardandoVacuna = ref(false);
const errorVacuna = ref("");
const formularioVacuna = ref(vacioVacuna());

function vacioVacuna() {
  return {
    nombre: "",
    dosis: "",
    fecha_aplicacion: isoLocal(),
    fecha_proxima: "",
    notas: "",
  };
}

function vacio() {
  return {
    nombre: "",
    especie: "Perro",
    raza: "",
    sexo: "",
    fecha_nacimiento: "",
    peso_kg: "",
    alergias: "",
    observaciones: "",
    cliente_id: "",
  };
}

const mascotasFiltradas = computed(() => {
  const texto = busqueda.value.trim().toLowerCase();
  if (!texto) return mascotas.value;
  return mascotas.value.filter(
    (p) =>
      p.nombre.toLowerCase().includes(texto) ||
      (p.clientes?.nombre_completo || "").toLowerCase().includes(texto),
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

function edadDe(fechaNacimiento) {
  if (!fechaNacimiento) return "Sin registrar";
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

function estadoMedico(mascota) {
  const deLaMascota = vacunas.value.filter((v) => v.mascota_id === mascota.id);
  if (!deLaMascota.length) return { texto: "Sin registro", color: "amarillo" };
  const hoy = isoLocal();
  if (deLaMascota.some((v) => v.fecha_proxima && v.fecha_proxima < hoy)) {
    return { texto: "Vacuna vencida", color: "rojo" };
  }
  const proximas = deLaMascota.filter((v) => v.fecha_proxima);
  if (proximas.length) return { texto: "Vacunas al día", color: "verde" };
  return { texto: "Sin próximas vacunas", color: "amarillo" };
}

async function cargar() {
  cargando.value = true;
  try {
    const [mascotasRes, clientesRes, vacunasRes] = await Promise.all([
      supabase
        .from("mascotas")
        .select(
          "id, nombre, especie, raza, sexo, fecha_nacimiento, peso_kg, alergias, observaciones, cliente_id, clientes(nombre_completo)",
        )
        .order("nombre"),
      supabase
        .from("clientes")
        .select("id, nombre_completo")
        .order("nombre_completo"),
      supabase
        .from("vacunas")
        .select(
          "id, mascota_id, nombre, fecha_aplicacion, fecha_proxima, dosis",
        ),
    ]);
    if (mascotasRes.error) throw mascotasRes.error;
    mascotas.value = mascotasRes.data || [];
    if (!clientesRes.error) clientes.value = clientesRes.data || [];
    if (!vacunasRes.error) vacunas.value = vacunasRes.data || [];
  } catch (e) {
    notificar(traducirError(e.message));
  } finally {
    cargando.value = false;
  }
}

function abrirFormulario(mascota = null) {
  errorFormulario.value = "";
  editandoId.value = mascota?.id ?? null;
  formulario.value = mascota
    ? {
        nombre: mascota.nombre,
        especie: mascota.especie,
        raza: mascota.raza || "",
        sexo: mascota.sexo || "",
        fecha_nacimiento: mascota.fecha_nacimiento || "",
        peso_kg: mascota.peso_kg ?? "",
        alergias: mascota.alergias || "",
        observaciones: mascota.observaciones || "",
        cliente_id: mascota.cliente_id || "",
      }
    : vacio();
  mostrarFormulario.value = true;
}

async function guardar() {
  errorFormulario.value = "";
  if (!formulario.value.nombre.trim())
    return (errorFormulario.value = "El nombre es obligatorio.");
  if (!formulario.value.cliente_id)
    return (errorFormulario.value = "Elegí el dueño de la mascota.");
  if (
    formulario.value.peso_kg !== "" &&
    isNaN(Number(formulario.value.peso_kg))
  ) {
    return (errorFormulario.value = "El peso debe ser un número.");
  }

  guardando.value = true;
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc(
      "obtener_mi_veterinaria_id",
    );
    if (errVet) throw errVet;

    const datos = {
      nombre: formulario.value.nombre.trim(),
      especie: formulario.value.especie,
      raza: formulario.value.raza.trim() || null,
      sexo: formulario.value.sexo || null,
      fecha_nacimiento: formulario.value.fecha_nacimiento || null,
      peso_kg:
        formulario.value.peso_kg === ""
          ? null
          : Number(formulario.value.peso_kg),
      alergias: formulario.value.alergias.trim() || null,
      observaciones: formulario.value.observaciones.trim() || null,
      cliente_id: formulario.value.cliente_id,
    };

    let error;
    if (editandoId.value) {
      const { data, error: errUpd } = await supabase
        .from("mascotas")
        .update(datos)
        .eq("id", editandoId.value)
        .select("id");
      error = errUpd;
      if (!error && !data?.length)
        error = { message: "No tenés permiso para modificar esta mascota." };
    } else {
      ({ error } = await supabase
        .from("mascotas")
        .insert({ ...datos, veterinaria_id: veterinariaId }));
    }
    if (error) throw error;

    mostrarFormulario.value = false;
    notificar(editandoId.value ? "Mascota actualizada" : "Mascota registrada");
    await cargar();
  } catch (e) {
    errorFormulario.value = traducirError(e.message);
  } finally {
    guardando.value = false;
  }
}

async function abrirFicha(mascota) {
  ficha.value = mascota;
  mostrarFicha.value = true;
  const { data, error } = await supabase
    .from("vacunas")
    .select(
      "id, mascota_id, nombre, dosis, fecha_aplicacion, fecha_proxima, notas",
    )
    .eq("mascota_id", mascota.id)
    .order("fecha_aplicacion", { ascending: false });
  if (!error)
    vacunas.value = [
      ...vacunas.value.filter((v) => v.mascota_id !== mascota.id),
      ...(data || []),
    ];
}

function irAClientes() {
  emit("navegar", "clientes");
}

async function recargarVacunas(mascotaId) {
  const { data, error } = await supabase
    .from("vacunas")
    .select(
      "id, mascota_id, nombre, dosis, fecha_aplicacion, fecha_proxima, notas",
    )
    .eq("mascota_id", mascotaId)
    .order("fecha_aplicacion", { ascending: false });
  if (!error) {
    vacunas.value = [
      ...vacunas.value.filter((v) => v.mascota_id !== mascotaId),
      ...(data || []),
    ];
  }
}

function abrirVacuna() {
  errorVacuna.value = "";
  formularioVacuna.value = vacioVacuna();
  mostrarVacuna.value = true;
}

async function guardarVacuna() {
  errorVacuna.value = "";
  if (!formularioVacuna.value.nombre.trim())
    return (errorVacuna.value = "Poné el nombre de la vacuna.");
  if (!formularioVacuna.value.fecha_aplicacion)
    return (errorVacuna.value = "Poné la fecha de aplicación.");
  if (
    formularioVacuna.value.fecha_proxima &&
    formularioVacuna.value.fecha_proxima <
      formularioVacuna.value.fecha_aplicacion
  ) {
    return (errorVacuna.value =
      "La próxima aplicación no puede ser anterior a la fecha aplicada.");
  }

  guardandoVacuna.value = true;
  try {
    const { data: veterinariaId, error: errVet } = await supabase.rpc(
      "obtener_mi_veterinaria_id",
    );
    if (errVet) throw errVet;

    const { error } = await supabase.from("vacunas").insert({
      veterinaria_id: veterinariaId,
      mascota_id: ficha.value.id,
      nombre: formularioVacuna.value.nombre.trim(),
      dosis: formularioVacuna.value.dosis.trim() || null,
      fecha_aplicacion: formularioVacuna.value.fecha_aplicacion,
      fecha_proxima: formularioVacuna.value.fecha_proxima || null,
      notas: formularioVacuna.value.notas.trim() || null,
    });
    if (error) throw error;

    mostrarVacuna.value = false;
    notificar("Vacuna registrada");
    await recargarVacunas(ficha.value.id);
  } catch (e) {
    errorVacuna.value = traducirError(e.message);
  } finally {
    guardandoVacuna.value = false;
  }
}

onMounted(cargar);
</script>

<template>
  <section class="contenido-pagina">
    <div class="encabezado-pagina">
      <div>
        <p class="sobretitulo">REGISTRO DE PACIENTES</p>
        <h1>Mascotas</h1>
        <p class="texto-atenuado">
          Accedé rápido a la ficha médica de cada paciente.
        </p>
      </div>
      <button class="boton-principal" @click="abrirFormulario()">
        <Plus /> Agregar mascota
      </button>
    </div>

    <div class="barra-herramientas">
      <label class="campo-busqueda">
        <span><Search /></span>
        <input v-model="busqueda" placeholder="Buscar por nombre o dueño" />
      </label>
    </div>

    <div class="tabla-mascotas panel">
      <div class="encabezado-tabla">
        <span>MASCOTA</span><span>DUEÑO</span><span>EDAD</span
        ><span>ESTADO MÉDICO</span><span></span>
      </div>

      <div v-if="cargando" class="estado-vacio">
        <p>Cargando mascotas...</p>
      </div>

      <div v-else-if="!mascotas.length" class="estado-vacio">
        <span class="icono-vacio"><PawPrint /></span>
        <strong>Todavía no hay mascotas registradas</strong>
        <p>Registrá la primera con “Agregar mascota”.</p>
        <button
          v-if="!clientes.length"
          class="boton-texto"
          style="margin-top: 8px"
          @click="irAClientes"
        >
          Primero cargá un dueño <ArrowRight />
        </button>
      </div>

      <div v-else-if="!mascotasFiltradas.length" class="estado-vacio">
        <p>No hay mascotas que coincidan con la búsqueda.</p>
      </div>

      <button
        v-for="mascota in mascotasFiltradas"
        :key="mascota.id"
        class="fila-mascota"
        @click="abrirFicha(mascota)"
      >
        <div class="celda-mascota">
          <span class="avatar-mascota">{{ iniciales(mascota.nombre) }}</span>
          <span>
            <strong>{{ mascota.nombre }}</strong>
            <small
              >{{ mascota.especie
              }}<template v-if="mascota.raza">
                · {{ mascota.raza }}</template
              ></small
            >
          </span>
        </div>
        <span>{{ mascota.clientes?.nombre_completo || "Sin dueño" }}</span>
        <span>{{ edadDe(mascota.fecha_nacimiento) }}</span>
        <span>
          <b class="estado" :class="estadoMedico(mascota).color">{{
            estadoMedico(mascota).texto
          }}</b>
        </span>
        <span class="flecha"><ArrowRight /></span>
      </button>
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
        <h2>{{ editandoId ? "Editar mascota" : "Nueva mascota" }}</h2>
        <p class="texto-atenuado">Completá los datos del paciente.</p>

        <div
          v-if="!clientes.length"
          class="nota-modal"
          style="margin-top: 16px"
        >
          Primero necesitás registrar al dueño.
          <button
            class="boton-texto"
            style="margin-left: 6px"
            @click="
              mostrarFormulario = false;
              irAClientes();
            "
          >
            Ir a Clientes <ArrowRight />
          </button>
        </div>

        <form v-else class="formulario-modal" @submit.prevent="guardar">
          <div class="fila">
            <label>
              Nombre *
              <input
                v-model="formulario.nombre"
                type="text"
                maxlength="80"
                placeholder="Ej: Luna"
              />
            </label>
            <label>
              Especie *
              <select v-model="formulario.especie">
                <option v-for="e in ESPECIES" :key="e" :value="e">
                  {{ e }}
                </option>
              </select>
            </label>
          </div>

          <div class="fila">
            <label>
              Raza
              <input
                v-model="formulario.raza"
                type="text"
                maxlength="80"
                placeholder="Ej: Golden retriever"
              />
            </label>
            <label>
              Sexo
              <select v-model="formulario.sexo">
                <option value="">Sin informar</option>
                <option value="Macho">Macho</option>
                <option value="Hembra">Hembra</option>
              </select>
            </label>
          </div>

          <div class="fila">
            <label>
              Fecha de nacimiento
              <input v-model="formulario.fecha_nacimiento" type="date" />
            </label>
            <label>
              Peso (kg)
              <input
                v-model="formulario.peso_kg"
                type="text"
                inputmode="decimal"
                maxlength="6"
                placeholder="Ej: 12.5"
                @input="
                  formulario.peso_kg = formulario.peso_kg
                    .replace(/[^0-9.]/g, '')
                    .replace(/(\..*)\./g, '$1')
                "
              />
            </label>
          </div>

          <label>
            Dueño *
            <select v-model="formulario.cliente_id">
              <option value="" disabled>Elegí un cliente</option>
              <option v-for="c in clientes" :key="c.id" :value="c.id">
                {{ c.nombre_completo }}
              </option>
            </select>
          </label>

          <label>
            Alergias
            <input
              v-model="formulario.alergias"
              type="text"
              maxlength="200"
              placeholder="Ej: polen, ciertos alimentos"
            />
          </label>

          <label>
            Observaciones
            <textarea
              v-model="formulario.observaciones"
              rows="2"
              maxlength="500"
              placeholder="Notas de la ficha..."
            ></textarea>
          </label>

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
                    : "Registrar mascota"
              }}
            </button>
          </div>
        </form>
      </section>
    </div>

    <div
      v-if="mostrarFicha && ficha"
      class="fondo-modal"
      @click.self="mostrarFicha = false"
    >
      <section class="ventana-reserva">
        <button
          class="cerrar-modal"
          aria-label="Cerrar"
          @click="mostrarFicha = false"
        >
          <X />
        </button>
        <div class="encabezado-perfil-mascota" style="margin-top: 4px">
          <span class="avatar-mascota-grande lima">{{
            iniciales(ficha.nombre)
          }}</span>
          <div>
            <p class="sobretitulo">FICHA DE MASCOTA</p>
            <h2>{{ ficha.nombre }}</h2>
            <p class="texto-atenuado">
              {{ ficha.especie
              }}<template v-if="ficha.raza"> · {{ ficha.raza }}</template> ·
              {{ edadDe(ficha.fecha_nacimiento) }}
              <template v-if="ficha.peso_kg">
                · {{ ficha.peso_kg }} kg</template
              >
            </p>
          </div>
        </div>

        <div class="ficha-datos">
          <div>
            <span>Dueño</span
            ><strong>{{
              ficha.clientes?.nombre_completo || "Sin dueño"
            }}</strong>
          </div>
          <div>
            <span>Sexo</span><strong>{{ ficha.sexo || "Sin informar" }}</strong>
          </div>
          <div>
            <span>Estado</span><strong>{{ estadoMedico(ficha).texto }}</strong>
          </div>
        </div>

        <div
          v-if="ficha.alergias"
          class="error-modal"
          style="background: #fff4d3; color: #ad7615"
        >
          <TriangleAlert /> Alergias: {{ ficha.alergias }}
        </div>
        <p v-if="ficha.observaciones" class="nota-modal">
          {{ ficha.observaciones }}
        </p>

        <div class="ficha-seccion">
          <div class="ficha-seccion-titulo">
            <h3><Syringe /> Vacunas</h3>
            <button class="boton-texto" @click="abrirVacuna">
              <Plus /> Agregar
            </button>
          </div>
          <div
            v-if="!vacunas.filter((v) => v.mascota_id === ficha.id).length"
            class="nota-modal"
          >
            Sin vacunas cargadas para esta mascota.
          </div>
          <div
            v-for="v in vacunas.filter((v) => v.mascota_id === ficha.id)"
            :key="v.id"
            class="vacuna-fila"
          >
            <strong>{{ v.nombre }}</strong>
            <small>
              Aplicada {{ v.fecha_aplicacion }}
              <template v-if="v.fecha_proxima">
                · próxima {{ v.fecha_proxima }}</template
              >
              <template v-if="v.dosis"> · {{ v.dosis }}</template>
            </small>
          </div>
        </div>

        <div class="acciones-modal">
          <button
            class="boton-contorno"
            @click="
              mostrarFicha = false;
              abrirFormulario(ficha);
            "
          >
            <Pencil /> Editar
          </button>
          <button class="boton-principal" @click="mostrarFicha = false">
            <X /> Cerrar
          </button>
        </div>
      </section>
    </div>

    <div
      v-if="mostrarVacuna"
      class="fondo-modal"
      @click.self="mostrarVacuna = false"
    >
      <section class="ventana-reserva">
        <button
          class="cerrar-modal"
          aria-label="Cerrar"
          @click="mostrarVacuna = false"
        >
          <X />
        </button>
        <p class="sobretitulo">FICHA DE MASCOTA</p>
        <h2>Registrar vacuna</h2>
        <p class="texto-atenuado">
          Para {{ ficha?.nombre }}. La próxima aplicación sirve para avisar si
          está vencida.
        </p>

        <form class="formulario-modal" @submit.prevent="guardarVacuna">
          <label>
            Nombre de la vacuna
            <input
              v-model="formularioVacuna.nombre"
              type="text"
              maxlength="80"
              placeholder="Ej: Antirrábica"
              required
            />
          </label>

          <div class="fila">
            <label>
              Dosis
              <input
                v-model="formularioVacuna.dosis"
                type="text"
                maxlength="40"
                placeholder="Ej: 1 ml"
              />
            </label>
            <label>
              Aplicada
              <input
                v-model="formularioVacuna.fecha_aplicacion"
                type="date"
                required
              />
            </label>
          </div>

          <label>
            Próxima aplicación (opcional)
            <input v-model="formularioVacuna.fecha_proxima" type="date" />
          </label>

          <label>
            Notas (opcional)
            <textarea
              v-model="formularioVacuna.notas"
              rows="2"
              maxlength="300"
              placeholder="Reacciones, observaciones..."
            ></textarea>
          </label>

          <p v-if="errorVacuna" class="error-modal">
            <TriangleAlert /> {{ errorVacuna }}
          </p>

          <div class="acciones-modal">
            <button
              type="button"
              class="boton-contorno"
              @click="mostrarVacuna = false"
            >
              Cancelar
            </button>
            <button
              type="submit"
              class="boton-principal"
              :disabled="guardandoVacuna"
            >
              <Plus />
              {{ guardandoVacuna ? "Guardando..." : "Registrar vacuna" }}
            </button>
          </div>
        </form>
      </section>
    </div>
  </section>
</template>

<style scoped>
.ficha-datos {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin: 16px 0 12px;
}
.ficha-datos > div {
  padding: 9px 11px;
  border: 1px solid var(--borde);
  border-radius: 8px;
  background: #fbfcfb;
}
.ficha-datos span {
  display: block;
  color: var(--atenuado);
  font-size: 10px;
  font-weight: 700;
}
.ficha-datos strong {
  display: block;
  margin-top: 3px;
  color: var(--verde-oscuro);
  font-size: 12px;
}
.ficha-seccion {
  margin-top: 16px;
}
.ficha-seccion-titulo {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 9px;
}
.ficha-seccion-titulo h3 {
  margin-bottom: 0;
}
.ficha-seccion-titulo .boton-texto {
  font-size: 11px;
}
.ficha-seccion h3 {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-bottom: 9px;
  color: var(--verde-oscuro);
  font-size: 13px;
  font-weight: 800;
}
.vacuna-fila {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 9px 11px;
  border-top: 1px solid #eef1ee;
  font-size: 12px;
}
.vacuna-fila small {
  color: var(--atenuado);
  font-size: 10px;
}
.error-modal svg,
.nota-modal svg {
  vertical-align: -2px;
}
.error-modal {
  display: flex;
  align-items: center;
  gap: 6px;
}
</style>
