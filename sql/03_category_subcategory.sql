-- ============================================================
-- 03_category_subcategory.sql
-- Purpose: Profit & margin breakdown by Category and Sub-Category
-- Key finding: Furniture is a low-margin trap; 3 sub-categories burn $22K
-- ============================================================

-- 3.1 — Category breakdown
SELECT
    category,
    ROUND(SUM(sales)::numeric, 0)                                AS sales,
    ROUND(SUM(profit)::numeric, 0)                               AS profit,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(sales), 0), 2)        AS margin_pct,
    ROUND(100.0 * SUM(sales) /
        (SELECT SUM(sales) FROM orders), 2)                      AS pct_of_sales,
    ROUND(100.0 * SUM(profit) /
        (SELECT SUM(profit) FROM orders), 2)                     AS pct_of_profit,
    ROUND(100.0 * AVG(discount)::numeric, 2)                     AS avg_discount_pct
FROM orders
GROUP BY category
ORDER BY profit DESC;
-- Expected:
-- Technology: 36% sales / 50% profit / 17.45% margin
-- Office Supplies: 32% sales / 43% profit / 17.0% margin
-- Furniture: 32% sales / 7% profit / 2.61% margin ← strategic problem

-- 3.2 — Sub-Category breakdown with TOXIC flag
SELECT
    category,
    sub_category,
    ROUND(SUM(sales)::numeric, 0)                                AS sales,
    ROUND(SUM(profit)::numeric, 0)                               AS profit,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(sales), 0), 2)        AS margin_pct,
    ROUND(100.0 * AVG(discount)::numeric, 2)                     AS avg_discount_pct,
    CASE
        WHEN SUM(profit) < 0                                  THEN 'TOXIC'
        WHEN 100.0 * SUM(profit) / NULLIF(SUM(sales), 0) < 5  THEN 'LOW_MARGIN'
        WHEN 100.0 * SUM(profit) / NULLIF(SUM(sales), 0) > 30 THEN 'STAR'
        ELSE 'HEALTHY'
    END AS flag
FROM orders
GROUP BY category, sub_category
ORDER BY profit ASC;
-- Expected TOXIC: Tables (-$17,753), Bookcases (-$3,632), Supplies (-$1,171)
-- Expected LOW_MARGIN: Machines (1.82% margin, 30.43% discount)
-- Expected STAR: Copiers (37.21%), Labels (43%), Envelopes (42%), Paper (43%)
