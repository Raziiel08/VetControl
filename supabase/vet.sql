
create table if not exists public.veterinarias (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  cuit_rut text,
  telefono text,
  email text,
  direccion text,
  codigo_invitacion text unique,
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
  peso_kg numeric check (peso_kg > 0),
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
  precio numeric not null check (precio >= 0),
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
  estado text not null default 'Pendiente'
    check (estado in ('Pendiente', 'Confirmado', 'Atendido', 'Cancelado')),
  motivo text,
  creado_en timestamptz not null default now()
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
  peso_actual_kg numeric,
  proximo_control date,
  creado_en timestamptz not null default now()
);

create table if not exists public.productos (
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

alter table public.productos
  add column if not exists usuario_id uuid
  not null default auth.uid() references auth.users(id) on delete cascade;
alter table public.productos add column if not exists imagen_url text;
alter table public.productos add column if not exists imagen_ruta text;

alter table public.veterinarias add column if not exists codigo_invitacion text unique;
update public.veterinarias
   set codigo_invitacion = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
 where codigo_invitacion is null;

create or replace function public.obtener_mi_veterinaria_id()
returns uuid
language sql
stable
security definer
set search_path to 'public'
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

create or replace function public.validar_codigo_invitacion(p_codigo text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1
      from public.veterinarias
     where codigo_invitacion is not null
       and upper(codigo_invitacion) = upper(coalesce(trim(p_codigo), ''))
  );
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

drop policy if exists "Usuarios acceden a su veterinaria" on public.veterinarias;
create policy "Usuarios acceden a su veterinaria" on public.veterinarias
for select to authenticated
using (id = public.obtener_mi_veterinaria_id());

drop policy if exists "Usuarios leen perfiles de su veterinaria" on public.perfiles;
create policy "Usuarios leen perfiles de su veterinaria" on public.perfiles
for select to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id() or id = auth.uid());

drop policy if exists "Acceso clientes por veterinaria" on public.clientes;
create policy "Acceso clientes por veterinaria" on public.clientes
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso mascotas por veterinaria" on public.mascotas;
create policy "Acceso mascotas por veterinaria" on public.mascotas
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso servicios por veterinaria" on public.servicios;
create policy "Acceso servicios por veterinaria" on public.servicios
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso turnos por veterinaria" on public.turnos;
create policy "Acceso turnos por veterinaria" on public.turnos
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso consultas por veterinaria" on public.consultas;
create policy "Acceso consultas por veterinaria" on public.consultas
for all to authenticated
using (veterinaria_id = public.obtener_mi_veterinaria_id())
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

drop policy if exists "Acceso productos por veterinaria" on public.productos;

drop policy if exists "Ver productos de mi veterinaria" on public.productos;
create policy "Ver productos de mi veterinaria" on public.productos
for select to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

drop policy if exists "Crear productos" on public.productos;
create policy "Crear productos" on public.productos
for insert to authenticated
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

drop policy if exists "Modificar productos" on public.productos;
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

drop policy if exists "Eliminar productos" on public.productos;
create policy "Eliminar productos" on public.productos
for delete to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() = 'admin_veterinaria'
);

grant select, insert, update, delete on all tables in schema public to authenticated;



alter table public.turnos drop constraint if exists turno_sin_superposicion;

do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conrelid = 'public.turnos'::regclass
       and conname = 'turno_horas_validas'
  ) then
    alter table public.turnos
      add constraint turno_horas_validas check (hora_fin > hora_inicio);
  end if;
end $$;

create or replace function public.proteger_cambios_de_perfil()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.rol is distinct from old.rol
     or new.veterinaria_id is distinct from old.veterinaria_id then
    raise exception 'No se puede modificar el rol ni la veterinaria de un perfil';
  end if;
  return new;
end;
$function$;

drop trigger if exists proteger_perfil on public.perfiles;
create trigger proteger_perfil
before update on public.perfiles
for each row execute function public.proteger_cambios_de_perfil();

