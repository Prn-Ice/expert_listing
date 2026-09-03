create extension if not exists pg_trgm;

create type public.post_type as enum (
  'general',
  'request',
  'property'
);

create type public.request_type as enum (
  'looking_to_buy',
  'looking_to_rent'
);

create type public.property_status as enum (
  'for_sale',
  'for_rent'
);

create table public.users (
  id uuid primary key,
  handle text not null unique,
  display_name text not null,
  role text not null,
  avatar_path text,
  created_at timestamptz not null default now()
);

create table public.property_requests (
  id bigint generated always as identity primary key,
  request_type public.request_type not null,
  location text not null check (location = btrim(location) and char_length(location) between 1 and 120),
  created_at timestamptz not null default now()
);

create table public.properties (
  id bigint generated always as identity primary key,
  property_status public.property_status not null,
  location text not null check (location = btrim(location) and char_length(location) between 1 and 120),
  created_at timestamptz not null default now()
);

create table public.posts (
  id bigint generated always as identity primary key,
  author_id uuid not null references public.users(id),
  body text not null check (body = btrim(body) and char_length(body) between 1 and 2000),
  post_type public.post_type not null,
  location text check (location = btrim(location) and char_length(location) between 1 and 120),
  property_request_id bigint unique references public.property_requests(id),
  property_id bigint unique references public.properties(id),
  view_count integer not null default 0 check (view_count >= 0),
  bookmark_count integer not null default 0 check (bookmark_count >= 0),
  created_at timestamptz not null default now(),
  constraint posts_variant_check check (
    (post_type = 'general' and location is not null and property_request_id is null and property_id is null)
    or (post_type = 'request' and location is null and property_request_id is not null and property_id is null)
    or (post_type = 'property' and location is null and property_request_id is null and property_id is not null)
  )
);

create table public.property_images (
  id bigint generated always as identity primary key,
  property_id bigint not null references public.properties(id) on delete cascade,
  storage_path text not null unique,
  position integer not null check (position between 0 and 3),
  created_at timestamptz not null default now(),
  unique (property_id, position)
);

create table public.comments (
  id bigint generated always as identity primary key,
  post_id bigint not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.users(id),
  body text not null check (body = btrim(body) and char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create table public.likes (
  post_id bigint not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index posts_pagination_idx on public.posts (created_at desc, id desc);
create index posts_post_type_pagination_idx on public.posts (post_type, created_at desc, id desc);
create index posts_location_trgm_idx on public.posts using gin (location gin_trgm_ops);
create index posts_author_id_idx on public.posts (author_id);
create index property_requests_request_type_idx on public.property_requests (request_type);
create index property_requests_location_trgm_idx on public.property_requests using gin (location gin_trgm_ops);
create index properties_property_status_idx on public.properties (property_status);
create index properties_location_trgm_idx on public.properties using gin (location gin_trgm_ops);
create index property_images_property_position_idx on public.property_images (property_id, position);
create index comments_post_created_id_idx on public.comments (post_id, created_at, id);
create index comments_author_id_idx on public.comments (author_id);
create index likes_user_id_idx on public.likes (user_id);

create function public.prevent_post_created_at_change()
returns trigger
language plpgsql
as $$
begin
  if new.created_at is distinct from old.created_at then
    raise exception 'posts.created_at is immutable';
  end if;

  return new;
end;
$$;

create trigger posts_created_at_immutable
before update on public.posts
for each row
execute function public.prevent_post_created_at_change();

alter table public.users enable row level security;
alter table public.property_requests enable row level security;
alter table public.properties enable row level security;
alter table public.posts enable row level security;
alter table public.property_images enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;

create function public.create_post(
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
