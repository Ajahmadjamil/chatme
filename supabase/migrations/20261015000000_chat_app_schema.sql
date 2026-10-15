-- =====================================================================
-- ChatMe backend — same database as chat_app, rebuilt for this project
-- (project ref: iwkeqytdmkaqcecyqlzc).
--
-- Safe to run on an empty project AND on top of chatme's older tables:
--   * tables / columns / indexes are only created when missing
--   * every old RLS policy on the app tables is replaced
--   * existing rows are kept
-- Run it once in the SQL editor, or apply it through the Supabase MCP.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Tables
-- ---------------------------------------------------------------------

-- One row per user (filled automatically on Google sign-in, see section 3)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade
);
alter table public.profiles add column if not exists name text not null default '';
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists last_seen timestamptz;
alter table public.profiles add column if not exists profile_complete boolean not null default false;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

-- Usernames are unique, but many people can have none
create unique index if not exists profiles_username_key
  on public.profiles (username)
  where username is not null and username <> '';

-- A 1-on-1 chat or a group
create table if not exists public.chats (
  id uuid primary key default gen_random_uuid()
);
alter table public.chats add column if not exists is_group boolean not null default false;
alter table public.chats add column if not exists name text;
alter table public.chats add column if not exists avatar_url text;
alter table public.chats add column if not exists wallpaper_url text;
alter table public.chats add column if not exists auto_clear_minutes integer;
alter table public.chats add column if not exists created_by uuid default auth.uid();
alter table public.chats add column if not exists created_at timestamptz not null default now();
-- Whoever inserts the chat is its creator (1-on-1 chats don't send it)
alter table public.chats alter column created_by set default auth.uid();

-- Who is in which chat, plus per-user settings for that chat
create table if not exists public.chat_members (
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  primary key (chat_id, user_id)
);
alter table public.chat_members add column if not exists is_admin boolean not null default false;
alter table public.chat_members add column if not exists joined_at timestamptz not null default now();
alter table public.chat_members add column if not exists cleared_at timestamptz;   -- "delete chat" for me
alter table public.chat_members add column if not exists left_at timestamptz;      -- left the group
alter table public.chat_members add column if not exists lock_pin_hash text;       -- chat lock
alter table public.chat_members add column if not exists lock_type text;           -- 'pin' | 'password'
create index if not exists chat_members_user_idx on public.chat_members (user_id);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade
);
alter table public.messages add column if not exists content text not null default '';
-- text | image | voice | file | location | sticker | system | deleted
alter table public.messages add column if not exists message_type text not null default 'text';
alter table public.messages add column if not exists media_url text;
alter table public.messages add column if not exists duration_seconds integer;
alter table public.messages add column if not exists status text not null default 'sent';
alter table public.messages add column if not exists reply_to_id uuid references public.messages (id) on delete set null;
alter table public.messages add column if not exists deleted_for uuid[] not null default '{}';
alter table public.messages add column if not exists expires_at timestamptz;          -- auto-delete
alter table public.messages add column if not exists created_at timestamptz not null default now();
create index if not exists messages_chat_created_idx on public.messages (chat_id, created_at);
create index if not exists messages_expires_idx on public.messages (expires_at) where expires_at is not null;

-- FCM tokens, one row per user + device
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null
);
alter table public.device_tokens add column if not exists platform text;
alter table public.device_tokens add column if not exists created_at timestamptz not null default now();
alter table public.device_tokens add column if not exists updated_at timestamptz not null default now();
-- The app upserts with onConflict: 'user_id,token'
create unique index if not exists device_tokens_user_token_key on public.device_tokens (user_id, token);


-- ---------------------------------------------------------------------
-- 2) Fixes for tables that already existed in chatme
-- ---------------------------------------------------------------------

do $$
declare
  r record;
begin
  -- The app embeds profiles!inner(...) and chats!inner(...) from chat_members,
  -- so these foreign keys must exist (old tables may point at auth.users).
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.chat_members'::regclass and contype = 'f'
      and confrelid = 'public.profiles'::regclass
  ) then
    alter table public.chat_members
      add constraint chat_members_user_id_profiles_fkey
      foreign key (user_id) references public.profiles (id) on delete cascade not valid;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.chat_members'::regclass and contype = 'f'
      and confrelid = 'public.chats'::regclass
  ) then
    alter table public.chat_members
      add constraint chat_members_chat_id_chats_fkey
      foreign key (chat_id) references public.chats (id) on delete cascade not valid;
  end if;

  -- Old CHECK constraints on message_type / status would block the new
  -- message kinds (sticker, location, system, deleted, ...)
  for r in
    select conname from pg_constraint
    where conrelid = 'public.messages'::regclass and contype = 'c'
      and (pg_get_constraintdef(oid) ilike '%message_type%'
           or pg_get_constraintdef(oid) ilike '%status%')
  loop
    execute format('alter table public.messages drop constraint %I', r.conname);
  end loop;

  -- chatme used profiles.about; chat_app calls it bio
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'about'
  ) then
    execute 'update public.profiles set bio = about where bio is null and about is not null';
  end if;

  -- Old versions of the RPCs with other argument types would make the
  -- app's rpc() calls ambiguous — section 6 recreates the right ones
  for r in
    select p.oid::regprocedure as sig from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('mark_chat_read', 'delete_message_for_me')
  loop
    execute format('drop function %s', r.sig);
  end loop;

  -- An older "create profile on sign-up" trigger under another name would
  -- run next to the one in section 3 and could fail sign-ups
  for r in
    select t.tgname from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    join pg_namespace n on n.oid = p.pronamespace
    where t.tgrelid = 'auth.users'::regclass and not t.tgisinternal
      and n.nspname = 'public' and t.tgname <> 'on_auth_user_created'
  loop
    raise notice 'Dropping old auth.users trigger %', r.tgname;
    execute format('drop trigger %I on auth.users', r.tgname);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 3) Profiles: auto-create on sign-up, keep usernames tidy