create or replace function public.evitar_solape_turno()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  superpuesto integer;
begin
  select count(*)
    into superpuesto
    from public.turnos
   where id <> new.id
     and veterinaria_id = new.veterinaria_id
     and coalesce(veterinario_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(new.veterinario_id, '00000000-0000-0000-0000-000000000000'::uuid)
     and fecha = new.fecha
     and (fecha + hora_inicio) < (new.fecha + new.hora_fin)
     and (fecha + hora_fin) > (new.fecha + new.hora_inicio);

  if superpuesto > 0 then
    raise exception 'El turno se superpone con otro turno existente de ese día';
  end if;

  return new;
end;
$function$;

drop trigger if exists evitar_solape_turno on public.turnos;
create trigger evitar_solape_turno
before insert or update on public.turnos
for each row execute function public.evitar_solape_turno();


create index if not exists perfiles_veterinaria_id_idx on public.perfiles (veterinaria_id);
create index if not exists clientes_veterinaria_id_idx on public.clientes (veterinaria_id);
create index if not exists mascotas_cliente_id_idx on public.mascotas (cliente_id);
create index if not exists mascotas_veterinaria_id_idx on public.mascotas (veterinaria_id);
create index if not exists turnos_veterinaria_fecha_idx on public.turnos (veterinaria_id, fecha);
create index if not exists consultas_mascota_id_idx on public.consultas (mascota_id);
create index if not exists productos_veterinaria_id_idx on public.productos (veterinaria_id);


drop policy if exists "Actualizo los datos de mi veterinaria" on public.veterinarias;
create policy "Actualizo los datos de mi veterinaria" on public.veterinarias
for update to authenticated
using (id = public.obtener_mi_veterinaria_id())
with check (id = public.obtener_mi_veterinaria_id());

drop policy if exists "Actualizo mi perfil" on public.perfiles;
create policy "Actualizo mi perfil" on public.perfiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());


insert into storage.buckets (id, name, public)
values ('productos', 'productos', true)
on conflict (id) do nothing;

drop policy if exists "Imagenes de productos visibles" on storage.objects;
create policy "Imagenes de productos visibles" on storage.objects
for select
using (bucket_id = 'productos');

drop policy if exists "Subo imagenes a mi veterinaria" on storage.objects;
create policy "Subo imagenes a mi veterinaria" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'productos'
  and (storage.foldername(name))[1] = public.obtener_mi_veterinaria_id()::text
);

drop policy if exists "Edito imagenes de mi veterinaria" on storage.objects;
create policy "Edito imagenes de mi veterinaria" on storage.objects
for update to authenticated
using (
  bucket_id = 'productos'
  and (storage.foldername(name))[1] = public.obtener_mi_veterinaria_id()::text
)
with check (
  bucket_id = 'productos'
  and (storage.foldername(name))[1] = public.obtener_mi_veterinaria_id()::text
);

drop policy if exists "Borro imagenes de mi veterinaria" on storage.objects;
create policy "Borro imagenes de mi veterinaria" on storage.objects
for delete to authenticated
using (
  bucket_id = 'productos'
  and (storage.foldername(name))[1] = public.obtener_mi_veterinaria_id()::text
);



alter table public.perfiles add column if not exists email text;

alter table public.veterinarias add column if not exists horarios jsonb
  not null default '{
    "lunes_viernes": "09:00 - 18:00",
    "sabados": "09:00 - 13:00",
    "domingos": "Cerrado"
  }'::jsonb;

update public.perfiles p
   set email = u.email
  from auth.users u
 where p.id = u.id
   and p.email is null
   and u.email is not null;

alter table public.clientes  alter column veterinaria_id set default public.obtener_mi_veterinaria_id();
alter table public.mascotas  alter column veterinaria_id set default public.obtener_mi_veterinaria_id();
alter table public.turnos    alter column veterinaria_id set default public.obtener_mi_veterinaria_id();
alter table public.consultas alter column veterinaria_id set default public.obtener_mi_veterinaria_id();
alter table public.servicios alter column veterinaria_id set default public.obtener_mi_veterinaria_id();
alter table public.consultas alter column veterinario_id set default auth.uid();

create or replace function public.crear_veterinaria_al_registrarse()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  nueva_veterinaria uuid;
  veterinaria_invitada uuid;
  v_email text := lower(coalesce(new.email, ''));
  v_rol text := coalesce(nullif(trim(new.raw_user_meta_data->>'rol'), ''), 'veterinaria');
  v_codigo text := nullif(upper(trim(coalesce(new.raw_user_meta_data->>'codigo_invitacion', ''))), '');
  v_nombre text := coalesce(
    nullif(trim(new.raw_user_meta_data->>'nombre_completo'), ''),
    split_part(new.email, '@', 1)
  );
  v_cliente record;
