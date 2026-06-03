-- ═══════════════════════════════════════════════════════════════════
-- SmartBrain Care: Re-sequence users.id อย่างปลอดภัย
-- วันที่สร้าง: 2026-06-03
-- แก้ไขปัญหา: System triggers / Foreign Key constraints permission denied
-- ═══════════════════════════════════════════════════════════════════
-- ⚠️  รัน SQL ทีละ STEP ใน Supabase SQL Editor
-- ⚠️  ห้ามรัน STEP 6 (Cleanup) จนกว่าจะตรวจสอบผลลัพธ์ใน STEP 5 เรียบร้อย
-- ═══════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════
-- STEP 1: สร้าง Backup Table ของ users
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS users_backup AS 
SELECT * FROM users;

-- ยืนยันจำนวนข้อมูล
SELECT 
    (SELECT COUNT(*) FROM users) AS original_users_count,
    (SELECT COUNT(*) FROM users_backup) AS backup_users_count;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 2: สร้าง Mapping Table (old_id ➔ new_id)
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS users_id_map AS
SELECT
    id AS old_id,
    ROW_NUMBER() OVER (ORDER BY id ASC)::INTEGER AS new_id
FROM users;

-- ตรวจสอบ mapping
SELECT * FROM users_id_map ORDER BY new_id;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 3: Re-sequence IDs (รันทั้งก้อนใน Transaction เดียว)
-- ═══════════════════════════════════════════════════════════════════
BEGIN;

DO $$
DECLARE
    r RECORD;
    offset_val CONSTANT INTEGER := 1000000;
BEGIN
    -- 3.1 สร้างตารางชั่วคราวเพื่อเก็บรายชื่อ Foreign Keys และเงื่อนไขการทำงาน
    CREATE TEMP TABLE temp_fk_definitions (
        child_table text,
        child_column text,
        constraint_name text,
        delete_rule text,
        update_rule text
    ) ON COMMIT DROP;

    -- 3.2 ดึงข้อมูล Foreign Keys ทั้งหมดที่ชี้ไปที่ users(id) ใน public schema
    INSERT INTO temp_fk_definitions (child_table, child_column, constraint_name, delete_rule, update_rule)
    SELECT
        tc.table_name AS child_table,
        kcu.column_name AS child_column,
        tc.constraint_name,
        rc.delete_rule,
        rc.update_rule
    FROM
        information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.referential_constraints rc
          ON rc.constraint_name = tc.constraint_name
          AND rc.constraint_schema = tc.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND ccu.table_name = 'users'
      AND ccu.column_name = 'id'
      AND tc.table_schema = 'public';

    -- 3.3 DROP Foreign Key constraints ทั้งหมด
    FOR r IN SELECT * FROM temp_fk_definitions LOOP
        EXECUTE format('ALTER TABLE %I DROP CONSTRAINT %I', r.child_table, r.constraint_name);
        RAISE NOTICE 'Dropped foreign key: % on table %', r.constraint_name, r.child_table;
    END LOOP;

    -- 3.4 ปิดใช้งาน User Triggers บนตาราง users และตารางลูกเพื่อความปลอดภัย
    ALTER TABLE users DISABLE TRIGGER USER;
    
    FOR r IN SELECT DISTINCT child_table FROM temp_fk_definitions LOOP
        EXECUTE format('ALTER TABLE %I DISABLE TRIGGER USER', r.child_table);
    END LOOP;
    RAISE NOTICE 'Disabled user-defined triggers';

    -- 3.5 ย้ายข้อมูล user_id ในตารางลูกไปยัง offset ชั่วคราว (ป้องก้น Unique Conflict)
    FOR r IN SELECT * FROM temp_fk_definitions LOOP
        EXECUTE format(
            'UPDATE %I c SET %I = m.new_id + %L FROM users_id_map m WHERE c.%I = m.old_id',
            r.child_table, r.child_column, offset_val, r.child_column
        );
    END LOOP;
    RAISE NOTICE 'Shifted child tables user_ids to temporary offset values';

    -- 3.6 ย้ายข้อมูล id ในตาราง users ไปยัง offset ชั่วคราว
    UPDATE users u
    SET id = m.new_id + offset_val
    FROM users_id_map m
    WHERE u.id = m.old_id;
    RAISE NOTICE 'Shifted users.id to temporary offset values';

    -- 3.7 ดึงข้อมูล user_id ในตารางลูกกลับมาจาก offset มายังค่า new_id จริง
    FOR r IN SELECT * FROM temp_fk_definitions LOOP
        EXECUTE format(
            'UPDATE %I SET %I = %I - %L WHERE %I > %L',
            r.child_table, r.child_column, r.child_column, offset_val, r.child_column, offset_val
        );
    END LOOP;
    RAISE NOTICE 'Restored child tables user_ids from offset to actual new_ids';

    -- 3.8 ดึงข้อมูล id ในตาราง users กลับมาจาก offset มายังค่า new_id จริง
    UPDATE users
    SET id = id - offset_val
    WHERE id > offset_val;
    RAISE NOTICE 'Restored users.id from offset to actual new_ids';

    -- 3.9 เปิดใช้งาน User Triggers กลับตามเดิม
    ALTER TABLE users ENABLE TRIGGER USER;
    
    FOR r IN SELECT DISTINCT child_table FROM temp_fk_definitions LOOP
        EXECUTE format('ALTER TABLE %I ENABLE TRIGGER USER', r.child_table);
    END LOOP;
    RAISE NOTICE 'Re-enabled user-defined triggers';

    -- 3.10 สร้าง Foreign Key constraints ทั้งหมดกลับคืนมาพร้อมคุณสมบัติเดิม
    FOR r IN SELECT * FROM temp_fk_definitions LOOP
        EXECUTE format(
            'ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES users(id) ON DELETE %s ON UPDATE %s',
            r.child_table,
            r.constraint_name,
            r.child_column,
            r.delete_rule,
            r.update_rule
        );
        RAISE NOTICE 'Recreated foreign key: % on table %', r.constraint_name, r.child_table;
    END LOOP;