-- ---------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name, email, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1),
      ''
    ),
    new.email,
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Users who signed in before this migration and have no profile yet
insert into public.profiles (id, name, email, avatar_url)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', split_part(u.email, '@', 1), ''),
  u.email,
  coalesce(u.raw_user_meta_data ->> 'avatar_url', u.raw_user_meta_data ->> 'picture')
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- '' becomes NULL so the unique index ignores "no username"
create or replace function public.profiles_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.username := nullif(lower(btrim(new.username)), '');
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_before_write on public.profiles;
create trigger profiles_before_write
  before insert or update on public.profiles
  for each row execute function public.profiles_before_write();


-- ---------------------------------------------------------------------
-- 4) Helper functions used by the RLS policies
--    (security definer = no recursion through chat_members' own policies)
-- ---------------------------------------------------------------------

create or replace function public.is_chat_member(p_chat_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.chat_members m
    where m.chat_id = p_chat_id and m.user_id = (select auth.uid())
  );
$$;

-- Still in the chat (has not left the group)
create or replace function public.is_active_chat_member(p_chat_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.chat_members m
    where m.chat_id = p_chat_id and m.user_id = (select auth.uid())
      and m.left_at is null
  );
$$;

create or replace function public.is_chat_admin(p_chat_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.chat_members m
    where m.chat_id = p_chat_id and m.user_id = (select auth.uid())
      and m.left_at is null and m.is_admin
  );
$$;

create or replace function public.is_chat_creator(p_chat_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.chats c
    where c.id = p_chat_id and c.created_by = (select auth.uid())
  );
$$;

-- Storage paths start with the chat id as text
create or replace function public.can_access_chat_folder(p_folder text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.chat_members m
    where m.chat_id::text = p_folder and m.user_id = (select auth.uid())
  );
$$;


-- ---------------------------------------------------------------------
-- 5) Guards for UPDATEs that RLS alone can't express per column
--    (functions running as their owner, like the RPCs below, skip these)
-- ---------------------------------------------------------------------

create or replace function public.chat_members_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  if new.chat_id <> old.chat_id or new.user_id <> old.user_id then
    raise exception 'chat_id and user_id cannot be changed';
  end if;

  -- Only an admin can make / unmake admins
  if new.is_admin is distinct from old.is_admin and not public.is_chat_admin(old.chat_id) then
    raise exception 'Only group admins can change admin rights';
  end if;

  -- Cleared / left / lock settings belong to the member themself
  if old.user_id <> auth.uid()
     and (new.cleared_at, new.left_at, new.lock_pin_hash, new.lock_type)
         is distinct from (old.cleared_at, old.left_at, old.lock_pin_hash, old.lock_type) then
    raise exception 'You can only change your own chat settings';
  end if;

  return new;
end;
$$;

drop trigger if exists chat_members_guard on public.chat_members;
create trigger chat_members_guard
  before update on public.chat_members
  for each row execute function public.chat_members_guard();

create or replace function public.messages_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  if new.chat_id <> old.chat_id or new.sender_id <> old.sender_id then
    raise exception 'chat_id and sender_id cannot be changed';
  end if;

  -- Someone else's message: I may only mark it as read
  if old.sender_id <> auth.uid()
     and (to_jsonb(new) - 'status') is distinct from (to_jsonb(old) - 'status') then
    raise exception 'You can only change the status of other people''s messages';
  end if;

  return new;
end;
$$;

drop trigger if exists messages_guard on public.messages;
create trigger messages_guard
  before update on public.messages
  for each row execute function public.messages_guard();

-- If the same phone token shows up for a new user (account switch on one
-- device), the old owner must stop getting that device's pushes
create or replace function public.device_tokens_claim()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.device_tokens
  where token = new.token and user_id <> new.user_id;
  return new;
end;
$$;

drop trigger if exists device_tokens_claim on public.device_tokens;
create trigger device_tokens_claim
  before insert or update of token, user_id on public.device_tokens
  for each row execute function public.device_tokens_claim();


-- ---------------------------------------------------------------------
-- 6) RPCs called by the app
-- ---------------------------------------------------------------------

