-- =============================================================
-- FILE   : sql/01a_daily_health.sql
-- PURPOSE: Calculate core daily game health metrics by day and platform:
--          1. Daily Active Users (DAU)
--          2. Gross Revenue (USD from real-money in-app purchases)
--          3. ARPDAU (Average Revenue Per Daily Active User)
--          4. Daily Payer Conversion Share (paying players / DAU)
--
-- TABLES / VIEWS USED:
--   player_day_clean  – active days per player (contains activity_date)
--   purchase_clean    – cleaned in-app purchases (usd_amount > 0)
--   profile_clean     – player platform (Android vs iOS)
--
-- ASSUMPTIONS & DESIGN CHOICES:
--   1. Numerator & Denominator alignment:
--      DAU comes from player_day_clean (all players active on that day).
--      Revenue comes from purchase_clean (all purchases on that day).
--      We aggregate each table separately by (date, platform) before
--      joining. This avoids losing purchases that don't have a matching
--      player_day record, and prevents fan-out duplication.
--   2. ARPDAU is Gross Revenue / DAU (dividing by ALL active players,
--      not just paying players).
--   3. Payer share is unique purchasing devices on that day / DAU.
-- =============================================================

-- Step 1: Calculate Daily Active Users (DAU) by day and platform.
WITH daily_dau AS (
    SELECT 
        pd.activity_date AS dt,
        pr.platform,
        COUNT(DISTINCT pd.device_id) AS dau
    FROM player_day_clean pd
    JOIN profile_clean pr ON pd.device_id = pr.device_id
    GROUP BY pd.activity_date, pr.platform
),

-- Step 2: Calculate Gross Revenue and unique purchasing players by day and platform.
daily_revenue AS (
    SELECT 
        p.event_date AS dt,
        pr.platform,
        COUNT(DISTINCT p.device_id) AS paying_users,
        ROUND(SUM(p.usd_amount), 2) AS gross_revenue
    FROM purchase_clean p
    JOIN profile_clean pr ON p.device_id = pr.device_id
    GROUP BY p.event_date, pr.platform
)

-- Step 3: Combine DAU and Revenue to compute ARPDAU and payer conversion rate.
SELECT 
    d.dt,
    d.platform,
    d.dau,
    -- If no purchases occurred on a given day/platform, treat revenue as 0
    COALESCE(r.gross_revenue, 0.0) AS gross_revenue,
    -- ARPDAU = total daily revenue divided by total daily active players
    ROUND(COALESCE(r.gross_revenue, 0.0) / d.dau, 4) AS arpdau,
    -- Share of active players who made at least one purchase on this day
    ROUND(COALESCE(r.paying_users, 0) * 1.0 / d.dau, 4) AS payer_share
FROM daily_dau d
LEFT JOIN daily_revenue r ON d.dt = r.dt AND d.platform = r.platform
ORDER BY d.dt, d.platform;
