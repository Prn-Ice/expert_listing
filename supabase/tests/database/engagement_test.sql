begin;

select plan(29);

insert into public.posts (id, author_id, body, post_type, location)
overriding system value
values (
  9901,
  '00000000-0000-0000-0000-000000000001',
  'Engagement test post',
  'general',
  'Yaba, Lagos'
);

select has_function(
  'public',
  'set_post_like',
  array['uuid', 'bigint', 'boolean'],
  'desired-state like RPC exists'
);
select has_function(
  'public',
  'list_post_comments',
  array['bigint'],
  'comment listing RPC exists'
);
select has_function(
  'public',
  'create_post_comment',
  array['uuid', 'bigint', 'text'],
  'comment creation RPC exists'
);

select ok(
  not has_function_privilege('anon', 'public.set_post_like(uuid,bigint,boolean)', 'execute'),
  'anon cannot execute the like RPC'
);
select ok(
  not has_function_privilege('authenticated', 'public.set_post_like(uuid,bigint,boolean)', 'execute'),
  'authenticated clients cannot execute the like RPC'
);
select ok(
  not has_function_privilege('public', 'public.set_post_like(uuid,bigint,boolean)', 'execute'),
  'PUBLIC cannot execute the like RPC'
);
select ok(
  not has_function_privilege('anon', 'public.list_post_comments(bigint)', 'execute'),
  'anon cannot execute the comment listing RPC'
);
select ok(
  not has_function_privilege('authenticated', 'public.list_post_comments(bigint)', 'execute'),
  'authenticated clients cannot execute the comment listing RPC'
);
select ok(
  not has_function_privilege('public', 'public.list_post_comments(bigint)', 'execute'),
  'PUBLIC cannot execute the comment listing RPC'
);
select ok(
  not has_function_privilege('anon', 'public.create_post_comment(uuid,bigint,text)', 'execute'),
  'anon cannot execute the comment creation RPC'
);
select ok(
  not has_function_privilege('authenticated', 'public.create_post_comment(uuid,bigint,text)', 'execute'),
  'authenticated clients cannot execute the comment creation RPC'
);
select ok(
  not has_function_privilege('public', 'public.create_post_comment(uuid,bigint,text)', 'execute'),
  'PUBLIC cannot execute the comment creation RPC'
);
select ok(
  has_function_privilege('service_role', 'public.set_post_like(uuid,bigint,boolean)', 'execute'),
  'the service role can execute engagement RPCs'
);
select ok(
  has_function_privilege('service_role', 'public.list_post_comments(bigint)', 'execute')
  and has_function_privilege('service_role', 'public.create_post_comment(uuid,bigint,text)', 'execute'),
  'the service role can execute comment RPCs'
);
select ok(
  not has_function_privilege('anon', 'public.feed_page(uuid,integer,timestamptz,bigint,post_type,request_type,property_status,text)', 'execute')
  and not has_function_privilege('authenticated', 'public.feed_page(uuid,integer,timestamptz,bigint,post_type,request_type,property_status,text)', 'execute')
  and not has_function_privilege('public', 'public.feed_page(uuid,integer,timestamptz,bigint,post_type,request_type,property_status,text)', 'execute'),
  'clients and PUBLIC cannot execute the feed RPC'
);
select ok(
  has_function_privilege('service_role', 'public.feed_page(uuid,integer,timestamptz,bigint,post_type,request_type,property_status,text)', 'execute'),
  'the service role can execute the feed RPC'
);

select results_eq(
  $$select liked, like_count from public.set_post_like('00000000-0000-0000-0000-000000000001', 9901, true)$$,
  $$values (true, 1::bigint)$$,
  'liking a post returns the desired state and authoritative count'
);
select results_eq(
  $$select liked, like_count from public.set_post_like('00000000-0000-0000-0000-000000000001', 9901, true)$$,
  $$values (true, 1::bigint)$$,
  'repeating a like is idempotent'
);
select results_eq(
  $$select liked, like_count from public.set_post_like('00000000-0000-0000-0000-000000000001', 9901, false)$$,
  $$values (false, 0::bigint)$$,
  'unliking returns the desired state and authoritative count'
);
select results_eq(
  $$select liked, like_count from public.set_post_like('00000000-0000-0000-0000-000000000001', 9901, false)$$,
  $$values (false, 0::bigint)$$,
  'repeating an unlike is idempotent'
);

select is(
  (select body from public.create_post_comment(
    '00000000-0000-0000-0000-000000000001',
    9901,
    'First comment'
  )),
  'First comment',
  'comment creation returns the persisted body'
);
select is(
  (select author_handle from public.create_post_comment(
    '00000000-0000-0000-0000-000000000002',
    9901,
    'Second comment'
  )),
  'ayo',
  'comment creation hydrates the request actor'
);
select is(
  (select array_agg(body) from public.list_post_comments(9901)),
  array['First comment', 'Second comment'],
  'comments are listed oldest first with an ID tiebreaker'
);

insert into public.likes (post_id, user_id, created_at)
select
  9901,
  id,
  '2026-09-05T12:00:00Z'::timestamptz + row_number() over (order by id) * interval '1 second'
from public.users;

select is(
  (
    select jsonb_array_length(like_previews)
    from public.feed_page('00000000-0000-0000-0000-000000000001', 20)
    where id = 9901
  ),
  3,
  'feed liker previews are bounded to three newest identities'
);
select is(
  (
    select array_agg(preview ->> 'handle' order by position)
    from public.feed_page('00000000-0000-0000-0000-000000000001', 20) feed
    cross join lateral jsonb_array_elements(feed.like_previews) with ordinality as previews(preview, position)
    where feed.id = 9901
  ),
  array['bizzaro', 'ifeoma', 'ayo'],
  'feed liker previews retain newest-first order at the three-item cap'
);
select is(
  (
    select latest_comment ->> 'body'
    from public.feed_page('00000000-0000-0000-0000-000000000001', 20)
    where id = 9901
  ),
  'Second comment',
  'feed rows include the newest comment preview'
);

select throws_ok(
  $$select public.create_post_comment('00000000-0000-0000-0000-000000000001', 9901, ' ')$$,
  'P0001',
  'Comment body must contain 1 through 1000 trimmed characters.',
  'the comment RPC rejects blank bodies'
);
select throws_ok(
  $$select public.set_post_like('00000000-0000-0000-0000-000000000001', 999999, true)$$,
  'P0002',
  'Post not found.',
  'the like RPC reports a missing post'
);
select throws_ok(
  $$select public.list_post_comments(999999)$$,
  'P0002',
  'Post not found.',
  'the comment RPC reports a missing post'
);

select * from finish();

rollback;
