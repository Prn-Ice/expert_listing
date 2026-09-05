begin;

select plan(43);

insert into public.posts (id, author_id, body, post_type, location)
overriding system value
values
  (9910, '00000000-0000-0000-0000-000000000001', 'Notification behavior probe', 'general', 'Yaba, Lagos'),
  (9911, '00000000-0000-0000-0000-000000000002', 'Notification ordering probe', 'general', 'Ikeja, Lagos');

select ok(to_regclass('public.notification_events') is not null, 'notification events table exists');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.notification_events'::regclass),
  'notification events have row-level security enabled'
);
select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'notification_events'
      and column_name = 'id' and is_identity = 'YES'
  ),
  'notification IDs are generated identities'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.notification_events'::regclass
      and conname = 'notification_events_event_type_check'
  ),
  'notification event types are constrained'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.notification_events'::regclass
      and conname = 'notification_events_actor_recipient_check'
  ),
  'notification actors must differ from recipients'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.notification_events'::regclass
      and conname = 'notification_events_read_at_check'
  ),
  'notification read timestamps are constrained'
);
select ok(
  (select count(*) = 3 and bool_and(confdeltype = 'c')
   from pg_constraint
   where conrelid = 'public.notification_events'::regclass and contype = 'f'),
  'all notification foreign keys cascade on delete'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'notification_events_recipient_created_id_idx'),
  'notification recipient ordering index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'notification_events_actor_id_idx'),
  'notification actor foreign-key index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'notification_events_post_id_idx'),
  'notification post foreign-key index exists'
);
select ok(
  not has_table_privilege('anon', 'public.notification_events', 'select')
  and not has_table_privilege('anon', 'public.notification_events', 'insert')
  and not has_table_privilege('anon', 'public.notification_events', 'update')
  and not has_table_privilege('anon', 'public.notification_events', 'delete')
  and not has_table_privilege('authenticated', 'public.notification_events', 'select')
  and not has_table_privilege('authenticated', 'public.notification_events', 'insert')
  and not has_table_privilege('authenticated', 'public.notification_events', 'update')
  and not has_table_privilege('authenticated', 'public.notification_events', 'delete')
  and not has_table_privilege('service_role', 'public.notification_events', 'select')
  and not has_table_privilege('service_role', 'public.notification_events', 'insert')
  and not has_table_privilege('service_role', 'public.notification_events', 'update')
  and not has_table_privilege('service_role', 'public.notification_events', 'delete'),
  'API roles have no direct notification table privileges'
);
select ok(
  not has_sequence_privilege('anon', 'public.notification_events_id_seq', 'usage')
  and not has_sequence_privilege('authenticated', 'public.notification_events_id_seq', 'usage')
  and not has_sequence_privilege('service_role', 'public.notification_events_id_seq', 'usage'),
  'API roles have no direct notification sequence privileges'
);
select has_function('public', 'set_post_like', array['uuid', 'bigint', 'boolean'], 'like RPC signature is preserved');
select has_function('public', 'list_notifications', array['uuid', 'integer'], 'notification listing RPC exists');
select has_function('public', 'mark_notification_read', array['uuid', 'bigint'], 'notification read RPC exists');
select ok(
  has_function_privilege('service_role', 'public.set_post_like(uuid,bigint,boolean)', 'execute')
  and has_function_privilege('service_role', 'public.list_notifications(uuid,integer)', 'execute')
  and has_function_privilege('service_role', 'public.mark_notification_read(uuid,bigint)', 'execute'),
  'the service role can execute vetted notification RPCs'
);
select ok(
  not has_function_privilege('anon', 'public.list_notifications(uuid,integer)', 'execute')
  and not has_function_privilege('authenticated', 'public.list_notifications(uuid,integer)', 'execute')
  and not has_function_privilege('public', 'public.list_notifications(uuid,integer)', 'execute')
  and not has_function_privilege('anon', 'public.mark_notification_read(uuid,bigint)', 'execute')
  and not has_function_privilege('authenticated', 'public.mark_notification_read(uuid,bigint)', 'execute')
  and not has_function_privilege('public', 'public.mark_notification_read(uuid,bigint)', 'execute'),
  'clients and PUBLIC cannot execute notification RPCs'
);
select ok(
  (select bool_and(prosecdef) from pg_proc where oid in (
    'public.set_post_like(uuid,bigint,boolean)'::regprocedure,
    'public.list_notifications(uuid,integer)'::regprocedure,
    'public.mark_notification_read(uuid,bigint)'::regprocedure
  )),
  'notification RPCs are security definer functions'
);
select ok(
  (select bool_and(proconfig @> array['search_path=""']) from pg_proc where oid in (
    'public.set_post_like(uuid,bigint,boolean)'::regprocedure,
    'public.list_notifications(uuid,integer)'::regprocedure,
    'public.mark_notification_read(uuid,bigint)'::regprocedure
  )),
  'notification RPCs pin an empty search path'
);

