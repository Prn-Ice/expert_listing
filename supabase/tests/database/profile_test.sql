begin;

select plan(6);

select has_function(
  'public',
  'user_profile',
  array['uuid'],
  'the profile read function exists'
);

select function_returns(
  'public',
  'user_profile',
  array['uuid'],
  'setof record',
  'the profile function returns its declared row'
);

select is(
  (select display_name from public.user_profile('00000000-0000-0000-0000-000000000001')),
  'Prince Adeyemi',
  'the profile function resolves a seeded user'
);

select is(
  (select count(*) from public.user_profile('ffffffff-ffff-ffff-ffff-ffffffffffff')),
  0::bigint,
  'an unknown user produces no profile row'
);

select throws_ok(
  $$set local role anon; select public.user_profile('00000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'anon cannot execute the profile function'
);

select throws_ok(
  $$set local role authenticated; select public.user_profile('00000000-0000-0000-0000-000000000001')$$,
  '42501',
  null,
  'authenticated cannot execute the profile function'
);

select * from finish();
rollback;
