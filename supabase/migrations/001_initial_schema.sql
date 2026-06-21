-- ===========================================
-- SmartBrain Care: Supabase Database Schema
-- ===========================================
-- ใช้ SQL นี้ใน Supabase SQL Editor เพื่อสร้างตาราง

-- Drop existing tables if needed (ระวังจะลบข้อมูลทั้งหมด)
-- DROP TABLE IF EXISTS chat_messages CASCADE;
-- DROP TABLE IF EXISTS schedules CASCADE;
-- DROP TABLE IF EXISTS activities CASCADE;
-- DROP TABLE IF EXISTS brainwave_data CASCADE;
-- DROP TABLE IF EXISTS test_results CASCADE;
-- DROP TABLE IF EXISTS user_settings CASCADE;
-- DROP TABLE IF EXISTS users CASCADE;

-- ===========================================
-- 1. USERS TABLE - ข้อมูลผู้ใช้
-- ===========================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(20),
    birth_date DATE,
    avatar_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for faster username lookup
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- ===========================================
-- 2. USER SETTINGS TABLE - การตั้งค่าผู้ใช้
-- ===========================================
CREATE TABLE IF NOT EXISTS user_settings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    daily_reminder BOOLEAN DEFAULT TRUE,
    weekly_report BOOLEAN DEFAULT TRUE,
    stress_alert BOOLEAN DEFAULT TRUE,
    reminder_time TIME DEFAULT '09:00:00',
    dark_mode BOOLEAN DEFAULT FALSE,
    language VARCHAR(10) DEFAULT 'th',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_settings_user_id ON user_settings(user_id);

