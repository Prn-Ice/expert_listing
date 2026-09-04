update public.users
set avatar_path = 'avatars/current-user.jpg'
where id = '00000000-0000-0000-0000-000000000001';

update public.users
set
  handle = 'ayo',
  display_name = 'Ayo Balogun',
  avatar_path = 'avatars/ayo.jpg'
where id = '00000000-0000-0000-0000-000000000002';

update public.users
set
  handle = 'ifeoma',
  display_name = 'Ifeoma Nwosu',
  avatar_path = 'avatars/ifeoma.jpg'
where id = '00000000-0000-0000-0000-000000000003';

update public.users
set
  handle = 'bizzaro',
  display_name = 'Bizzaro Cole',
  avatar_path = 'avatars/bizzaro.jpg'
where id = '00000000-0000-0000-0000-000000000004';

update public.property_images
set storage_path = 'properties/lekki-kitchen-01.jpg'
where id = 2001 and property_id = 5001;

update public.property_images
set storage_path = 'properties/lekki-kitchen-02.jpg'
where id = 2002 and property_id = 5001;

update public.property_images
set storage_path = 'properties/ikeja-gra-apartment-compound.jpg'
where id = 2003 and property_id = 5002;

update public.property_images
set storage_path = 'properties/magodo-garden-home.jpg'
where id = 2004 and property_id = 5004;

update public.property_images
set storage_path = 'properties/chevron-family-home.jpg'
where id = 2005 and property_id = 5006;