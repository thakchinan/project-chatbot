-- ═══════════════════════════════════════════════════════════════════
-- SmartBrain Care: RESET ข้อมูลทั้ง Database
-- วันที่สร้าง: 2026-06-03
-- ═══════════════════════════════════════════════════════════════════
-- ⚠️  คำสั่งนี้จะ **ลบข้อมูลทั้งหมด** ในทุกตารางแล้ว reset id sequence
-- ⚠️  Schema (โครงสร้างตาราง, Index, RLS, Function) จะยังคงอยู่
-- ⚠️  Copy ทั้งหมดแล้วรันใน Supabase SQL Editor ครั้งเดียว
-- ═══════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════
-- STEP 1: TRUNCATE ทุกตารางที่มีอยู่จริง
-- ═══════════════════════════════════════════════════════════════════
-- ใช้ DO block ตรวจสอบว่าตารางมีอยู่จริงก่อน truncate
-- RESTART IDENTITY จะ reset sequence (id) กลับไป 1 อัตโนมัติ

DO $$
DECLARE
    tbl TEXT;
    tbl_list TEXT[] := ARRAY[
        -- Leaf tables (ไม่มีใครอ้างถึง)
        'eeg_assessment_reports',
        'emotion_sessions',
        'emotion_logs',
        'voice_metadata',
        'retrieval_logs',
        'elderly_profiles',
        'emergency_contacts',
        'conversations',
        -- Tables ที่มี FK ทั้งขาเข้าและขาออก
        'eeg_sessions',
        'brainwave_data',
        'activities',
        'schedules',
        'test_results',
        'chat_messages',
        'eeg_devices',
        'user_settings',
        'knowledge_base',
        -- Root table
        'users'
    ];
BEGIN
    FOREACH tbl IN ARRAY tbl_list
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = tbl
        ) THEN
            EXECUTE format('TRUNCATE TABLE %I RESTART IDENTITY CASCADE', tbl);
            RAISE NOTICE 'Truncated: %', tbl;
        ELSE
            RAISE NOTICE 'Skipped (not found): %', tbl;
        END IF;
    END LOOP;
END $$;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 2: ตรวจสอบว่าทุกตารางว่าง + sequence reset แล้ว
-- ═══════════════════════════════════════════════════════════════════

SELECT 
    schemaname,
    relname AS table_name,
    n_live_tup AS row_count
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY relname;

-- ✅ คาดหวัง: row_count = 0 ทุกตาราง


-- ═══════════════════════════════════════════════════════════════════
-- STEP 3: ยืนยัน Sequence reset (next id = 1)
-- ═══════════════════════════════════════════════════════════════════

SELECT
    sequencename,
    last_value
FROM pg_sequences
WHERE schemaname = 'public'
ORDER BY sequencename;

-- ✅ คาดหวัง: last_value = 1 (หรือ 0) ทุก sequence


-- ═══════════════════════════════════════════════════════════════════
-- STEP 4 (OPTIONAL): Re-insert sample knowledge data
-- ═══════════════════════════════════════════════════════════════════
-- ถ้าต้องการใส่ข้อมูลความรู้ RAG กลับ ให้รัน migration 002 อีกครั้ง
-- (เฉพาะส่วน INSERT INTO knowledge_base)
-- หรือ uncomment ด้านล่าง:

