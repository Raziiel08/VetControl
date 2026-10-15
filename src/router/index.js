import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from '@/supabase'
import LoginView from '@/views/LoginView.vue'
import RegistroView from '@/views/RegistroView.vue'
import InicioView from '@/views/InicioView.vue'
import ProductosView from '@/views/ProductosView.vue'

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
      component: LoginView,
    },
    {
      path: '/registro',
      name: 'registro',
      component: RegistroView,
    },
    {
      path: '/inicio',
      name: 'inicio',
      component: InicioView,
      meta: { requiereAutenticacion: true },
    },
    {
      path: '/productos',
      name: 'productos',
      component: ProductosView,
      meta: { requiereAutenticacion: true },
    },
    {
      path: '/cambiar-clave',
      name: 'cambiar-clave',
      component: () => import('@/views/CambiarClaveView.vue'),
      meta: { requiereAutenticacion: true },
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
