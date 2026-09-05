insert into public.users (id, handle, display_name, role, avatar_path, created_at)
values
  ('00000000-0000-0000-0000-000000000001', 'prince', 'Prince Adeyemi', 'Realtor', 'avatars/current-user.jpg', '2026-09-01T08:00:00Z'),
  ('00000000-0000-0000-0000-000000000002', 'ayo', 'Ayo Balogun', 'Property Consultant', 'avatars/ayo.jpg', '2026-09-01T08:01:00Z'),
  ('00000000-0000-0000-0000-000000000003', 'ifeoma', 'Ifeoma Nwosu', 'Architect', 'avatars/ifeoma.jpg', '2026-09-01T08:02:00Z'),
  ('00000000-0000-0000-0000-000000000004', 'bizzaro', 'Bizzaro Cole', 'Homeowner', 'avatars/bizzaro.jpg', '2026-09-01T08:03:00Z')
on conflict (id) do update
set
  handle = excluded.handle,
  display_name = excluded.display_name,
  role = excluded.role,
  avatar_path = excluded.avatar_path,
  created_at = excluded.created_at;

insert into public.property_requests (id, request_type, location, created_at)
overriding system value
values
  (4001, 'looking_to_rent', 'Yaba, Lagos', '2026-09-02T11:45:00Z'),
  (4002, 'looking_to_buy', 'Surulere, Lagos', '2026-09-02T11:30:00Z'),
  (4003, 'looking_to_buy', 'Gbagada, Lagos', '2026-09-02T10:15:00Z')
on conflict (id) do update
set
  request_type = excluded.request_type,
  location = excluded.location,
  created_at = excluded.created_at;

insert into public.properties (id, property_status, location, created_at)
overriding system value
values
  (5001, 'for_sale', 'Lekki Phase 1, Lagos', '2026-09-02T12:00:00Z'),
  (5002, 'for_rent', 'Ikeja GRA, Lagos', '2026-09-02T11:30:00Z'),
  (5003, 'for_rent', 'Ikoyi, Lagos', '2026-09-02T11:00:00Z'),
  (5004, 'for_sale', 'Magodo, Lagos', '2026-09-02T10:30:00Z'),
  (5005, 'for_rent', 'Ajah, Lagos', '2026-09-02T10:00:00Z'),
  (5006, 'for_sale', 'Chevron, Lagos', '2026-09-02T09:30:00Z')
on conflict (id) do update
set
  property_status = excluded.property_status,
  location = excluded.location,
  created_at = excluded.created_at;

insert into public.posts (
  id,
  author_id,
  body,
  post_type,
  location,
  property_request_id,
  property_id,
  view_count,
  bookmark_count,
  created_at
)
overriding system value
values
  (1001, '00000000-0000-0000-0000-000000000002', 'Three-bedroom family home with a bright kitchen and quick access to the Lekki corridor.', 'property', null, null, 5001, 243, 17, '2026-09-02T12:00:00Z'),
  (1002, '00000000-0000-0000-0000-000000000003', 'Looking for a quiet two-bedroom apartment close to a dependable school run.', 'request', null, 4001, null, 0, 0, '2026-09-02T11:45:00Z'),
  (1003, '00000000-0000-0000-0000-000000000004', 'Newly renovated flat available for professionals who need a short commute.', 'property', null, null, 5002, 197, 12, '2026-09-02T11:30:00Z'),
  (1004, '00000000-0000-0000-0000-000000000002', 'Seeking a compact first property with room to grow near a green space.', 'request', null, 4002, null, 63, 2, '2026-09-02T11:30:00Z'),
  (1005, '00000000-0000-0000-0000-000000000003', 'A practical note on choosing natural light over another extra room.', 'general', 'Victoria Island, Lagos', null, null, 151, 9, '2026-09-02T11:15:00Z'),
  (1006, '00000000-0000-0000-0000-000000000001', 'Two-bedroom apartment with a walkable route to cafes and the waterfront.', 'property', null, null, 5003, 111, 8, '2026-09-02T11:00:00Z'),
  (1007, '00000000-0000-0000-0000-000000000004', 'Sharing a calm renovation before-and-after from an older Lagos terrace.', 'general', 'Maryland, Lagos', null, null, 91, 3, '2026-09-02T10:45:00Z'),
  (1008, '00000000-0000-0000-0000-000000000002', 'Four-bedroom home with a flexible study and a compact garden.', 'property', null, null, 5004, 288, 24, '2026-09-02T10:30:00Z'),
  (1009, '00000000-0000-0000-0000-000000000003', 'Looking to buy a starter home near a reliable public transport route.', 'request', null, 4003, null, 76, 4, '2026-09-02T10:15:00Z'),
  (1010, '00000000-0000-0000-0000-000000000004', 'One-bedroom flat available now with a separate work corner.', 'property', null, null, 5005, 135, 6, '2026-09-02T10:00:00Z'),
  (1011, '00000000-0000-0000-0000-000000000001', 'A small checklist for viewing homes after a heavy rain.', 'general', 'Ogba, Lagos', null, null, 54, 1, '2026-09-02T09:45:00Z'),
  (1012, '00000000-0000-0000-0000-000000000002', 'Three-bedroom duplex with a dedicated laundry room and secure parking.', 'property', null, null, 5006, 211, 15, '2026-09-02T09:30:00Z')
