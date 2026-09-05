create function public.set_post_like(
  p_actor_id uuid,
  p_post_id bigint,
  p_liked boolean
)
returns table (
  post_id bigint,
  liked boolean,
  like_count bigint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_actor_id::text || ':' || p_post_id::text, 0)
  );

  if not exists (select 1 from public.posts where id = p_post_id) then
    raise no_data_found using message = 'Post not found.';
  end if;

  if p_liked then
    insert into public.likes (post_id, user_id)
    values (p_post_id, p_actor_id)
    on conflict on constraint likes_pkey do nothing;
  else
    delete from public.likes
    where likes.post_id = p_post_id and likes.user_id = p_actor_id;
  end if;

  return query
  select
    p_post_id,
    p_liked,
    (select count(*) from public.likes where likes.post_id = p_post_id);
end;
$$;

create function public.list_post_comments(p_post_id bigint)
returns table (
  id bigint,
  post_id bigint,
  body text,
  created_at timestamptz,
  author_id uuid,
  author_handle text,
  author_display_name text,
  author_role text,
  author_avatar_path text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.posts where posts.id = p_post_id) then
    raise no_data_found using message = 'Post not found.';
  end if;

  return query
  select
    comment.id,
    comment.post_id,
    comment.body,
    comment.created_at,
    author.id,
    author.handle,
    author.display_name,
    author.role,
    author.avatar_path
  from public.comments comment
  join public.users author on author.id = comment.author_id
  where comment.post_id = p_post_id
  order by comment.created_at, comment.id;
end;
$$;

create function public.create_post_comment(
  p_actor_id uuid,
  p_post_id bigint,
  p_body text
)
returns table (
  id bigint,
  post_id bigint,
  body text,
  created_at timestamptz,
  author_id uuid,
  author_handle text,
  author_display_name text,
  author_role text,
  author_avatar_path text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_comment_id bigint;
begin
  if p_body is null
    or p_body <> btrim(p_body)
    or char_length(p_body) not between 1 and 1000 then
    raise exception 'Comment body must contain 1 through 1000 trimmed characters.';
  end if;
  if not exists (select 1 from public.posts where posts.id = p_post_id) then
    raise no_data_found using message = 'Post not found.';
  end if;

  insert into public.comments (post_id, author_id, body)
  values (p_post_id, p_actor_id, p_body)
  returning comments.id into v_comment_id;

  return query
  select
    comment.id,
    comment.post_id,
    comment.body,
    comment.created_at,
    author.id,
    author.handle,
    author.display_name,
    author.role,
    author.avatar_path
  from public.comments comment
  join public.users author on author.id = comment.author_id
  where comment.id = v_comment_id;
end;
$$;

revoke all on function public.set_post_like(uuid, bigint, boolean) from public, anon, authenticated;
revoke all on function public.list_post_comments(bigint) from public, anon, authenticated;
revoke all on function public.create_post_comment(uuid, bigint, text) from public, anon, authenticated;
grant execute on function public.set_post_like(uuid, bigint, boolean) to service_role;
grant execute on function public.list_post_comments(bigint) to service_role;
grant execute on function public.create_post_comment(uuid, bigint, text) to service_role;
