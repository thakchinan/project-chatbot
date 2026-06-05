-- =========================================================================
-- SmartBrain Care: Drop Unused Database Tables & Refactor User Context
-- Date: 2026-06-05
-- =========================================================================
-- This script removes database tables that are defined in schema but not used
-- in the Flutter or Python application code:
-- 1. chat_context (Vectorized chatbot context)
-- 2. user_knowledge (Obsolete vectorized user summary table)
--
-- Note: retrieval_logs table is kept and used for recording RAG queries.
--
-- It also re-defines get_user_context() to dynamically compute averages from
-- active tables (users, brainwave_data, test_results, activities) instead of
-- relying on the user_knowledge table.
-- =========================================================================

-- 1. Drop unused tables (CASCADE to drop associated indexes and policies)
DROP TABLE IF EXISTS chat_context CASCADE;
DROP TABLE IF EXISTS user_knowledge CASCADE;

-- Also clean up backup/temporary tables from previous migrations if they exist
DROP TABLE IF EXISTS user_knowledge_backup CASCADE;
DROP TABLE IF EXISTS user_knowledge_id_map CASCADE;

-- 2. Redefine the get_user_context function to query from users + active metrics directly
CREATE OR REPLACE FUNCTION get_user_context(
    p_user_id INT,
    context_limit INT DEFAULT 5
)
RETURNS TABLE (
    topic VARCHAR(255),
    summary TEXT,
    brainwave_avg JSONB,
    stress_level VARCHAR(50),
    recent_activities TEXT[]
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'user_profile'::VARCHAR(255) AS topic,
        'Profile and health data'::TEXT AS summary,
        (
            SELECT jsonb_build_object(
                'alpha', COALESCE(AVG(bd.alpha_wave), 0),
                'beta', COALESCE(AVG(bd.beta_wave), 0),
                'theta', COALESCE(AVG(bd.theta_wave), 0),
                'delta', COALESCE(AVG(bd.delta_wave), 0),
                'gamma', COALESCE(AVG(bd.gamma_wave), 0),
                'attention', COALESCE(AVG(bd.attention_score), 0),
                'meditation', COALESCE(AVG(bd.meditation_score), 0)
            )
            FROM brainwave_data bd 
            WHERE bd.user_id = p_user_id
            AND bd.recorded_at > NOW() - INTERVAL '7 days'
        ) AS brainwave_avg,
        (
            SELECT tr.stress_level 
            FROM test_results tr 
            WHERE tr.user_id = p_user_id 
            ORDER BY tr.test_date DESC 
            LIMIT 1
        ) AS stress_level,
        (
            SELECT COALESCE(array_agg(a.activity_name), ARRAY[]::TEXT[])
            FROM (
                SELECT activity_name 
                FROM activities 
                WHERE user_id = p_user_id 
                ORDER BY completed_at DESC 
                LIMIT 5
            ) a
        ) AS recent_activities
    FROM users u
    WHERE u.id = p_user_id;
END;
$$;

COMMENT ON FUNCTION get_user_context IS 'ดึงบริบทผู้ใช้สำหรับ personalized AI (คำนวณข้อมูลเรียลไทม์จากกิจกรรมและคลื่นสมอง)';