select results_eq(
  $$select liked, like_count from public.set_post_like('00000000-0000-0000-0000-000000000002', 9910, true)$$,
  $$values (true, 1::bigint)$$,
  'a successful like is persisted atomically'
);
select is(
  (select count(*) from public.notification_events where post_id = 9910),
  1::bigint,
  'a new non-self like creates exactly one notification'
);
select lives_ok(
  $$select public.set_post_like('00000000-0000-0000-0000-000000000002', 9910, true)$$,
  'a repeated desired-state like succeeds'
);
select is(
  (select count(*) from public.notification_events where post_id = 9910),
  1::bigint,
  'a repeated desired-state like creates no duplicate notification'
);
select lives_ok(
  $$select public.set_post_like('00000000-0000-0000-0000-000000000002', 9910, false)$$,
  'unliking succeeds'
);
select ok(
  not exists (select 1 from public.likes where post_id = 9910 and user_id = '00000000-0000-0000-0000-000000000002')
  and (select count(*) from public.notification_events where post_id = 9910) = 1,
  'unlike removes the like but retains durable activity'
);
select lives_ok(
  $$select public.set_post_like('00000000-0000-0000-0000-000000000002', 9910, true)$$,
  'liking again after an unlike succeeds'
);
select is(
  (select count(*) from public.notification_events where post_id = 9910),
  2::bigint,
  'a later false-to-true transition creates a new notification'
);
select lives_ok(
  $$select public.set_post_like('00000000-0000-0000-0000-000000000001', 9910, true)$$,
  'self-like state is still persisted'
);
select is(
  (select count(*) from public.notification_events where post_id = 9910),
  2::bigint,
  'self-likes create no notification noise'
);
select ok(
  not exists (
    select 1 from public.list_notifications('00000000-0000-0000-0000-000000000002', 20)
    where post_id = 9910
  ),
  'recipients cannot list another recipient notification'
);

insert into public.notification_events (id, event_type, recipient_id, actor_id, post_id, created_at)
overriding system value
select
  999200 + item,
  'post_like',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000003',
  9911,
  '2099-01-01T00:00:00Z'
from generate_series(1, 21) item;

select is(
  (select count(*) from public.list_notifications('00000000-0000-0000-0000-000000000001', 20)),
  20::bigint,
  'notification listing is bounded to 20 rows'
);
select is(
  (select array_agg(id) from public.list_notifications('00000000-0000-0000-0000-000000000001', 2)),
  array[999221::bigint, 999220::bigint],
  'notification listing uses descending ID as the tied-timestamp tiebreaker'
);
select throws_ok(
  $$select public.list_notifications('00000000-0000-0000-0000-000000000001', 21)$$,
  'P0001',
  'Notification limit must be between 1 and 20.',
  'notification listing rejects an unbounded limit'
);

create temp table first_notification_read as
select * from public.mark_notification_read(
  '00000000-0000-0000-0000-000000000001',
  (select min(id) from public.notification_events where post_id = 9910)
);
select ok(
  (select read_at is not null from first_notification_read),
  'marking a notification records a read timestamp'
);
select is(
  (select read_at from public.mark_notification_read(
    '00000000-0000-0000-0000-000000000001',
    (select id from first_notification_read)
  )),
  (select read_at from first_notification_read),
  'marking a notification again preserves its first read timestamp'
);
select throws_ok(
  $$select public.mark_notification_read('00000000-0000-0000-0000-000000000002', 999221)$$,
  'P0002',
  'Notification not found.',
  'another recipient receives the same not-found result'
);
select throws_ok(
  $$select public.mark_notification_read('00000000-0000-0000-0000-000000000001', 999999999)$$,
  'P0002',
  'Notification not found.',
  'a missing notification reports not found'
);
select throws_ok(
  $$insert into public.notification_events (event_type, recipient_id, actor_id, post_id) values ('post_like', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 9910)$$,
  '23514',
  null,
  'notification events reject self activity'
);
select throws_ok(
  $$insert into public.notification_events (event_type, recipient_id, actor_id, post_id, created_at, read_at) values ('post_like', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 9910, '2026-09-05T12:00:00Z', '2026-09-05T11:59:59Z')$$,
  '23514',
  null,
  'notification events reject reads before creation'
);
select throws_ok(
  $$insert into public.notification_events (event_type, recipient_id, actor_id, post_id) values ('comment', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 9910)$$,
  '23514',
  null,
  'notification events reject unsupported event types'
);

create function pg_temp.reject_notification_event()
returns trigger
language plpgsql
as $trigger$
begin
  raise exception 'notification insert blocked';
end;
$trigger$;
create trigger notification_event_failure_probe
before insert on public.notification_events
for each row execute function pg_temp.reject_notification_event();
select throws_ok(
  $$select public.set_post_like('00000000-0000-0000-0000-000000000004', 9910, true)$$,
  'P0001',
  'notification insert blocked',
  'notification insertion failure aborts the like RPC'
);
select is(
  (select count(*) from public.likes where post_id = 9910 and user_id = '00000000-0000-0000-0000-000000000004'),
  0::bigint,
  'notification insertion failure rolls back the like'
);
drop trigger notification_event_failure_probe on public.notification_events;

select ok(
  not exists (
    select 1
    from public.likes post_like
    join public.posts post on post.id = post_like.post_id
    where post_like.post_id between 1001 and 1012
      and post_like.user_id <> post.author_id
      and not exists (
        select 1
        from public.notification_events notification
        where notification.event_type = 'post_like'
          and notification.recipient_id = post.author_id
          and notification.actor_id = post_like.user_id
          and notification.post_id = post_like.post_id
          and notification.created_at = post_like.created_at
      )
  ),
  'deterministic non-self likes have matching durable activity timestamps'
);

select * from finish();

rollback;