-- Notification "Mark as read" action
create function public.mark_chat_read(p_chat_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_chat_member(p_chat_id) then
    raise exception 'Not a member of this chat';
  end if;

  update public.messages
  set status = 'read'
  where chat_id = p_chat_id
    and sender_id <> auth.uid()
    and status <> 'read';
end;
$$;

-- "Delete for me": hides one message only for the caller
create function public.delete_message_for_me(target_message_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.messages m
  set deleted_for = array_append(m.deleted_for, auth.uid())
  where m.id = target_message_id
    and public.is_chat_member(m.chat_id)
    and not (auth.uid() = any (m.deleted_for));
end;
$$;

-- Only signed-in users may call the app's functions
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.is_chat_member(uuid)',
    'public.is_active_chat_member(uuid)',
    'public.is_chat_admin(uuid)',
    'public.is_chat_creator(uuid)',
    'public.can_access_chat_folder(text)',
    'public.mark_chat_read(uuid)',
    'public.delete_message_for_me(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end $$;

-- Trigger functions are never called through the API (triggers still fire:
-- Postgres only checks EXECUTE when a trigger is created)
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.device_tokens_claim() from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 7) Row Level Security
-- ---------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;
alter table public.device_tokens enable row level security;

-- Start clean: remove every old policy on these tables
do $$
declare
  r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('profiles', 'chats', 'chat_members', 'messages', 'device_tokens')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- profiles: everyone signed in can find people to chat with
create policy "profiles_select" on public.profiles
  for select to authenticated using (true);
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (id = (select auth.uid()));
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- chats
create policy "chats_select_member" on public.chats
  for select to authenticated
  using (public.is_chat_member(id) or created_by = (select auth.uid()));
create policy "chats_insert" on public.chats
  for insert to authenticated with check (created_by = (select auth.uid()));
-- name / photo / wallpaper / auto-delete can be changed by members still in the chat
create policy "chats_update_member" on public.chats
  for update to authenticated
  using (public.is_active_chat_member(id)) with check (public.is_active_chat_member(id));

-- chat_members
create policy "chat_members_select" on public.chat_members
  for select to authenticated using (public.is_chat_member(chat_id));
-- creator adds the first members, admins add more later
create policy "chat_members_insert" on public.chat_members
  for insert to authenticated
  with check (public.is_chat_creator(chat_id) or public.is_chat_admin(chat_id));
-- my own row (clear, leave, lock) or any row if I'm admin (promote / demote)
create policy "chat_members_update" on public.chat_members
  for update to authenticated
  using (user_id = (select auth.uid()) or public.is_chat_admin(chat_id))
  with check (user_id = (select auth.uid()) or public.is_chat_admin(chat_id));
create policy "chat_members_delete" on public.chat_members
  for delete to authenticated
  using (user_id = (select auth.uid()) or public.is_chat_admin(chat_id));

-- messages
create policy "messages_select_member" on public.messages
  for select to authenticated using (public.is_chat_member(chat_id));
create policy "messages_insert_member" on public.messages
  for insert to authenticated
  with check (sender_id = (select auth.uid()) and public.is_active_chat_member(chat_id));
-- sender edits / deletes for everyone; others only mark as read (see messages_guard)
create policy "messages_update_member" on public.messages
  for update to authenticated
  using (public.is_chat_member(chat_id)) with check (public.is_chat_member(chat_id));
-- sender deletes own messages; any member may remove auto-deleted (expired) ones
create policy "messages_delete" on public.messages
  for delete to authenticated
  using (
    sender_id = (select auth.uid())
    or (expires_at is not null and expires_at < now() and public.is_chat_member(chat_id))
  );

-- device_tokens: only my own
create policy "device_tokens_own" on public.device_tokens
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));


-- ---------------------------------------------------------------------
-- 8) Realtime (messages list, wallpaper, online status)
-- ---------------------------------------------------------------------

do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;

  foreach t in array array['messages', 'chats', 'profiles'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

alter table public.messages replica identity full;


-- ---------------------------------------------------------------------
-- 9) Storage buckets (public URLs are stored on the rows)
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', true),
  ('wallpapers', 'wallpapers', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "chatme_read_app_buckets" on storage.objects;
create policy "chatme_read_app_buckets" on storage.objects
  for select to authenticated
  using (bucket_id in ('avatars', 'chat-media', 'wallpapers'));

-- avatars/<my user id>/<file>
drop policy if exists "chatme_upload_own_avatar" on storage.objects;
create policy "chatme_upload_own_avatar" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- chat-media/<chat id>/<file>  or  chat-media/group-avatars/<chat id>/<file>
drop policy if exists "chatme_upload_chat_media" on storage.objects;
create policy "chatme_upload_chat_media" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and (
      public.can_access_chat_folder((storage.foldername(name))[1])
      or (
        (storage.foldername(name))[1] = 'group-avatars'
        and public.can_access_chat_folder((storage.foldername(name))[2])
      )
    )
  );

-- wallpapers/<chat id>/<file>
drop policy if exists "chatme_upload_wallpapers" on storage.objects;
create policy "chatme_upload_wallpapers" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'wallpapers'
    and public.can_access_chat_folder((storage.foldername(name))[1])
  );
