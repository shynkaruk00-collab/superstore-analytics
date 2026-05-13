# Superstore Analytics — Sales, Customers & Pareto

> End-to-end data analytics portfolio project — 4-year analysis of $2.33M in retail sales across US + Canada, built with **PostgreSQL · SQL · Python (pandas) · Tableau Public**.

**🔗 Live Dashboards:** [public.tableau.com/.../SuperstoreAnalytics](https://public.tableau.com/app/profile/oleksii.shynkaruk/viz/SuperstoreAnalyticsSalesCustomersPareto/Executive_Overview)

---

## 📊 The Business Question

A mid-size retailer with **804 customers, 1,862 products, 5,111 orders** wants to know:

- Where do we actually make money — and where do we burn it?
- Which customers drive disproportionate revenue, and who is at risk of churning?
- How does discount strategy correlate with profitability?
- How does the business evolve year-over-year?

Two dashboards answer these questions for the executive layer and the customer team respectively.

---

## 🎯 Key Insights

| # | Finding | Impact |
|---|---------|--------|
| 1 | **Top 10% of customers generate 29% of revenue** ($660K) | Concentrate retention budget here |
| 2 | **3 sub-categories destroy $22K profit** — Tables (-$17.8K), Bookcases (-$3.6K), Supplies (-$1.2K) | Discontinue or re-price |
| 3 | **10 US states are unprofitable** — all share 28-39% average discount | Cap discounts at 25% by policy |
| 4 | **Furniture sells in volume but has 2.61% margin** vs Technology's 17.45% | Furniture is a "false win" category |
| 5 | **Sean Miller is the #1 customer by sales** ($25K) but has **-7.91% margin** | Revenue ≠ profitability |
| 6 | **2024 was a "smart retreat"** — sales fell 7.5% YoY but profit grew 14.4% | Discipline on discounts paid off |
| 7 | **Discount > 25-30% = near-guaranteed losses** (single strongest predictor in the data) | Headline policy lever |

---

## 🛠 Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Database | **PostgreSQL** | Data warehouse, query engine |
| Query Language | **SQL** (CTE, window functions, NTILE, percentile) | Data cleaning, KPIs, RFM, cohorts |
| Processing | **Python · pandas** | RFM scoring, CLV calculation, CSV export |
| Visualization | **Tableau Public** | Interactive dashboards |
| Version Control | **Git · GitHub** | This repository |

---

## 🗂 Repository Structure

```
.
├── README.md                  ← you are here
├── PROGRESS.md                ← chronological work log
├── data/
│   ├── orders.csv             ← 10,194 line items, 21 columns
│   ├── people.csv             ← regional managers
│   ├── returns.csv            ← 296 returned orders
│   └── customer_summary.csv   ← pre-aggregated per-customer metrics (RFM, CLV)
└── sql/
    ├── 01_data_cleaning.sql           ← schema + 7 integrity checks
    ├── 02_business_overview.sql       ← master KPI snapshot
    ├── 03_category_subcategory.sql    ← profit & margin by category / sub-category
    └── 04_region_state.sql            ← geographic deep-dive (US states + cross-tabs)
```

> RFM, CLV and Pareto logic shown in the **SQL Highlights** section below were used directly in PostgreSQL / Tableau and are documented inline here rather than as separate files.

---

## 🎨 Dashboards

Both dashboards are **published live on Tableau Public** — interactive filters, tooltips, drill-downs.

### Dashboard 1 — Executive Overview

🔗 **[Open live dashboard →](https://public.tableau.com/app/profile/oleksii.shynkaruk/viz/SuperstoreAnalyticsSalesCustomersPareto/Executive_Overview)**

**Audience:** CEO / COO  
**Reading order (Z-pattern):** KPIs → Trend → Where (map) → What (categories)

- 4 master KPIs ($2.33M sales, $292K profit, 12.56% margin, 804 customers)
- Monthly sales + profit trend (dual axis, 4 years)
- US state filled map colored by Profit
- Sales by Category & Profit by Sub-Category (diverging red-green)

### Dashboard 2 — Customer Intelligence

🔗 **[Open live dashboard →](https://public.tableau.com/app/profile/oleksii.shynkaruk/viz/SuperstoreAnalyticsSalesCustomersPareto/Customer_Intelligence)**

**Audience:** Marketing / CRM team  
**Reading order:** Segments → Top spenders → Quadrant → Pareto

- RFM segmentation (8 segments, color-coded by lifetime value)
- Top 10 customers by sales, colored by profit margin (catches the Sean Miller paradox)
- Customer Value Quadrant scatter (Recency × Monetary × Frequency for 804 customers)
- Revenue concentration by CLV decile (Pareto chart)

---

## 🧪 SQL Highlights

### RFM Segmentation (Window Functions + NTILE)

```sql
CREATE OR REPLACE VIEW v_customer_rfm AS
WITH ref_date AS (
    SELECT MAX(order_date) AS max_date FROM orders
),
rfm_base AS (
    SELECT
        customer_id,
        customer_name,
        segment,
        ((SELECT max_date FROM ref_date) - MAX(order_date))::int AS recency_days,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(sales)              AS monetary,
        SUM(profit)             AS total_profit
    FROM orders
    GROUP BY customer_id, customer_name, segment
),
rfm_scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- recent = 5
        NTILE(5) OVER (ORDER BY frequency   ASC)  AS f_score,  -- high freq = 5
        NTILE(5) OVER (ORDER BY monetary    ASC)  AS m_score   -- high $ = 5
    FROM rfm_base
)
SELECT *,
    (r_score * 100 + f_score * 10 + m_score)::text AS rfm_code,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'New Customers'
        WHEN r_score >= 3 AND f_score >= 2 AND m_score <= 2 THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
        WHEN r_score <= 1                                   THEN 'Lost / Hibernating'
        ELSE 'Need Attention'
    END AS rfm_segment
FROM rfm_scored;
```

**Why this matters:** NTILE direction matters. Recency is "lower = better" (more recent), so we sort `DESC` to give recent customers a high score. Frequency and Monetary are "higher = better," so we sort `ASC` so that the top quintile gets score 5.

### Pareto / 80-20 Revenue Concentration

```sql
WITH customer_clv AS (
    SELECT
        customer_id,
        SUM(sales)  AS lifetime_sales,
        NTILE(10) OVER (ORDER BY SUM(sales) DESC) AS clv_decile
    FROM orders
    GROUP BY customer_id
)
SELECT
    clv_decile,
    COUNT(*)                                          AS customers,
    ROUND(SUM(lifetime_sales)::numeric, 0)            AS revenue,
    ROUND(100.0 * SUM(lifetime_sales) /
                  SUM(SUM(lifetime_sales)) OVER (), 2) AS pct_of_revenue
FROM customer_clv
GROUP BY clv_decile
ORDER BY clv_decile;
```

**Result:** Top decile = 28.4% of revenue. Top 5 deciles = 78%. Classic Pareto.

### Toxic Sub-Categories — Cross-Tab Discovery

```sql
SELECT
    region,
    sub_category,
    ROUND(SUM(profit)::numeric, 0)                                 AS profit,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(sales), 0), 2)          AS margin_pct,
    ROUND(100.0 * AVG(discount)::numeric, 2)                       AS avg_discount_pct
FROM orders
WHERE region IS NOT NULL
GROUP BY region, sub_category
HAVING SUM(profit) < 0
ORDER BY profit ASC;
```

**Why it matters:** Surfaces *intersections* — e.g., East × Tables loses $11K with 37% avg discount. This is more actionable than category-level aggregates.

---

## 🚀 Reproduce Locally

```bash
# 1. Clone
git clone https://github.com/oleksii-shynkaruk/superstore-analytics.git
cd superstore-analytics

# 2. Create database and load schema + CSVs
psql -d postgres -c "CREATE DATABASE superstore;"
psql -d superstore < sql/01_data_cleaning.sql

# 3. Run analysis queries in order
for f in sql/0*.sql; do psql -d superstore -f "$f"; done

# 4. View dashboards
# Open the live versions on Tableau Public (links above)
```

---

## 👤 About

Built by **Oleksii Shynkaruk** as a portfolio project — applying for Junior Data Analyst / BI roles.

- 📧 [shynkaruk00@gmail.com](mailto:shynkaruk00@gmail.com)
- 🔗 [Live Tableau Profile](https://public.tableau.com/app/profile/oleksii.shynkaruk/vizzes)

---

## 📦 Dataset

**Source:** [Tableau Public — Sample Data (Superstore)](https://public.tableau.com/app/learn/sample-data)

Publicly available sample dataset provided by Tableau for learning and portfolio purposes. Covers US + Canada retail transactions across 4 years (2023–2026), 10,194 line items, 21 columns. All sales / profit / customer figures in this project come from this dataset.

No proprietary or personally identifiable information is used — the dataset is fully open for educational and portfolio purposes.
