# Admin User Setup Guide

## 🔐 Admin Credentials

**Email:** `admin@visioncore.erp`  
**Password:** `VisionCore@2026!`

---

## 📝 Setup Instructions

### Step 1: Create User in Supabase Dashboard

1. Go to [Supabase Dashboard](https://app.supabase.com/project/YOUR_PROJECT_REF)
2. Navigate to **Authentication** → **Users** (sidebar)
3. Click **"Add User"** button (top right)
4. Select **"Create new user"**
5. Enter the credentials:
   - **Email:** `admin@visioncore.erp`
   - **Password:** `VisionCore@2026!`
   - **Auto Confirm User:** ✅ (check this box)
6. Click **"Create user"**

### Step 2: Run Admin Setup Script

After creating the user, run the setup script to assign admin role:

1. Go to **SQL Editor** in Supabase Dashboard
2. Click **"New Query"**
3. Copy and paste the contents of `supabase/admin_setup.sql`
4. Click **"Run"** (or press Ctrl/Cmd + Enter)

The script will:

- Create a profile for the admin user
- Assign the admin role
- Link user to the main branch

---

## ✅ Verification

After setup, verify the admin user:

```sql
-- Check if admin user exists
SELECT
    p.id,
    p.full_name,
    p.email,
    r.name as role,
    b.name as branch
FROM profiles p
LEFT JOIN user_roles ur ON ur.user_id = p.id
LEFT JOIN roles r ON r.id = ur.role_id
LEFT JOIN user_branches ub ON ub.user_id = p.id
LEFT JOIN branches b ON b.id = ub.branch_id
WHERE p.email = 'admin@visioncore.erp';
```

You should see:

- **Full Name:** VisionCore Administrator
- **Email:** admin@visioncore.erp
- **Role:** admin
- **Branch:** Main Branch - Colombo

---

## 🚀 Login to Application

1. Open the application at: http://localhost:9001/
2. You'll be redirected to `/auth/login`
3. Enter credentials:
   - **Email:** admin@visioncore.erp
   - **Password:** VisionCore@2026!
4. Click **Login**
5. You should be redirected to `/dashboard`

The admin user will have access to **all menu items** in the sidebar including:

- Dashboard
- Sales Point (POS)
- Inventory
- Finance
- Admin

---

## 🗄️ Database Structure

### Company

- **ID:** `YOUR_COMPANY_ID`
- **Name:** VisionCore ERP Solutions

### Branch

- **ID:** `YOUR_BRANCH_ID`
- **Name:** Main Branch - Colombo

### Admin Role

- **ID:** `YOUR_ADMIN_ROLE_ID`
- **Name:** admin

---

## 🔧 Troubleshooting

### Issue: "Email not confirmed"

**Solution:** Make sure you checked "Auto Confirm User" when creating the user in Supabase Dashboard.

### Issue: "No roles found" / Menu items not showing

**Solution:**

1. Verify the admin setup script ran successfully
2. Check user_roles table:
   ```sql
   SELECT * FROM user_roles WHERE user_id = (
     SELECT id FROM profiles WHERE email = 'admin@visioncore.erp'
   );
   ```

### Issue: Login redirects back to login page

**Solution:** Check browser console for errors. Ensure:

- Supabase URL and anon key are correct in `.env`
- User is confirmed in Supabase Dashboard

---

## 📌 Important Notes

- The password `Admin@123456` is for **development only**
- Change the password in production
- Admin users have full access to all modules
- Additional users can be created with different roles (manager, waiter, cashier, etc.)
