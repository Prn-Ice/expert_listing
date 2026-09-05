-- Return a newly-created post in the same discriminated shape consumed by the feed API.

create function public.create_hydrated_post(
  p_author_id uuid,
  p_body text,
  p_post_type public.post_type,
  p_location text,
  p_request_type public.request_type default null,
  p_property_status public.property_status default null,
  p_image_paths text[] default array[]::text[]
)
returns table (
  id bigint,
  body text,
  post_type public.post_type,
  created_at timestamptz,
  view_count integer,
  bookmark_count integer,
  general_location text,
  author_id uuid,
  author_handle text,
  author_display_name text,
  author_role text,
  author_avatar_path text,
  request_type public.request_type,
  request_location text,
  property_id bigint,
  property_status public.property_status,
  property_location text,
  property_images jsonb,
  like_count bigint,
  comment_count bigint,
  liked_by_viewer boolean,
  like_previews jsonb,
  latest_comment jsonb
)
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_post_id bigint;
begin
  v_post_id := public.create_post(
    p_author_id,
    p_body,
    p_post_type,
    p_location,
    p_request_type,
    p_property_status,
    p_image_paths
  );

  return query
  select
    p.id,
    p.body,
    p.post_type,
    p.created_at,
    p.view_count,
    p.bookmark_count,
    p.location as general_location,
    u.id as author_id,
    u.handle as author_handle,
    u.display_name as author_display_name,
    u.role as author_role,
    u.avatar_path as author_avatar_path,
    pr.request_type,
    pr.location as request_location,
    prop.id as property_id,
    prop.property_status,
    prop.location as property_location,
    coalesce(images.items, '[]'::jsonb) as property_images,
    0::bigint as like_count,
    0::bigint as comment_count,
    false as liked_by_viewer,
    '[]'::jsonb as like_previews,
    null::jsonb as latest_comment
  from public.posts p
  join public.users u on u.id = p.author_id
  left join public.property_requests pr on pr.id = p.property_request_id
  left join public.properties prop on prop.id = p.property_id
  left join lateral (
    select jsonb_agg(
      jsonb_build_object(
        'id', pi.id,
        'storagePath', pi.storage_path,
        'position', pi.position
      )
      order by pi.position
    ) as items
    from public.property_images pi
    where pi.property_id = prop.id
  ) images on true
  where p.id = v_post_id;
end;
$$;

revoke all on function public.create_hydrated_post(uuid, text, public.post_type, text, public.request_type, public.property_status, text[]) from public;
revoke all on function public.create_hydrated_post(uuid, text, public.post_type, text, public.request_type, public.property_status, text[]) from anon;
revoke all on function public.create_hydrated_post(uuid, text, public.post_type, text, public.request_type, public.property_status, text[]) from authenticated;
grant execute on function public.create_hydrated_post(uuid, text, public.post_type, text, public.request_type, public.property_status, text[]) to service_role;
