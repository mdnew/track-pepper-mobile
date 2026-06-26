-- Add dog or cat species to household pets

ALTER TABLE pets
  ADD COLUMN species text NOT NULL DEFAULT 'dog'
  CHECK (species IN ('dog', 'cat'));
