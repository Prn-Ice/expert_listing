-- Bounded property and location autocomplete behind one vetted read function.

create index posts_property_body_trgm_idx
on public.posts using gin (body gin_trgm_ops)
where post_type = 'property';

create function public.property_search_suggestions(
  p_query text,
  p_limit integer
)
returns table (
  suggestion_type text,
  label text,
  post_id bigint,
  property_id bigint,
  property_status public.property_status,
  location text,
  body text,
  image_storage_path text,
  matching_property_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with input as (
    select
      replace(replace(replace(btrim(p_query), '\', '\\'), '%', '\%'), '_', '\_') as literal_query
  ),
  location_matches as (
    select
      prop.location,
      count(*) as property_count,
      max(post.created_at) as newest_match
    from public.properties prop
    join public.posts post on post.property_id = prop.id
    cross join input
    where prop.location ilike '%' || input.literal_query || '%' escape '\'
    group by prop.location
  ),
  property_matches as (
    select
      post.id as post_id,
      prop.id as property_id,
      prop.property_status,
      prop.location,
      post.body,
      image.storage_path as image_storage_path,
      post.created_at,
      case
        when prop.location ilike input.literal_query || '%' escape '\' then 1
        when prop.location ilike '%' || input.literal_query || '%' escape '\' then 2
        else 3
      end as match_rank
    from public.posts post
    join public.properties prop on prop.id = post.property_id
    cross join input
    left join lateral (
      select property_image.storage_path
      from public.property_images property_image
      where property_image.property_id = prop.id
      order by property_image.position
      limit 1
    ) image on true
    where post.post_type = 'property'
      and (
        prop.location ilike '%' || input.literal_query || '%' escape '\'
        or post.body ilike '%' || input.literal_query || '%' escape '\'
      )
  ),
  suggestions as (
    select
      'location'::text as suggestion_type,
      location_match.location as label,
      null::bigint as post_id,
      null::bigint as property_id,
      null::public.property_status as property_status,
      location_match.location,
      null::text as body,
      null::text as image_storage_path,
      location_match.property_count as matching_property_count,
      0 as match_rank,
      location_match.newest_match as matched_at
    from location_matches location_match

    union all

    select
      'property'::text,
      property_match.location,
      property_match.post_id,
      property_match.property_id,
      property_match.property_status,
      property_match.location,
      property_match.body,
      property_match.image_storage_path,
      null::bigint,
      property_match.match_rank,
      property_match.created_at
    from property_matches property_match
  )
  select
    suggestion.suggestion_type,
    suggestion.label,
    suggestion.post_id,
    suggestion.property_id,
    suggestion.property_status,
    suggestion.location,
    suggestion.body,
    suggestion.image_storage_path,
    suggestion.matching_property_count
  from suggestions suggestion
  order by suggestion.match_rank, suggestion.matched_at desc, suggestion.post_id desc nulls last
  limit greatest(0, least(p_limit, 10));
$$;

revoke all on function public.property_search_suggestions(text, integer) from public;
revoke all on function public.property_search_suggestions(text, integer) from anon;
revoke all on function public.property_search_suggestions(text, integer) from authenticated;
grant execute on function public.property_search_suggestions(text, integer) to service_role;