begin
  if v_rol = 'cliente' then
    select c.id, c.veterinaria_id, c.perfil_id
      into v_cliente
      from public.clientes c
     where lower(coalesce(c.email, '')) = v_email
     order by c.creado_en
     limit 1;

    if v_cliente.id is null then
      raise exception 'No encontramos un cliente con ese correo. Pedí el alta en tu veterinaria y volvé a intentar.';
    end if;

    if v_cliente.perfil_id is not null and v_cliente.perfil_id <> new.id then
      raise exception 'Ese correo ya está vinculado a otra cuenta.';
    end if;

    insert into public.perfiles (id, veterinaria_id, nombre_completo, rol, email)
    values (new.id, v_cliente.veterinaria_id, v_nombre, 'cliente', new.email);

    update public.clientes set perfil_id = new.id where id = v_cliente.id;
    return new;
  end if;

  if v_codigo is not null then
    select id
      into veterinaria_invitada
      from public.veterinarias
     where codigo_invitacion is not null
       and upper(codigo_invitacion) = v_codigo;

    if veterinaria_invitada is null then
      raise exception 'El código de invitación no es válido. Pedile uno nuevo a tu veterinaria.';
    end if;

    insert into public.perfiles (id, veterinaria_id, nombre_completo, rol, email)
    values (new.id, veterinaria_invitada, v_nombre, 'veterinario', new.email);

    return new;
  end if;

  insert into public.veterinarias (nombre, email, codigo_invitacion)
  values (
    coalesce(nullif(trim(new.raw_user_meta_data->>'nombre_veterinaria'), ''), 'Mi veterinaria'),
    new.email,
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
  )
  returning id into nueva_veterinaria;

  insert into public.perfiles (id, veterinaria_id, nombre_completo, rol, email)
  values (new.id, nueva_veterinaria, v_nombre, 'admin_veterinaria', new.email);

  return new;
end;
$function$;

create or replace function public.obtener_mi_cliente_id()
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $function$
  select c.id
    from public.clientes c
   where c.perfil_id = auth.uid()
      or (
        c.veterinaria_id = public.obtener_mi_veterinaria_id()
        and lower(coalesce(c.email, '')) = lower(coalesce(auth.email(), ''))
        and c.perfil_id is null
      )
   order by (c.perfil_id = auth.uid()) desc
   limit 1;
$function$;

create or replace function public.vincular_mi_cliente()
returns uuid
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_vet uuid := public.obtener_mi_veterinaria_id();
  v_email text := lower(coalesce(auth.email(), ''));
  v_cliente uuid;
begin
  if v_vet is null or v_email = '' then
    return null;
  end if;

  select c.id into v_cliente
    from public.clientes c
   where c.perfil_id = auth.uid()
   limit 1;

  if v_cliente is not null then
    return v_cliente;
  end if;

  select c.id into v_cliente
    from public.clientes c
   where c.veterinaria_id = v_vet
     and lower(coalesce(c.email, '')) = v_email
     and c.perfil_id is null
   order by c.creado_en
   limit 1;

  if v_cliente is null then
    return null;
  end if;

  update public.clientes set perfil_id = auth.uid() where id = v_cliente;
  return v_cliente;
end;
$function$;

