-- =====================================================
-- auth_has_role & auth_get_roles RPC Functions
-- =====================================================

-- auth_has_role: Returns TRUE if the authenticated user has the given role
CREATE OR REPLACE FUNCTION public.auth_has_role(role_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = auth.uid()
      AND r.name = role_name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.auth_has_role(TEXT) TO authenticated;

-- auth_get_roles: Returns all role names for the authenticated user
CREATE OR REPLACE FUNCTION public.auth_get_roles()
RETURNS SETOF TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT r.name
    FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.auth_get_roles() TO authenticated;
