-- ATC Calendar Analytics: run this entire script in Supabase SQL Editor.
-- Project: pcgywfcguxhvmzwjftei
-- After running it, create/choose your admin Auth user and add that user's UUID
-- to public.atc_analytics_admins (instructions are in the analytics panel README).

create extension if not exists pgcrypto;

create table if not exists public.atc_analytics_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  platform text not null check (platform in ('pwa','apk')),
  visitor_id text,
  session_id text,
  is_new boolean not null default false,
  app_version text,
  device_type text,
  browser text,
  path text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.atc_analytics_events add column if not exists event_type text;
alter table public.atc_analytics_events add column if not exists platform text;
alter table public.atc_analytics_events add column if not exists visitor_id text;
alter table public.atc_analytics_events add column if not exists session_id text;
alter table public.atc_analytics_events add column if not exists is_new boolean not null default false;
alter table public.atc_analytics_events add column if not exists app_version text;
alter table public.atc_analytics_events add column if not exists device_type text;
alter table public.atc_analytics_events add column if not exists browser text;
alter table public.atc_analytics_events add column if not exists path text;
alter table public.atc_analytics_events add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table public.atc_analytics_events add column if not exists created_at timestamptz not null default now();

create table if not exists public.atc_ad_click_events (
  id uuid primary key default gen_random_uuid(),
  image_url text not null,
  target_url text,
  platform text not null check (platform in ('pwa','apk')),
  visitor_id text,
  session_id text,
  clicked_at timestamptz not null default now()
);

create table if not exists public.atc_analytics_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists atc_analytics_events_created_idx on public.atc_analytics_events(created_at desc);
create index if not exists atc_analytics_events_platform_type_idx on public.atc_analytics_events(platform,event_type);
create index if not exists atc_ad_click_events_image_idx on public.atc_ad_click_events(image_url);
create index if not exists atc_ad_click_events_clicked_idx on public.atc_ad_click_events(clicked_at desc);

alter table public.atc_analytics_events enable row level security;
alter table public.atc_ad_click_events enable row level security;
alter table public.atc_analytics_admins enable row level security;

create or replace function public.is_atc_analytics_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.atc_analytics_admins where user_id=auth.uid()); $$;
revoke all on function public.is_atc_analytics_admin() from public;
grant execute on function public.is_atc_analytics_admin() to anon, authenticated;

drop policy if exists "analytics public insert" on public.atc_analytics_events;
create policy "analytics public insert" on public.atc_analytics_events for insert to anon, authenticated with check (platform in ('pwa','apk'));
drop policy if exists "analytics admin read" on public.atc_analytics_events;
create policy "analytics admin read" on public.atc_analytics_events for select to authenticated using (public.is_atc_analytics_admin());
drop policy if exists "analytics admin delete" on public.atc_analytics_events;
create policy "analytics admin delete" on public.atc_analytics_events for delete to authenticated using (public.is_atc_analytics_admin());

drop policy if exists "ad clicks public insert" on public.atc_ad_click_events;
create policy "ad clicks public insert" on public.atc_ad_click_events for insert to anon, authenticated with check (platform in ('pwa','apk'));
drop policy if exists "ad clicks admin read" on public.atc_ad_click_events;
create policy "ad clicks admin read" on public.atc_ad_click_events for select to authenticated using (public.is_atc_analytics_admin());
drop policy if exists "ad clicks admin delete" on public.atc_ad_click_events;
create policy "ad clicks admin delete" on public.atc_ad_click_events for delete to authenticated using (public.is_atc_analytics_admin());

drop policy if exists "analytics admins read self" on public.atc_analytics_admins;
create policy "analytics admins read self" on public.atc_analytics_admins for select to authenticated using (user_id=auth.uid());

grant insert on public.atc_analytics_events to anon, authenticated;
grant select,delete on public.atc_analytics_events to authenticated;
grant insert on public.atc_ad_click_events to anon, authenticated;
grant select,delete on public.atc_ad_click_events to authenticated;
grant select on public.atc_analytics_admins to authenticated;

create or replace function public.atc_analytics_summary()
returns jsonb language plpgsql stable security invoker set search_path=public
as $$
declare result jsonb;
begin
  if not public.is_atc_analytics_admin() then raise exception 'not authorized'; end if;
  select jsonb_build_object(
    'total_page_views',count(*) filter(where event_type='page_view'),
    'pwa_page_views',count(*) filter(where event_type='page_view' and platform='pwa'),
    'apk_page_views',count(*) filter(where event_type='page_view' and platform='apk'),
    'unique_visitors',count(distinct visitor_id) filter(where event_type='page_view'),
    'pwa_unique_visitors',count(distinct visitor_id) filter(where event_type='page_view' and platform='pwa'),
    'apk_unique_visitors',count(distinct visitor_id) filter(where event_type='page_view' and platform='apk'),
    'sessions',count(*) filter(where event_type='session_start'),
    'last_30_days',coalesce((
      select jsonb_agg(jsonb_build_object('day',d.day,'pwa',d.pwa,'apk',d.apk) order by d.day)
      from (select date(created_at) day,
        count(*) filter(where platform='pwa') pwa,
        count(*) filter(where platform='apk') apk
        from public.atc_analytics_events
        where event_type='page_view' and created_at>=now()-interval '30 days'
        group by date(created_at)) d
    ),'[]'::jsonb)
  ) into result from public.atc_analytics_events;
  return result;
end $$;

create or replace function public.atc_ad_click_summary()
returns table(image_url text,target_url text,click_count bigint,first_clicked_at timestamptz,last_clicked_at timestamptz,pwa_clicks bigint,apk_clicks bigint)
language plpgsql stable security invoker set search_path=public
as $$
begin
  if not public.is_atc_analytics_admin() then raise exception 'not authorized'; end if;
  return query select c.image_url,
    (array_agg(c.target_url order by c.clicked_at desc))[1],
    count(*)::bigint,min(c.clicked_at),max(c.clicked_at),
    count(*) filter(where c.platform='pwa')::bigint,
    count(*) filter(where c.platform='apk')::bigint
  from public.atc_ad_click_events c
  group by c.image_url
  order by max(c.clicked_at) desc;
end $$;
revoke all on function public.atc_analytics_summary() from public;
revoke all on function public.atc_ad_click_summary() from public;
grant execute on function public.atc_analytics_summary() to authenticated;
grant execute on function public.atc_ad_click_summary() to authenticated;
