-- =============================================================
-- FILE   : sql/02_arpdau_decomp.sql
-- PURPOSE: Perform a Shift-Share Decomposition of the ~16% drop in
--          overall ARPDAU between the first 30 days (2026-01-01 to 2026-01-30)
--          and the last 30 days (2026-04-01 to 2026-04-30).
--
-- CORE QUESTION:
--   Why did overall ARPDAU drop ~16% while ARPDAU in EVERY SINGLE
--   country tier was flat or rising? (Simpson's Paradox).
--
-- DECOMPOSITION FORMULA (3-Part Shift-Share):
--   Change in ARPDAU (Delta R) = Within-Tier Effect + Mix Effect + Interaction
--   1. Within-Tier Effect: Sum( w_i1 * (r_i2 - r_i1) )
--      How much ARPDAU changed because tiers monetized better/worse.
--   2. Mix Effect (Between): Sum( (w_i2 - w_i1) * r_i1 )
--      How much ARPDAU changed purely because player composition shifted.
--   3. Interaction Effect:  Sum( (w_i2 - w_i1) * (r_i2 - r_i1) )
--      The dynamic cross-product between rate change and weight shift.
--
-- TABLES / VIEWS USED:
--   player_day_clean  – daily player activity
--   purchase_clean    – cleaned in-app purchases (usd_amount > 0)
--   profile_clean     – player country_tier and acquisition_channel
-- =============================================================


-- -------------------------------------------------------------
-- 1. VIEW: arpdau_period_by_tier
-- -------------------------------------------------------------
-- Computes DAU, Gross Revenue, ARPDAU, and DAU share for each country tier
-- across Period 1 (first 30 days) and Period 2 (last 30 days).
CREATE OR REPLACE VIEW arpdau_period_by_tier AS
WITH daily_tier_dau AS (
    SELECT 
        pd.activity_date AS dt,
        pr.country_tier,
        COUNT(DISTINCT pd.device_id) AS dau
    FROM player_day_clean pd
    JOIN profile_clean pr ON pd.device_id = pr.device_id
    GROUP BY pd.activity_date, pr.country_tier
),
daily_tier_rev AS (
    SELECT 
        p.event_date AS dt,
        pr.country_tier,
        SUM(p.usd_amount) AS revenue
    FROM purchase_clean p
    JOIN profile_clean pr ON p.device_id = pr.device_id
    GROUP BY p.event_date, pr.country_tier
),
combined AS (
    SELECT 
        d.dt,
        d.country_tier,
        d.dau,
        COALESCE(r.revenue, 0.0) AS revenue,
        CASE 
            WHEN d.dt BETWEEN '2026-01-01' AND '2026-01-30' THEN 'Period 1 (Jan 1-30)'
            WHEN d.dt BETWEEN '2026-04-01' AND '2026-04-30' THEN 'Period 2 (Apr 1-30)'
        END AS period
    FROM daily_tier_dau d
    LEFT JOIN daily_tier_rev r ON d.dt = r.dt AND d.country_tier = r.country_tier
    WHERE (d.dt BETWEEN '2026-01-01' AND '2026-01-30')
       OR (d.dt BETWEEN '2026-04-01' AND '2026-04-30')
)
SELECT 
    period,
    country_tier,
    SUM(dau) AS total_dau,
    ROUND(SUM(revenue), 2) AS total_revenue,
    -- Tier ARPDAU = total tier revenue divided by total tier DAU
    ROUND(SUM(revenue) / SUM(dau), 4) AS tier_arpdau,
    -- DAU share = tier DAU divided by all-tier DAU in that period
    ROUND(SUM(dau) * 1.0 / SUM(SUM(dau)) OVER (PARTITION BY period), 4) AS dau_share
FROM combined
GROUP BY period, country_tier
ORDER BY period, country_tier;


-- -------------------------------------------------------------
-- 2. VIEW: arpdau_shift_share_decomp
-- -------------------------------------------------------------
-- Executes the 3-part shift-share decomposition of the ARPDAU change.
CREATE OR REPLACE VIEW arpdau_shift_share_decomp AS
WITH tier_data AS (
    SELECT * FROM arpdau_period_by_tier
),
p1 AS (
    SELECT 
        country_tier,
        tier_arpdau AS r1,
        dau_share AS w1
    FROM tier_data
    WHERE period LIKE 'Period 1%'
),
p2 AS (
    SELECT 
        country_tier,
        tier_arpdau AS r2,
        dau_share AS w2
    FROM tier_data
    WHERE period LIKE 'Period 2%'
),
tier_calc AS (
    SELECT 
        p1.country_tier,
        p1.w1,
        p2.w2,
        ROUND(p2.w2 - p1.w1, 4) AS delta_w,
        p1.r1,
        p2.r2,
        ROUND(p2.r2 - p1.r1, 4) AS delta_r,
        -- Within effect = baseline weight * rate change
        ROUND(p1.w1 * (p2.r2 - p1.r1), 6) AS within_tier_effect,
        -- Mix effect = weight shift * baseline rate
        ROUND((p2.w2 - p1.w1) * p1.r1, 6) AS mix_effect,
        -- Interaction = weight shift * rate change
        ROUND((p2.w2 - p1.w1) * (p2.r2 - p1.r1), 6) AS interaction_effect
    FROM p1
    JOIN p2 ON p1.country_tier = p2.country_tier
)
SELECT 
    country_tier,
    w1 AS dau_share_p1,
    w2 AS dau_share_p2,
    delta_w AS dau_share_change,
    r1 AS arpdau_p1,
    r2 AS arpdau_p2,
    delta_r AS arpdau_change,
    within_tier_effect,
    mix_effect,
    interaction_effect,
    ROUND(within_tier_effect + mix_effect + interaction_effect, 6) AS total_tier_effect
FROM tier_calc
ORDER BY country_tier;


-- -------------------------------------------------------------
-- 3. VIEW: arpdau_shift_share_summary
-- -------------------------------------------------------------
-- Aggregates the decomposition to game-level headline percentages.
CREATE OR REPLACE VIEW arpdau_shift_share_summary AS
WITH totals AS (
    SELECT 
        SUM(within_tier_effect) AS sum_within_effect,
        SUM(mix_effect) AS sum_mix_effect,
        SUM(interaction_effect) AS sum_interaction_effect,
        SUM(total_tier_effect) AS total_arpdau_change
    FROM arpdau_shift_share_decomp
)
SELECT 
    ROUND(total_arpdau_change, 4) AS total_arpdau_change,
    ROUND(sum_within_effect, 4) AS within_tier_effect,
    ROUND(sum_within_effect * 100.0 / total_arpdau_change, 1) AS within_tier_pct_of_change,
    ROUND(sum_mix_effect, 4) AS mix_effect,
    ROUND(sum_mix_effect * 100.0 / total_arpdau_change, 1) AS mix_pct_of_change,
    ROUND(sum_interaction_effect, 4) AS interaction_effect,
    ROUND(sum_interaction_effect * 100.0 / total_arpdau_change, 1) AS interaction_pct_of_change
FROM totals;


-- -------------------------------------------------------------
-- 4. VIEW: mix_shift_channel_drivers
-- -------------------------------------------------------------
-- Pinpoints exactly which channels and tiers drove the volume expansion.
CREATE OR REPLACE VIEW mix_shift_channel_drivers AS
SELECT 
    pr.country_tier,
    pr.acquisition_channel,
    COUNT(CASE WHEN pr.install_date BETWEEN '2026-01-01' AND '2026-01-30' THEN 1 END) AS installs_p1,
    COUNT(CASE WHEN pr.install_date BETWEEN '2026-04-01' AND '2026-04-30' THEN 1 END) AS installs_p2,
    ROUND(COUNT(CASE WHEN pr.install_date BETWEEN '2026-04-01' AND '2026-04-30' THEN 1 END) * 1.0 / 
          NULLIF(COUNT(CASE WHEN pr.install_date BETWEEN '2026-01-01' AND '2026-01-30' THEN 1 END), 0), 2) AS install_growth_ratio
FROM profile_clean pr
GROUP BY pr.country_tier, pr.acquisition_channel
ORDER BY pr.country_tier, pr.acquisition_channel;
