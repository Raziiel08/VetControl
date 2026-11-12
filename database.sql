create table public.veterinarias (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  cuit_rut text,
  telefono text,
  email text,
  direccion text,
  creado_en timestamptz not null default now()
);

create table public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  veterinaria_id uuid references public.veterinarias(id) on delete cascade,
  nombre_completo text not null,
  rol text not null check (rol in ('admin_veterinaria', 'veterinario', 'cliente')),
  telefono text,
  creado_en timestamptz not null default now()
);

create table public.clientes (
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

create table public.mascotas (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null references public.veterinarias(id) on delete cascade,
  cliente_id uuid not null references public.clientes(id) on delete cascade,
  nombre text not null,
  especie text not null check (especie in ('Perro', 'Gato', 'Ave', 'Conejo', 'Otro')),
  raza text,
  sexo text check (sexo in ('Macho', 'Hembra')),
  fecha_nacimiento date,
  peso_kg numeric check (peso_kg > 0),
  alergias text,
  observaciones text,
  creado_en timestamptz not null default now()
);

create table public.servicios (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null references public.veterinarias(id) on delete cascade,
  nombre text not null,
  descripcion text,
  duracion_minutos integer not null default 30 check (duracion_minutos > 0),
  precio numeric not null check (precio >= 0),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create table public.turnos (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null references public.veterinarias(id) on delete cascade,
  mascota_id uuid not null references public.mascotas(id) on delete cascade,
  servicio_id uuid not null references public.servicios(id) on delete restrict,
  veterinario_id uuid references public.perfiles(id) on delete set null,
  fecha date not null,
  hora_inicio time not null,
  hora_fin time not null,
  estado text not null default 'Pendiente'
    check (estado in ('Pendiente', 'Confirmado', 'Atendido', 'Cancelado')),
  motivo text,
  creado_en timestamptz not null default now(),
  constraint turno_sin_superposicion unique (veterinaria_id, veterinario_id, fecha, hora_inicio)
);

create table public.consultas (
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
  peso_actual_kg numeric,
  proximo_control date,
  creado_en timestamptz not null default now()
);

create table public.productos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  veterinaria_id uuid not null references public.veterinarias(id) on delete cascade,
  nombre text not null,
  descripcion text,
  precio numeric not null check (precio >= 0),
  stock integer not null default 0 check (stock >= 0),
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  imagen_url text,
  imagen_ruta text,
  constraint productos_nombre_no_vacio check (length(trim(nombre)) > 0)
);


create or replace function public.obtener_mi_veterinaria_id()
returns uuid
language sql
stable
security definer
as $function$
  select veterinaria_id from public.perfiles where id = auth.uid();
$function$;

create or replace function public.obtener_mi_rol()
returns text
language sql
stable
security definer
set search_path to 'public'
as $function$
  select rol from public.perfiles where id = auth.uid();
$function$;

create or replace function public.crear_veterinaria_al_registrarse()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  nueva_veterinaria uuid;
begin
  insert into public.veterinarias (nombre, email)
  values (
    coalesce(nullif(trim(new.raw_user_meta_data->>'nombre_veterinaria'), ''), 'Mi veterinaria'),
    new.email
  )
  returning id into nueva_veterinaria;

  insert into public.perfiles (id, veterinaria_id, nombre_completo, rol)
  values (
    new.id,
    nueva_veterinaria,
    coalesce(nullif(trim(new.raw_user_meta_data->>'nombre_completo'), ''), split_part(new.email, '@', 1)),
    'admin_veterinaria'
  );

  return new;
end;
$function$;

alter table public.productos
  alter column veterinaria_id set default public.obtener_mi_veterinaria_id();

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.crear_veterinaria_al_registrarse();


alter table public.veterinarias enable row level security;
alter table public.perfiles enable row level security;
alter table public.clientes enable row level security;
alter table public.mascotas enable row level security;
alter table public.servicios enable row level security;
alter table public.turnos enable row level security;
alter table public.consultas enable row level security;
alter table public.productos enable row level security;

create policy "Usuarios acceden a su veterinaria" on public.veterinarias
for select to authenticated
using (id = public.obtener_mi_veterinaria_id());

create policy "Usuarios leen perfiles de su veterinaria" on public.perfiles
for select to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id() or id = auth.uid());

create policy "Acceso clientes por veterinaria" on public.clientes
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

create policy "Acceso mascotas por veterinaria" on public.mascotas
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

create policy "Acceso servicios por veterinaria" on public.servicios
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

create policy "Acceso turnos por veterinaria" on public.turnos
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

create policy "Acceso consultas por veterinaria" on public.consultas
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

-- productos: políticas por rol (etapa 7)
create policy "Ver productos de mi veterinaria" on public.productos
for select to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

create policy "Crear productos" on public.productos
for insert to authenticated
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

create policy "Modificar productos" on public.productos
for update to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
)
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

create policy "Eliminar productos" on public.productos
for delete to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() = 'admin_veterinaria'
);

grant select, insert, update, delete on all tables in schema public to authenticated;