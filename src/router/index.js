import { createRouter, createWebHistory } from "vue-router";
import { supabase } from "@/supabase";

const enrutador = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: "/",
      redirect: "/inicio",
    },
    {
      path: "/login",
      name: "login",
      component: () => import("@/views/LoginView.vue"),
    },
    {
      path: "/registro",
      name: "registro",
      component: () => import("@/views/RegistroView.vue"),
    },
    {
      path: "/inicio",
      name: "inicio",
      component: () => import("@/views/InicioView.vue"),
      meta: { requiereAutenticacion: true },
    },
    {
      path: "/productos",
      name: "productos",
      component: () => import("@/views/ProductosView.vue"),
      meta: { requiereAutenticacion: true },
    },
    {
      path: "/cambiar-clave",
      name: "cambiar-clave",
      component: () => import("@/views/CambiarClaveView.vue"),
      meta: { requiereAutenticacion: true },
    },
    {
      path: "/:pathMatch(.*)*",
      name: "no-encontrada",
      component: () => import("@/views/NotFoundView.vue"),
    },
  ],
});

enrutador.beforeEach(async (ruta) => {
  const {
    data: { session: sesion },
  } = await supabase.auth.getSession();

  const paginasPublicas = ["login", "registro"];
  const esPublica = paginasPublicas.includes(ruta.name);

  if (ruta.meta.requiereAutenticacion && !sesion) {
    return { name: "login" };
  }

  if (sesion && esPublica) {
    return { name: "inicio" };
  }

  return true;
});

export default enrutador;
