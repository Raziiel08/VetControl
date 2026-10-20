create extension if not exists "uuid-ossp";

create table if not exists public.veterinarias (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  cuit_rut text,
  telefono text,
  email text,
  direccion text,
  creado_en timestamptz not null default now()
);

create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  veterinaria_id uuid references public.veterinarias(id) on delete cascade,
  nombre_completo text not null,
  rol text not null check (rol in ('admin_veterinaria', 'veterinario', 'cliente')),
  telefono text,
  creado_en timestamptz not null default now()
);

create table if not exists public.clientes (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null references public.veterinarias(id) on delete cascade,
  perfil_id uuid references public.perfiles(id) on delete set null,
  nombre_completo text not null,
  email text,
  telefono text not null,
  direccion text,
  dni text,
  creado_en timestamptz not null default now()
);

create table if not exists public.mascotas (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null references public.veterinarias(id) on delete cascade,
  cliente_id uuid not null references public.clientes(id) on delete cascade,
  nombre text not null,
  especie text not null check (especie in ('Perro', 'Gato', 'Ave', 'Conejo', 'Otro')),
  raza text,
  sexo text check (sexo in ('Macho', 'Hembra')),
  fecha_nacimiento date,
  peso_kg numeric(5, 2) check (peso_kg > 0),
  alergias text,
  observaciones text,
  creado_en timestamptz not null default now()
);

create table if not exists public.servicios (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null references public.veterinarias(id) on delete cascade,
  nombre text not null,
  descripcion text,
  duracion_minutos integer not null default 30 check (duracion_minutos > 0),
  precio numeric(10, 2) not null check (precio >= 0),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create table if not exists public.turnos (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null references public.veterinarias(id) on delete cascade,
  mascota_id uuid not null references public.mascotas(id) on delete cascade,
  servicio_id uuid not null references public.servicios(id) on delete restrict,
  veterinario_id uuid references public.perfiles(id) on delete set null,
  fecha date not null,
  hora_inicio time not null,
  hora_fin time not null,
  estado text not null default 'Pendiente' check (estado in ('Pendiente', 'Confirmado', 'Atendido', 'Cancelado')),
  motivo text,
  creado_en timestamptz not null default now(),

  constraint turno_sin_superposicion unique (veterinaria_id, veterinario_id, fecha, hora_inicio)
);

create table if not exists public.consultas (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null references public.veterinarias(id) on delete cascade,
  mascota_id uuid not null references public.mascotas(id) on delete cascade,
  turno_id uuid references public.turnos(id) on delete set null,
  veterinario_id uuid references public.perfiles(id) on delete set null,
  fecha timestamptz not null default now(),
  motivo text not null,
  sintomas text,
  diagnostico text not null,
  tratamiento text not null,
  peso_actual_kg numeric(5, 2),
  proximo_control date,
  creado_en timestamptz not null default now()
);

create table if not exists public.productos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nombre text not null,
  descripcion text,
  precio numeric(12, 2) not null check (precio >= 0),
  stock integer not null default 0 check (stock >= 0),
  activo boolean not null default true,
  imagen_url text,
  imagen_ruta text,
  creado_en timestamptz not null default now()
);

alter table public.productos add column if not exists veterinaria_id uuid references public.veterinarias(id) on delete cascade;

alter table public.veterinarias enable row level security;
alter table public.perfiles enable row level security;
alter table public.clientes enable row level security;
alter table public.mascotas enable row level security;
alter table public.servicios enable row level security;
alter table public.turnos enable row level security;
alter table public.consultas enable row level security;
alter table public.productos enable row level security;

create or replace function public.obtener_mi_veterinaria_id()
returns uuid
language sql
security definer
stable
as $$
  select veterinaria_id from public.perfiles where id = auth.uid();
$$;

drop policy if exists "Usuarios acceden a su veterinaria" on public.veterinarias;
create policy "Usuarios acceden a su veterinaria"
on public.veterinarias for select to authenticated
using (id = public.obtener_mi_veterinaria_id());

drop policy if exists "Usuarios leen perfiles de su veterinaria" on public.perfiles;
create policy "Usuarios leen perfiles de su veterinaria"
on public.perfiles for select to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id() or id = auth.uid());

drop policy if exists "Acceso clientes por veterinaria" on public.clientes;
create policy "Acceso clientes por veterinaria"
on public.clientes for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso mascotas por veterinaria" on public.mascotas;
create policy "Acceso mascotas por veterinaria"
on public.mascotas for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso servicios por veterinaria" on public.servicios;
create policy "Acceso servicios por veterinaria"
on public.servicios for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso turnos por veterinaria" on public.turnos;
create policy "Acceso turnos por veterinaria"
on public.turnos for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso consultas por veterinaria" on public.consultas;
create policy "Acceso consultas por veterinaria"
on public.consultas for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso productos por veterinaria" on public.productos;
create policy "Acceso productos por veterinaria"
on public.productos for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id() or usuario_id = auth.uid())
with check (veterinaria_id = public.obtener_mi_veterinaria_id() or usuario_id = auth.uid());