create or replace function public.evitar_solape_turno()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  superpuesto integer;
begin
  if new.estado = 'Cancelado' then
    return new;
  end if;

  select count(*)
    into superpuesto
    from public.turnos
   where id <> new.id
     and veterinaria_id = new.veterinaria_id
     and estado <> 'Cancelado'
     and coalesce(veterinario_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(new.veterinario_id, '00000000-0000-0000-0000-000000000000'::uuid)
     and fecha = new.fecha
     and (fecha + hora_inicio) < (new.fecha + new.hora_fin)
     and (fecha + hora_fin) > (new.fecha + new.hora_inicio);

  if superpuesto > 0 then
    raise exception 'Ese horario ya está ocupado por otro turno';
  end if;

  return new;
end;
$function$;

create or replace function public.proteger_cambios_de_perfil()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.veterinaria_id is distinct from old.veterinaria_id then
    raise exception 'No se puede cambiar la veterinaria de un perfil';
  end if;

  if new.rol is distinct from old.rol then
    if new.id = auth.uid() then
      raise exception 'No podés cambiar tu propio rol';
    end if;
    if coalesce(public.obtener_mi_rol(), '') <> 'admin_veterinaria'
       or new.veterinaria_id is distinct from public.obtener_mi_veterinaria_id() then
      raise exception 'Solo un administrador puede cambiar roles';
    end if;
  end if;

  return new;
end;
$function$;

create table if not exists public.vacunas (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null default public.obtener_mi_veterinaria_id()
    references public.veterinarias(id) on delete cascade,
  mascota_id uuid not null references public.mascotas(id) on delete cascade,
  nombre text not null,
  dosis text,
  fecha_aplicacion date not null default current_date,
  fecha_proxima date,
  veterinario_id uuid default auth.uid() references public.perfiles(id) on delete set null,
  notas text,
  creado_en timestamptz not null default now(),
  constraint vacunas_fechas_coherentes check (fecha_proxima is null or fecha_proxima >= fecha_aplicacion)
);

create table if not exists public.movimientos_stock (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null default public.obtener_mi_veterinaria_id()
    references public.veterinarias(id) on delete cascade,
  producto_id uuid not null references public.productos(id) on delete cascade,
  tipo text not null check (tipo in ('Entrada', 'Salida', 'Venta')),
  cantidad integer not null check (cantidad > 0),
  precio_unitario numeric check (precio_unitario is null or precio_unitario >= 0),
  motivo text,
  usuario_id uuid default auth.uid() references auth.users(id) on delete set null,
  creado_en timestamptz not null default now()
);

alter table public.vacunas enable row level security;
alter table public.movimientos_stock enable row level security;

create or replace function public.aplicar_movimiento_stock()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_delta integer;
  v_stock integer;
  v_vet uuid;
begin
  select stock, veterinaria_id into v_stock, v_vet
    from public.productos
   where id = new.producto_id
   for update;

  if not found then
    raise exception 'El producto no existe';
  end if;

  if v_vet is distinct from new.veterinaria_id then
    raise exception 'El producto pertenece a otra veterinaria';
  end if;

  v_delta := case new.tipo
    when 'Entrada' then new.cantidad
    else -new.cantidad
  end;

  if v_stock + v_delta < 0 then
    raise exception 'Stock insuficiente: quedan % unidades de ese producto', v_stock;
  end if;

  update public.productos set stock = v_stock + v_delta where id = new.producto_id;
  return new;
end;
$function$;

drop trigger if exists aplicar_movimiento_stock on public.movimientos_stock;
create trigger aplicar_movimiento_stock
before insert on public.movimientos_stock
for each row execute function public.aplicar_movimiento_stock();

drop policy if exists "Acceso clientes por veterinaria" on public.clientes;
drop policy if exists "Clientes: el staff gestiona su veterinaria" on public.clientes;
drop policy if exists "Clientes: el equipo gestiona su veterinaria" on public.clientes;
create policy "Clientes: el equipo gestiona su veterinaria" on public.clientes
for all to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
)
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

drop policy if exists "Clientes: el dueño ve su ficha" on public.clientes;
create policy "Clientes: el dueño ve su ficha" on public.clientes
for select to authenticated
using (id = public.obtener_mi_cliente_id());

drop policy if exists "Clientes: el dueño actualiza sus datos de contacto" on public.clientes;
create policy "Clientes: el dueño actualiza sus datos de contacto" on public.clientes
for update to authenticated
using (id = public.obtener_mi_cliente_id())
with check (id = public.obtener_mi_cliente_id());

drop policy if exists "Acceso mascotas por veterinaria" on public.mascotas;
drop policy if exists "Mascotas: el staff gestiona su veterinaria" on public.mascotas;
drop policy if exists "Mascotas: el equipo gestiona su veterinaria" on public.mascotas;
create policy "Mascotas: el equipo gestiona su veterinaria" on public.mascotas
for all to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
)
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

drop policy if exists "Mascotas: el dueño ve las suyas" on public.mascotas;
create policy "Mascotas: el dueño ve las suyas" on public.mascotas
for select to authenticated
using (cliente_id = public.obtener_mi_cliente_id());

