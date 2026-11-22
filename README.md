# VetControl

## ¿Qué es?

VetControl es una aplicación web para gestionar una clínica veterinaria chica: turnos, mascotas, clientes, consultas, productos y el portal de los dueños, todo junto y conectado a datos reales.

Está hecha con **Vue 3 + Vite** y **Supabase** (base de datos, ingreso con usuario y contraseña, e imágenes).

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
- Comprar productos con stock desde la Tienda (carrito y confirmación de compra).
- Usar el menú lateral desde el celular.

## Cómo sumar veterinarios a una clínica

La primera persona que se registra con un nombre de veterinaria queda como **administrador** y se crea una clínica nueva. Para sumar más profesionales a **esa misma** clínica:

1. Entrá con la cuenta de administrador y andá a **Configuración → Código de invitación**.
2. Copiá el código de 8 caracteres y pasalo a la persona que querés sumar.
3. Esa persona abre `/registro`, elige **"Me invitaron"**, carga el código y completa correo y contraseña.
4. Queda como **veterinario** de esa clínica, con acceso al panel interno.

Registrarse otra vez con el mismo nombre de veterinaria **no une a nadie**: crea una clínica nueva.

En el registro se aceptan correos de proveedores conocidos (gmail, hotmail, outlook, yahoo, iCloud, live, aol, protonmail, mail.com, gmx, yandex, zoho y sus variantes `.com.ar`). No se aceptan dominios propios ni otros dominios, incluso si terminan en `.com`. El mensaje de error es: *"Usá un correo de gmail, hotmail, outlook, yahoo, iCloud, etc."*

## Puesta en marcha

Creá un archivo `.env` en la raíz con los datos de tu proyecto Supabase:

```env
VITE_SUPABASE_URL=https://TU-PROYECTO.supabase.co
VITE_SUPABASE_ANON_KEY=TU-CLAVE-PUBLICABLE
```

La app también acepta `VITE_SUPABASE_PUBLISHABLE_KEY` en lugar de `VITE_SUPABASE_ANON_KEY`.

```bash
npm install
npm run dev
```

La base de datos se crea aplicando `supabase/vet.sql` en el SQL Editor de Supabase. Ese archivo ya incluye las tablas, triggers, funciones, el bucket de imágenes y las políticas de seguridad.

Requiere **Node 22 o superior**

## Cuentas de prueba

**Veterinaria (administrador)**

- Correo: `qweq@gmail.com`
- Contraseña: `qweqadmin`

**Cliente (portal)**

- Correo: `qweqw@gmail.com`
- Contraseña: `qwecliente`


## Guía de uso

### Cómo ingresar

1. Abrí el sistema en el navegador: en local `http://localhost:5173`, o la versión publicada en `https://vetcontrol-012.netlify.app`.
2. Registrate desde `/registro`.
3. El sistema te lleva automáticamente a donde corresponde:
   - Si sos veterinaria o veterinario, entrás al **panel interno**.
   - Si sos cliente, entrás directo al **portal del cliente**.

### Qué puede hacer cada rol

**Administrador de la veterinaria (`admin_veterinaria`)**
- Ver la agenda del día y de la semana, con métricas.
- Crear, editar y cambiar el estado de los turnos.
- Dar de alta y editar clientes, y ver sus mascotas.
- Crear y editar mascotas, con ficha clínica, vacunas y consultas.
- Registrar consultas con diagnóstico y tratamiento.
- Configurar los datos de la clínica, teléfono, dirección y horarios de atención.
- Administrar productos y farmacia: altas, ediciones, bajas, stock y movimientos de entrada, salida y venta.
- Compartir el código de invitación desde Configuración para sumar veterinarios.


**Veterinario**
- Ver y gestionar la agenda, clientes, mascotas, turnos, consultas y vacunas.
- Registrar consultas y ver el historial de cada paciente.
- Ver, crear y editar productos. No puede eliminarlos ni administrar usuarios.

**Cliente**
- Reservar turnos online eligiendo servicio y horario disponible.
- Ver sus mascotas y su historial (consultas y vacunas).
- Ver sus turnos próximos y anteriores.
- Vincular su cuenta con la ficha de cliente.
- Comprar productos con stock desde la Tienda (carrito y confirmación de compra).

### Cómo completar la tarea principal

**Reservar un turno (cliente):**
1. Iniciá sesión con la cuenta de cliente.
2. En el portal, tocá **"Reservar turno"**.
3. **Paso 1:** elegí el servicio (consulta, control, vacunación).
4. **Paso 2:** elegí la mascota, la fecha y un horario disponible.
5. **Paso 3:** revisá el resumen y tocá **"Solicitar turno"**.
6. El turno queda creado en estado "Pendiente" y aparece en "Mis turnos".

**Registrar una mascota y su vacuna (veterinaria):**
1. Iniciá sesión con la cuenta de la veterinaria.
2. Andá a **Clientes**, creá o elegí un cliente y agregá una mascota.
3. En **Mascotas**, abrí la ficha de la mascota y tocá **"Agregar"** en Vacunas.
4. Completá nombre, dosis, fecha de aplicación y próxima aplicación. La ficha muestra "Vacunas al día" o "Vacuna próxima".

**Registrar un movimiento de stock (veterinaria):**
1. Andá a **Productos**, creá un producto (la imagen es opcional).
2. En el panel "Movimientos de stock", tocá **"Registrar movimiento"**.
3. Elegí el producto, el tipo (entrada, salida o venta), la cantidad y un motivo.
4. El stock del producto se actualiza automáticamente.