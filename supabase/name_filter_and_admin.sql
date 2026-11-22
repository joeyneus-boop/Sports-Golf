-- Sports Golf: server-side name filter + admin tools
create extension if not exists unaccent with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
revoke all on schema private from anon, authenticated;

create table if not exists private.settings (k text primary key, v text not null);
insert into private.settings values ('admin_key_sha256', '<sha256 hex of your admin key>')
  on conflict (k) do update set v = excluded.v;

-- hashed fingerprints of the LDNOOBW English list (no plain words stored)
create table if not exists private.blocked_names (h text primary key, long boolean not null);
insert into private.blocked_names (h, long) values ('50b77de2b93608ce',true),('062f45cc2dd0504a',true),('efd7dd97933b67cf',true),('cdbad58609e1cbd3',true),('8d118a98ab0aa3b5',true),('e2b33334ac09a6e0',false),('c8c2c830b09b36c0',false),('20996dbd5dfd7add',true),('216a112b5e8486a4',false),('c58034e4f0688653',true),('bdbdfd3ba7605ce6',false),('250188c62c0aafed',true),('0c40bf4bedd5a053',true),('0bf73e03fb09ebad',true),('e3013515c421afb5',true),('17cdd54aa27b9c9d',true),('91340d5d3d2579dc',true),('e95be16d71816acd',true),('c5f44a5358a16be8',true),('d1c58a7246180c53',true),('447adaf59211bd5f',true),('714edb40ee1b3eea',false),('c528e70f70510f52',false),('b4d45565a3e5534c',true),('84e06666f71e934a',false),('9f263ce6e8923250',true),('93360c4f76e5c594',true),('839113406f358ae0',false),('243d3308248e9f3b',true),('cd920061e7cfae4e',true),('dcf965c921498b4c',true),('31baa5d33e601c7f',true),('582e3e617e22124a',true),('2f28d3cdf8a27c51',false),('735d68db20470e48',true),('8dab56800bc7f22e',false),('8505d025c1f9aa8f',false),('120fb9b1ea6806fb',true),('9dd7eaad77a9c1c9',true),('88410ec0624b06c3',true),('d9d6ab2f8654e4f5',true),('e751adb36b810c01',false),('98d80eb6393b57af',true),('afd31dcafcbb1010',true),('44cf990ce5316e6f',true),('4487f2b80cc59917',true),('75f5bfc16aa0fbc7',true),('2757bea3568cf322',true),('e0fb873ff444d778',true),('d3fae7d8a8827c11',true),('1a221a7641be2bb3',false),('89b825c984919473',false),('503d67c3ae003970',false),('d61a6c8957a46258',false),('a5e8a28d98eb8a6b',true),('60aceb3ab4c5b23d',true),('279b561b1124237f',false),('53fa8419f4021670',true),('f37aa4d74b84e714',false),('de999ebd16b5c69f',false),('75d09b27a9d32d9d',true),('ccb8bff1f4cb24e3',true),('20b0785931c75ba9',true),('c27e443929172089',true),('517b7d7af2543d4f',true),('78856fd8168dd67c',true),('de05259e88cc7083',true) on conflict do nothing;

create or replace function private.fp(x text) returns text language sql immutable as $$
  select left(encode(extensions.digest('sportsgolf:' || x, 'sha256'), 'hex'), 16) $$;

create or replace function private.name_blocked(name text) returns boolean language plpgsql stable as $$
declare n text; sq text; co text; f text; i int; j int;
begin
  n  := translate(lower(extensions.unaccent(coalesce(name,''))), '0134578@$!|', 'oieastbasii');
  sq := regexp_replace(n, '[^a-z]', '', 'g');
  co := regexp_replace(sq, '(.)\1+', '\1', 'g');
  for f in select unnest(array[sq, co]) union select t from regexp_split_to_table(n, '[^a-z]+') t
           union select regexp_replace(t, '(.)\1+', '\1', 'g') from regexp_split_to_table(n, '[^a-z]+') t loop
    if f <> '' and exists (select 1 from private.blocked_names where h = private.fp(f)) then return true; end if;
  end loop;
  foreach f in array array[sq, co] loop
    for i in 1 .. greatest(char_length(f) - 4, 0) loop
      for j in 5 .. char_length(f) - i + 1 loop
        if exists (select 1 from private.blocked_names where long and h = private.fp(substr(f, i, j))) then return true; end if;
      end loop;
    end loop;
  end loop;
  return false;
end $$;

create or replace function public.scores_valid() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select sum(h) from unnest(new.holes) h) <> new.total
     or exists (select 1 from unnest(new.holes) h where h < -3 or h > 5) then
    raise exception 'invalid holes';
  end if;
  if new.day not between ((now() at time zone 'America/New_York')::date - 1)
                     and ((now() at time zone 'America/New_York')::date) then
    raise exception 'wrong day';
  end if;
  new.name := btrim(new.name);
  if private.name_blocked(new.name) then raise exception 'name not allowed'; end if;
  new.hidden := false;
  new.created_at := now();
  return new;
end $$;

-- admin tools (require the admin key)
create or replace function private.check_admin(p_key text) returns void language plpgsql security definer as $$
begin
  if encode(extensions.digest(coalesce(p_key,''), 'sha256'), 'hex') is distinct from (select v from private.settings where k = 'admin_key_sha256') then
    perform pg_sleep(1); raise exception 'bad admin key';
  end if;
end $$;

create or replace function public.admin_list(p_key text, p_day date)
returns table (id bigint, day date, mix text, name text, total smallint, spots smallint, strikes smallint, hidden boolean, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  perform private.check_admin(p_key);
  return query select s.id, s.day, s.mix, s.name, s.total, s.spots, s.strikes, s.hidden, s.created_at
    from public.scores s where s.day = p_day order by s.mix, s.total, s.spots, s.strikes, s.created_at;
end $$;

create or replace function public.admin_set_hidden(p_key text, p_id bigint, p_hidden boolean) returns void
language plpgsql security definer set search_path = public as $$
begin perform private.check_admin(p_key); update public.scores set hidden = p_hidden where id = p_id; end $$;

create or replace function public.admin_delete(p_key text, p_id bigint) returns void
language plpgsql security definer set search_path = public as $$
begin perform private.check_admin(p_key); delete from public.scores where id = p_id; end $$;

revoke all on function public.admin_list(text, date), public.admin_set_hidden(text, bigint, boolean), public.admin_delete(text, bigint) from public;
grant execute on function public.admin_list(text, date), public.admin_set_hidden(text, bigint, boolean), public.admin_delete(text, bigint) to anon;