drop policy if exists "Acceso servicios por veterinaria" on public.servicios;
drop policy if exists "Servicios: el staff gestiona su veterinaria" on public.servicios;
drop policy if exists "Servicios: el equipo gestiona su veterinaria" on public.servicios;
create policy "Servicios: el equipo gestiona su veterinaria" on public.servicios
for all to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
)
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

drop policy if exists "Servicios: se pueden ver para reservar" on public.servicios;
create policy "Servicios: se pueden ver para reservar" on public.servicios
for select to authenticated
using (activo);

drop policy if exists "Acceso turnos por veterinaria" on public.turnos;
drop policy if exists "Turnos: el staff gestiona su veterinaria" on public.turnos;
drop policy if exists "Turnos: el equipo gestiona su veterinaria" on public.turnos;
create policy "Turnos: el equipo gestiona su veterinaria" on public.turnos
for all to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
)
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

drop policy if exists "Turnos: el dueño ve los suyos" on public.turnos;
create policy "Turnos: el dueño ve los suyos" on public.turnos
for select to authenticated
using (
  mascota_id in (
    select m.id from public.mascotas m
     where m.cliente_id = public.obtener_mi_cliente_id()
  )
);

drop policy if exists "Turnos: el dueño cancela los suyos" on public.turnos;
create policy "Turnos: el dueño cancela los suyos" on public.turnos
for update to authenticated
using (
  mascota_id in (
    select m.id from public.mascotas m
     where m.cliente_id = public.obtener_mi_cliente_id()
  )
  and estado in ('Pendiente', 'Confirmado')
)
with check (
  mascota_id in (
    select m.id from public.mascotas m
     where m.cliente_id = public.obtener_mi_cliente_id()
  )
  and estado = 'Cancelado'
);

drop policy if exists "Turnos: el dueño reserva el suyo" on public.turnos;
create policy "Turnos: el dueño reserva el suyo" on public.turnos
for insert to authenticated
with check (
  estado = 'Pendiente'
  and mascota_id in (
    select m.id from public.mascotas m
     where m.cliente_id = public.obtener_mi_cliente_id()
  )
);

drop policy if exists "Acceso consultas por veterinaria" on public.consultas;
drop policy if exists "Consultas: el staff gestiona su veterinaria" on public.consultas;
drop policy if exists "Consultas: el equipo gestiona su veterinaria" on public.consultas;
create policy "Consultas: el equipo gestiona su veterinaria" on public.consultas
for all to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
)
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

drop policy if exists "Consultas: el dueño ve las de sus mascotas" on public.consultas;
create policy "Consultas: el dueño ve las de sus mascotas" on public.consultas
for select to authenticated
using (
  mascota_id in (
    select m.id from public.mascotas m
     where m.cliente_id = public.obtener_mi_cliente_id()
  )
);

drop policy if exists "Vacunas: el staff gestiona su veterinaria" on public.vacunas;
drop policy if exists "Vacunas: el equipo gestiona su veterinaria" on public.vacunas;
create policy "Vacunas: el equipo gestiona su veterinaria" on public.vacunas
for all to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
)
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

drop policy if exists "Vacunas: el dueño ve las de sus mascotas" on public.vacunas;
create policy "Vacunas: el dueño ve las de sus mascotas" on public.vacunas
for select to authenticated
using (
  mascota_id in (
    select m.id from public.mascotas m
     where m.cliente_id = public.obtener_mi_cliente_id()
  )
);

drop policy if exists "Movimientos: el staff de su veterinaria" on public.movimientos_stock;
drop policy if exists "Movimientos: el equipo de su veterinaria" on public.movimientos_stock;
create policy "Movimientos: el equipo de su veterinaria" on public.movimientos_stock
for all to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
)
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

drop policy if exists "Administradores actualizan su equipo" on public.perfiles;
create policy "Administradores actualizan su equipo" on public.perfiles
for update to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() = 'admin_veterinaria'
)
with check (veterinaria_id = public.obtener_mi_veterinaria_id());

