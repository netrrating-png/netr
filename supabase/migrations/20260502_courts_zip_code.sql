-- Adds zip_code column to courts so search-by-zip in CourtsViewModel works.
-- Idempotent: safe to apply if column already exists.
ALTER TABLE public.courts
  ADD COLUMN IF NOT EXISTS zip_code text;

CREATE INDEX IF NOT EXISTS idx_courts_zip_code ON public.courts (zip_code);
