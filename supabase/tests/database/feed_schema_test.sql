begin;

select plan(67);

select ok(to_regclass('public.users') is not null, 'users table exists');
select ok(to_regclass('public.property_requests') is not null, 'property_requests table exists');
select ok(to_regclass('public.properties') is not null, 'properties table exists');
select ok(to_regclass('public.posts') is not null, 'posts table exists');
select ok(to_regclass('public.property_images') is not null, 'property_images table exists');
select ok(to_regclass('public.comments') is not null, 'comments table exists');
select ok(to_regclass('public.likes') is not null, 'likes table exists');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.posts'::regclass),
  'posts have row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.property_requests'::regclass),
  'property requests have row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.properties'::regclass),
  'properties have row-level security enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.property_images'::regclass),
  'property images have row-level security enabled'
);

select ok(to_regtype('public.post_type') is not null, 'post_type enum exists');
select ok(to_regtype('public.request_type') is not null, 'request_type enum exists');
select ok(to_regtype('public.property_status') is not null, 'property_status enum exists');

select throws_ok(
  $$insert into public.posts (author_id, body, post_type, location) values ('00000000-0000-0000-0000-000000000001', ' ', 'general', 'Yaba, Lagos')$$,
  '23514',
  null,
  'posts reject blank bodies'
);

select throws_ok(
  $$insert into public.posts (author_id, body, post_type) values ('00000000-0000-0000-0000-000000000001', 'Missing location', 'general')$$,
  '23514',
  null,
  'general posts require their own location'
);

select throws_ok(
  $$insert into public.posts (author_id, body, post_type, location, property_request_id) values ('00000000-0000-0000-0000-000000000001', 'Mixed general', 'general', 'Yaba, Lagos', 4001)$$,
  '23514',
  null,
  'general posts cannot reference a request'
);

select throws_ok(
  $$insert into public.posts (author_id, body, post_type, location, property_request_id) values ('00000000-0000-0000-0000-000000000001', 'Mixed request', 'request', 'Yaba, Lagos', 4001)$$,
  '23514',
  null,
  'request posts store their location on property_requests only'
);

select throws_ok(
  $$insert into public.posts (author_id, body, post_type, property_request_id) values ('00000000-0000-0000-0000-000000000001', 'Mixed property', 'property', 4001)$$,
  '23514',
  null,
  'property posts require a property reference and no request reference'
);

select throws_ok(
  $$insert into public.property_requests (request_type, location) values ('looking_to_buy', ' ')$$,
  '23514',
  null,
  'property requests reject blank desired-area locations'
);

select throws_ok(
  $$insert into public.property_requests (request_type, location) values ('for_sale', 'Yaba, Lagos')$$,
  '22P02',
  null,
  'property requests reject property statuses as request types'
);

select throws_ok(
  $$insert into public.properties (property_status, location) values ('for_rent', ' ')$$,
  '23514',
  null,
  'properties reject blank physical locations'
);

select throws_ok(
  $$insert into public.properties (property_status, location) values ('looking_to_rent', 'Yaba, Lagos')$$,
  '22P02',
  null,
  'properties reject request types as property statuses'
);

select throws_ok(
  $$insert into public.property_images (property_id, storage_path, position) values (5001, 'properties/too-many.png', 4)$$,
  '23514',
  null,
  'property images reject a fifth position'
);

select throws_ok(
  $$insert into public.property_images (property_id, storage_path, position) values (5001, 'properties/duplicate-position.png', 0)$$,
  '23505',
  null,
  'property images require a unique position per property'
);

select throws_ok(
  $$insert into public.property_images (property_id, storage_path, position) values (5002, 'properties/lekki-kitchen-01.jpg', 1)$$,
  '23505',
  null,
  'property images require globally unique storage paths'
);

insert into public.properties (id, property_status, location)
overriding system value
values (9001, 'for_sale', 'Test Property, Lagos');
insert into public.property_images (property_id, storage_path, position)
values (9001, 'properties/cascade-test.png', 0);
delete from public.properties where id = 9001;
select is(
  (select count(*) from public.property_images where storage_path = 'properties/cascade-test.png'),
  0::bigint,
  'deleting a property cascades its image metadata'
);

