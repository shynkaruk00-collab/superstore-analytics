-- ============================================================
-- 02_business_overview.sql
-- Purpose: Master KPIs at company level
-- ============================================================

-- Master KPI snapshot
SELECT
    ROUND(SUM(sales)::numeric, 0)                                       AS total_sales,
    ROUND(SUM(profit)::numeric, 0)                                      AS total_profit,
    ROUND(100.0 * SUM(profit) / SUM(sales), 2)                          AS profit_margin_pct,
    COUNT(DISTINCT order_id)                                            AS total_orders,
    COUNT(DISTINCT customer_id)                                         AS unique_customers,
    COUNT(DISTINCT product_id)                                          AS unique_products,
    ROUND((SUM(sales) / COUNT(DISTINCT order_id))::numeric, 2)          AS avg_order_value,
    ROUND(100.0 * AVG(discount), 2)                                     AS avg_discount_pct
FROM orders;
-- Expected:
-- total_sales=2326534, total_profit=292297, margin=12.56%,
-- orders=5111, customers=804, products=1862, AOV=455.20, avg_disc=15.54%

-- ============================================================
-- Returns impact
-- ============================================================
SELECT
    COUNT(DISTINCT r.order_id)                                  AS returned_orders,
    ROUND(SUM(o.sales)::numeric, 0)                             AS returned_sales,
    ROUND(100.0 * SUM(o.sales) /
        (SELECT SUM(sales) FROM orders), 2)                     AS pct_of_revenue
FROM returns r
JOIN orders o USING (order_id);
-- Expected: 296 orders, $180,504 returned (7.76% of revenue) — above industry benchmark

-- ============================================================
-- Orders per customer — repeat business signal
-- ============================================================
SELECT
    ROUND(AVG(order_count), 2) AS avg_orders_per_customer,
    MIN(order_count)           AS min_orders,
    MAX(order_count)           AS max_orders
FROM (
    SELECT customer_id, COUNT(DISTINCT order_id) AS order_count
    FROM orders
    GROUP BY customer_id
) per_customer;
-- Expected: ~6.36 avg orders/customer → strong repeat behavior
