-- Make feed location filtering index-compatible and tighten API-role
-- privileges.
--
-- The previous feed_page applied ILIKE to coalesce(...) across three tables, a
-- computed expression no per-column trigram index can serve. Each variant
-- branch below filters its own indexed location column directly, so a
-- selective location engages posts_location_trgm_idx,
-- property_requests_location_trgm_idx, or properties_location_trgm_idx. Each
-- branch also bounds its own work with the pagination index before the union
-- applies the global order and limit.

create or replace function public.feed_page(
  p_viewer_id uuid,
  p_limit integer,
  p_cursor_created_at timestamptz default null,
  p_cursor_id bigint default null,
  p_post_type public.post_type default null,
  p_request_type public.request_type default null,
  p_property_status public.property_status default null,
  p_location text default null
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
  liked_by_viewer boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with page as (
    (
      select general_post.*
      from public.posts general_post
      where general_post.post_type = 'general'
        and (p_post_type is null or p_post_type = 'general')
        and general_post.location ilike coalesce(
          '%' || replace(replace(replace(p_location, '\', '\\'), '%', '\%'), '_', '\_') || '%',
          '%'
        )
        and (
          p_cursor_created_at is null
          or (general_post.created_at, general_post.id) < (p_cursor_created_at, p_cursor_id)
        )
      order by general_post.created_at desc, general_post.id desc
      limit p_limit
    )
    union all
    (
      select request_post.*
      from public.posts request_post
      join public.property_requests pr on pr.id = request_post.property_request_id
      where request_post.post_type = 'request'
        and (p_post_type is null or p_post_type = 'request')
        and (p_request_type is null or pr.request_type = p_request_type)
        and pr.location ilike coalesce(
          '%' || replace(replace(replace(p_location, '\', '\\'), '%', '\%'), '_', '\_') || '%',
          '%'
        )
        and (
          p_cursor_created_at is null
          or (request_post.created_at, request_post.id) < (p_cursor_created_at, p_cursor_id)
        )
      order by request_post.created_at desc, request_post.id desc
      limit p_limit
    )
    union all
    (
      select property_post.*
      from public.posts property_post
      join public.properties prop on prop.id = property_post.property_id
      where property_post.post_type = 'property'
        and (p_post_type is null or p_post_type = 'property')
        and (p_property_status is null or prop.property_status = p_property_status)
        and prop.location ilike coalesce(
          '%' || replace(replace(replace(p_location, '\', '\\'), '%', '\%'), '_', '\_') || '%',
          '%'
        )
        and (
          p_cursor_created_at is null
          or (property_post.created_at, property_post.id) < (p_cursor_created_at, p_cursor_id)
        )
      order by property_post.created_at desc, property_post.id desc
      limit p_limit
    )
    order by created_at desc, id desc
    limit p_limit
  )
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
    (select count(*) from public.likes l where l.post_id = p.id) as like_count,
    (select count(*) from public.comments c where c.post_id = p.id) as comment_count,
    exists (
      select 1 from public.likes viewer_like
      where viewer_like.post_id = p.id and viewer_like.user_id = p_viewer_id
    ) as liked_by_viewer
  from page p
  join public.users u on u.id = p.author_id
  left join public.property_requests pr on pr.id = p.property_request_id
  left join public.properties prop on prop.id = p.property_id
  left join lateral (
    select jsonb_agg(
      jsonb_build_object('id', pi.id, 'storagePath', pi.storage_path, 'position', pi.position)
      order by pi.position
    ) as items
    from public.property_images pi
    where pi.property_id = prop.id
  ) images on true
  order by p.created_at desc, p.id desc;
$$;

revoke all on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) from public;
revoke all on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) from anon;
revoke all on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) from authenticated;
grant execute on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) to service_role;

-- API roles reach data only through the security-definer functions above; the
-- platform default REFERENCES, TRIGGER, and TRUNCATE grants serve no caller
-- here and are revoked so the no-direct-grants contract is literally true.
revoke references, trigger, truncate on table public.users from anon, authenticated, service_role;
revoke references, trigger, truncate on table public.property_requests from anon, authenticated, service_role;
revoke references, trigger, truncate on table public.properties from anon, authenticated, service_role;
revoke references, trigger, truncate on table public.posts from anon, authenticated, service_role;
revoke references, trigger, truncate on table public.property_images from anon, authenticated, service_role;
revoke references, trigger, truncate on table public.comments from anon, authenticated, service_role;
revoke references, trigger, truncate on table public.likes from anon, authenticated, service_role;
