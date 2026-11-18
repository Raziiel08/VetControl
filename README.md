# VetControl

## ¿Qué es?

VetControl es una aplicación web para gestionar una clínica veterinaria chica: turnos, mascotas, clientes, consultas, productos y el portal de los dueños, todo junto y conectado a datos reales.

Está hecha con **Vue 3 + Vite** y **Supabase** (base de datos, ingreso con usuario y contraseña, e imágenes). La interfaz habla español, usa "vos" y solamente iconos SVG de `lucide-vue-next`: no hay emojis ni glifos de texto.

## ¿Qué podés hacer?

**Desde el panel de la veterinaria**

- Ver la agenda del día y de la semana, con métricas, crear turnos y cambiar sus estados.
- Gestionar clientes: altas, ediciones, búsqueda y las mascotas asociadas a cada uno.
- Gestionar mascotas: ficha, datos clínicos, consultas y vacunas con aviso de próxima aplicación.
- Registrar consultas y ver el historial de cada paciente.
- Configurar los datos de la clínica, el teléfono, la dirección y los horarios de atención.
- Administrar productos y farmacia: altas, ediciones, imágenes, stock y movimientos de entrada, salida y venta.

**Desde el portal del cliente**

- Reservar turnos online eligiendo servicio y horario.
- Ver las mascotas propias y sus turnos.
- Vincular la cuenta con la ficha de cliente.
- Usar el menú lateral desde el celular.

Cada cuenta entra donde corresponde: los clientes van directo al portal y el panel interno queda para el equipo de la veterinaria (administrador o veterinario). Si una sección nueva todavía no está habilitada en la base, la app lo avisa en lugar de romperse.

## Puesta en marcha

Completá `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` con los datos de tu proyecto Supabase.

```bash
npm install
npm run dev
```