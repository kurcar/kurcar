-- KURCAR: tablas para guardar la colección de cada jugador en Supabase.
-- Ejecutado a mano en el SQL Editor de Supabase el 10-11-2026 (proyecto "kurcar").
-- Si se vuelve a ejecutar entero dará "policy ... already exists": es normal, ya estaba creado.

create table if not exists public.cartas (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null,
  datos jsonb not null,
  actualizado timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.progreso (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  datos jsonb not null,
  actualizado timestamptz not null default now()
);

-- Seguridad: cada jugador solo puede tocar lo suyo
alter table public.cartas enable row level security;
alter table public.progreso enable row level security;

grant select, insert, update, delete on public.cartas, public.progreso to authenticated;

create policy "ver mis cartas" on public.cartas for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "añadir mis cartas" on public.cartas for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "cambiar mis cartas" on public.cartas for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "borrar mis cartas" on public.cartas for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "ver mi progreso" on public.progreso for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "añadir mi progreso" on public.progreso for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "cambiar mi progreso" on public.progreso for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
