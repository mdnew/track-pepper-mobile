-- TrackPepper initial schema

-- Households
CREATE TABLE households (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  invite_code text UNIQUE NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Profiles (linked to auth.users)
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  display_name text NOT NULL,
  household_id uuid REFERENCES households ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Schedule template (seeded, read-only for users)
CREATE TABLE schedule_tasks (
  id text PRIMARY KEY,
  sort_order int NOT NULL,
  time_label text NOT NULL,
  category text NOT NULL CHECK (category IN ('potty', 'feed', 'sleep', 'play', 'train', 'wind', 'night')),
  title text NOT NULL,
  subtitle text,
  icon text NOT NULL,
  section text NOT NULL
);

-- Daily completions
CREATE TABLE completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES households ON DELETE CASCADE,
  task_id text NOT NULL REFERENCES schedule_tasks ON DELETE CASCADE,
  date date NOT NULL,
  completed_by uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  completed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (household_id, task_id, date)
);

CREATE INDEX idx_completions_household_date ON completions (household_id, date);
CREATE INDEX idx_profiles_household ON profiles (household_id);

-- Helper: get current user's household_id
CREATE OR REPLACE FUNCTION auth_household_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT household_id FROM profiles WHERE id = auth.uid();
$$;

-- RLS
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE completions ENABLE ROW LEVEL SECURITY;

-- Households: members can read their household; anyone authenticated can create
CREATE POLICY "Members can read own household"
  ON households FOR SELECT
  USING (id = auth_household_id());

CREATE POLICY "Authenticated users can create households"
  ON households FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Members can update own household"
  ON households FOR UPDATE
  USING (id = auth_household_id());

-- Profiles: users can read profiles in same household; manage own profile
CREATE POLICY "Users can read household profiles"
  ON profiles FOR SELECT
  USING (household_id = auth_household_id() OR id = auth.uid());

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (id = auth.uid());

-- Schedule tasks: readable by all authenticated users
CREATE POLICY "Authenticated users can read schedule tasks"
  ON schedule_tasks FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Completions: household members only
CREATE POLICY "Members can read completions"
  ON completions FOR SELECT
  USING (household_id = auth_household_id());

CREATE POLICY "Members can insert completions"
  ON completions FOR INSERT
  WITH CHECK (
    household_id = auth_household_id()
    AND completed_by = auth.uid()
  );

CREATE POLICY "Members can delete completions"
  ON completions FOR DELETE
  USING (household_id = auth_household_id());

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO profiles (id, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Enable realtime for completions
ALTER PUBLICATION supabase_realtime ADD TABLE completions;
