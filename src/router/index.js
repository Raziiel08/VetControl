import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from '@/supabase'

// Todas las vistas se cargan bajo demanda (código por ruta).
const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/inicio',
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/LoginView.vue'),
    },
    {
      path: '/registro',
      name: 'registro',
      component: () => import('@/views/RegistroView.vue'),
    },
    {
      path: '/inicio',
      name: 'inicio',
      component: () => import('@/views/InicioView.vue'),
      meta: { requiereAutenticacion: true },
    },
    {
      path: '/productos',
      name: 'productos',
      component: () => import('@/views/ProductosView.vue'),
      meta: { requiereAutenticacion: true },
    },
    {
      path: '/cambiar-clave',
      name: 'cambiar-clave',
      component: () => import('@/views/CambiarClaveView.vue'),
      meta: { requiereAutenticacion: true },
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'no-encontrada',
      component: () => import('@/views/NotFoundView.vue'),
    },
  ],
})

router.beforeEach(async (to) => {
  const {
    data: { session },
  } = await supabase.auth.getSession()

  const paginasPublicas = ['login', 'registro']
  const esPublica = paginasPublicas.includes(to.name)

  // Si la ruta requiere autenticación y no hay sesión, ir al login
  if (to.meta.requiereAutenticacion && !session) {
    return { name: 'login' }
  }

  // Si el usuario ya está conectado e intenta ir a login o registro, ir a inicio
  if (session && esPublica) {
    return { name: 'inicio' }
  }

  return true
})

export default router
