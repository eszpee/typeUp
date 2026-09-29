-- typeUp #9: profilok, osztálykód, szerepek, levélkeret. Minden jogosultság auth.uid()-hez kötött.
-- Futtatás: Management API, POST /v1/projects/{ref}/database/query. Az IDE-A-KEZDO-OSZTALYKOD
-- helyére futtatáskor a valódi kód kerül; a valódi kód nem kerül a repóba.

create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 30),
  name_key   text not null unique,            -- a join_class számolja: normalizált, kisbetűs név
  role       text not null default 'student' check (role in ('student', 'teacher')),
  gold       integer not null default 0 check (gold >= 0),   -- a #8 használja
  items      jsonb   not null default '{}'::jsonb,           -- a #8 használja
  created_at timestamptz not null default now()
);

-- Egyetlen sor; RLS policy nélkül, így csak a security definer függvények érik el.
create table public.settings (
  id                boolean primary key default true check (id),
  class_code_hash   text not null,
  email_hour_limit  integer not null default 60,   -- a levélkeret (send-email függvény); SQL-lel módosítható
  email_month_limit integer not null default 500
);
insert into public.settings (class_code_hash)
values (extensions.crypt('IDE-A-KEZDO-OSZTALYKOD', extensions.gen_salt('bf')));

-- A kódpróbálgatás fékezése: felhasználónként legfeljebb 10 hibás próba.
create table public.join_attempts (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  failures integer not null default 0
);

-- Levélkeret: minden elküldött Auth-levél egy sor (cím és kód nélkül). Policy nincs, csak a függvények érik el.
create table public.email_log (
  id      bigint generated always as identity primary key,
  sent_at timestamptz not null default now(),
  action  text
);

alter table public.profiles      enable row level security;
alter table public.settings      enable row level security;
alter table public.join_attempts enable row level security;
alter table public.email_log     enable row level security;

-- A Supabase alapértelmezett jogai (pg_default_acl) minden új táblára mindent megadnak az anon és
-- authenticated szerepnek. Az RLS enélkül is véd, de a jogokat itt kifejezetten szűkítjük.
revoke all on public.profiles, public.settings, public.join_attempts, public.email_log
  from anon, authenticated;

create function public.is_teacher() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'teacher');
$$;

-- Olvasás: a saját profil, a tanárnak mindenkié. Közvetlen insert/update nincs, csak függvényen át.
create policy "sajat vagy tanar" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_teacher());
create policy "tanar torol" on public.profiles for delete to authenticated
  using (public.is_teacher() and id <> auth.uid());
grant select, delete on public.profiles to authenticated;

-- Csatlakozás osztálykóddal. A nevet és a name_key-t a szerver normalizálja, így a kliens nem
-- kerülheti meg az egyediséget. Hibakódok (a kliens ezek alapján ír üzenetet):
--   TU001 nincs bejelentkezve, TU002 már van profil, TU003 túl sok hibás próba,
--   TU005 érvénytelen név, 23505 foglalt név. Rossz kódnál null a válasz.
create function public.join_class(p_code text, p_name text)
returns public.profiles
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_uid  uuid := auth.uid();
  v_name text := regexp_replace(btrim(normalize(coalesce(p_name, ''), NFC)), '\s+', ' ', 'g');
  v_row  profiles;
begin
  if v_uid is null then raise exception 'not signed in' using errcode = 'TU001'; end if;
  if exists (select 1 from profiles where id = v_uid) then
    raise exception 'already joined' using errcode = 'TU002';
  end if;
  if coalesce((select failures from join_attempts where user_id = v_uid), 0) >= 10 then
    raise exception 'too many attempts' using errcode = 'TU003';
  end if;
  if not exists (select 1 from settings where class_code_hash = crypt(coalesce(p_code, ''), class_code_hash)) then
    insert into join_attempts (user_id, failures) values (v_uid, 1)
      on conflict (user_id) do update set failures = join_attempts.failures + 1;
    return null;  -- a hibás próba rögzítése megmarad (raise visszagörgetné)
  end if;
  if char_length(v_name) not between 1 and 30 then
    raise exception 'invalid name' using errcode = 'TU005';
  end if;
  insert into profiles (id, name, name_key) values (v_uid, v_name, lower(v_name))
    returning * into v_row;
  delete from join_attempts where user_id = v_uid;
  return v_row;
end;
$$;

-- Osztálykód cseréje (csak tanár, legalább 8 karakter).
create function public.set_class_code(p_code text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not is_teacher() then raise exception 'forbidden' using errcode = '42501'; end if;
  if char_length(coalesce(p_code, '')) < 8 then raise exception 'too short' using errcode = 'TU006'; end if;
  update settings set class_code_hash = crypt(p_code, gen_salt('bf')) where id;
end;
$$;

-- Szerep állítása (csak tanár, saját magán nem).
create function public.set_role(p_user uuid, p_role text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_teacher() or p_user = auth.uid() or p_role not in ('student', 'teacher') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update profiles set role = p_role where id = p_user;
end;
$$;

-- Az Edge Function hívja küldés előtt (service_role). Atomikus: a settings sor zárolása sorba állítja a hívásokat.
create function public.claim_email_slot(p_action text) returns boolean
language plpgsql security definer set search_path = public as $$
declare
  s settings;
  month_start timestamptz := date_trunc('month', now() at time zone 'Europe/Budapest') at time zone 'Europe/Budapest';
begin
  select * into s from settings for update;
  if (select count(*) from email_log where sent_at > now() - interval '1 hour') >= s.email_hour_limit
     or (select count(*) from email_log where sent_at >= month_start) >= s.email_month_limit then
    return false;
  end if;
  insert into email_log (action) values (p_action);
  return true;
end;
$$;

-- A tanári felületnek: a havi levélkeret állása.
create function public.email_usage() returns table (month_used integer, month_limit integer)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_teacher() then raise exception 'forbidden' using errcode = '42501'; end if;
  return query
    select (select count(*)::int from email_log
             where sent_at >= date_trunc('month', now() at time zone 'Europe/Budapest') at time zone 'Europe/Budapest'),
           (select email_month_limit from settings);
end;
$$;

-- A heti ébresztőnek (GitHub Actions), hogy a Free projekt ne szüneteljen. Semmit nem ad ki.
create function public.ping() returns integer language sql stable as $$ select 1 $$;

-- Függvényjogok. A Supabase alapból az anon és authenticated szerepnek is ad futtatási jogot,
-- ezért mindegyiknél kifejezetten beállítjuk.
revoke execute on function public.join_class(text, text), public.set_class_code(text),
  public.set_role(uuid, text), public.is_teacher(), public.email_usage() from public, anon;
grant execute on function public.join_class(text, text), public.set_class_code(text),
  public.set_role(uuid, text), public.is_teacher(), public.email_usage() to authenticated;
revoke execute on function public.claim_email_slot(text) from public, anon, authenticated;
grant execute on function public.claim_email_slot(text) to service_role;
grant execute on function public.ping() to anon;
