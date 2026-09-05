create table public.notification_events (
  id bigint generated always as identity primary key,
  event_type text not null,
  recipient_id uuid not null references public.users(id) on delete cascade,
  actor_id uuid not null references public.users(id) on delete cascade,
  post_id bigint not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint notification_events_event_type_check check (event_type = 'post_like'),
  constraint notification_events_actor_recipient_check check (actor_id <> recipient_id),
  constraint notification_events_read_at_check check (read_at is null or read_at >= created_at)
);

create index notification_events_recipient_created_id_idx
on public.notification_events (recipient_id, created_at desc, id desc);
create index notification_events_actor_id_idx
on public.notification_events (actor_id);
create index notification_events_post_id_idx
on public.notification_events (post_id);

alter table public.notification_events enable row level security;

revoke all on table public.notification_events from public, anon, authenticated, service_role;
revoke all on sequence public.notification_events_id_seq from public, anon, authenticated, service_role;

insert into public.notification_events (
  event_type,
  recipient_id,
  actor_id,
  post_id,
  created_at
)
select
  'post_like',
  post.author_id,
  post_like.user_id,
  post_like.post_id,
  post_like.created_at
from public.likes post_like
join public.posts post on post.id = post_like.post_id
where post_like.user_id <> post.author_id
order by post_like.created_at, post_like.post_id, post_like.user_id;

select setval(
  pg_get_serial_sequence('public.notification_events', 'id'),
  coalesce((select max(id) from public.notification_events), 1),
  exists (select 1 from public.notification_events)
);

create or replace function public.set_post_like(
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
declare
  v_like_inserted integer;
  v_post_author_id uuid;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_actor_id::text || ':' || p_post_id::text, 0)
  );

  select post.author_id
  into v_post_author_id
  from public.posts post
  where post.id = p_post_id;

  if not found then
    raise no_data_found using message = 'Post not found.';
  end if;

  if p_liked then
    insert into public.likes (post_id, user_id)
    values (p_post_id, p_actor_id)
    on conflict on constraint likes_pkey do nothing;

    get diagnostics v_like_inserted = row_count;
    if v_like_inserted = 1 and p_actor_id <> v_post_author_id then
      insert into public.notification_events (
        event_type,
        recipient_id,
        actor_id,
        post_id
      )
      values ('post_like', v_post_author_id, p_actor_id, p_post_id);
    end if;
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

create function public.list_notifications(
  p_recipient_id uuid,
  p_limit integer default 20
)
returns table (
  id bigint,
  event_type text,
  created_at timestamptz,
  read_at timestamptz,
  actor_handle text,
  actor_display_name text,
  actor_role text,
  actor_avatar_path text,
  post_id bigint,
  post_body text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_limit is null or p_limit not between 1 and 20 then
    raise exception 'Notification limit must be between 1 and 20.';
  end if;

  return query
  select
    notification.id,
    notification.event_type,
    notification.created_at,
    notification.read_at,
    actor.handle,
    actor.display_name,
    actor.role,
    actor.avatar_path,
    post.id,
    post.body
  from public.notification_events notification
  join public.users actor on actor.id = notification.actor_id
  join public.posts post on post.id = notification.post_id
  where notification.recipient_id = p_recipient_id
  order by notification.created_at desc, notification.id desc
  limit p_limit;
end;
$$;

create function public.mark_notification_read(
  p_recipient_id uuid,
  p_notification_id bigint
)
returns table (
  id bigint,
  read_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  update public.notification_events notification
  set read_at = coalesce(notification.read_at, statement_timestamp())
  where notification.id = p_notification_id
    and notification.recipient_id = p_recipient_id
  returning notification.id, notification.read_at;

  if not found then
    raise no_data_found using message = 'Notification not found.';
  end if;
end;
$$;

revoke all on function public.set_post_like(uuid, bigint, boolean) from public, anon, authenticated;
revoke all on function public.list_notifications(uuid, integer) from public, anon, authenticated;
revoke all on function public.mark_notification_read(uuid, bigint) from public, anon, authenticated;
grant execute on function public.set_post_like(uuid, bigint, boolean) to service_role;
grant execute on function public.list_notifications(uuid, integer) to service_role;
grant execute on function public.mark_notification_read(uuid, bigint) to service_role;
