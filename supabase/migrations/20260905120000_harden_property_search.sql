-- Keep broad autocomplete useful while rejecting inputs that bypass Hono validation.

create or replace function public.property_search_suggestions(
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
      btrim(coalesce(p_query, '')) as raw_query,
      replace(replace(replace(btrim(coalesce(p_query, '')), '\', '\\'), '%', '\%'), '_', '\_') as literal_query,
      greatest(0, least(coalesce(p_limit, 6), 10)) as result_limit
  ),
  location_matches as (
    select
      prop.location,
      count(*) as property_count,
      max(post.created_at) as newest_match
    from public.properties prop
    join public.posts post on post.property_id = prop.id
    cross join input
    where char_length(input.raw_query) between 3 and 120
      and prop.location ilike '%' || input.literal_query || '%' escape '\'
    group by prop.location
  ),
  ranked_locations as (
    select
      location_match.*,
      row_number() over (
        order by location_match.newest_match desc, location_match.location
      ) as location_rank
    from location_matches location_match
  ),
  location_property_matches as (
    select
      post.id as post_id,
      case
        when prop.location ilike input.literal_query || '%' escape '\' then 1
        else 2
      end as match_rank
    from public.posts post
    join public.properties prop on prop.id = post.property_id
    cross join input
    where post.post_type = 'property'
      and char_length(input.raw_query) between 3 and 120
      and prop.location ilike '%' || input.literal_query || '%' escape '\'
  ),
  body_property_matches as (
    select post.id as post_id, 3 as match_rank
    from public.posts post
    cross join input
    where post.post_type = 'property'
      and char_length(input.raw_query) between 3 and 120
      and post.body ilike '%' || input.literal_query || '%' escape '\'
  ),
  matched_properties as (
    select match.post_id, min(match.match_rank) as match_rank
    from (
      select * from location_property_matches
      union all
      select * from body_property_matches
    ) match
    group by match.post_id
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
      matched_property.match_rank
    from matched_properties matched_property
    join public.posts post on post.id = matched_property.post_id
    join public.properties prop on prop.id = post.property_id
    left join lateral (
      select property_image.storage_path
      from public.property_images property_image
      where property_image.property_id = prop.id
      order by property_image.position
      limit 1
    ) image on true
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
      case when location_match.location_rank = 1 then 0 else 4 end as match_rank,
      location_match.newest_match as matched_at
    from ranked_locations location_match

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
  order by
    suggestion.match_rank,
    suggestion.matched_at desc,
    suggestion.post_id desc nulls last,
    suggestion.label
  limit (select input.result_limit from input);
$$;