END $$;

COMMIT;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 4: รีเซ็ต Sequence ของตาราง users
-- ═══════════════════════════════════════════════════════════════════
SELECT setval(
    pg_get_serial_sequence('users', 'id'),
    COALESCE((SELECT MAX(id) FROM users), 0)
);

-- ตรวจสอบค่าลำดับถัดไป
SELECT currval(pg_get_serial_sequence('users', 'id'));


-- ═══════════════════════════════════════════════════════════════════
-- STEP 5: การตรวจสอบความถูกต้อง (Verification)
-- ═══════════════════════════════════════════════════════════════════

-- 5a: ตรวจสอบว่า id ของ users เรียงจาก 1..N ต่อเนื่อง
SELECT 
    MIN(id) AS min_id,
    MAX(id) AS max_id,
    COUNT(*) AS total_rows,
    CASE 
        WHEN MAX(id) = COUNT(*) AND MIN(id) = 1 THEN '✅ PASS: id ต่อเนื่อง 1..N'
        ELSE '❌ FAIL: id ไม่ต่อเนื่อง'
    END AS result
FROM users;

-- 5b: ตรวจความสมบูรณ์และเทียบกับ Backup
SELECT 
    b.id AS "id เดิม",
    u.id AS "id ใหม่",
    u.name,
    u.email
FROM users u
JOIN users_id_map m ON u.id = m.new_id
JOIN users_backup b ON m.old_id = b.id
ORDER BY u.id;


-- ═══════════════════════════════════════════════════════════════════
-- STEP 6: ลบตารางชั่วคราว (Cleanup)
-- ═══════════════════════════════════════════════════════════════════
DROP TABLE IF EXISTS users_id_map;
DROP TABLE IF EXISTS users_backup;
