-- ============================================================
-- 04_region_state.sql
-- Purpose: Geographic profit analysis
-- Key finding: 10 unprofitable states all share 28-39% avg discount
-- ============================================================

-- 4.1 — Regional breakdown
SELECT
    country_region,
    region,
    ROUND(SUM(sales)::numeric, 0)                                AS sales,
    ROUND(SUM(profit)::numeric, 0)                               AS profit,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(sales), 0), 2)        AS margin_pct,
    ROUND(100.0 * AVG(discount)::numeric, 2)                     AS avg_discount_pct,
    COUNT(DISTINCT order_id)                                     AS orders
FROM orders
GROUP BY country_region, region
ORDER BY profit DESC;
-- Expected:
-- US West: best volume (margin 14.94%)
-- US Central: worst (margin 7.92%, 24% discount)
-- Canada East: best margin 25.76% but tiny volume

-- 4.2 — State-level deep dive with HEALTH flag
SELECT
    state_province,
    region,
    ROUND(SUM(sales)::numeric, 0)                                AS sales,
    ROUND(SUM(profit)::numeric, 0)                               AS profit,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(sales), 0), 2)        AS margin_pct,
    ROUND(100.0 * AVG(discount)::numeric, 2)                     AS avg_discount_pct,
    CASE
        WHEN SUM(profit) < 0 THEN 'BLEEDING'
        WHEN 100.0 * AVG(discount) > 25 THEN 'OVER_DISCOUNTING'
        WHEN 100.0 * SUM(profit) / NULLIF(SUM(sales), 0) > 20 THEN 'HEALTHY_PREMIUM'
        ELSE 'HEALTHY'
    END AS state_health
FROM orders
WHERE country_region = 'United States'
GROUP BY state_province, region
ORDER BY profit ASC;
-- Expected BLEEDING (10 states): Texas (-$25,729 / 37% disc), Ohio (-$16,971),
--   Pennsylvania (-$15,560), Illinois, North Carolina, Colorado, Tennessee,
--   Arizona, Florida, Oregon — all with 28-39% avg discount
-- Expected HEALTHY: California, New York, Washington (avg discount <= 7%)

-- 4.3 — Cross-tab: Category × Region (find TOXIC intersections)
SELECT
    region,
    category,
    ROUND(SUM(profit)::numeric, 0)                                AS profit,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(sales), 0), 2)         AS margin_pct,
    ROUND(100.0 * AVG(discount)::numeric, 2)                      AS avg_discount_pct
FROM orders
WHERE region IS NOT NULL
GROUP BY region, category
ORDER BY profit ASC;
-- Expected single TOXIC cell: Furniture × Central (-$2,871, margin -1.75%)

-- 4.4 — Sub-Category × Region drill-down (where the bleeding actually happens)
SELECT
    region,
    sub_category,
    ROUND(SUM(profit)::numeric, 0)                                AS profit,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(sales), 0), 2)         AS margin_pct,
    ROUND(100.0 * AVG(discount)::numeric, 2)                      AS avg_discount_pct
FROM orders
WHERE region IS NOT NULL
GROUP BY region, sub_category
HAVING SUM(profit) < 0
ORDER BY profit ASC;
-- Expected worst: East × Tables (-$11,025, margin -28.17%, disc 37.37%)
-- Central × Binders: discount 50.93% (highest in dataset)
-- Tables toxic in 3 of 4 regions; Machines toxic in 3 regions (systemic product problem)
