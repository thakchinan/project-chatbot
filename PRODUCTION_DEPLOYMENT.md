# SmartBrain Care Production Deployment

This checklist turns the demo features into a production-ready deployment without committing secrets.

## 1. OpenAI key

Do not commit a real OpenAI key.

Local Flutter:

```bash
OPENAI_API_KEY=sk-proj-your-rotated-key
```

Supabase Edge Functions:

```bash
supabase secrets set OPENAI_API_KEY=sk-proj-your-rotated-key
```

If a key was pasted into chat, rotate it before production use.

## 2. Database migrations

Run migrations in order, including:

```text
supabase/migrations/011_weekly_reports_and_caregiver_alerts.sql
```

This creates:

- `weekly_reports`
- `caregiver_alerts`
- `caregiver_device_tokens`
- `notification_deliveries`

## 3. Weekly report automation

Deploy the scheduled report generator:

```bash
supabase functions deploy generate-weekly-reports
```

Required secrets:

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
supabase secrets set OPENAI_API_KEY=...
```

Schedule `generate-weekly-reports` weekly in Supabase Dashboard, for example Sunday 23:30 Asia/Bangkok.

## 4. Caregiver push notifications

Deploy the alert dispatcher:

```bash
supabase functions deploy dispatch-caregiver-alerts
```

Required secret:

```bash
supabase secrets set FIREBASE_SERVER_KEY=...
```

Schedule `dispatch-caregiver-alerts` every 1-5 minutes. The function reads unread high/medium caregiver alerts, sends them to active tokens in `caregiver_device_tokens`, and stores delivery status in `notification_deliveries`.

## 5. Flutter app behavior

The Flutter app works in two modes:

- On-demand mode: user opens AI Weekly Report and the app generates the report immediately.
- Production mode: Supabase scheduled functions generate reports and alerts in the background.

The app also keeps a fallback statistical summary if OpenAI is unavailable, so the report screen remains usable during network or quota failures.
