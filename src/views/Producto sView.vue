<script setup>
import { ArrowLeft, Plus } from "lucide-vue-next";
</script>

<template>
  <div class="pagina-acceso">
    <div class="tarjeta-acceso">
      <div class="marca-acceso">
        <span class="icono-marca"><Plus /></span>
        <div>
          <span class="texto-marca-acceso"
            ><strong>Vet</strong><b>Control</b></span
          >
          <small>Gestión veterinaria simple</small>
        </div>
      </div>

      <h1>Página no encontrada</h1>
      <p class="subtitulo-acceso">
        El enlace que seguiste no existe o ya no está disponible.
      </p>

      <p class="enlace-acceso">
        <router-link to="/inicio"><ArrowLeft /> Volver al inicio</router-link>
      </p>
    </div>
  </div>
</template>

<style scoped>
.pagina-acceso {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 20px;
  background: linear-gradient(135deg, #f5f8f4 0%, #e7f5da 100%);
}
.tarjeta-acceso {
  width: min(100%, 420px);
  padding: 40px;
  background: #fff;
  border-radius: 16px;
  border: 1px solid var(--borde);
  box-shadow: 0 8px 30px rgba(27, 94, 58, 0.08);
  text-align: center;
}
.marca-acceso {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin-bottom: 32px;
}
.texto-marca-acceso strong,
.texto-marca-acceso b {
  font-size: 22px;
  letter-spacing: -0.8px;
}
.texto-marca-acceso strong {
  color: var(--verde-oscuro);
}
.texto-marca-acceso b {
  color: var(--verde);
}
.marca-acceso small {
  display: block;
  color: var(--atenuado);
  font-size: 10px;
  font-weight: 600;
}
.tarjeta-acceso h1 {
  color: var(--verde-oscuro);
  font-size: 24px;
  font-weight: 800;
  letter-spacing: -0.5px;
  margin-bottom: 6px;
}
.subtitulo-acceso {
  color: var(--atenuado);
  font-size: 13px;
  margin-bottom: 28px;
}
.enlace-acceso a {
  color: var(--verde);
  font-weight: 700;
  text-decoration: none;
}
.enlace-acceso a:hover {
  text-decoration: underline;
}
</style>
