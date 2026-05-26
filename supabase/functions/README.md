# Production Edge Functions

## Required secrets

Set these in Supabase before deploying:

```bash
supabase secrets set OPENAI_API_KEY=...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
supabase secrets set FIREBASE_SERVER_KEY=...
```

Do not commit real keys to git.

## Deploy

```bash
supabase functions deploy generate-weekly-reports
supabase functions deploy dispatch-caregiver-alerts
```

Schedule them in Supabase Dashboard:

- `generate-weekly-reports`: weekly, e.g. Sunday 23:30 Asia/Bangkok.
- `dispatch-caregiver-alerts`: every 1-5 minutes, depending on alert urgency.

The Flutter app still generates reports on demand. These Edge Functions add production background generation and push dispatch.
