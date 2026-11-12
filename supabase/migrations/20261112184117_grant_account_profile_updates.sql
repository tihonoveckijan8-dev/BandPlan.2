-- WHY: authenticated users need to persist their own shared profile fields.
-- Existing account-own INSERT/UPDATE RLS policies still restrict writes to auth.uid() = user_id.
-- Column-level grants deliberately exclude personal_settings and identity reassignment on UPDATE.
grant insert (user_id, display_name, roles, updated_at)
  on table public.bandplan_accounts to authenticated;

grant update (display_name, roles, updated_at)
  on table public.bandplan_accounts to authenticated;