grant select, insert, update, delete on all tables in schema public to authenticated;


insert into public.veterinarias (id, nombre, cuit_rut, telefono, email, direccion) values
('11111111-1111-1111-1111-111111111111', 'Veterinaria San Roque', '30-71234567-8', '011-4567-8901', 'contacto@sanroquevet.com', 'Av. Rivadavia 4520, CABA'),
('22222222-2222-2222-2222-222222222222', 'Clínica Veterinaria Huellitas', '30-79876543-2', '011-4890-1234', 'info@huellitasvet.com', 'Calle Belgrano 1280, San Isidro')
on conflict (id) do nothing;

insert into public.clientes (id, veterinaria_id, nombre_completo, email, telefono, direccion, dni) values
('c1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Sofía Ramos', 'sofia.ramos@gmail.com', '11-3456-7890', 'Av. Medrano 850', '38450123'),
('c1111111-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Martín López', 'martin.lopez@yahoo.com.ar', '11-8765-4321', 'Bulnes 1240', '35210984')
on conflict (id) do nothing;

insert into public.clientes (id, veterinaria_id, nombre_completo, email, telefono, direccion, dni) values
('c2222222-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'Esteban Morales', 'esteban.m@hotmail.com', '11-9988-7766', 'Av. Centenario 520', '32145698'),
('c2222222-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Camila Benítez', 'camila.b@gmail.com', '11-4433-2211', 'Primera Junta 890', '40567812')
on conflict (id) do nothing;

insert into public.mascotas (id, veterinaria_id, cliente_id, nombre, especie, raza, sexo, fecha_nacimiento, peso_kg, alergias, observaciones) values
('d1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'c1111111-0000-0000-0000-000000000001', 'Milo', 'Gato', 'Mestizo', 'Macho', '2023-03-10', 4.30, 'Ninguna', 'Dócil, vacunación al día'),
('d1111111-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'c1111111-0000-0000-0000-000000000002', 'Luna', 'Perro', 'Golden Retriever', 'Hembra', '2021-08-15', 28.50, 'Alergia a pulgas', 'Muy activa, requiere chequeo de cadera')
on conflict (id) do nothing;

insert into public.mascotas (id, veterinaria_id, cliente_id, nombre, especie, raza, sexo, fecha_nacimiento, peso_kg, alergias, observaciones) values
('d2222222-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'c2222222-0000-0000-0000-000000000001', 'Rocky', 'Perro', 'Beagle', 'Macho', '2019-11-20', 14.10, 'Intolerancia a pollo', 'Castrado'),
('d2222222-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'c2222222-0000-0000-0000-000000000002', 'Cleo', 'Gato', 'Siamés', 'Hembra', '2022-01-05', 3.80, 'Ninguna', 'Control anual')
on conflict (id) do nothing;

insert into public.servicios (id, veterinaria_id, nombre, descripcion, duracion_minutos, precio) values
('e1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Consulta General', 'Revisión clínica completa', 30, 8500.00),
('e1111111-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Vacunación Antirrábica', 'Aplicación y certificado oficial', 20, 6200.00)
on conflict (id) do nothing;

insert into public.servicios (id, veterinaria_id, nombre, descripcion, duracion_minutos, precio) values
('e2222222-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'Consulta Veterinaria Integral', 'Examen físico y preventivo', 40, 9000.00),
('e2222222-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Limpieza Dental por Ultrasonido', 'Tratamiento odontológico con sedación', 60, 24000.00)
on conflict (id) do nothing;

insert into public.turnos (veterinaria_id, mascota_id, servicio_id, fecha, hora_inicio, hora_fin, estado, motivo) values
('11111111-1111-1111-1111-111111111111', 'd1111111-0000-0000-0000-000000000001', 'e1111111-0000-0000-0000-000000000001', current_date + 1, '09:00', '09:30', 'Confirmado', 'Control anual y desparasitación'),
('11111111-1111-1111-1111-111111111111', 'd1111111-0000-0000-0000-000000000002', 'e1111111-0000-0000-0000-000000000002', current_date + 1, '10:30', '10:50', 'Pendiente', 'Refuerzo de vacuna séxtuple');

insert into public.turnos (veterinaria_id, mascota_id, servicio_id, fecha, hora_inicio, hora_fin, estado, motivo) values
('22222222-2222-2222-2222-222222222222', 'd2222222-0000-0000-0000-000000000001', 'e2222222-0000-0000-0000-000000000001', current_date + 2, '14:00', '14:40', 'Confirmado', 'Control digestivo periódico');