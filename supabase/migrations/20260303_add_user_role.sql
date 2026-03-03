-- ============================================================================
-- MIGRATION: Add 'user' Role
-- Date: 2026-03-03
-- Description: Adds a 'user' role for standard staff accounts
-- ============================================================================

INSERT INTO roles (name, description)
VALUES ('user', 'Standard staff user with access controlled by admin')
ON CONFLICT (name) DO NOTHING;
