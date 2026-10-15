-- =====================================================================
-- !!! DANGER: FULL RESET OF CHATME'S APP DATABASE — CANNOT BE UNDONE !!!
--
-- Run ONLY on Supabase project iwkeqytdmkaqcecyqlzc (chatme), then apply
-- supabase/migrations/20261015000000_chat_app_schema.sql to rebuild.
--
-- Deletes:
--   * every table, view, function, type and sequence in schema public
--     (ALL app data: profiles, chats, chat members, messages, device tokens,
--      plus everything left from chatme's older migrations)
--   * triggers / webhooks / policies that depend on those (via CASCADE),
--     including the old profile trigger on auth.users
--   * storage policies for the avatars / chat-media / wallpapers buckets
--   * pg_cron jobs that call into the app database
--   * the migration history (supabase_migrations.schema_migrations)
--
-- Keeps:
--   * auth users (Google accounts) — they get a fresh profile and see
--     "Finish your profile" again on next sign-in
--   * storage buckets and their files (empty them in the dashboard if wanted)
--   * extensions, edge functions, secrets, project settings
--
-- Kept out of supabase/migrations on purpose so it never runs by accident.
-- =====================================================================

do $$
declare
  r record;
begin
  -- 1) Cron jobs that would keep calling dropped functions
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    for r in execute 'select jobid, jobname, command from cron.job' loop
      if r.command ilike '%public.%'
         or r.command ilike '%cleanup_expired%'
         or r.command ilike '%messages%' then
        raise notice 'Unscheduling cron job % (%): %', r.jobid, r.jobname, r.command;
        perform cron.unschedule(r.jobid);
      end if;
    end loop;
  end if;

  -- 2) Storage policies for the app buckets (the migration recreates its own)
  for r in
    select policyname from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (coalesce(qual, '') || ' ' || coalesce(with_check, '')) ~* '(avatars|chat-media|wallpapers)'
  loop
    raise notice 'Dropping storage policy %', r.policyname;
    execute format('drop policy %I on storage.objects', r.policyname);
  end loop;

  -- 3) Everything in schema public that doesn't belong to an extension
  for r in
    select c.relname, c.relkind
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('v', 'm')
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e'
      )
  loop
    raise notice 'Dropping view %', r.relname;
    execute format('drop %s if exists public.%I cascade',
                   case r.relkind when 'm' then 'materialized view' else 'view' end, r.relname);
  end loop;

  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e'
      )
  loop
    raise notice 'Dropping table %', r.relname;
    execute format('drop table if exists public.%I cascade', r.relname);
  end loop;

  for r in
    select p.oid::regprocedure as sig, p.prokind
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e'
      )
  loop
    raise notice 'Dropping function %', r.sig;
    execute format('drop %s if exists %s cascade',
                   case r.prokind when 'p' then 'procedure' when 'a' then 'aggregate' else 'function' end,
                   r.sig);
  end loop;

  for r in
    select t.typname, t.typtype
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    left join pg_class c on c.oid = t.typrelid
    where n.nspname = 'public'
      and (t.typtype in ('e', 'd') or (t.typtype = 'c' and c.relkind = 'c'))
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_type'::regclass and d.objid = t.oid and d.deptype = 'e'
      )
  loop
    raise notice 'Dropping type %', r.typname;
    execute format('drop %s if exists public.%I cascade',
                   case r.typtype when 'd' then 'domain' else 'type' end, r.typname);
  end loop;

  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'S'
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e'
      )
  loop
    raise notice 'Dropping sequence %', r.relname;
    execute format('drop sequence if exists public.%I cascade', r.relname);
  end loop;

  -- 4) Migration history, so it matches supabase/migrations again
  if to_regclass('supabase_migrations.schema_migrations') is not null then
    delete from supabase_migrations.schema_migrations;
    raise notice 'Cleared migration history';
  end if;
end $$;

-- Optional: also remove every sign-in account (users just sign in with
-- Google again and get a new id). Uncomment only if you really want that.
-- delete from auth.users;