select lives_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Created general post', 'general', 'Yaba, Lagos')$$,
  'the atomic creation RPC creates a general post'
);
select lives_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Created request post', 'request', 'Yaba, Lagos', 'looking_to_rent')$$,
  'the atomic creation RPC creates a request post'
);
select lives_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Created property post', 'property', 'Yaba, Lagos', null, 'for_sale', array['properties/created-property.png'])$$,
  'the atomic creation RPC creates a property post with images'
);
select lives_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Created four-image property post', 'property', 'Lekki, Lagos', null, 'for_rent', array['properties/four-0.png', 'properties/four-1.png', 'properties/four-2.png', 'properties/four-3.png'])$$,
  'the atomic creation RPC accepts four ordered property images'
);
select is(
  (select location from public.posts where body = 'Created general post'),
  'Yaba, Lagos',
  'general posts own their location'
);
select is(
  (select property_requests.location from public.posts join public.property_requests on property_requests.id = posts.property_request_id where posts.body = 'Created request post'),
  'Yaba, Lagos',
  'request posts own their desired-area location through property_requests'
);
select is(
  (select properties.location from public.posts join public.properties on properties.id = posts.property_id where posts.body = 'Created property post'),
  'Yaba, Lagos',
  'property posts own their physical location through properties'
);
select is(
  (select count(*) from public.property_images where property_id = 5003),
  0::bigint,
  'properties may have zero images'
);
select is(
  (select array_agg(position order by position) from public.property_images where property_id = 5001),
  array[0, 1],
  'properties retain ordered image positions'
);
select is(
  (select count(*) from public.posts join public.property_images on property_images.property_id = posts.property_id where posts.body = 'Created four-image property post'),
  4::bigint,
  'a property may have four images'
);

select throws_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Invalid general images', 'general', 'Yaba, Lagos', null, null, array['properties/general.png'])$$,
  'P0001',
  null,
  'general posts cannot receive images'
);
select throws_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Invalid request images', 'request', 'Yaba, Lagos', 'looking_to_buy', null, array['properties/request.png'])$$,
  'P0001',
  null,
  'request posts cannot receive images'
);
select throws_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Invalid general request', 'general', 'Yaba, Lagos', 'looking_to_buy')$$,
  'P0001',
  null,
  'general posts cannot receive request fields'
);
select throws_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Invalid request property', 'request', 'Yaba, Lagos', 'looking_to_buy', 'for_sale')$$,
  'P0001',
  null,
  'request posts cannot receive property fields'
);
select throws_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Invalid property request', 'property', 'Yaba, Lagos', 'looking_to_buy', 'for_sale')$$,
  'P0001',
  null,
  'property posts cannot receive request fields'
);
select throws_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'Too many property images', 'property', 'Yaba, Lagos', null, 'for_sale', array['properties/five-0.png', 'properties/five-1.png', 'properties/five-2.png', 'properties/five-3.png', 'properties/five-4.png'])$$,
  'P0001',
  null,
  'the atomic creation RPC rejects more than four property images'
);

select throws_ok(
  $$set local role anon; select public.create_post('00000000-0000-0000-0000-000000000001', 'Anonymous RPC', 'general', 'Yaba, Lagos')$$,
  '42501',
  null,
  'anon cannot execute the post creation RPC'
);

select throws_ok(
  $$select public.create_post('00000000-0000-0000-0000-000000000001', 'A rollback check', 'property', 'Rollback, Lagos', null, 'for_sale', array['properties/lekki-kitchen-01.jpg'])$$,
  '23505',
  null,
  'duplicate property image paths fail the post creation RPC'
);
select is(
  (select count(*) from public.posts where body = 'A rollback check'),
  0::bigint,
  'failed property creation rolls back the post row'
);
select is(
  (select count(*) from public.properties where location = 'Rollback, Lagos' and property_status = 'for_sale'),
  0::bigint,
  'failed property creation rolls back the property row'
);

