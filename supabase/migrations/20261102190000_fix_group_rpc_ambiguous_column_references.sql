-- WHY: PL/pgSQL OUT parameters share the function namespace; qualify table columns
-- to prevent invite_code/group_id from resolving ambiguously during group actions.
create or replace function public.bandplan_create_group(
  p_name text,
  p_display_name text,
  p_roles text[] default '{}'::text[]
)
returns table(group_id uuid, invite_code text)
language plpgsql
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_uid uuid := auth.uid();
  v_gid uuid;
  v_code text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if length(trim(coalesce(p_name,''))) not between 3 and 50 then
    raise exception 'GROUP_NAME_INVALID';
  end if;

  insert into public.bandplan_groups(name, owner_id)
  values (trim(p_name), v_uid) returning id into v_gid;

  insert into public.bandplan_group_members(group_id, user_id)
  values (v_gid, v_uid);

  insert into public.bandplan_accounts(user_id, display_name, roles)
  values (v_uid, trim(coalesce(p_display_name,'')), coalesce(p_roles,'{}'))
  on conflict (user_id) do update set
    display_name = case when nullif(trim(coalesce(p_display_name,'')), '') is null
      then public.bandplan_accounts.display_name else trim(p_display_name) end,
    roles = case when coalesce(array_length(p_roles,1),0) = 0
      then public.bandplan_accounts.roles else p_roles end,
    updated_at = now();

  loop
    v_code := upper(substr(encode(extensions.gen_random_bytes(8),'hex'),1,10));
    exit when not exists (
      select 1 from public.bandplan_group_invites i where i.invite_code = v_code
    );
  end loop;

  insert into public.bandplan_group_invites(group_id, invite_code, created_by)
  values (v_gid, v_code, v_uid);

  insert into public.bandplan_group_state(group_id, state)
  values (v_gid, '{"members":[],"events":[],"songs":[],"setlists":[]}'::jsonb);

  perform public.bandplan_set_active_group(v_gid);
  return query select v_gid, v_code;
end;
$function$;

create or replace function public.bandplan_leave_group(p_group_id uuid default null)
returns table(group_id uuid, group_name text)
language plpgsql
security definer
set search_path to 'public', 'auth'
as $function$
declare
  v_uid uuid := auth.uid();
  v_group_id uuid := p_group_id;
  v_group_name text;
  v_personal jsonb;
  v_next_owner uuid;
  v_next_group uuid;
  v_next_name text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  if v_group_id is null then
    select gm.group_id into v_group_id
    from public.bandplan_group_members gm
    where gm.user_id = v_uid
    order by case when gm.group_id = (
      select nullif(us.state->>'activeGroupId','')::uuid
      from public.bandplan_user_state us where us.user_id = v_uid
    ) then 0 else 1 end, gm.joined_at
    limit 1;
  end if;

  if v_group_id is null then return; end if;

  if not exists (
    select 1 from public.bandplan_group_members gm
    where gm.user_id = v_uid and gm.group_id = v_group_id
  ) then raise exception 'GROUP_MEMBERSHIP_REQUIRED'; end if;

  select g.name into v_group_name
  from public.bandplan_groups g where g.id = v_group_id;

  if exists (
    select 1 from public.bandplan_groups g
    where g.id = v_group_id and g.owner_id = v_uid
  ) then
    select gm.user_id into v_next_owner
    from public.bandplan_group_members gm
    where gm.group_id = v_group_id and gm.user_id <> v_uid
    order by gm.joined_at asc nulls last, gm.user_id
    limit 1;

    if v_next_owner is null then
      -- WHY: a sole owner may leave; delete only the now-unowned workspace.
      delete from public.bandplan_groups g
      where g.id = v_group_id and g.owner_id = v_uid;
    else
      update public.bandplan_groups g set owner_id = v_next_owner
      where g.id = v_group_id and g.owner_id = v_uid;
    end if;
  end if;

  if exists (select 1 from public.bandplan_groups g where g.id = v_group_id) then
    update public.bandplan_group_state gs
    set state = jsonb_set(
      coalesce(gs.state, '{}'::jsonb),
      '{members}',
      coalesce((
        select jsonb_agg(member)
        from jsonb_array_elements(coalesce(gs.state->'members', '[]'::jsonb)) member
        where coalesce(member->>'accountId', member->>'id', '') <> v_uid::text
      ), '[]'::jsonb),
      true
    ),
    updated_at = now()
    where gs.group_id = v_group_id;

    delete from public.bandplan_group_invites gi
    where gi.created_by = v_uid and gi.group_id = v_group_id;

    delete from public.bandplan_group_members gm
    where gm.user_id = v_uid and gm.group_id = v_group_id;
  end if;

  select gm.group_id, g.name into v_next_group, v_next_name
  from public.bandplan_group_members gm
  join public.bandplan_groups g on g.id = gm.group_id
  where gm.user_id = v_uid
  order by gm.joined_at asc nulls last
  limit 1;

  select us.state into v_personal
  from public.bandplan_user_state us where us.user_id = v_uid;
  v_personal := coalesce(v_personal, '{}'::jsonb);

  if v_next_group is not null then
    v_personal := jsonb_set(v_personal, '{activeGroupId}', to_jsonb(v_next_group::text), true);
    v_personal := jsonb_set(v_personal, '{profile}',
      (coalesce(v_personal->'profile', '{}'::jsonb) - 'groupDetached')
        || jsonb_build_object('groupId', v_next_group::text, 'bandName', v_next_name), true);
  else
    v_personal := v_personal - 'activeGroupId';
    v_personal := jsonb_set(v_personal, '{profile}',
      (coalesce(v_personal->'profile', '{}'::jsonb) - 'groupId')
        || jsonb_build_object('groupDetached', true, 'eventParticipation', '{}'::jsonb), true);
    v_personal := jsonb_set(v_personal, '{songs}', '[]'::jsonb, true);
    v_personal := jsonb_set(v_personal, '{events}', '[]'::jsonb, true);
    v_personal := jsonb_set(v_personal, '{setlists}', '[]'::jsonb, true);
    v_personal := jsonb_set(v_personal, '{members}', '[]'::jsonb, true);
  end if;

  insert into public.bandplan_user_state(user_id, state)
  values (v_uid, v_personal)
  on conflict (user_id) do update
    set state = excluded.state, updated_at = now();

  return query select v_group_id, v_group_name;
end;
$function$;
