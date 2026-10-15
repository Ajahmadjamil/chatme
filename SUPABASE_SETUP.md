# Supabase setup for ChatMe

ChatMe now runs chat_app's code on **its own** backend:

| | chatme (use this) | chat_app (do NOT touch) |
|---|---|---|
| Supabase project ref | `iwkeqytdmkaqcecyqlzc` | `gjbzwlbuirszhbhlxdlw` |
| Firebase project | `chat-me-9dca6` | `chat-app-be7d0` |

Part A is for you (things only a person can do). Part B is for Cursor's agent.

---

## Part A — You

1. **Sign Cursor in to Supabase.** `.cursor/mcp.json` is already set up for `iwkeqytdmkaqcecyqlzc`.
   Open Cursor → **Settings → Tools & MCP** → find **supabase** → click **Connect / Login** →
   approve in the browser. It should show a green dot and a list of tools.

2. **Add the Firebase key for push notifications** (needed by both edge functions).
   - Firebase console → project **chat-me-9dca6** → ⚙ Project settings → **Service accounts** →
     **Generate new private key** → a `.json` file downloads.
   - Supabase dashboard → project `iwkeqytdmkaqcecyqlzc` → **Edge Functions → Secrets** →
     add secret **`FIREBASE_SERVICE_ACCOUNT`** = the whole contents of that `.json` file.
   - Don't paste this key into a chat or commit it to git.

3. **Check Google sign-in is still on** (it worked before, so this is just a check).
   Supabase → **Authentication → Sign In / Providers → Google**: enabled, and **Client IDs**
   contains the same `GOOGLE_WEB_CLIENT_ID` as in `.env`.

4. **Check Realtime allows public channels** (calls ring through broadcast channels `calls:<userId>`).
   Supabase → **Project Settings → Realtime** → "Allow public access" must be **on**
   (i.e. *not* "private channels only").

5. **Add the two extra keys to `.env`** (optional — features just stay off if empty):
   ```
   GEMINI_API_KEY=...   # AI chatbot
   GIPHY_API_KEY=...    # sticker picker
   ```

6. Then give Cursor this prompt:

   > Read `SUPABASE_SETUP.md` and do Part B using the Supabase MCP.

---

## Part B — Cursor agent (Supabase MCP)

Work **only** on project `iwkeqytdmkaqcecyqlzc`. Never drop tables or delete user data.
Report back what you found and what you changed after each step.

### B1. Confirm the project
- Use the Supabase MCP to confirm you are connected to `iwkeqytdmkaqcecyqlzc`
  (e.g. `get_project_url` should be `https://iwkeqytdmkaqcecyqlzc.supabase.co`). Stop if not.

### B2. Look at what already exists (read-only)
- `list_tables` (schema `public`) and `list_migrations`.
- With `execute_sql`, list columns that are **NOT NULL without a default** on
  `profiles`, `chats`, `chat_members`, `messages`, `device_tokens`:
  ```sql
  select table_name, column_name, data_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name in ('profiles','chats','chat_members','messages','device_tokens')
    and is_nullable = 'NO' and column_default is null
  order by 1, 2;
  ```
  The app only sends these columns, so any **other** column in that list will make inserts fail:
  - `profiles`: id (filled by trigger)
  - `chats`: id, is_group, name, created_by
  - `chat_members`: chat_id, user_id, is_admin
  - `messages`: chat_id, sender_id, content, message_type, media_url, duration_seconds, status, expires_at, reply_to_id
  - `device_tokens`: user_id, token, platform, updated_at

  For any extra NOT NULL column without a default, include in B3 an
  `alter table ... alter column ... drop not null;` (don't drop the column).
- Check column **types** the app relies on: `chats.id`, `messages.id`, `chat_members.chat_id`
  must be `uuid`; `messages.deleted_for` (if it already exists) must be `uuid[]`.
  If something differs, stop and report instead of guessing.

### B3. Apply the schema
- `apply_migration` with name `chat_app_schema` and the exact contents of
  `supabase/migrations/20261015000000_chat_app_schema.sql`
  (plus any `drop not null` fixes from B2 appended at the end).
- The file is idempotent: it creates missing tables/columns/indexes, replaces all RLS policies
  on the 5 app tables, creates the `mark_chat_read` and `delete_message_for_me` RPCs, enables
  Realtime on `messages`/`chats`/`profiles`, and creates the public buckets
  `avatars`, `chat-media`, `wallpapers` with upload policies.
- If it errors, fix only the failing statement, re-apply, and explain the fix.

### B4. Verify
Run with `execute_sql` and report the results:
```sql
-- tables + RLS
select tablename, rowsecurity from pg_tables
where schemaname = 'public'
  and tablename in ('profiles','chats','chat_members','messages','device_tokens');

-- policies per table
select tablename, count(*) from pg_policies where schemaname = 'public' group by 1 order by 1;

-- RPCs
select proname, pg_get_function_identity_arguments(oid) from pg_proc
where proname in ('mark_chat_read','delete_message_for_me');

-- realtime
select tablename from pg_publication_tables where pubname = 'supabase_realtime';

-- buckets
select id, public from storage.buckets where id in ('avatars','chat-media','wallpapers');

-- every auth user has a profile
select count(*) as users_without_profile from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);
```
Then run `get_advisors` (type `security`, then `performance`) and report anything marked
ERROR. Fix only issues that touch the objects created by this migration.

### B5. Deploy the edge functions
Deploy both with `deploy_edge_function`, each with its `index.ts` and `deno.json`,
and **JWT verification off** (`verify_jwt: false`, same as `supabase/config.toml`):
- `push-new-message` → `supabase/functions/push-new-message/`
- `push-call` → `supabase/functions/push-call/` (checks the caller's JWT itself)

If the tool can't turn JWT verification off, tell me so I can switch it off in
Supabase → Edge Functions → *function* → Settings.
Confirm with `list_edge_functions`. They need the `FIREBASE_SERVICE_ACCOUNT` secret from Part A.

### B6. Final report
List: what existed before, what the migration changed, verification results,
deployed functions, and anything I still have to do by hand.

---

## Part C — Test on two phones (you)

Sign in with two different Google accounts and check:
- [ ] First login shows **Finish your profile**, then the chat list
- [ ] New 1-on-1 chat, text + photo + voice + file + location + sticker
- [ ] Message arrives in real time; ticks turn **read**
- [ ] Push notification when the app is in the background; **Reply** / **Mark as read** from it
- [ ] Create a group, add/remove members, make admin, leave group
- [ ] Edit, reply, forward, delete for me, delete for everyone
- [ ] Auto-delete timer, wallpaper, chat lock (PIN), home-screen shortcut
- [ ] Audio and video call, including a call while the other app is closed
- [ ] Online / last seen status

If something fails, Supabase → **Logs** (Postgres / Edge Functions) shows the error — paste it
to Cursor or Claude.