select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'posts_pagination_idx'),
  'posts pagination index exists'
);

select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'posts_location_trgm_idx'),
  'general-post location trigram index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'posts_post_type_pagination_idx'),
  'post-type pagination index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'property_requests_request_type_idx'),
  'request-type filter index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'property_requests_location_trgm_idx'),
  'request location trigram index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'properties_property_status_idx'),
  'property-status filter index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'properties_location_trgm_idx'),
  'property location trigram index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'property_images_property_position_idx'),
  'property image order index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'posts_author_id_idx'),
  'posts author foreign-key index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'comments_post_created_id_idx'),
  'comments post foreign-key index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'comments_author_id_idx'),
  'comments author foreign-key index exists'
);
select ok(
  exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'likes_user_id_idx'),
  'likes user foreign-key index exists'
);

select is(
  (select array_agg(id order by created_at desc, id desc) from public.posts where created_at = '2026-09-02T11:30:00Z'::timestamptz),
  array[1004::bigint, 1003::bigint],
  'tied timestamps retain descending ID order'
);

select throws_ok(
  $$set local role anon; insert into public.posts (author_id, body, post_type, location) values ('00000000-0000-0000-0000-000000000001', 'Anonymous write', 'general', 'Yaba, Lagos')$$,
  '42501',
  null,
  'anon cannot write posts'
);

select is(
  (select count(*) from public.posts where post_type = 'general'),
  4::bigint,
  'deterministic fixtures include general posts'
);
select is(
  (select count(*) from public.posts where post_type = 'request'),
  4::bigint,
  'deterministic fixtures include request posts'
);
select is(
  (select count(*) from public.posts where post_type = 'property'),
  8::bigint,
  'deterministic fixtures include property posts'
);

-- The feed location filter must keep a predicate form PostgreSQL can connect
-- to the per-variant trigram indexes: a direct ILIKE on each indexed location
-- column, never an expression over several columns. With sequential scans
-- disabled, each variant's predicate must resolve to its index as a
-- server-side Index Cond rather than a post-scan Filter. At real scale the
-- planner also chooses these indexes on cost; the engagement evidence is
-- recorded on expert-listing-t70.
create or replace function pg_temp.explain_location_predicate(p_table text)
returns setof text
language plpgsql
set enable_seqscan = off
as $explain$
declare
  plan_line text;
begin
  for plan_line in execute format(
    'explain select id from public.%I where location ilike ''%%Yaba%%''',
    p_table
  )
  loop
    return next plan_line;
  end loop;
end;
$explain$;

select ok(
  exists (
    select 1
    from pg_temp.explain_location_predicate('posts') as plan_line
    where plan_line like '%Bitmap Index Scan on posts_location_trgm_idx%'
  ) and exists (
    select 1
    from pg_temp.explain_location_predicate('posts') as plan_line
    where plan_line like '%Index Cond: (location ~~*%'
  ),
  'general location predicates engage posts_location_trgm_idx as an index condition'
);
select ok(
  exists (
    select 1
    from pg_temp.explain_location_predicate('property_requests') as plan_line
    where plan_line like '%Bitmap Index Scan on property_requests_location_trgm_idx%'
  ) and exists (
    select 1
    from pg_temp.explain_location_predicate('property_requests') as plan_line
    where plan_line like '%Index Cond: (location ~~*%'
  ),
  'request location predicates engage property_requests_location_trgm_idx as an index condition'
);
select ok(
  exists (
    select 1
    from pg_temp.explain_location_predicate('properties') as plan_line
    where plan_line like '%Bitmap Index Scan on properties_location_trgm_idx%'
  ) and exists (
    select 1
    from pg_temp.explain_location_predicate('properties') as plan_line
    where plan_line like '%Index Cond: (location ~~*%'
  ),
  'property location predicates engage properties_location_trgm_idx as an index condition'
);

select * from finish();

rollback;
