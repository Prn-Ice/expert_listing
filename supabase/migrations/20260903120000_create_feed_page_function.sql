-- Read path for the feed API and a privilege fix for the creation RPC.
--
-- Both functions are security definer so the database surface reachable by
-- service_role stays limited to these vetted contracts; the feed tables
-- themselves keep no direct grants for API roles. Each function pins
-- search_path so the definer context cannot be hijacked.

create or replace function public.create_post(
  p_author_id uuid,
  p_body text,
  p_post_type public.post_type,
  p_location text,
  p_request_type public.request_type default null,
  p_property_status public.property_status default null,
  p_image_paths text[] default array[]::text[]
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_id bigint;
  v_property_request_id bigint;
  v_property_id bigint;
  v_image_count integer := coalesce(array_length(p_image_paths, 1), 0);
begin
  if v_image_count > 4 then
    raise exception 'A post may contain at most four images.';
  end if;

  if exists (
    select 1
    from unnest(p_image_paths) as image_path
    where image_path is null or btrim(image_path) = ''
  ) then
    raise exception 'Image paths must be non-empty.';
  end if;

  if p_post_type = 'general' then
    if p_location is null or p_location <> btrim(p_location) or char_length(p_location) not between 1 and 120 then
      raise exception 'General posts require a trimmed location.';
    end if;

    if p_request_type is not null or p_property_status is not null or v_image_count <> 0 then
      raise exception 'General posts cannot include request, property, or image data.';
    end if;

    insert into public.posts (author_id, body, post_type, location)
    values (p_author_id, p_body, p_post_type, p_location)
    returning id into v_post_id;
  elsif p_post_type = 'request' then
    if p_location is null or p_location <> btrim(p_location) or char_length(p_location) not between 1 and 120 then
      raise exception 'Request posts require a trimmed desired-area location.';
    end if;

    if p_request_type is null or p_property_status is not null or v_image_count <> 0 then
      raise exception 'Request posts require only request data and no images.';
    end if;

    insert into public.property_requests (request_type, location)
    values (p_request_type, p_location)
    returning id into v_property_request_id;

    insert into public.posts (author_id, body, post_type, property_request_id)
    values (p_author_id, p_body, p_post_type, v_property_request_id)
    returning id into v_post_id;
  elsif p_post_type = 'property' then
    if p_location is null or p_location <> btrim(p_location) or char_length(p_location) not between 1 and 120 then
      raise exception 'Property posts require a trimmed property location.';
    end if;

    if p_request_type is not null or p_property_status is null then
      raise exception 'Property posts require only property data.';
    end if;

    insert into public.properties (property_status, location)
    values (p_property_status, p_location)
    returning id into v_property_id;

    insert into public.posts (author_id, body, post_type, property_id)
    values (p_author_id, p_body, p_post_type, v_property_id)
    returning id into v_post_id;

    for v_position in 1..v_image_count loop
      insert into public.property_images (property_id, storage_path, position)
      values (v_property_id, p_image_paths[v_position], v_position - 1);
    end loop;
  else
    raise exception 'A post type is required.';
  end if;

  return v_post_id;
end;
$$;

revoke all on function public.create_post(uuid, text, public.post_type, text, public.request_type, public.property_status, text[]) from public;
revoke all on function public.create_post(uuid, text, public.post_type, text, public.request_type, public.property_status, text[]) from anon;
revoke all on function public.create_post(uuid, text, public.post_type, text, public.request_type, public.property_status, text[]) from authenticated;
grant execute on function public.create_post(uuid, text, public.post_type, text, public.request_type, public.property_status, text[]) to service_role;

-- One page of the feed in a single round trip: hydrated author, the matching
-- variant payload, engagement counts, and the viewer's like state. Callers
-- pass limit + 1 and derive nextCursor from the surplus row.
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
  liked_by_viewer boolean
)
language sql
stable
security definer
set search_path = public
as $$
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
  from public.posts p
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
  where
    (p_post_type is null or p.post_type = p_post_type)
    and (p_request_type is null or pr.request_type = p_request_type)
    and (p_property_status is null or prop.property_status = p_property_status)
    and (
      p_location is null
      or coalesce(p.location, pr.location, prop.location) ilike
        '%' || replace(replace(replace(p_location, '\', '\\'), '%', '\%'), '_', '\_') || '%'
    )
    and (
      p_cursor_created_at is null
      or (p.created_at, p.id) < (p_cursor_created_at, p_cursor_id)
    )
  order by p.created_at desc, p.id desc
  limit p_limit;
$$;

revoke all on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) from public;
revoke all on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) from anon;
revoke all on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) from authenticated;
grant execute on function public.feed_page(uuid, integer, timestamptz, bigint, public.post_type, public.request_type, public.property_status, text) to service_role;
