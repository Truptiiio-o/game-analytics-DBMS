-- =============================================================
-- FILE   : sql/01d_ads.sql
-- PURPOSE: Analyse rewarded-video ad engagement across two key questions:
--          1. Rewarded Ad Cap Saturation: What percentage of active
--             ad-watching player-days reach or exceed the daily cap?
--             Broken down by cap tier (cap=5 vs cap=8).
--          2. Daily Ad Volume Trend: Total completed ad views per day
--             across the observation window to identify anomalies.
--
-- TABLES / VIEWS USED:
--   ad_clean  – cleaned ad views (status='completed', dates within Jan-Apr 2026)
--
-- WHY COUNT ONLY status='completed'?
--   Rewarded ads in mobile games operate on a contract: the player only
--   receives their in-game currency grant (and the studio only gets credited)
--   when the video is viewed to the end. Incomplete views ('started', 'abandoned')
--   do not provide economy rewards or revenue value.
-- =============================================================


-- -------------------------------------------------------------
-- 1. VIEW: ad_cap_saturation
-- -------------------------------------------------------------
-- Computes what share of ad-watching player-days reached their cap.
CREATE OR REPLACE VIEW ad_cap_saturation AS
WITH daily_player_caps AS (
    SELECT 
        device_id,
        event_date,
        ad_daily_cap,
        MAX(ad_daily_count) AS max_ad_count
    FROM ad_clean
    GROUP BY device_id, event_date, ad_daily_cap
)
SELECT 
    ad_daily_cap,
    COUNT(*) AS total_ad_watching_player_days,
    SUM(CASE WHEN max_ad_count >= ad_daily_cap THEN 1 ELSE 0 END) AS capped_player_days,
    ROUND(SUM(CASE WHEN max_ad_count >= ad_daily_cap THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_hit_cap
FROM daily_player_caps
GROUP BY ad_daily_cap
ORDER BY ad_daily_cap;


-- -------------------------------------------------------------
-- 2. VIEW: daily_ad_views
-- -------------------------------------------------------------
-- Daily time-series of total completed ads and unique watching players.
CREATE OR REPLACE VIEW daily_ad_views AS
SELECT 
    event_date,
    COUNT(*) AS total_completed_ads,
    COUNT(DISTINCT device_id) AS unique_ad_watchers,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT device_id), 2) AS ads_per_watcher
FROM ad_clean
GROUP BY event_date
ORDER BY event_date;