insert into public.servicios (veterinaria_id, nombre, descripcion, duracion_minutos, precio)
select v.id, s.nombre, s.descripcion, s.duracion, 0
  from public.veterinarias v
 cross join (values
   ('Consulta general', 'Revisión y seguimiento', 30),
   ('Vacunación', 'Aplicación de vacunas', 20),
   ('Control', 'Seguimiento de tratamiento', 20)
 ) as s(nombre, descripcion, duracion)
 where not exists (
   select 1 from public.servicios x where x.veterinaria_id = v.id
 );

create index if not exists vacunas_mascota_id_idx on public.vacunas (mascota_id);
create index if not exists vacunas_vet_proxima_idx on public.vacunas (veterinaria_id, fecha_proxima);
create index if not exists movimientos_producto_idx on public.movimientos_stock (producto_id);
create index if not exists movimientos_vet_fecha_idx on public.movimientos_stock (veterinaria_id, creado_en);
create index if not exists clientes_perfil_id_idx on public.clientes (perfil_id);
create index if not exists clientes_email_idx on public.clientes (lower(coalesce(email, '')));

create unique index if not exists clientes_vet_dni_unique
  on public.clientes (veterinaria_id, dni)
  where dni is not null and trim(dni) <> '';

create unique index if not exists clientes_vet_email_unique
  on public.clientes (veterinaria_id, lower(coalesce(email, '')))
  where email is not null and trim(email) <> '';

grant select, insert, update, delete on all tables in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- Tienda del portal del cliente: compra de productos con stock
-- ---------------------------------------------------------------------------

create table if not exists public.pedidos (
  id uuid primary key default gen_random_uuid(),
  veterinaria_id uuid not null default public.obtener_mi_veterinaria_id()
    references public.veterinarias(id) on delete cascade,
  cliente_id uuid not null references public.clientes(id) on delete cascade,
  total numeric not null default 0 check (total >= 0),
  estado text not null default 'Pendiente'
    check (estado in ('Pendiente', 'Confirmado', 'Entregado', 'Cancelado')),
  creado_en timestamptz not null default now()
);

create table if not exists public.pedido_detalles (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos(id) on delete cascade,
  producto_id uuid not null references public.productos(id) on delete restrict,
  cantidad integer not null check (cantidad > 0),
  precio_unitario numeric not null check (precio_unitario >= 0)
);

alter table public.pedidos enable row level security;
alter table public.pedido_detalles enable row level security;

-- El cliente solo consulta sus propios pedidos; el equipo, los de su veterinaria.
drop policy if exists "Pedidos: el cliente ve los suyos" on public.pedidos;
create policy "Pedidos: el cliente ve los suyos" on public.pedidos
for select to authenticated
using (cliente_id = public.obtener_mi_cliente_id());

drop policy if exists "Pedidos: el equipo ve los de su veterinaria" on public.pedidos;
create policy "Pedidos: el equipo ve los de su veterinaria" on public.pedidos
for select to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

-- El detalle se lee siguiendo las reglas del pedido al que pertenece.
drop policy if exists "Detalle de pedido: se lee según el pedido" on public.pedido_detalles;
create policy "Detalle de pedido: se lee según el pedido" on public.pedido_detalles
for select to authenticated
using (
  pedido_id in (
    select p.id
      from public.pedidos p
     where p.cliente_id = public.obtener_mi_cliente_id()
        or (
          p.veterinaria_id = public.obtener_mi_veterinaria_id()
          and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
        )
  )
);

-- Los clientes ven los productos activos de su veterinaria para poder comprarlos.
drop policy if exists "Clientes ven productos para comprar" on public.productos;
create policy "Clientes ven productos para comprar" on public.productos
for select to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() = 'cliente'
  and activo
);

-- La compra se hace en una sola llamada: valida el stock, guarda el pedido y
-- descuenta las unidades mediante un movimiento de stock tipo "Venta".
create or replace function public.registrar_compra(p_items jsonb)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_vet uuid := public.obtener_mi_veterinaria_id();
  v_cliente uuid := public.obtener_mi_cliente_id();
  v_rol text := public.obtener_mi_rol();
  v_pedido uuid;
  v_total numeric := 0;
  item record;
  v_producto record;
