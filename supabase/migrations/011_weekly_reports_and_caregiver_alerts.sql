-- AI Weekly Report + Caregiver alert persistence
-- Run after previous migrations in Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS weekly_reports (
  report_id BIGSERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  summary TEXT,
  report_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, period_start)
);

CREATE TABLE IF NOT EXISTS caregiver_alerts (
  alert_id BIGSERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  level VARCHAR(20) NOT NULL CHECK (level IN ('low', 'medium', 'high')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  source VARCHAR(80) NOT NULL DEFAULT 'weekly_report',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS caregiver_device_tokens (
  token_id BIGSERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  caregiver_name TEXT,
  platform VARCHAR(40) NOT NULL DEFAULT 'unknown',
  push_provider VARCHAR(40) NOT NULL DEFAULT 'fcm',
  device_token TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, device_token)
);

CREATE TABLE IF NOT EXISTS notification_deliveries (
  delivery_id BIGSERIAL PRIMARY KEY,
  alert_id BIGINT REFERENCES caregiver_alerts(alert_id) ON DELETE CASCADE,
  token_id BIGINT REFERENCES caregiver_device_tokens(token_id) ON DELETE SET NULL,
  provider VARCHAR(40) NOT NULL DEFAULT 'fcm',
  status VARCHAR(40) NOT NULL DEFAULT 'queued',
  provider_message_id TEXT,
  error_message TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_weekly_reports_user_period
  ON weekly_reports(user_id, period_start DESC);

CREATE INDEX IF NOT EXISTS idx_caregiver_alerts_user_created
  ON caregiver_alerts(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_caregiver_device_tokens_user_active
  ON caregiver_device_tokens(user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_notification_deliveries_alert
  ON notification_deliveries(alert_id, status);

ALTER TABLE weekly_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE caregiver_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE caregiver_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_deliveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow weekly reports access" ON weekly_reports;
CREATE POLICY "Allow weekly reports access"
  ON weekly_reports FOR ALL
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Allow caregiver alerts access" ON caregiver_alerts;
CREATE POLICY "Allow caregiver alerts access"
  ON caregiver_alerts FOR ALL
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Allow caregiver device tokens access" ON caregiver_device_tokens;
CREATE POLICY "Allow caregiver device tokens access"
  ON caregiver_device_tokens FOR ALL
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Allow notification deliveries access" ON notification_deliveries;
CREATE POLICY "Allow notification deliveries access"
  ON notification_deliveries FOR ALL
  USING (true)
  WITH CHECK (true);

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE caregiver_alerts;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE weekly_reports;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;
