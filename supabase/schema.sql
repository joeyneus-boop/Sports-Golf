-- Sports Golf leaderboard: paste this whole file into Supabase > SQL Editor > New query, then Run.

create table if not exists public.scores (
  id          bigint generated always as identity primary key,
  day         date        not null,
  mix         text        not null check (mix ~ '^[A-Z]{3}(-[A-Z]{3}){0,5}$'),
  player_id   text        not null check (char_length(player_id) between 8 and 64),
  name        text        not null check (char_length(btrim(name)) between 1 and 20),
  total       smallint    not null check (total between -27 and 27),
  spots       smallint    not null check (spots between 0 and 900),
  strikes     smallint    not null check (strikes between 0 and 27),
  holes       smallint[]  not null check (array_length(holes, 1) = 9),
  hidden      boolean     not null default false,   -- set true in the dashboard to remove a bad name
  created_at  timestamptz not null default now(),
  unique (day, mix, player_id)                      -- one posted round per device per course
);

-- Golf score must equal the sum of the nine holes, and each hole is -3..+3.
create or replace function public.scores_valid() returns trigger language plpgsql as $$
begin
  if (select sum(h) from unnest(new.holes) h) <> new.total
     or exists (select 1 from unnest(new.holes) h where h < -3 or h > 3) then
    raise exception 'invalid holes';
  end if;
  -- only today's (or yesterday's, for late finishers) course, in US Eastern time
  if new.day not between ((now() at time zone 'America/New_York')::date - 1)
                     and ((now() at time zone 'America/New_York')::date) then
    raise exception 'wrong day';
  end if;
  new.name := btrim(new.name);
  new.hidden := false;
  new.created_at := now();
  return new;
end $$;
drop trigger if exists scores_valid on public.scores;
create trigger scores_valid before insert on public.scores for each row execute function public.scores_valid();

create index if not exists scores_board on public.scores (day, mix, total, spots, strikes, created_at) where not hidden;

-- Anyone can read the board and post a score. Nobody can edit or delete through the API.
alter table public.scores enable row level security;
drop policy if exists "read board" on public.scores;
create policy "read board" on public.scores for select to anon using (not hidden);
drop policy if exists "post score" on public.scores;
create policy "post score" on public.scores for insert to anon with check (true);
revoke update, delete on public.scores from anon, authenticated;
