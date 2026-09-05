begin;

select plan(10);

select has_function(
  'public',
  'property_search_suggestions',
  array['text', 'integer'],
  'property autocomplete function exists'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'posts_property_body_trgm_idx'
  ),
  'property summaries have a partial trigram index'
);

select is(
  (
    select count(*)
    from public.property_search_suggestions('Lekki', 6)
    where suggestion_type = 'location'
      and label = 'Lekki Phase 1, Lagos'
      and matching_property_count = 1
  ),
  1::bigint,
  'autocomplete returns a matching location with its property count'
);

select is(
  (
    select property_id
    from public.property_search_suggestions('Lekki', 6)
    where suggestion_type = 'property'
    limit 1
  ),
  5001::bigint,
  'autocomplete returns the matching property'
);

select is(
  (
    select post_id
    from public.property_search_suggestions('waterfront', 6)
    where suggestion_type = 'property'
    limit 1
  ),
  1006::bigint,
  'autocomplete matches property summaries'
);

select ok(
  exists (
    select 1
    from public.property_search_suggestions('Lagos', 6)
    where suggestion_type = 'property'
  ),
  'broad location autocomplete retains a property result'
);

select is(
  (
    select count(*)
    from public.property_search_suggestions(null, null)
  ),
  0::bigint,
  'null inputs are bounded and return no suggestions'
);

select is(
  (
    select count(*)
    from public.property_search_suggestions(repeat('a', 121), 6)
  ),
  0::bigint,
  'oversized direct queries return no suggestions'
);

select is(
  (
    select count(*)
    from public.property_search_suggestions('%%', 6)
  ),
  0::bigint,
  'autocomplete treats LIKE wildcards literally'
);

select throws_ok(
  $$set local role anon; select * from public.property_search_suggestions('Lekki', 6)$$,
  '42501',
  null,
  'anonymous callers cannot execute the autocomplete function'
);

select * from finish();
rollback;
