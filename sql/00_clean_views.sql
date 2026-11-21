-- =============================================================
-- FILE   : sql/00_clean_views.sql
-- PURPOSE: Create cleaned "views" on top of the five raw tables.
--          All later notebooks use these views, never the raw tables.
--          Run this file at the top of every notebook via:
--              run_sql_file('00_clean_views.sql')
--
-- TABLES USED:
--   player_profile  – one row per registered device/player
--   player_day      – one row per (player, calendar day)
--   purchase        – real-money transactions
--   currency_spend  – in-game currency spending events
--   ad_view         – rewarded-video ad events
--
-- ASSUMPTIONS:
--   1. Observation window is 2026-01-01 to 2026-04-30 (inclusive).
--   2. Players installed before 2026 are "existing players" who are
--      still in the data; they are NOT excluded from analysis.
--   3. Duplicate purchase_id rows with DIFFERENT timestamps are treated
--      as separate real transactions (same transaction ID re-used by the
--      game server). We keep all rows but flag duplicates so they can
--      be excluded if needed.
--   4. device_id is the unique player identifier we use everywhere.
--      original_device_id links a "reinstall" device to its first device.
--      We collapse these into a "root" player via the mapping view below.
--   5. ad_view rows dated 2026-05-01 (7,732 rows) are midnight-rollover
--      events captured just after the window closed. We exclude them.
-- =============================================================


-- -------------------------------------------------------------
-- STEP 1: Device-mapping view
-- -------------------------------------------------------------
-- Some players uninstalled and reinstalled the game on the same device.
-- When they reinstall, the game assigns them a NEW device_id but records
-- their OLD device_id in original_device_id. This view gives every device
-- a single "root_id" – the oldest known device_id for that player.
-- If a device has no original_device_id, its root_id is itself.
CREATE OR REPLACE VIEW device_map AS
SELECT
    device_id,
    -- If original_device_id is NULL (never reinstalled), use the device itself.
    -- If it is set, follow the link to the original player.
    COALESCE(original_device_id, device_id) AS root_id
FROM player_profile;


-- -------------------------------------------------------------
-- STEP 2: profile_clean
-- -------------------------------------------------------------
-- Cleaned version of player_profile.
-- Changes made:
--   • Adds root_id from device_map (the "true" player identity)
--   • No rows are removed — all 80,295 players are kept.
--   • NULL first_purchase_date means the player has never paid (non-payer).
CREATE OR REPLACE VIEW profile_clean AS
SELECT
    pp.device_id,
    dm.root_id,                      -- canonical player ID after re-install collapsing
    pp.install_date,
    pp.platform,
    pp.country,
    pp.country_tier,                 -- 1 = top-tier markets (US, UK…), 4 = lowest
    pp.acquisition_channel,
    pp.first_purchase_date,
    -- Convenience flag: did this player ever pay real money?
    CASE WHEN pp.first_purchase_date IS NOT NULL THEN TRUE ELSE FALSE END AS is_payer
FROM player_profile pp
LEFT JOIN device_map dm ON pp.device_id = dm.device_id;


-- -------------------------------------------------------------
-- STEP 3: player_day_clean
-- -------------------------------------------------------------
-- Cleaned version of player_day.
-- Changes made:
--   • activity_date (integer YYYYMMDD) is converted to a real DATE column.
--     E.g. 20260115 → 2026-01-15.
--   • Only rows in the observation window are kept (all were already OK).
CREATE OR REPLACE VIEW player_day_clean AS
SELECT
    device_id,
    -- Convert integer YYYYMMDD to a proper DATE so we can do date arithmetic.
    -- strptime parses a string using a format pattern; %Y=4-digit year,
    -- %m=2-digit month, %d=2-digit day.
    strptime(CAST(activity_date AS VARCHAR), '%Y%m%d')::DATE AS activity_date,
    player_level,
    session_count,
    playtime_minutes,
    app_version
FROM player_day
-- Keep only rows inside the observation window (all rows qualify already).
WHERE activity_date BETWEEN 20260101 AND 20260430;


-- -------------------------------------------------------------
-- STEP 4: purchase_clean
-- -------------------------------------------------------------
-- Cleaned version of purchase.
-- Problems found and handled:
--   a) 228 rows have usd_amount <= 0  → EXCLUDED (refunds / data errors).
--   b) 122 purchase_id values appear twice, with different timestamps.
--      These look like the game server re-used a transaction ID.
--      We KEEP both rows (real revenue was collected) but add a
--      dup_purchase_id flag = TRUE so analysts can double-check if needed.
CREATE OR REPLACE VIEW purchase_clean AS

-- First, find which purchase_ids are duplicated.
WITH dup_ids AS (
    SELECT purchase_id
    FROM purchase
    GROUP BY purchase_id
    HAVING COUNT(*) > 1   -- any purchase_id that appears more than once
)

SELECT
    p.purchase_id,
    p.device_id,
    p.event_ts,
    p.event_ts::DATE AS event_date,       -- date portion of the timestamp
    p.pack_name,
    p.usd_amount,
    p.currency_granted,
    p.sale_flag,
    -- Flag rows whose purchase_id appeared more than once.
    CASE WHEN d.purchase_id IS NOT NULL THEN TRUE ELSE FALSE END AS dup_purchase_id
FROM purchase p
LEFT JOIN dup_ids d ON p.purchase_id = d.purchase_id
-- Exclude rows where usd_amount is zero or negative (refunds / errors).
WHERE p.usd_amount > 0;


-- -------------------------------------------------------------
-- STEP 5: ad_clean
-- -------------------------------------------------------------
-- Cleaned version of ad_view.
-- Changes made:
--   • 7,732 rows with event_ts on 2026-05-01 are excluded (outside window).
--   • Only "completed" ad views are kept (player watched the full ad and
--     received the reward). Partial / failed views are dropped.
CREATE OR REPLACE VIEW ad_clean AS
SELECT
    device_id,
    event_ts,
    event_ts::DATE AS event_date,
    status,
    placement,
    reward_type,
    reward_amount,     -- IN-GAME currency only; this is NOT real money.
    ad_daily_count,
    ad_daily_cap
FROM ad_view
-- Only keep events inside the observation window.
WHERE event_ts::DATE BETWEEN CAST('2026-01-01' AS DATE)
                         AND CAST('2026-04-30' AS DATE)
-- Only keep ads the player actually completed (watched to the end).
  AND status = 'completed';


-- -------------------------------------------------------------
-- STEP 6: currency_spend_clean
-- -------------------------------------------------------------
-- currency_spend has no data-quality issues found in the audit.
-- This view just adds a date column for convenience.
CREATE OR REPLACE VIEW currency_spend_clean AS
SELECT
    device_id,
    event_ts,
    event_ts::DATE AS event_date,
    spend_type,
    currency_type,
    currency_value,
    spend_category,
    player_level,
    premium_balance,
    social_balance,
    grind_balance
FROM currency_spend
WHERE event_ts::DATE BETWEEN CAST('2026-01-01' AS DATE)
                         AND CAST('2026-04-30' AS DATE);
