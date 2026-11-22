-- =============================================================
-- FILE   : sql/01c_spenders.sql
-- PURPOSE: Analyse paying player behaviour across three dimensions:
--          1. Revenue concentration: share of total revenue from top 1%, 10%, 50%
--             (evaluated for BOTH 'Payers Only' and 'All Players').
--          2. Time to first purchase: days from install to first IAP in buckets
--             (Day 0, Day 1-3, Day 4-7, Day 8-30, Day 30+, Never Paid),
--             restricted to cohorts with >=30 days of observation to prevent censoring bias.
--          3. Repeat purchase gap: interval between consecutive purchases
--             using the LAG() window function, summarized by P25, P50, P75, P90.
--
-- TABLES / VIEWS USED:
--   profile_clean   – player install_date and first_purchase_date
--   purchase_clean  – player purchases (usd_amount > 0 and event_ts)
-- =============================================================


-- -------------------------------------------------------------
-- 1. VIEW: spender_concentration
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW spender_concentration AS

-- Part A: Payers-Only Population
WITH payer_totals AS (
    SELECT 
        device_id,
        SUM(usd_amount) AS player_revenue
    FROM purchase_clean
    GROUP BY device_id
),
ranked_payers AS (
    SELECT 
        device_id,
        player_revenue,
        ROW_NUMBER() OVER (ORDER BY player_revenue DESC) AS rank_pos,
        COUNT(*) OVER () AS total_payers,
        SUM(player_revenue) OVER () AS total_revenue
    FROM payer_totals
),
payers_only_summary AS (
    SELECT 
        'Payers Only' AS population,
        MAX(total_payers) AS population_size,
        ROUND(SUM(CASE WHEN rank_pos <= CEIL(total_payers * 0.01) THEN player_revenue ELSE 0 END) * 100.0 / MAX(total_revenue), 2) AS top_1_pct_rev_share,
        ROUND(SUM(CASE WHEN rank_pos <= CEIL(total_payers * 0.10) THEN player_revenue ELSE 0 END) * 100.0 / MAX(total_revenue), 2) AS top_10_pct_rev_share,
        ROUND(SUM(CASE WHEN rank_pos <= CEIL(total_payers * 0.50) THEN player_revenue ELSE 0 END) * 100.0 / MAX(total_revenue), 2) AS top_50_pct_rev_share
    FROM ranked_payers
),

-- Part B: All-Players Population (including non-payers with $0 revenue)
all_player_totals AS (
    SELECT 
        p.device_id,
        COALESCE(SUM(pc.usd_amount), 0.0) AS player_revenue
    FROM profile_clean p
    LEFT JOIN purchase_clean pc ON p.device_id = pc.device_id
    GROUP BY p.device_id
),
ranked_all AS (
    SELECT 
        device_id,
        player_revenue,
        ROW_NUMBER() OVER (ORDER BY player_revenue DESC) AS rank_pos,
        COUNT(*) OVER () AS total_players,
        SUM(player_revenue) OVER () AS total_revenue
    FROM all_player_totals
),
all_players_summary AS (
    SELECT 
        'All Players' AS population,
        MAX(total_players) AS population_size,
        ROUND(SUM(CASE WHEN rank_pos <= CEIL(total_players * 0.01) THEN player_revenue ELSE 0 END) * 100.0 / MAX(total_revenue), 2) AS top_1_pct_rev_share,
        ROUND(SUM(CASE WHEN rank_pos <= CEIL(total_players * 0.10) THEN player_revenue ELSE 0 END) * 100.0 / MAX(total_revenue), 2) AS top_10_pct_rev_share,
        ROUND(SUM(CASE WHEN rank_pos <= CEIL(total_players * 0.50) THEN player_revenue ELSE 0 END) * 100.0 / MAX(total_revenue), 2) AS top_50_pct_rev_share
    FROM ranked_all
)

SELECT * FROM payers_only_summary
UNION ALL
SELECT * FROM all_players_summary;


-- -------------------------------------------------------------
-- 2. VIEW: time_to_first_purchase
-- -------------------------------------------------------------
-- Only include players who installed between 2026-01-01 and 2026-03-31
-- (at least 30 days before our window closed on 2026-04-30), so that every
-- player had equal opportunity to convert across all buckets.
CREATE OR REPLACE VIEW time_to_first_purchase AS
WITH mature_cohort AS (
    SELECT 
        device_id,
        install_date,
        first_purchase_date,
        CASE 
            WHEN first_purchase_date IS NULL THEN 'Never paid'
            WHEN (first_purchase_date - install_date) = 0 THEN 'Day 0'
            WHEN (first_purchase_date - install_date) BETWEEN 1 AND 3 THEN 'Day 1-3'
            WHEN (first_purchase_date - install_date) BETWEEN 4 AND 7 THEN 'Day 4-7'
            WHEN (first_purchase_date - install_date) BETWEEN 8 AND 30 THEN 'Day 8-30'
            ELSE 'Day 30+'
        END AS time_bucket,
        CASE 
            WHEN first_purchase_date IS NULL THEN 6
            WHEN (first_purchase_date - install_date) = 0 THEN 1
            WHEN (first_purchase_date - install_date) BETWEEN 1 AND 3 THEN 2
            WHEN (first_purchase_date - install_date) BETWEEN 4 AND 7 THEN 3
            WHEN (first_purchase_date - install_date) BETWEEN 8 AND 30 THEN 4
            ELSE 5
        END AS bucket_order
    FROM profile_clean
    WHERE install_date BETWEEN '2026-01-01' AND '2026-03-31'
)
SELECT 
    time_bucket,
    COUNT(*) AS player_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_all_players,
    -- Also report share among paying players only
    ROUND(COUNT(*) * 100.0 / NULLIF(SUM(CASE WHEN time_bucket != 'Never paid' THEN COUNT(*) ELSE 0 END) OVER (), 0), 2) AS pct_of_payers
FROM mature_cohort
GROUP BY time_bucket, bucket_order
ORDER BY bucket_order;


-- -------------------------------------------------------------
-- 3. VIEW: repeat_purchase_gaps
-- -------------------------------------------------------------
-- Computes the days elapsed between consecutive purchases by the same player.
CREATE OR REPLACE VIEW repeat_purchase_gaps AS
WITH purchase_lags AS (
    SELECT 
        device_id,
        event_ts,
        -- Window function LAG finds the timestamp of the immediately preceding purchase
        LAG(event_ts) OVER (PARTITION BY device_id ORDER BY event_ts) AS previous_event_ts,
        -- Calculate the difference in minutes, then convert to fractional days
        DATE_DIFF('minute', LAG(event_ts) OVER (PARTITION BY device_id ORDER BY event_ts), event_ts) / (60.0 * 24.0) AS gap_days
    FROM purchase_clean
)
SELECT 
    COUNT(*) AS repeat_purchase_count,
    ROUND(AVG(gap_days), 2) AS mean_gap_days,
    ROUND(QUANTILE_CONT(gap_days, 0.25), 2) AS p25_gap_days,
    ROUND(QUANTILE_CONT(gap_days, 0.50), 2) AS p50_median_gap_days,
    ROUND(QUANTILE_CONT(gap_days, 0.75), 2) AS p75_gap_days,
    ROUND(QUANTILE_CONT(gap_days, 0.90), 2) AS p90_gap_days
FROM purchase_lags
WHERE previous_event_ts IS NOT NULL;