begin
  if v_rol <> 'cliente' then
    raise exception 'Solo los clientes pueden realizar compras';
  end if;

  if v_cliente is null then
    raise exception 'Tu cuenta no está vinculada a una ficha de cliente';
  end if;

  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Tu carrito está vacío';
  end if;

  insert into public.pedidos (veterinaria_id, cliente_id)
  values (v_vet, v_cliente)
  returning id into v_pedido;

  for item in
    select *
      from jsonb_to_recordset(p_items) as x(producto_id uuid, cantidad integer)
  loop
    if item.producto_id is null or item.cantidad is null or item.cantidad <= 0 then
      raise exception 'La cantidad de cada producto debe ser mayor a cero';
    end if;

    select id, nombre, precio, stock, activo, veterinaria_id
      into v_producto
      from public.productos
     where id = item.producto_id
       for update;

    if not found or v_producto.veterinaria_id <> v_vet then
      raise exception 'Un producto del carrito no está disponible';
    end if;

    if not v_producto.activo then
      raise exception 'El producto % ya no está disponible', v_producto.nombre;
    end if;

    if v_producto.stock < item.cantidad then
      raise exception 'Stock insuficiente para %: quedan % unidades',
        v_producto.nombre, v_producto.stock;
    end if;

    insert into public.pedido_detalles (pedido_id, producto_id, cantidad, precio_unitario)
    values (v_pedido, item.producto_id, item.cantidad, v_producto.precio);

    insert into public.movimientos_stock
      (veterinaria_id, producto_id, tipo, cantidad, precio_unitario, motivo)
    values
      (v_vet, item.producto_id, 'Venta', item.cantidad, v_producto.precio,
       'Venta desde el portal del cliente');

    v_total := v_total + (v_producto.precio * item.cantidad);
  end loop;

  update public.pedidos set total = v_total where id = v_pedido;

  return v_pedido;
end;
$function$;

grant execute on function public.registrar_compra(jsonb) to authenticated;

create index if not exists pedidos_cliente_idx
  on public.pedidos (cliente_id, creado_en);
create index if not exists pedidos_veterinaria_idx
  on public.pedidos (veterinaria_id, creado_en);
create index if not exists pedido_detalles_pedido_idx
  on public.pedido_detalles (pedido_id);

grant select, insert, update, delete on public.pedidos, public.pedido_detalles to authenticated;

-- Habilita la actualización en tiempo real de los estados de los pedidos.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pedidos'
  ) then
    alter publication supabase_realtime add table public.pedidos;
  end if;
end
$$;

drop policy if exists "Pedidos: el equipo actualiza el estado" on public.pedidos;
create policy "Pedidos: el equipo actualiza el estado" on public.pedidos
for update to authenticated
using (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
)
with check (
  veterinaria_id = public.obtener_mi_veterinaria_id()
  and public.obtener_mi_rol() in ('admin_veterinaria', 'veterinario')
);

-- Los turnos solo se reservan dentro del horario de atención de la veterinaria.
create or replace function public.validar_horario_atencion()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_horarios jsonb;
  v_clave text;
  v_texto text;
  v_ini time;
  v_fin time;
begin
  if new.estado = 'Cancelado' then
    return new;
  end if;

  select horarios into v_horarios
    from public.veterinarias
   where id = new.veterinaria_id;

  if v_horarios is null then
    return new;
  end if;

  v_clave := case extract(dow from new.fecha)::int
    when 0 then 'domingos'
    when 6 then 'sabados'
    else 'lunes_viernes'
  end;

  v_texto := coalesce(v_horarios->>v_clave, '');
  if v_texto is null or lower(btrim(v_texto)) = '' then
    return new;
  end if;

  if lower(btrim(v_texto)) = 'cerrado' then
    raise exception 'La veterinaria está cerrada ese día. Elegí otra fecha.';
  end if;

  if btrim(v_texto) !~ '^\d{2}:\d{2}\s*-\s*\d{2}:\d{2}$' then
    return new;
  end if;

  v_ini := btrim(split_part(v_texto, '-', 1))::time;
  v_fin := btrim(split_part(v_texto, '-', 2))::time;

  if new.hora_inicio < v_ini or new.hora_fin > v_fin then
    raise exception 'Ese turno está fuera del horario de atención (%)', v_texto;
  end if;

  return new;
end;
$function$;

drop trigger if exists validar_horario_atencion on public.turnos;
create trigger validar_horario_atencion
before insert or update of fecha, hora_inicio, hora_fin, veterinaria_id
on public.turnos
for each row execute function public.validar_horario_atencion();