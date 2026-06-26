-- RPC to create household and link current user's profile (bypasses RLS for atomic setup)

CREATE OR REPLACE FUNCTION create_household(household_name text, invite text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_household households%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND household_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Already in a household';
  END IF;

  INSERT INTO households (name, invite_code)
  VALUES (household_name, upper(trim(invite)))
  RETURNING * INTO new_household;

  UPDATE profiles
  SET household_id = new_household.id
  WHERE id = auth.uid();

  RETURN row_to_json(new_household);
END;
$$;

GRANT EXECUTE ON FUNCTION create_household(text, text) TO authenticated;
