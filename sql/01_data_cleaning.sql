-- ============================================================
-- 01_data_cleaning.sql
-- Purpose: Schema definition, data import, integrity checks
-- ============================================================

-- Drop existing tables (for clean re-runs)
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS returns CASCADE;
DROP TABLE IF EXISTS people CASCADE;

-- 1. Orders table — 10,194 line items, 21 columns
CREATE TABLE orders (
    row_id          INT PRIMARY KEY,
    order_id        TEXT,
    order_date      DATE,
    ship_date       DATE,
    ship_mode       TEXT,
    customer_id     TEXT,
    customer_name   TEXT,
    segment         TEXT,
    country_region  TEXT,
    city            TEXT,
    state_province  TEXT,
    postal_code     TEXT,
    region          TEXT,
    product_id      TEXT,
    category        TEXT,
    sub_category    TEXT,
    product_name    TEXT,
    sales           NUMERIC(10, 2),
    quantity        INT,
    discount        NUMERIC(4, 2),
    profit          NUMERIC(10, 2)
);

-- 2. Returns table — 296 returned orders
CREATE TABLE returns (
    returned    TEXT,
    order_id    TEXT,
    region      TEXT
);

-- 3. People — regional managers
CREATE TABLE people (
    regional_manager TEXT,
    region           TEXT
);

-- Import data (adjust path)
\copy orders FROM 'data/orders.csv' WITH (FORMAT csv, HEADER true);
\copy returns FROM 'data/returns.csv' WITH (FORMAT csv, HEADER true);
\copy people FROM 'data/people.csv' WITH (FORMAT csv, HEADER true);

-- ============================================================
-- INTEGRITY CHECKS (Assert step in CARA)
-- ============================================================

-- Check 1: Row counts
SELECT 'orders'  AS table_name, COUNT(*) FROM orders
UNION ALL
SELECT 'returns', COUNT(*) FROM returns
UNION ALL
SELECT 'people',  COUNT(*) FROM people;
-- Expected: orders 10194, returns 296, people 5

-- Check 2: NULL values in critical columns
SELECT
    SUM(CASE WHEN order_id      IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN customer_id   IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN sales         IS NULL THEN 1 ELSE 0 END) AS null_sales,
    SUM(CASE WHEN profit        IS NULL THEN 1 ELSE 0 END) AS null_profit,
    SUM(CASE WHEN order_date    IS NULL THEN 1 ELSE 0 END) AS null_order_date
FROM orders;
-- Expected: 0 across the board

-- Check 3: Duplicate row_id
SELECT row_id, COUNT(*)
FROM orders
GROUP BY row_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- Check 4: Negative sales (impossible — but check)
SELECT COUNT(*) FROM orders WHERE sales < 0;
-- Expected: 0

-- Check 5: Invalid discount (must be between 0 and 1)
SELECT COUNT(*) FROM orders WHERE discount < 0 OR discount > 1;
-- Expected: 0

-- Check 6: ship_date < order_date (logical error)
SELECT COUNT(*) FROM orders WHERE ship_date < order_date;
-- Expected: 0

-- Check 7: Date range
SELECT MIN(order_date) AS min_date, MAX(order_date) AS max_date FROM orders;
-- Expected: 2023-01-03 to 2026-12-30
