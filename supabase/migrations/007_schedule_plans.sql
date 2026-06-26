-- Age- and species-specific schedule plans

CREATE TABLE schedule_plans (
  id text PRIMARY KEY,
  species text NOT NULL CHECK (species IN ('dog', 'cat')),
  name text NOT NULL,
  emoji text NOT NULL,
  intro_title text,
  intro_description text,
  tips_title text,
  tips_body text,
  min_age_days int NOT NULL DEFAULT 0,
  max_age_days int
);

ALTER TABLE schedule_tasks
  ADD COLUMN plan_id text REFERENCES schedule_plans(id) ON DELETE CASCADE;

ALTER TABLE schedule_tasks
  DROP CONSTRAINT schedule_tasks_category_check;

ALTER TABLE schedule_tasks
  ADD CONSTRAINT schedule_tasks_category_check
  CHECK (category IN (
    'potty', 'feed', 'sleep', 'play', 'train', 'wind', 'night',
    'groom', 'vet', 'enrich', 'note'
  ));

DELETE FROM completions;
DELETE FROM schedule_tasks;

ALTER TABLE completions
  ADD COLUMN pet_id uuid REFERENCES pets(id) ON DELETE CASCADE;

ALTER TABLE completions
  DROP CONSTRAINT completions_household_id_task_id_date_key;

ALTER TABLE completions
  ADD CONSTRAINT completions_pet_id_task_id_date_key
  UNIQUE (pet_id, task_id, date);

CREATE INDEX idx_schedule_tasks_plan ON schedule_tasks (plan_id);
CREATE INDEX idx_completions_pet_date ON completions (pet_id, date);

ALTER TABLE schedule_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read schedule plans"
  ON schedule_plans FOR SELECT
  USING (auth.uid() IS NOT NULL);
