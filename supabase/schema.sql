-- Run once in the Supabase SQL Editor. No passwords or secret keys belong in this file.
create table if not exists public.calenotes_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object' and pg_column_size(data) <= 5242880),
  revision bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.calenotes_accounts enable row level security;
revoke all on public.calenotes_accounts from anon;
grant select, insert, update, delete on public.calenotes_accounts to authenticated;
drop policy if exists "own account data" on public.calenotes_accounts;
create policy "own account data" on public.calenotes_accounts for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create or replace function public.save_calenotes_data(payload jsonb, expected_revision bigint)
returns bigint language plpgsql security invoker set search_path = '' as $$
declare next_revision bigint; who uuid := auth.uid();
begin
  if who is null then raise exception 'Authentication required'; end if;
  if jsonb_typeof(payload) <> 'object' or pg_column_size(payload) > 5242880 then raise exception 'Invalid or oversized document'; end if;
  update public.calenotes_accounts set data = payload, revision = revision + 1, updated_at = now()
    where user_id = who and revision = expected_revision returning revision into next_revision;
  if next_revision is null and expected_revision = 0 then
    insert into public.calenotes_accounts(user_id, data, revision) values (who, payload, 1)
      on conflict (user_id) do nothing returning revision into next_revision;
  end if;
  if next_revision is null then raise exception 'Sync conflict: cloud revision changed'; end if;
  return next_revision;
end $$;
revoke all on function public.save_calenotes_data(jsonb,bigint) from public;
grant execute on function public.save_calenotes_data(jsonb,bigint) to authenticated;

-- A server-side unique claim prevents the same day's anchor on two logged-in devices.
create table if not exists public.calenotes_anchor_days (
  user_id uuid references auth.users(id) on delete cascade,
  day date not null,
  primary key(user_id,day)
);
alter table public.calenotes_anchor_days enable row level security;
revoke all on public.calenotes_anchor_days from anon, authenticated;
grant select, insert on public.calenotes_anchor_days to authenticated;
drop policy if exists "own anchor day" on public.calenotes_anchor_days;
create policy "own anchor day" on public.calenotes_anchor_days for all to authenticated
  using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create or replace function public.claim_calenotes_anchor_day(p_day date)
returns boolean language plpgsql security invoker set search_path = '' as $$
declare affected integer;
begin
  if auth.uid() is null then return false; end if;
  insert into public.calenotes_anchor_days(user_id,day) values (auth.uid(),p_day) on conflict do nothing;
  get diagnostics affected = row_count;
  return affected = 1;
end $$;
revoke all on function public.claim_calenotes_anchor_day(date) from public;
grant execute on function public.claim_calenotes_anchor_day(date) to authenticated;

-- Optional AI endpoint: 20 authenticated requests per user and UTC day.
create table if not exists public.calenotes_ai_usage (
  user_id uuid references auth.users(id) on delete cascade,
  day date not null, requests integer not null default 0,
  primary key(user_id,day)
);
alter table public.calenotes_ai_usage enable row level security;
revoke all on public.calenotes_ai_usage from anon, authenticated;
create or replace function public.consume_calenotes_ai_quota()
returns boolean language plpgsql security definer set search_path = '' as $$
declare who uuid := auth.uid(); used integer;
begin
  if who is null then return false; end if;
  insert into public.calenotes_ai_usage(user_id,day,requests) values (who,(now() at time zone 'UTC')::date,1)
  on conflict(user_id,day) do update set requests=public.calenotes_ai_usage.requests+1
    where public.calenotes_ai_usage.requests < 20
  returning requests into used;
  return used is not null;
end $$;
revoke all on function public.consume_calenotes_ai_quota() from public;
grant execute on function public.consume_calenotes_ai_quota() to authenticated;
