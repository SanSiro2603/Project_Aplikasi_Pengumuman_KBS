-- ==============================================================================
-- 1. Create Tables
-- ==============================================================================

-- Tabel Announcements
CREATE TABLE public.announcements (
  id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('umum', 'kesehatan', 'infrastruktur', 'keuangan', 'acara')),
  image_url TEXT,
  status TEXT NOT NULL CHECK (status IN ('draft', 'published')) DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  view_count INTEGER NOT NULL DEFAULT 0
);

-- Tabel Device Tokens (untuk FCM)
CREATE TABLE public.device_tokens (
  id UUID DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
  token TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 2. Setup Realtime
-- ==============================================================================
-- Aktifkan replikasi realtime untuk tabel announcements
alter publication supabase_realtime add table public.announcements;

-- ==============================================================================
-- 3. Setup Storage
-- ==============================================================================
-- Buat bucket untuk images
insert into storage.buckets (id, name, public)
values ('announcements', 'announcements', true)
on conflict (id) do nothing;

-- ==============================================================================
-- 4. Row Level Security (RLS)
-- ==============================================================================

-- Aktifkan RLS
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Warga (Anon / Public) bisa melihat pengumuman yang statusnya 'published'
CREATE POLICY "Public can view published announcements"
ON public.announcements
FOR SELECT
USING (status = 'published');

-- Warga bisa mendaftarkan device token mereka
CREATE POLICY "Public can insert device tokens"
ON public.device_tokens
FOR INSERT
WITH CHECK (true);

-- Admin (Authenticated) bisa melakukan full CRUD di tabel announcements
CREATE POLICY "Admins can do everything on announcements"
ON public.announcements
FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Admin (Authenticated) bisa membaca device tokens
CREATE POLICY "Admins can view device tokens"
ON public.device_tokens
FOR SELECT
USING (auth.role() = 'authenticated');

-- RLS untuk Storage Bucket
CREATE POLICY "Public can view announcement images"
ON storage.objects FOR SELECT
USING (bucket_id = 'announcements');

CREATE POLICY "Admins can upload/edit/delete announcement images"
ON storage.objects FOR ALL
USING (bucket_id = 'announcements' AND auth.role() = 'authenticated')
WITH CHECK (bucket_id = 'announcements' AND auth.role() = 'authenticated');
