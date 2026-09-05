-- Add the bounded engagement previews rendered beneath each feed post.

create index if not exists likes_post_created_user_idx
on public.likes (post_id, created_at desc, user_id);

drop function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text);

create function public.feed_page(
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
  liked_by_viewer boolean,
  like_previews jsonb,
  latest_comment jsonb
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
    ) as liked_by_viewer,
    coalesce(like_preview.items, '[]'::jsonb) as like_previews,
    comment_preview.item as latest_comment
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
  left join lateral (
    select jsonb_agg(
      jsonb_build_object(
        'id', liker.id,
        'handle', liker.handle,
        'displayName', liker.display_name,
        'role', liker.role,
        'avatarPath', liker.avatar_path
      )
      order by liker.liked_at desc, liker.id
    ) as items
    from (
      select liked_user.*, l.created_at as liked_at
      from public.likes l
      join public.users liked_user on liked_user.id = l.user_id
      where l.post_id = p.id
      order by l.created_at desc, l.user_id
      limit 3
    ) liker
  ) like_preview on true
  left join lateral (
    select jsonb_build_object(
      'id', c.id,
      'body', c.body,
      'author', jsonb_build_object(
        'id', comment_author.id,
        'handle', comment_author.handle,
        'displayName', comment_author.display_name,
        'role', comment_author.role,
        'avatarPath', comment_author.avatar_path
      )
    ) as item
    from public.comments c
    join public.users comment_author on comment_author.id = c.author_id
    where c.post_id = p.id
    order by c.created_at desc, c.id desc
    limit 1
  ) comment_preview on true
  order by p.created_at desc, p.id desc;
$$;

revoke all on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) from public;
revoke all on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) from anon;
revoke all on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) from authenticated;
grant execute on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) to service_role;
