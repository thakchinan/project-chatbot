-- ใบสรุปประเมินภาวะซึมเศร้า (qEEG) หลังวัดคลื่นสมอง 2 นาที
CREATE TABLE IF NOT EXISTS eeg_assessment_reports (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    eeg_index REAL NOT NULL DEFAULT 0,
    risk_level VARCHAR(100),
    risk_level_en VARCHAR(100),
    samples_collected INTEGER DEFAULT 0,
    duration_seconds INTEGER DEFAULT 120,
    report_data JSONB NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_eeg_reports_user_id ON eeg_assessment_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_eeg_reports_recorded_at ON eeg_assessment_reports(recorded_at DESC);

ALTER TABLE eeg_assessment_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for eeg_assessment_reports"
    ON eeg_assessment_reports FOR ALL USING (true) WITH CHECK (true);

ALTER PUBLICATION supabase_realtime ADD TABLE eeg_assessment_reports;

COMMENT ON TABLE eeg_assessment_reports IS 'ใบสรุปประเมินภาวะซึมเศร้าจาก qEEG (2 นาที)';
