-- =====================================================
-- RBAC ROW LEVEL SECURITY (FINAL PRODUCTION VERSION)
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- ENABLE RLS ON ALL RBAC TABLES
-- =====================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_branches ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION public.is_admin() 
RETURNS BOOLEAN 
SECURITY DEFINER 
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON ur.role_id = r.id
    WHERE ur.user_id = auth.uid() AND r.name = 'admin'
  );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PROFILES POLICIES
-- =====================================================

-- Users can read their own profile
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own"
ON profiles FOR SELECT
TO authenticated
USING (id = auth.uid());

-- Admins can read all profiles
DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
CREATE POLICY "profiles_select_admin"
ON profiles FOR SELECT
TO authenticated
USING (is_admin());

-- Users can update their own profile
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own"
ON profiles FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Allow insert for new user trigger (service role)
DROP POLICY IF EXISTS "profiles_insert_self" ON profiles;
CREATE POLICY "profiles_insert_self"
ON profiles FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- =====================================================
-- ROLES POLICIES
-- =====================================================

-- All authenticated users can read roles (lookup table)
DROP POLICY IF EXISTS "roles_select_authenticated" ON roles;
CREATE POLICY "roles_select_authenticated"
ON roles FOR SELECT
TO authenticated
USING (true);

-- =====================================================
-- USER_ROLES POLICIES
-- =====================================================

-- Users can read their own role assignments
DROP POLICY IF EXISTS "user_roles_select_own" ON user_roles;
CREATE POLICY "user_roles_select_own"
ON user_roles FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Admins can read all user role assignments
DROP POLICY IF EXISTS "user_roles_select_admin" ON user_roles;
CREATE POLICY "user_roles_select_admin"
ON user_roles FOR SELECT
TO authenticated
USING (is_admin());

-- =====================================================
-- USER_BRANCHES POLICIES
-- =====================================================

-- Users can read their own branch assignments
DROP POLICY IF EXISTS "user_branches_select_own" ON user_branches;
CREATE POLICY "user_branches_select_own"
ON user_branches FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Admins can read all user branch assignments
DROP POLICY IF EXISTS "user_branches_select_admin" ON user_branches;
CREATE POLICY "user_branches_select_admin"
ON user_branches FOR SELECT
TO authenticated
USING (is_admin());

-- =====================================================
-- AUTO-CREATE PROFILE ON SIGNUP TRIGGER
-- =====================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, is_active)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    true
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if any, then create
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();
