create function public.user_profile(p_user_id uuid)
returns table (
  handle text,
  display_name text,
  role text,
  avatar_path text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    profile_user.handle,
    profile_user.display_name,
    profile_user.role,
    profile_user.avatar_path
  from public.users profile_user
  where profile_user.id = p_user_id;
$$;

revoke all on function public.user_profile(uuid) from public;
revoke all on function public.user_profile(uuid) from anon;
revoke all on function public.user_profile(uuid) from authenticated;
grant execute on function public.user_profile(uuid) to service_role;