/*
INSERT INTO knowledge_base (title, content, category, tags, metadata) VALUES

('คลื่นสมอง Alpha คืออะไร', 
'คลื่น Alpha (8-13 Hz) เป็นคลื่นสมองที่เกิดขึ้นเมื่อเราอยู่ในสภาวะผ่อนคลาย สงบ และตื่นตัว เช่น การทำสมาธิ ปิดตาพักผ่อน หรือมองทิวทัศน์ธรรมชาติ คลื่น Alpha ช่วยลดความเครียด เพิ่มความคิดสร้างสรรค์ และส่งเสริมการเรียนรู้',
'brainwave', ARRAY['alpha', 'relaxation', 'meditation'], '{"frequency": "8-13 Hz", "state": "relaxed alertness"}'),

('คลื่นสมอง Beta และการทำงาน',
'คลื่น Beta (13-30 Hz) เป็นคลื่นที่ครองสมองเมื่อเราตื่นตัว ทำงาน คิดวิเคราะห์ หรือแก้ปัญหา Beta สูงเกินไปอาจทำให้วิตกกังวล เครียด หรือนอนไม่หลับ การฝึกสมาธิช่วยลด Beta ที่มากเกินไปได้',
'brainwave', ARRAY['beta', 'focus', 'work', 'anxiety'], '{"frequency": "13-30 Hz", "state": "active thinking"}'),

('คลื่นสมอง Theta และความคิดสร้างสรรค์',
'คลื่น Theta (4-8 Hz) เกิดขึ้นระหว่างการเคลิ้มหลับ ฝันกลางวัน หรือสมาธิลึก คลื่นนี้เชื่อมโยงกับความคิดสร้างสรรค์ ความจำ และการประมวลผลอารมณ์ การเพิ่ม Theta ช่วยให้จิตใจสงบและเข้าถึงจิตใต้สำนึก',
'brainwave', ARRAY['theta', 'creativity', 'meditation', 'dream'], '{"frequency": "4-8 Hz", "state": "deep relaxation"}'),

('คลื่นสมอง Delta และการนอนหลับ',
'คลื่น Delta (0.5-4 Hz) เกิดในระหว่างการนอนหลับลึก ไม่ฝัน เป็นคลื่นที่สำคัญสำหรับการฟื้นฟูร่างกาย ซ่อมแซมเนื้อเยื่อ และเสริมระบบภูมิคุ้มกัน การนอนไม่พอทำให้ Delta ลดลง',
'brainwave', ARRAY['delta', 'sleep', 'recovery', 'healing'], '{"frequency": "0.5-4 Hz", "state": "deep sleep"}'),

('คลื่นสมอง Gamma และสมาธิสูง',
'คลื่น Gamma (30-100+ Hz) เกี่ยวข้องกับการประมวลผลข้อมูลระดับสูง สติปัญญา และความตระหนักรู้ พบในผู้ทำสมาธิที่ชำนาญ Gamma สูงช่วยเพิ่มความจำ การเรียนรู้ และความสุข',
'brainwave', ARRAY['gamma', 'cognition', 'awareness', 'advanced meditation'], '{"frequency": "30-100+ Hz", "state": "peak mental processing"}'),

('ความเครียดคืออะไรและผลกระทบ',
'ความเครียดคือการตอบสนองของร่างกายต่อสถานการณ์ที่ท้าทาย ความเครียดเฉียบพลันช่วยให้ตื่นตัว แต่ความเครียดเรื้อรังทำลายสุขภาพ ทำให้นอนไม่หลับ ปวดหัว ระบบภูมิคุ้มกันอ่อนแอ และเพิ่มความเสี่ยงโรคหัวใจ',
'mental_health', ARRAY['stress', 'health', 'chronic'], '{"type": "educational"}'),

('วิธีจัดการความเครียดอย่างมีประสิทธิภาพ',
'การจัดการความเครียดที่ได้ผล ได้แก่ 1) หายใจลึก 4-7-8: หายใจเข้า 4 วินาที กลั้น 7 วินาที หายใจออก 8 วินาที 2) ออกกำลังกายสม่ำเสมอ 3) นอนหลับให้เพียงพอ 4) ทำสมาธิ 10-20 นาทีต่อวัน 5) พูดคุยกับคนที่ไว้ใจ',
'mental_health', ARRAY['stress', 'management', 'breathing', 'exercise'], '{"type": "practical_advice"}'),

('สัญญาณของภาวะซึมเศร้า',
'สัญญาณซึมเศร้า ได้แก่ เศร้าหมองมากกว่า 2 สัปดาห์ ไม่สนใจสิ่งที่เคยชอบ นอนมากหรือน้อยผิดปกติ เบื่ออาหารหรือกินมาก เหนื่อยล้า รู้สึกไร้ค่า มีปัญหาสมาธิ หากมีหลายอาการ ควรปรึกษาผู้เชี่ยวชาญ',
'mental_health', ARRAY['depression', 'symptoms', 'warning signs'], '{"type": "awareness"}'),

('การทำสมาธิเบื้องต้น',
'เริ่มต้นสมาธิง่ายๆ: 1) นั่งสบาย หลับตา 2) หายใจตามธรรมชาติ 3) จดจ่อที่ลมหายใจ 4) เมื่อใจลอย ให้กลับมาที่ลมหายใจ 5) เริ่มจาก 5 นาที ค่อยๆ เพิ่ม การฝึกสม่ำเสมอช่วยเพิ่ม Alpha และ Theta',
'meditation', ARRAY['beginner', 'breathing', 'practice'], '{"difficulty": "beginner", "duration": "5-20 minutes"}'),

('Body Scan Meditation',
'Body Scan คือการสังเกตความรู้สึกทางกายตั้งแต่ศีรษะถึงปลายเท้า ช่วยผ่อนคลายกล้ามเนื้อ ลดความเครียด และเพิ่มการตระหนักรู้ในร่างกาย เหมาะทำก่อนนอนหรือเมื่อเครียด ใช้เวลา 15-30 นาที',
'meditation', ARRAY['body scan', 'relaxation', 'awareness'], '{"difficulty": "intermediate", "duration": "15-30 minutes"}'),

('วิธีนอนหลับให้ดีขึ้น',
'เคล็ดลับนอนหลับดี: 1) นอนและตื่นเวลาเดิมทุกวัน 2) ห้องนอนมืดและเย็น 3) งดหน้าจอ 1 ชั่วโมงก่อนนอน 4) งดคาเฟอีนหลังบ่าย 5) ออกกำลังกายแต่ไม่ใกล้เวลานอน 6) ทำกิจกรรมผ่อนคลายก่อนนอน',
'sleep', ARRAY['sleep hygiene', 'quality', 'tips'], '{"type": "practical_advice"}'),

('ความสัมพันธ์ระหว่างการนอนกับคลื่นสมอง',
'ในการนอนหลับปกติ สมองผ่านหลายระยะ: NREM 1 (Theta), NREM 2 (Sleep Spindles), NREM 3 (Delta ลึก), และ REM (ฝัน, คลื่นหลากหลาย) การนอนครบทุกระยะสำคัญต่อความจำ การเรียนรู้ และสุขภาพกาย',
'sleep', ARRAY['sleep stages', 'brainwave', 'REM', 'NREM'], '{"type": "educational"}'),

('วิธีใช้ Muse S สำหรับการทำสมาธิ',
'Muse S คืออุปกรณ์ EEG สำหรับผู้บริโภคที่วัดคลื่นสมองขณะทำสมาธิ วิธีใช้: 1) สวมใส่ให้แน่นพอดี 2) เชื่อมต่อ Bluetooth กับแอป 3) เลือกโปรแกรมสมาธิ 4) ฟังเสียง feedback ที่เปลี่ยนตามสภาวะจิตใจ สมาธิดี = เสียงธรรมชาติสงบ',
'device', ARRAY['muse', 'eeg', 'meditation', 'setup'], '{"device": "Muse S", "type": "tutorial"}'),

('การอ่านค่าคลื่นสมองจาก Muse',
'Muse แสดงข้อมูล: Attention (สมาธิ) และ Meditation (ความสงบ) คะแนน 0-100 คะแนน Attention สูงหมายถึงจิตจดจ่อ คะแนน Meditation สูงหมายถึงจิตสงบผ่อนคลาย การติดตามแนวโน้มช่วยเห็นความก้าวหน้าในการฝึก',
'device', ARRAY['muse', 'metrics', 'attention', 'meditation'], '{"device": "Muse S/Muse 2", "type": "interpretation"}')

ON CONFLICT DO NOTHING;
*/
