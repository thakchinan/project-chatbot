-- ═══════════════════════════════════════════════════════════════════
-- SmartBrain Care: Re-sequence user_knowledge.id
-- วันที่สร้าง: 2026-06-03
-- เรียงตาม: last_updated ASC, id ASC (tiebreaker)
-- ═══════════════════════════════════════════════════════════════════
-- ⚠️  รัน SQL ทีละ STEP — ตรวจผลแต่ละ Step ก่อนไปต่อ
-- ⚠️  ห้ามรัน Step 6 (Cleanup) จนกว่าจะยืนยันผล Step 5 แล้ว
-- ═══════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════
-- STEP 0: Pre-flight — ตรวจว่าไม่มีตารางอื่น reference user_knowledge.id
-- ═══════════════════════════════════════════════════════════════════
-- ✅ คาดหวัง: 0 rows → ปลอดภัย
-- ❌ ถ้ามี rows → หยุดแล้วแจ้งกลับ

SELECT
    tc.table_schema,
    tc.table_name,
    kcu.column_name,
    ccu.table_name   AS foreign_table_name,
    ccu.column_name  AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage  AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_name = 'user_knowledge'
  AND ccu.column_name = 'id';


-- ═══════════════════════════════════════════════════════════════════
-- STEP 1: Backup — สร้าง snapshot ก่อนเปลี่ยนแปลง
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE user_knowledge_backup AS
SELECT * FROM user_knowledge;

-- ✅ ตรวจจำนวน rows ตรงกัน
SELECT
    (SELECT COUNT(*) FROM user_knowledge) AS original_count,
    (SELECT COUNT(*) FROM user_knowledge_backup) AS backup_count;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 2: สร้าง Mapping Table (old_id → new_id)
-- ═══════════════════════════════════════════════════════════════════

CREATE TABLE user_knowledge_id_map AS
SELECT
    id AS old_id,
    ROW_NUMBER() OVER (ORDER BY last_updated ASC, id ASC)::INTEGER AS new_id
FROM user_knowledge;

-- ✅ ตรวจ mapping (ดูก่อนไปต่อ)
SELECT * FROM user_knowledge_id_map ORDER BY new_id;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 3: Re-sequence ID (TRANSACTION — ต้องรันทั้งก้อน)
-- ═══════════════════════════════════════════════════════════════════
-- ⚠️  Copy ตั้งแต่ BEGIN จนถึง COMMIT แล้วรันทั้งหมดพร้อมกัน

BEGIN;

-- 3a: ปิด triggers ชั่วคราว (ป้องกัน auto-update timestamp)
ALTER TABLE user_knowledge DISABLE TRIGGER ALL;

-- 3b: ย้าย id ไปค่าสูง ๆ ก่อน (หลีกเลี่ยง PK conflict)
UPDATE user_knowledge uk
SET id = m.new_id + (SELECT MAX(id) FROM user_knowledge_backup)
FROM user_knowledge_id_map m
WHERE uk.id = m.old_id;

-- 3c: ย้ายจากค่าสูง ๆ กลับมาค่าจริง (1..N)
UPDATE user_knowledge
SET id = id - (SELECT MAX(id) FROM user_knowledge_backup);

-- 3d: เปิด triggers กลับ
ALTER TABLE user_knowledge ENABLE TRIGGER ALL;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 4: Reset Sequence
-- ═══════════════════════════════════════════════════════════════════

SELECT setval(
    pg_get_serial_sequence('user_knowledge', 'id'),
    COALESCE((SELECT MAX(id) FROM user_knowledge), 0)
);

-- ✅ ตรวจค่า sequence ปัจจุบัน
SELECT currval(pg_get_serial_sequence('user_knowledge', 'id'));


-- ═══════════════════════════════════════════════════════════════════
-- STEP 5: Verification — ตรวจสอบผลลัพธ์
-- ═══════════════════════════════════════════════════════════════════

-- 5a: ดูข้อมูลหลัง re-sequence
SELECT id, user_id, topic, last_updated
FROM user_knowledge
ORDER BY id;

-- 5b: ตรวจว่า id ต่อเนื่อง 1..N
SELECT
    MIN(id) AS min_id,
    MAX(id) AS max_id,
    COUNT(*) AS total_rows,
    CASE
        WHEN MAX(id) = COUNT(*) AND MIN(id) = 1
        THEN '✅ PASS: id ต่อเนื่อง 1..N'
        ELSE '❌ FAIL: id ไม่ต่อเนื่อง'
    END AS result
FROM user_knowledge;

-- 5c: เทียบข้อมูลกับ backup (ทุก row ต้องตรงกัน)
SELECT
    b.id AS "id เดิม",
    uk.id AS "id ใหม่",
    uk.user_id,
    uk.topic,
    CASE
        WHEN b.user_id = uk.user_id
         AND b.topic = uk.topic
         AND b.summary = uk.summary
        THEN '✅ ข้อมูลตรงกัน'
        ELSE '❌ ข้อมูลไม่ตรง!'
    END AS integrity_check
FROM user_knowledge uk
JOIN user_knowledge_id_map m ON uk.id = m.new_id
JOIN user_knowledge_backup b ON m.old_id = b.id
ORDER BY uk.id;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 6: Cleanup — ลบตาราง temp (รันเมื่อยืนยันผล Step 5 แล้วเท่านั้น!)
-- ═══════════════════════════════════════════════════════════════════
-- ⚠️  ลบแล้ว rollback ไม่ได้!

DROP TABLE IF EXISTS user_knowledge_id_map;
DROP TABLE IF EXISTS user_knowledge_backup;


-- ═══════════════════════════════════════════════════════════════════
-- ROLLBACK PLAN (ใช้กรณีเกิดปัญหาเท่านั้น — ก่อนรัน Step 6)
-- ═══════════════════════════════════════════════════════════════════
/*
BEGIN;

TRUNCATE user_knowledge;

INSERT INTO user_knowledge (id, user_id, topic, summary, embedding, last_updated)
SELECT id, user_id, topic, summary, embedding, last_updated
FROM user_knowledge_backup;

SELECT setval(
    pg_get_serial_sequence('user_knowledge', 'id'),
    (SELECT MAX(id) FROM user_knowledge)
);

COMMIT;
*/
