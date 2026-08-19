-- SteriCord local dev seed data.
-- Creates two organizations so tenant isolation (master prompt section 50:
-- "Hospital A cannot access Hospital B") can be manually and automatically
-- verified. Auth users are inserted directly into auth.users, which is only
-- valid against the local Supabase stack (`supabase start`), never against a
-- hosted project.
--
-- All seed users share the password: SteriCord!2026

begin;

-- Organizations -----------------------------------------------------------------

insert into public.organizations (id, name, slug) values
  ('00000000-0000-0000-0000-000000000a01', 'General Hospital (Hospital A)', 'hospital-a'),
  ('00000000-0000-0000-0000-000000000b01', 'St. Mary Medical Center (Hospital B)', 'hospital-b');

insert into public.departments (id, organization_id, name, code) values
  ('00000000-0000-0000-0000-0000000a0d01', '00000000-0000-0000-0000-000000000a01', 'CSSD', 'CSSD'),
  ('00000000-0000-0000-0000-0000000a0d02', '00000000-0000-0000-0000-000000000a01', 'Operating Theatre', 'OT'),
  ('00000000-0000-0000-0000-0000000b0d01', '00000000-0000-0000-0000-000000000b01', 'CSSD', 'CSSD'),
  ('00000000-0000-0000-0000-0000000b0d02', '00000000-0000-0000-0000-000000000b01', 'Operating Theatre', 'OT');

-- Auth users (local stack only) --------------------------------------------------

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, reauthentication_token, phone_change, phone_change_token
) values
  ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'admin@hospital-a.test', crypt('SteriCord!2026', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}',
   '{"organization_id":"00000000-0000-0000-0000-000000000a01","department_id":"00000000-0000-0000-0000-0000000a0d01","full_name":"Hospital A Admin"}',
   now(), now(), '', '', '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-0000000a1002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'supervisor@hospital-a.test', crypt('SteriCord!2026', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}',
   '{"organization_id":"00000000-0000-0000-0000-000000000a01","department_id":"00000000-0000-0000-0000-0000000a0d01","full_name":"CSSD Supervisor A"}',
   now(), now(), '', '', '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-0000000a1003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'technician@hospital-a.test', crypt('SteriCord!2026', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}',
   '{"organization_id":"00000000-0000-0000-0000-000000000a01","department_id":"00000000-0000-0000-0000-0000000a0d01","full_name":"CSSD Technician A"}',
   now(), now(), '', '', '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-0000000a1004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'nurse@hospital-a.test', crypt('SteriCord!2026', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}',
   '{"organization_id":"00000000-0000-0000-0000-000000000a01","department_id":"00000000-0000-0000-0000-0000000a0d02","full_name":"OT Nurse A"}',
   now(), now(), '', '', '', '', '', '', '', ''),
  ('00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
   'admin@hospital-b.test', crypt('SteriCord!2026', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}',
   '{"organization_id":"00000000-0000-0000-0000-000000000b01","department_id":"00000000-0000-0000-0000-0000000b0d01","full_name":"Hospital B Admin"}',
   now(), now(), '', '', '', '', '', '', '', '');

-- Role grants ---------------------------------------------------------------------

insert into public.user_roles (user_id, organization_id, role) values
  ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000000a01', 'HOSPITAL_ADMIN'),
  ('00000000-0000-0000-0000-0000000a1002', '00000000-0000-0000-0000-000000000a01', 'CSSD_SUPERVISOR'),
  ('00000000-0000-0000-0000-0000000a1003', '00000000-0000-0000-0000-000000000a01', 'CSSD_TECHNICIAN'),
  ('00000000-0000-0000-0000-0000000a1004', '00000000-0000-0000-0000-000000000a01', 'OT_NURSE'),
  ('00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-000000000b01', 'HOSPITAL_ADMIN');

-- Sample equipment -----------------------------------------------------------------

insert into public.equipment (organization_id, department_id, equipment_code, equipment_type, manufacturer, model_name, serial_number, location, created_by) values
  ('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-0000000a0d01', 'AUTOCLAVE-A1', 'STEAM_AUTOCLAVE', 'Getinge', 'GSS67', 'SN-A1-001', 'CSSD Room 1', '00000000-0000-0000-0000-0000000a1001'),
  ('00000000-0000-0000-0000-000000000a01', '00000000-0000-0000-0000-0000000a0d01', 'WASHER-A1', 'WASHER_DISINFECTOR', 'Belimed', 'WD290', 'SN-A1-002', 'CSSD Room 1', '00000000-0000-0000-0000-0000000a1001'),
  ('00000000-0000-0000-0000-000000000b01', '00000000-0000-0000-0000-0000000b0d01', 'AUTOCLAVE-B1', 'STEAM_AUTOCLAVE', 'Steris', 'AMSCO600', 'SN-B1-001', 'CSSD Room 1', '00000000-0000-0000-0000-0000000b1001');

commit;
