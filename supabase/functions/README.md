## Deploy Edge Function

This repo now includes:

- `admin-create-user-profile` at:
  - `supabase/functions/admin-create-user-profile/index.ts`
- `delete-own-account` at:
  - `supabase/functions/delete-own-account/index.ts`

### 1) Login and link project

```bash
supabase login
supabase link --project-ref vqssydeyzhdoazulgzpm
```

### 2) Deploy function

```bash
supabase functions deploy admin-create-user-profile
supabase functions deploy delete-own-account
```

### 3) Verify from dashboard

Supabase Dashboard -> Edge Functions -> both functions should appear as `Active`.

### Notes

- Function requires:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
- These are automatically available in Supabase-hosted Edge Functions.
- Caller must be logged in and have `profiles.is_admin = true`.
