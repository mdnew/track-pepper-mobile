-- Household pets with name and date of birth

CREATE TABLE pets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES households ON DELETE CASCADE,
  name text NOT NULL,
  date_of_birth date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pets_name_not_empty CHECK (length(trim(name)) > 0)
);

CREATE INDEX idx_pets_household ON pets (household_id);

ALTER TABLE pets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read household pets"
  ON pets FOR SELECT
  USING (household_id = auth_household_id());

CREATE POLICY "Members can insert household pets"
  ON pets FOR INSERT
  WITH CHECK (household_id = auth_household_id());

CREATE POLICY "Members can update household pets"
  ON pets FOR UPDATE
  USING (household_id = auth_household_id());

CREATE POLICY "Members can delete household pets"
  ON pets FOR DELETE
  USING (household_id = auth_household_id());
