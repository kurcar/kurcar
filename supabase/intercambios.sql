-- KURCAR: mercadillo de cromos (intercambio de repetidas) y apodos.
-- Se puede ejecutar varias veces sin error.

-- ========== APODOS ==========
create table if not exists public.perfiles (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  apodo text not null check (char_length(apodo) between 2 and 20),
  actualizado timestamptz not null default now()
);
create unique index if not exists perfiles_apodo_unico on public.perfiles (lower(apodo));

alter table public.perfiles enable row level security;
grant select, insert, update on public.perfiles to authenticated;

drop policy if exists "ver apodos" on public.perfiles;
create policy "ver apodos" on public.perfiles for select to authenticated using (true);
drop policy if exists "crear mi apodo" on public.perfiles;
create policy "crear mi apodo" on public.perfiles for insert to authenticated
  with check ((select auth.uid()) = user_id);
drop policy if exists "cambiar mi apodo" on public.perfiles;
create policy "cambiar mi apodo" on public.perfiles for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- ========== OFERTAS ==========
create table if not exists public.ofertas (
  id uuid primary key default gen_random_uuid(),
  autor uuid not null references auth.users(id) on delete cascade,
  da jsonb not null,                       -- la carta que se ofrece
  quiere text not null default '',         -- "Marca Modelo" que se busca; vacío = cualquier repetido
  estado text not null default 'abierta' check (estado in ('abierta', 'cerrada')),
  comprador uuid references auth.users(id) on delete set null,
  recibe jsonb,                            -- la carta que dio quien aceptó
  visto boolean not null default false,    -- el autor ya vio el aviso de "han aceptado tu oferta"
  creada timestamptz not null default now(),
  cerrada timestamptz
);
create index if not exists ofertas_abiertas on public.ofertas (estado, creada desc);

alter table public.ofertas enable row level security;
revoke all on public.ofertas from anon, authenticated;
grant select on public.ofertas to authenticated;
grant update (visto) on public.ofertas to authenticated;   -- lo único que un jugador puede cambiar a mano

drop policy if exists "ver ofertas" on public.ofertas;
create policy "ver ofertas" on public.ofertas for select to authenticated
  using (estado = 'abierta' or autor = (select auth.uid()) or comprador = (select auth.uid()));
drop policy if exists "marcar visto" on public.ofertas;
create policy "marcar visto" on public.ofertas for update to authenticated
  using (autor = (select auth.uid())) with check (autor = (select auth.uid()));
-- No hay reglas para crear ni borrar ofertas: solo se puede con las operaciones de abajo.

-- ========== OPERACIONES (las hace Supabase de una sola vez) ==========

-- Interna: mete una carta nueva en la colección de alguien. Nadie puede llamarla directamente.
create or replace function public.kurcar_nueva_carta(dueno uuid, carta jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare n int; nid text; c jsonb;
begin
  select count(*) into n from public.cartas where user_id = dueno and (datos->>'premio') = 'true';
  nid := 'x' || replace(gen_random_uuid()::text, '-', '');
  c := (carta - 'id' - 'h' - 'code' - 't') || jsonb_build_object(
         'id', nid, 't', (extract(epoch from clock_timestamp()) * 1000)::bigint,
         'premio', true, 'code', 'P' || (n + 1), 'cambio', true);
  insert into public.cartas (user_id, id, datos) values (dueno, nid, c);
  return c;
end $$;

-- Publicar: saca la carta de tu colección y la pone en el mostrador.
create or replace function public.kurcar_publicar(carta_id text, quiere text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare yo uuid := auth.uid(); c jsonb; nueva uuid;
begin
  if yo is null then raise exception 'sin_cuenta'; end if;
  if not exists (select 1 from public.perfiles where user_id = yo) then raise exception 'sin_apodo'; end if;
  if (select count(*) from public.ofertas where autor = yo and estado = 'abierta') >= 5 then raise exception 'maximo'; end if;
  delete from public.cartas where user_id = yo and id = carta_id returning datos into c;
  if c is null then raise exception 'no_es_tuya'; end if;
  if c ? 'h' or coalesce(c->>'premio', '') <> 'true' then raise exception 'no_cambiable'; end if;
  insert into public.ofertas (autor, da, quiere)
    values (yo, c - 'id' - 't' - 'code' - 'h', coalesce(quiere, ''))
    returning id into nueva;
  return nueva;
end $$;

-- Aceptar: das una repetida tuya y te llevas la de la oferta. El autor recibe la tuya al momento.
create or replace function public.kurcar_aceptar(oferta_id uuid, carta_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare yo uuid := auth.uid(); o public.ofertas; c jsonb; recibida jsonb;
begin
  if yo is null then raise exception 'sin_cuenta'; end if;
  if not exists (select 1 from public.perfiles where user_id = yo) then raise exception 'sin_apodo'; end if;
  select * into o from public.ofertas where id = oferta_id for update;
  if not found or o.estado <> 'abierta' then raise exception 'ocupada'; end if;
  if o.autor = yo then raise exception 'es_tuya'; end if;
  delete from public.cartas where user_id = yo and id = carta_id returning datos into c;
  if c is null then raise exception 'no_es_tuya'; end if;
  if c ? 'h' or coalesce(c->>'premio', '') <> 'true' then raise exception 'no_cambiable'; end if;
  if o.quiere <> '' and trim(coalesce(c->>'marca', '') || ' ' || coalesce(c->>'modelo', '')) <> o.quiere then
    raise exception 'no_es_la_buscada';
  end if;
  c := c - 'id' - 't' - 'code' - 'h';
  recibida := public.kurcar_nueva_carta(yo, o.da);
  perform public.kurcar_nueva_carta(o.autor, c);
  update public.ofertas set estado = 'cerrada', comprador = yo, recibe = c, cerrada = now() where id = oferta_id;
  return recibida;
end $$;

-- Retirar: si nadie la ha aceptado, la carta vuelve a tu colección.
create or replace function public.kurcar_retirar(oferta_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare yo uuid := auth.uid(); o public.ofertas;
begin
  if yo is null then raise exception 'sin_cuenta'; end if;
  select * into o from public.ofertas where id = oferta_id and autor = yo for update;
  if not found or o.estado <> 'abierta' then raise exception 'ocupada'; end if;
  delete from public.ofertas where id = oferta_id;
  return public.kurcar_nueva_carta(yo, o.da);
end $$;

-- Quién puede usar cada operación
revoke execute on function public.kurcar_nueva_carta(uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.kurcar_publicar(text, text) from public, anon;
revoke execute on function public.kurcar_aceptar(uuid, text) from public, anon;
revoke execute on function public.kurcar_retirar(uuid) from public, anon;
grant execute on function public.kurcar_publicar(text, text) to authenticated;
grant execute on function public.kurcar_aceptar(uuid, text) to authenticated;
grant execute on function public.kurcar_retirar(uuid) to authenticated;