on conflict (id) do update
set
  author_id = excluded.author_id,
  body = excluded.body,
  post_type = excluded.post_type,
  location = excluded.location,
  property_request_id = excluded.property_request_id,
  property_id = excluded.property_id,
  view_count = excluded.view_count,
  bookmark_count = excluded.bookmark_count,
  created_at = excluded.created_at;

insert into public.property_images (id, property_id, storage_path, position, created_at)
overriding system value
values
  (2001, 5001, 'properties/lekki-kitchen-01.jpg', 0, '2026-09-02T12:00:00Z'),
  (2002, 5001, 'properties/lekki-kitchen-02.jpg', 1, '2026-09-02T12:00:00Z'),
  (2003, 5002, 'properties/ikeja-gra-apartment-compound.jpg', 0, '2026-09-02T11:30:00Z'),
  (2004, 5004, 'properties/magodo-garden-home.jpg', 0, '2026-09-02T10:30:00Z'),
  (2005, 5006, 'properties/chevron-family-home.jpg', 0, '2026-09-02T09:30:00Z')
on conflict (id) do update
set
  property_id = excluded.property_id,
  storage_path = excluded.storage_path,
  position = excluded.position,
  created_at = excluded.created_at;

insert into public.comments (id, post_id, author_id, body, created_at)
overriding system value
values
  (3001, 1001, '00000000-0000-0000-0000-000000000001', 'The kitchen light is excellent. Is the garden private?', '2026-09-02T12:05:00Z'),
  (3002, 1001, '00000000-0000-0000-0000-000000000003', 'The study could work well as a nursery too.', '2026-09-02T12:06:00Z'),
  (3003, 1003, '00000000-0000-0000-0000-000000000002', 'The commute from Ikeja GRA is a strong point.', '2026-09-02T11:35:00Z')
on conflict (id) do update
set
  post_id = excluded.post_id,
  author_id = excluded.author_id,
  body = excluded.body,
  created_at = excluded.created_at;

insert into public.likes (post_id, user_id, created_at)
values
  (1001, '00000000-0000-0000-0000-000000000001', '2026-09-02T12:07:00Z'),
  (1001, '00000000-0000-0000-0000-000000000003', '2026-09-02T12:08:00Z'),
  (1003, '00000000-0000-0000-0000-000000000001', '2026-09-02T11:36:00Z'),
  (1006, '00000000-0000-0000-0000-000000000002', '2026-09-02T11:07:00Z'),
  (1008, '00000000-0000-0000-0000-000000000001', '2026-09-02T10:35:00Z'),
  (1011, '00000000-0000-0000-0000-000000000003', '2026-09-02T09:50:00Z')
on conflict (post_id, user_id) do update
set created_at = excluded.created_at;

