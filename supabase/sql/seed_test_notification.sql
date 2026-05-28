-- Seeder test untuk memicu notifikasi pengumuman
-- Jalankan di Supabase SQL Editor

insert into public.announcements (title, content, category, status)
values
(
  'Seeder Notif ' || to_char(now(), 'YYYY-MM-DD HH24:MI:SS'),
  'Ini data seeder untuk verifikasi push notification dari backend.',
  'umum',
  'published'
);