-- ===========================================
-- 3. BRAINWAVE DATA TABLE - ข้อมูลคลื่นสมอง EEG
-- ===========================================
CREATE TABLE IF NOT EXISTS brainwave_data (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    alpha_wave REAL DEFAULT 0,      -- Alpha (8-13 Hz) - Relaxation
    beta_wave REAL DEFAULT 0,       -- Beta (13-30 Hz) - Active thinking
    theta_wave REAL DEFAULT 0,      -- Theta (4-8 Hz) - Drowsiness, meditation
    delta_wave REAL DEFAULT 0,      -- Delta (0.5-4 Hz) - Deep sleep
    gamma_wave REAL DEFAULT 0,      -- Gamma (30-100 Hz) - High cognitive functions
    attention_score REAL DEFAULT 0,  -- Calculated attention level (0-100)
    meditation_score REAL DEFAULT 0, -- Calculated meditation level (0-100)
    device_name VARCHAR(100) DEFAULT 'Muse S',
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_brainwave_data_user_id ON brainwave_data(user_id);
CREATE INDEX IF NOT EXISTS idx_brainwave_data_recorded_at ON brainwave_data(recorded_at DESC);

-- ===========================================
-- 4. TEST RESULTS TABLE - ผลการทดสอบความเครียด
-- ===========================================
CREATE TABLE IF NOT EXISTS test_results (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stress_score INTEGER DEFAULT 0,        -- คะแนนความเครียด (0-100)
    depression_score INTEGER DEFAULT 0,    -- คะแนนความซึมเศร้า (0-100)
    stress_level VARCHAR(50) DEFAULT 'normal', -- normal, mild, moderate, severe
    test_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_test_results_user_id ON test_results(user_id);
CREATE INDEX IF NOT EXISTS idx_test_results_test_date ON test_results(test_date DESC);

-- ===========================================
-- 5. ACTIVITIES TABLE - กิจกรรมต่างๆ
-- ===========================================
CREATE TABLE IF NOT EXISTS activities (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    activity_type VARCHAR(50),     -- meditation, breathing, game, etc.
    activity_name VARCHAR(255),    -- ชื่อกิจกรรม
    score INTEGER DEFAULT 0,       -- คะแนนที่ได้
    duration_minutes INTEGER DEFAULT 0, -- ระยะเวลา (นาที)
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_activities_user_id ON activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_completed_at ON activities(completed_at DESC);

-- ===========================================
-- 6. SCHEDULES TABLE - ตารางกิจกรรมประจำวัน
-- ===========================================
CREATE TABLE IF NOT EXISTS schedules (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    time VARCHAR(10) NOT NULL,     -- Format: "HH:mm"
    icon_name VARCHAR(50) DEFAULT 'event',
    color VARCHAR(50) DEFAULT 'purple',
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_schedules_user_id ON schedules(user_id);
CREATE INDEX IF NOT EXISTS idx_schedules_time ON schedules(time);

-- ===========================================
-- 7. CHAT MESSAGES TABLE - ประวัติแชท AI
-- ===========================================
CREATE TABLE IF NOT EXISTS chat_messages (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT,
    is_bot BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sent_at ON chat_messages(sent_at);

-- ===========================================
-- AUTO UPDATE TIMESTAMP TRIGGER
-- ===========================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- Apply trigger to users table
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to user_settings table
DROP TRIGGER IF EXISTS update_user_settings_updated_at ON user_settings;
CREATE TRIGGER update_user_settings_updated_at 
    BEFORE UPDATE ON user_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- ROW LEVEL SECURITY (RLS) - ความปลอดภัย
-- ===========================================
-- เปิด RLS สำหรับทุกตาราง
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE brainwave_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all operations for now (ปรับตามความต้องการ)
-- สำหรับ development: อนุญาตทุก operations ผ่าน anon key
DROP POLICY IF EXISTS "Allow all for users" ON users;
CREATE POLICY "Allow all for users" ON users FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for user_settings" ON user_settings;
CREATE POLICY "Allow all for user_settings" ON user_settings FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for brainwave_data" ON brainwave_data;
CREATE POLICY "Allow all for brainwave_data" ON brainwave_data FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for test_results" ON test_results;
CREATE POLICY "Allow all for test_results" ON test_results FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for activities" ON activities;
CREATE POLICY "Allow all for activities" ON activities FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for schedules" ON schedules;
CREATE POLICY "Allow all for schedules" ON schedules FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for chat_messages" ON chat_messages;
CREATE POLICY "Allow all for chat_messages" ON chat_messages FOR ALL USING (true) WITH CHECK (true);

-- ===========================================
-- SAMPLE DATA (Optional - Demo User)
-- ===========================================
-- Uncomment ถ้าต้องการข้อมูลตัวอย่าง

-- INSERT INTO users (username, password, full_name, email, phone)
-- VALUES ('demo', 'demo123', 'ผู้ใช้ทดสอบ', 'demo@example.com', '0812345678');

-- INSERT INTO user_settings (user_id) VALUES (1);

-- INSERT INTO brainwave_data (user_id, alpha_wave, beta_wave, theta_wave, delta_wave, gamma_wave, attention_score, meditation_score)
-- VALUES (1, 35.5, 25.0, 20.0, 15.0, 4.5, 65.0, 72.0);

-- INSERT INTO test_results (user_id, stress_score, depression_score, stress_level)
-- VALUES (1, 25, 15, 'normal');

-- INSERT INTO activities (user_id, activity_type, activity_name, score, duration_minutes)
-- VALUES (1, 'meditation', 'กายสมาธิ 10 นาที', 85, 10);

-- INSERT INTO schedules (user_id, title, description, time, icon_name, color)
-- VALUES 
--     (1, 'ตื่นนอน', 'เริ่มต้นวันใหม่', '07:00', 'wb_sunny', 'orange'),
--     (1, 'ทำสมาธิเช้า', 'นั่งสมาธิ 10 นาที', '07:30', 'self_improvement', 'purple'),
--     (1, 'ออกกำลังกาย', 'เดินเล่น 20 นาที', '17:00', 'directions_walk', 'green');

COMMENT ON TABLE users IS 'ตารางเก็บข้อมูลผู้ใช้งาน';
COMMENT ON TABLE user_settings IS 'ตารางเก็บการตั้งค่าของผู้ใช้';
COMMENT ON TABLE brainwave_data IS 'ตารางเก็บข้อมูลคลื่นสมอง EEG จากอุปกรณ์ Muse';
COMMENT ON TABLE test_results IS 'ตารางเก็บผลการทดสอบความเครียดและซึมเศร้า';
COMMENT ON TABLE activities IS 'ตารางเก็บกิจกรรมที่ผู้ใช้ทำ เช่น สมาธิ, หายใจ, เกม';
COMMENT ON TABLE schedules IS 'ตารางเก็บตารางกิจกรรมประจำวัน';
COMMENT ON TABLE chat_messages IS 'ตารางเก็บประวัติการสนทนากับ AI';