with fixtures (event_type, recipient_id, actor_id, post_id, created_at, read_at) as (
  values
    ('post_like', '00000000-0000-0000-0000-000000000002'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 1001::bigint, '2026-09-02T12:07:00Z'::timestamptz, '2026-09-02T12:10:00Z'::timestamptz),
    ('post_like', '00000000-0000-0000-0000-000000000002'::uuid, '00000000-0000-0000-0000-000000000003'::uuid, 1001::bigint, '2026-09-02T12:08:00Z'::timestamptz, null::timestamptz),
    ('post_like', '00000000-0000-0000-0000-000000000004'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 1003::bigint, '2026-09-02T11:36:00Z'::timestamptz, null::timestamptz),
    ('post_like', '00000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000002'::uuid, 1006::bigint, '2026-09-02T11:07:00Z'::timestamptz, null::timestamptz),
    ('post_like', '00000000-0000-0000-0000-000000000002'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 1008::bigint, '2026-09-02T10:35:00Z'::timestamptz, '2026-09-02T10:40:00Z'::timestamptz),
    ('post_like', '00000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000003'::uuid, 1011::bigint, '2026-09-02T09:50:00Z'::timestamptz, '2026-09-02T10:00:00Z'::timestamptz)
)
update public.notification_events notification
set read_at = fixture.read_at
from fixtures fixture
where notification.event_type = fixture.event_type
  and notification.recipient_id = fixture.recipient_id
  and notification.actor_id = fixture.actor_id
  and notification.post_id = fixture.post_id
  and notification.created_at = fixture.created_at;

insert into public.notification_events (
  id,
  event_type,
  recipient_id,
  actor_id,
  post_id,
  created_at,
  read_at
)
overriding system value
select *
from (
  values
    (6001::bigint, 'post_like', '00000000-0000-0000-0000-000000000002'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 1001::bigint, '2026-09-02T12:07:00Z'::timestamptz, '2026-09-02T12:10:00Z'::timestamptz),
    (6002::bigint, 'post_like', '00000000-0000-0000-0000-000000000002'::uuid, '00000000-0000-0000-0000-000000000003'::uuid, 1001::bigint, '2026-09-02T12:08:00Z'::timestamptz, null::timestamptz),
    (6003::bigint, 'post_like', '00000000-0000-0000-0000-000000000004'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 1003::bigint, '2026-09-02T11:36:00Z'::timestamptz, null::timestamptz),
    (6004::bigint, 'post_like', '00000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000002'::uuid, 1006::bigint, '2026-09-02T11:07:00Z'::timestamptz, null::timestamptz),
    (6005::bigint, 'post_like', '00000000-0000-0000-0000-000000000002'::uuid, '00000000-0000-0000-0000-000000000001'::uuid, 1008::bigint, '2026-09-02T10:35:00Z'::timestamptz, '2026-09-02T10:40:00Z'::timestamptz),
    (6006::bigint, 'post_like', '00000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-000000000003'::uuid, 1011::bigint, '2026-09-02T09:50:00Z'::timestamptz, '2026-09-02T10:00:00Z'::timestamptz)
) as fixture(id, event_type, recipient_id, actor_id, post_id, created_at, read_at)
where not exists (
  select 1
  from public.notification_events notification
  where notification.event_type = fixture.event_type
    and notification.recipient_id = fixture.recipient_id
    and notification.actor_id = fixture.actor_id
    and notification.post_id = fixture.post_id
    and notification.created_at = fixture.created_at
)
on conflict (id) do nothing;

select setval(pg_get_serial_sequence('public.posts', 'id'), greatest((select max(id) from public.posts), 1), true);
select setval(pg_get_serial_sequence('public.property_requests', 'id'), greatest((select max(id) from public.property_requests), 1), true);
select setval(pg_get_serial_sequence('public.properties', 'id'), greatest((select max(id) from public.properties), 1), true);
select setval(pg_get_serial_sequence('public.property_images', 'id'), greatest((select max(id) from public.property_images), 1), true);
select setval(pg_get_serial_sequence('public.comments', 'id'), greatest((select max(id) from public.comments), 1), true);
select setval(pg_get_serial_sequence('public.notification_events', 'id'), greatest((select max(id) from public.notification_events), 1), true);
