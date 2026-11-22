-- =============================================================
-- FILE   : sql/01b_retention_cohorts.sql
-- PURPOSE: Build a retention cohort grid by install week.
--          Measures the percentage of players in each weekly cohort
--          who were active on exactly Day 1, Day 7, Day 14, and Day 30.
--
-- TABLES / VIEWS USED:
--   profile_clean     – player install_date and unique device_id
--   player_day_clean  – player activity_date
--
-- CENSORING RULE (One line definition):
--   A milestone cell (D1, D7, D14, D30) is set to NULL if any player
--   in that weekly cohort could not have reached Day N by 2026-04-30
--   (i.e. MAX(install_date) + N > '2026-04-30'), preventing artificial 0% values.
-- =============================================================

-- Step 1: Assign each new 2026 install to its weekly cohort (starting on Monday).
WITH cohorts AS (
    SELECT 
        DATE_TRUNC('week', install_date)::DATE AS cohort_week,
        device_id,
        install_date
    FROM profile_clean
    -- Focus on players who installed during the 2026 observation window
    WHERE install_date >= '2026-01-01' AND install_date <= '2026-04-30'
),

-- Step 2: Calculate the size and latest install date of each cohort.
cohort_sizes AS (
    SELECT 
        cohort_week,
        COUNT(DISTINCT device_id) AS cohort_size,
        MAX(install_date) AS max_install_date
    FROM cohorts
    GROUP BY cohort_week
),

-- Step 3: Find which players were active on exact day milestones after install.
activity_milestones AS (
    SELECT 
        c.cohort_week,
        c.device_id,
        -- Calculate exact number of days between activity and install day (Day 0)
        (pd.activity_date - c.install_date) AS day_n
    FROM cohorts c
    JOIN player_day_clean pd ON c.device_id = pd.device_id
    WHERE pd.activity_date >= c.install_date
)

-- Step 4: Construct the cohort retention grid with censoring logic applied.
SELECT 
    cs.cohort_week,
    cs.cohort_size,
    
    -- Day 1 Retention (% active exactly 1 day after install)
    CASE 
        WHEN cs.max_install_date + 1 > DATE '2026-04-30' THEN NULL
        ELSE ROUND(COUNT(DISTINCT CASE WHEN am.day_n = 1 THEN am.device_id END) * 100.0 / cs.cohort_size, 2)
    END AS d1_retention_pct,

    -- Day 7 Retention (% active exactly 7 days after install)
    CASE 
        WHEN cs.max_install_date + 7 > DATE '2026-04-30' THEN NULL
        ELSE ROUND(COUNT(DISTINCT CASE WHEN am.day_n = 7 THEN am.device_id END) * 100.0 / cs.cohort_size, 2)
    END AS d7_retention_pct,

    -- Day 14 Retention (% active exactly 14 days after install)
    CASE 
        WHEN cs.max_install_date + 14 > DATE '2026-04-30' THEN NULL
        ELSE ROUND(COUNT(DISTINCT CASE WHEN am.day_n = 14 THEN am.device_id END) * 100.0 / cs.cohort_size, 2)
    END AS d14_retention_pct,

    -- Day 30 Retention (% active exactly 30 days after install)
    CASE 
        WHEN cs.max_install_date + 30 > DATE '2026-04-30' THEN NULL
        ELSE ROUND(COUNT(DISTINCT CASE WHEN am.day_n = 30 THEN am.device_id END) * 100.0 / cs.cohort_size, 2)
    END AS d30_retention_pct

FROM cohort_sizes cs
LEFT JOIN activity_milestones am ON cs.cohort_week = am.cohort_week
GROUP BY cs.cohort_week, cs.cohort_size, cs.max_install_date
ORDER BY cs.cohort_week;
