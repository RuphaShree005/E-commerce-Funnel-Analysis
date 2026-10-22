CREATE DATABASE IF NOT EXISTS ecommerce_demo;
USE ecommerce_demo;
CREATE TABLE IF NOT EXISTS events (
    event_timestamp VARCHAR(40),
    event_name VARCHAR(40),
    user_id VARCHAR(64),
    session_id VARCHAR(64),
    device_category VARCHAR(32),
    source VARCHAR(128),
    medium VARCHAR(128),
    campaign VARCHAR(128),
    product_category VARCHAR(64),
    transaction_id VARCHAR(64),
    event_value VARCHAR(32)
);
USE ecommerce_demo;
DROP TABLE IF EXISTS funnel_analysis;
CREATE TABLE funnel_analysis AS
WITH
params AS (
    SELECT
        CAST('2026-07-01' AS DATE) AS start_date,
        CAST('2026-09-28' AS DATE) AS end_date
),
source_events AS (
    SELECT
        STR_TO_DATE(
            REPLACE(event_timestamp, '+00:00', ''),
            '%Y-%m-%d %H:%i:%s'
        ) AS event_ts,
        event_name,
        NULLIF(TRIM(user_id), '') AS user_id,
        NULLIF(TRIM(session_id), '') AS session_id,
        COALESCE(NULLIF(TRIM(device_category), ''), 'unknown') AS device_category,
        COALESCE(NULLIF(TRIM(source), ''), '(not set)') AS source,
        COALESCE(NULLIF(TRIM(medium), ''), '(not set)') AS medium,
        COALESCE(NULLIF(TRIM(campaign), ''), '(not set)') AS campaign,
        NULLIF(TRIM(transaction_id), '') AS transaction_id,
        CAST(NULLIF(TRIM(event_value), '') AS DECIMAL(12,2)) AS event_value
    FROM sample_events
    WHERE event_name IN (
        'view_item',
        'add_to_cart',
        'begin_checkout',
        'purchase'
    )
),
valid_events AS (
    SELECT *
    FROM source_events
    WHERE user_id IS NOT NULL
      AND session_id IS NOT NULL
      AND event_ts IS NOT NULL
),
first_touch AS (
    SELECT
        session_id,
        device_category,
        source,
        medium,
        campaign
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY session_id
                ORDER BY event_ts
            ) AS event_rank
        FROM valid_events
    ) ranked
    WHERE event_rank = 1
),
session_steps AS (
    SELECT
        session_id,
        MIN(user_id) AS user_id,
        MIN(event_ts) AS session_started_at,
        MIN(CASE WHEN event_name = 'view_item' THEN event_ts END) AS view_ts,
        MIN(CASE WHEN event_name = 'add_to_cart' THEN event_ts END) AS cart_ts,
        MIN(CASE WHEN event_name = 'begin_checkout' THEN event_ts END) AS checkout_ts,
        MIN(CASE WHEN event_name = 'purchase' THEN event_ts END) AS purchase_ts
    FROM valid_events
    GROUP BY session_id
),
session_flags AS (
    SELECT
        s.session_id,
        s.user_id,
        DATE(s.session_started_at) AS session_date,
        f.device_category,
        f.source,
        f.medium,
        f.campaign,
        CASE
            WHEN s.view_ts IS NOT NULL THEN 1
            ELSE 0
        END AS reached_view,
        CASE
            WHEN s.view_ts IS NOT NULL
             AND s.cart_ts >= s.view_ts THEN 1
            ELSE 0
        END AS reached_cart,
        CASE
            WHEN s.view_ts IS NOT NULL
             AND s.cart_ts >= s.view_ts
             AND s.checkout_ts >= s.cart_ts THEN 1
            ELSE 0
        END AS reached_checkout,
        CASE
            WHEN s.view_ts IS NOT NULL
             AND s.cart_ts >= s.view_ts
             AND s.checkout_ts >= s.cart_ts
             AND s.purchase_ts >= s.checkout_ts THEN 1
            ELSE 0
        END AS reached_purchase
    FROM session_steps s
    JOIN first_touch f
        ON f.session_id = s.session_id
),
ranked_transactions AS (
    SELECT
        session_id,
        transaction_id,
        event_value,
        ROW_NUMBER() OVER (
            PARTITION BY session_id, transaction_id
            ORDER BY event_ts
        ) AS transaction_rank
    FROM valid_events
    WHERE event_name = 'purchase'
      AND transaction_id IS NOT NULL
),
session_revenue AS (
    SELECT
        session_id,
        SUM(COALESCE(event_value, 0)) AS revenue_usd
    FROM ranked_transactions
    WHERE transaction_rank = 1
    GROUP BY session_id
),
session_base AS (
    SELECT
        f.*,
        COALESCE(r.revenue_usd, 0) AS revenue_usd,
        DATE_FORMAT(f.session_date, '%x-W%v') AS week_label
    FROM session_flags f
    CROSS JOIN params p
    LEFT JOIN session_revenue r
        ON r.session_id = f.session_id
    WHERE f.session_date BETWEEN p.start_date AND p.end_date
),
session_views AS (
    SELECT
        'Overall' AS view_name,
        'All sessions' AS dimension_value,
        session_id, user_id, session_date, device_category, source, medium,
        campaign, reached_view, reached_cart, reached_checkout,
        reached_purchase, week_label, revenue_usd
    FROM session_base

    UNION ALL

    SELECT
        'Device', device_category,
        session_id, user_id, session_date, device_category, source, medium,
        campaign, reached_view, reached_cart, reached_checkout,
        reached_purchase, week_label, revenue_usd
    FROM session_base

    UNION ALL

    SELECT
        'Channel', CONCAT(source, ' / ', medium),
        session_id, user_id, session_date, device_category, source, medium,
        campaign, reached_view, reached_cart, reached_checkout,
        reached_purchase, week_label, revenue_usd
    FROM session_base

    UNION ALL

    SELECT
        'Week', week_label,
        session_id, user_id, session_date, device_category, source, medium,
        campaign, reached_view, reached_cart, reached_checkout,
        reached_purchase, week_label, revenue_usd
    FROM session_base
),
step_counts AS (
    SELECT
        view_name,
        dimension_value,
        SUM(reached_view) AS view_sessions,
        SUM(reached_cart) AS cart_sessions,
        SUM(reached_checkout) AS checkout_sessions,
        SUM(reached_purchase) AS purchase_sessions,
        SUM(
            CASE
                WHEN reached_purchase = 1 THEN revenue_usd
                ELSE 0
            END
        ) AS purchase_revenue_usd
    FROM session_views
    GROUP BY view_name, dimension_value
),
long_funnel AS (
    SELECT
        view_name, dimension_value,
        1 AS step_order,
        'Product view' AS step_name,
        view_sessions AS step_sessions,
        CAST(0 AS DECIMAL(14,2)) AS purchase_revenue_usd
    FROM step_counts

    UNION ALL

    SELECT
        view_name, dimension_value,
        2, 'Add to cart', cart_sessions,
        CAST(0 AS DECIMAL(14,2))
    FROM step_counts

    UNION ALL

    SELECT
        view_name, dimension_value,
        3, 'Begin checkout', checkout_sessions,
        CAST(0 AS DECIMAL(14,2))
    FROM step_counts

    UNION ALL

    SELECT
        view_name, dimension_value,
        4, 'Purchase', purchase_sessions,
        purchase_revenue_usd
    FROM step_counts
),
with_rates AS (
    SELECT
        *,
        LAG(step_sessions) OVER (
            PARTITION BY view_name, dimension_value
            ORDER BY step_order
        ) AS previous_step_sessions,
        MAX(
            CASE WHEN step_order = 1 THEN step_sessions END
        ) OVER (
            PARTITION BY view_name, dimension_value
        ) AS view_entry_sessions
    FROM long_funnel
)
SELECT
    (SELECT start_date FROM params) AS report_start_date,
    (SELECT end_date FROM params) AS report_end_date,
    view_name,
    dimension_value,
    step_order,
    step_name,
    step_sessions,
    previous_step_sessions,
    CASE
        WHEN previous_step_sessions > 0
        THEN step_sessions / previous_step_sessions
    END AS conversion_from_previous,
    CASE
        WHEN previous_step_sessions > 0
        THEN 1 - step_sessions / previous_step_sessions
    END AS dropoff_from_previous,
    view_entry_sessions,
    CASE
        WHEN view_entry_sessions > 0
        THEN step_sessions / view_entry_sessions
    END AS overall_conversion_from_view,
    CASE
        WHEN step_order = 4 THEN purchase_revenue_usd
    END AS purchase_revenue_usd
FROM with_rates;
SELECT
    step_order,
    step_name,
    step_sessions,
    conversion_from_previous,
    dropoff_from_previous,
    overall_conversion_from_view
FROM ecommerce_demo.funnel_analysis
WHERE view_name = 'Overall'
ORDER BY step_order;
SELECT *
FROM ecommerce_demo.funnel_analysis
ORDER BY
    CASE view_name
        WHEN 'Overall' THEN 1
        WHEN 'Device' THEN 2
        WHEN 'Channel' THEN 3
        ELSE 4
    END,
    dimension_value,
    step_order;