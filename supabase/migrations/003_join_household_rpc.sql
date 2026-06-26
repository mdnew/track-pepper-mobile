-- RPC to join household by invite code (bypasses RLS for lookup)

CREATE OR REPLACE FUNCTION join_household_by_invite(invite text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  household_uuid uuid;
BEGIN
  SELECT id INTO household_uuid
  FROM households
  WHERE invite_code = upper(trim(invite));

  IF household_uuid IS NULL THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  UPDATE profiles
  SET household_id = household_uuid
  WHERE id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  RETURN household_uuid;
END;
$$;

GRANT EXECUTE ON FUNCTION join_household_by_invite(text) TO authenticated;
