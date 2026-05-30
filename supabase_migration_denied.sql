-- MediAlert Migration: Add 'denied' status and update view
-- ⚠️ IMPORTANT: Run these as TWO SEPARATE queries in the Supabase SQL Editor.

-- =====================================================
-- STEP 1: Add the new enum value
-- Run this FIRST, then click "Run"
-- =====================================================
ALTER TYPE log_status ADD VALUE IF NOT EXISTS 'denied';

-- =====================================================
-- STEP 2: Drop and recreate the view to avoid column mismatch errors
-- After Step 1 succeeds, run THIS separately
-- =====================================================
DROP VIEW IF EXISTS patient_adherence_view;

CREATE VIEW patient_adherence_view AS
SELECT
  l.patient_id,
  date_trunc('day', l.scheduled_time) AS day,
  count(*) AS total_doses,
  count(*) FILTER (WHERE l.status = 'taken') AS taken_doses,
  count(*) FILTER (WHERE l.status = 'missed') AS missed_doses,
  count(*) FILTER (WHERE l.status = 'skipped') AS skipped_doses,
  count(*) FILTER (WHERE l.status = 'denied') AS denied_doses,
  round(
    CASE WHEN count(*) = 0 THEN 0
    ELSE (count(*) FILTER (WHERE l.status = 'taken')::numeric / count(*)::numeric) * 100
    END,
    2
  ) AS adherence_percent
FROM medicine_logs l
GROUP BY l.patient_id, date_trunc('day', l.scheduled_time);
