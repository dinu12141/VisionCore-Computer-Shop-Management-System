-- =====================================================
-- ADMIN USER SETUP SCRIPT (VisionCore ERP)
-- =====================================================
-- Run this AFTER creating the admin user via Supabase Dashboard
-- 
-- Admin Credentials:
-- Email: admin@visioncore.erp
-- Password: VisionCore@2026!
--
-- Instructions:
-- 1. Go to Supabase Dashboard → Authentication → Users
2. Click "Add User" → "Create new user"
3. Enter email: admin@visioncore.erp
4. Enter password: VisionCore@2026!
5. Click "Create user"
6. Run this script in the SQL Editor
-- =====================================================

DO $$
DECLARE
    v_admin_user_id UUID;
    v_admin_role_id UUID;
    v_company_id UUID := '5c7ff29c-418a-461a-9624-3667375c2af4';
    v_branch_id UUID := '340efb20-513a-4d99-b1e7-f32f938e31a8';
BEGIN
    -- 1. Get the admin user ID
    SELECT id INTO v_admin_user_id 
    FROM auth.users 
    WHERE email = 'admin@visioncore.erp';

    IF v_admin_user_id IS NULL THEN
        RAISE EXCEPTION 'Admin user not found. Please create user with email admin@visioncore.erp in Supabase Dashboard first';
    END IF;

    -- 2. Get Admin Role ID
    SELECT id INTO v_admin_role_id FROM roles WHERE name = 'admin';
    
    IF v_admin_role_id IS NULL THEN
        -- Fallback: create role if missing (though schema.sql should have done it)
        INSERT INTO roles (name, description) VALUES ('admin', 'System Administrator') RETURNING id INTO v_admin_role_id;
    END IF;

    -- 3. Ensure Company Exists
    INSERT INTO companies (id, name, email)
    VALUES (v_company_id, 'VisionCore ERP Solutions', 'admin@visioncore.erp')
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, email = EXCLUDED.email;

    -- 4. Ensure Branch Exists
    INSERT INTO branches (id, company_id, name, is_main, is_active)
    VALUES (v_branch_id, v_company_id, 'Main ERP Headquarters', true, true)
    ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

    -- 5. Create profile for admin
    INSERT INTO profiles (id, full_name, email, phone, is_active)
    VALUES (
        v_admin_user_id,
        'VisionCore Administrator',
        'admin@visioncore.erp',
        '+94112345678',
        true
    )
    ON CONFLICT (id) DO UPDATE 
    SET full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        phone = EXCLUDED.phone;

    -- 6. Assign admin role
    INSERT INTO user_roles (user_id, role_id)
    VALUES (v_admin_user_id, v_admin_role_id)
    ON CONFLICT (user_id, role_id) DO NOTHING;

    -- 7. Assign to main branch
    INSERT INTO user_branches (user_id, branch_id, is_home_branch)
    VALUES (v_admin_user_id, v_branch_id, true)
    ON CONFLICT (user_id, branch_id) DO UPDATE
    SET is_home_branch = EXCLUDED.is_home_branch;

    -- 8. Ensure Main Store Exists
    IF NOT EXISTS (SELECT 1 FROM stores WHERE branch_id = v_branch_id AND type = 'main') THEN
        INSERT INTO stores (branch_id, name, type)
        VALUES (v_branch_id, 'Main ERP Store', 'main');
    END IF;

    RAISE NOTICE 'Admin user setup completed for: %', v_admin_user_id;
END $$;
