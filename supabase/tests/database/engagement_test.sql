begin;

select plan(24);

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
