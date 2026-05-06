-- ===========================================
-- 9. EMOTION SESSION SCHEMA
-- เพิ่มคอลัมน์สำหรับ label อารมณ์ใน brainwave_data
-- และสร้างตาราง emotion_sessions สำหรับจัดการ session
-- ===========================================

-- เพิ่มคอลัมน์ใน brainwave_data สำหรับ emotion labeling
ALTER TABLE brainwave_data 
  ADD COLUMN IF NOT EXISTS emotion_label VARCHAR(50),
  ADD COLUMN IF NOT EXISTS activity_type VARCHAR(100),
  ADD COLUMN IF NOT EXISTS session_phase VARCHAR(50);

COMMENT ON COLUMN brainwave_data.emotion_label IS 'อารมณ์ที่ตั้งใจกระตุ้น (ground truth label) เช่น neutral, calm, happy, stressed, sad';
COMMENT ON COLUMN brainwave_data.activity_type IS 'ประเภทกิจกรรมที่ทำอยู่ เช่น baseline, breathing, music, stroop, memory_game';
COMMENT ON COLUMN brainwave_data.session_phase IS 'ช่วงของ session เช่น baseline, stimulation, recovery';

-- สร้าง Index สำหรับ query ตาม emotion_label
CREATE INDEX IF NOT EXISTS idx_brainwave_data_emotion_label ON brainwave_data(emotion_label);
CREATE INDEX IF NOT EXISTS idx_brainwave_data_activity_type ON brainwave_data(activity_type);

-- ===========================================
-- ตาราง emotion_sessions - จัดการ session การเก็บข้อมูล
-- ===========================================
CREATE TABLE IF NOT EXISTS emotion_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_name VARCHAR(255),
    target_emotion VARCHAR(50) NOT NULL,
    activity_type VARCHAR(100) NOT NULL,
    duration_seconds INTEGER DEFAULT 0,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP WITH TIME ZONE,
    samples_collected INTEGER DEFAULT 0,
    avg_alpha REAL DEFAULT 0,
    avg_beta REAL DEFAULT 0,
    avg_theta REAL DEFAULT 0,
    avg_delta REAL DEFAULT 0,
    avg_gamma REAL DEFAULT 0,
    self_report_valence INTEGER,
    self_report_arousal INTEGER,
    notes TEXT,
    is_completed BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_emotion_sessions_user_id ON emotion_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_emotion_sessions_target_emotion ON emotion_sessions(target_emotion);

ALTER TABLE emotion_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for emotion_sessions" ON emotion_sessions FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE emotion_sessions IS 'ตาราง session การเก็บข้อมูลอารมณ์ แต่ละ session จะกำหนดอารมณ์เป้าหมายและกิจกรรมที่ใช้กระตุ้น';
