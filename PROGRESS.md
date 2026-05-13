# Superstore Analysis — Progress Log

## Setup
- **DB:** PostgreSQL (locally), VS Code підключений
- **Dataset:** US + Canada Superstore (не EU, попри назву папки)
  - 10,194 line items (9,994 US + 200 Canada)
  - Date range: 2023-01-03 → 2026-12-30 (4 роки)
- **Tables in DB:** `orders`, `orders_raw`, `people`, `returns`
- **CSV copies for verification:** `orders.csv`, `people.csv`, `returns.csv` в папці проєкту

## Workflow методологія: CARA
- **C**ontext — перевіряємо схему перед запитом
- **A**sk — уточнюємо бізнес-логіку
- **R**eview — пояснюємо кожен блок запиту
- **A**ssert — даємо spot-check для перевірки

## Завершені етапи

### ✅ Data Cleaning
- Schema verified для `orders`, `people`, `returns`
- Виявлено та виправлено: дані в `returns` ↔ `people` помінялися місцями під час імпорту → виконано SQL swap
- Orders: 0 NULLs, 0 duplicates, 0 negative sales, 0 invalid discounts, 0 ship_date < order_date

### ✅ Етап 1 — Business Overview

**Master KPI:**
- Total Sales: **$2,326,534**
- Total Profit: **$292,297**
- Profit Margin: **12.56%**
- Total Orders (unique): **5,111**
- Unique Customers: **804**
- Unique Products: **1,862**
- AOV: **$455.20**
- Avg Discount: **15.54%**

**Returns Impact:**
- Returned sales: $180,504 (**7.76%** від revenue) ⚠️ високо
- Returned orders: 296

**Key insights:**
- ~6.4 замовлення на клієнта → strong repeat business
- Returns 7.76% — вище industry benchmark (3-5%)
- Avg discount 15.54% — потенційно тисне на маржу
- Canada — лише 1.26% бізнесу

### ✅ Етап 2 — Breakdown за вимірами

**2.1 Category / Sub-Category:**
- Technology: 50% profit на 36% sales (margin 17.45%) — золота категорія
- Furniture: 32% sales але лише 7% profit (margin **2.61%**) — стратегічна проблема
- TOXIC sub-categories: **Tables** (-$17,753, disc 25.81%), **Bookcases** (-$3,632), **Supplies** (-$1,171)
- LOW_MARGIN: Machines (1.82% margin, **30.43% discount**)
- Топ-маржа: Copiers (37.21%), Labels/Paper (43%), Envelopes (42%)

**2.2 Region / State:**
- US Central — найгірший регіон (margin 7.92%, disc 24%)
- US West — топ (margin 14.94%, найбільший об'єм)
- Canada East — найвища маржа в датасеті (25.76%), але мікрооб'єм
- **10 збиткових штатів**, усі мають avg discount **28-39%**
- Worst offenders: Texas (-$25,729 / 37% disc), Ohio (-$16,971), Pennsylvania (-$15,560)
- Top healthy: California, New York, Washington (всі disc ≤ 7%)

**2.3 Segment:**
- Consumer: 50% sales / 47% profit / 416 customers — найбільший, найнижча маржа (11.65%)
- Corporate: 31% sales, 13.17% margin — стабільний
- Home Office: 19% sales, **найвища маржа 14.02%**, найвищий AOV ($472.68) — недооцінений MVP
- Orders/customer ≈ 6.3 у всіх трьох → сегмент НЕ драйвер repeat behavior
- Return rate однаковий (5.26-5.99%) → сегмент НЕ драйвер повернень

**2.4 Cross-tab Category × Region:**
- Єдина TOXIC клітинка: **Furniture × Central** (-$2,871, margin -1.75%)
- Worst sub-combo: **East × Tables** (-$11,025, margin -28.17%, disc 37.37%)
- Central × Binders: discount **50.93%** — найвища в датасеті
- Tables токсичні в 3 з 4 регіонів (тільки West не страждає)
- Machines (Technology) збиткові в 3 регіонах — системна проблема продукту, не географії

**Головний інсайт Етапу 2:** discount > 25-30% = майже гарантовано збитки. Це найсильніший single predictor токсичності в даних.

### ✅ Етап 3 — Time Series (SQL виконано, інкорпоровано у Tableau)
- Monthly trend за 4 роки → Tableau sheet `Monthly_Sales_&_Profit_Trend`
- **2024 — "smart retreat":** sales -7.5% YoY, але profit +14.4% (компанія здисциплінувала discounts)
- 2025-2026 розгін, **November 2026 = $103K** (пік)
- Seasonality: Q4 завжди найсильніший
- YoY: 2023→2024 (-7.5%), 2024→2025 (+~30%), 2025→2026 (+~25%)

### ✅ Етап 4 — Customer Analytics (через pandas → `customer_summary.csv`)
- Файл `customer_summary.csv` створено (804 × 23 колонки)
- Pre-computed: RFM scores, segments, CLV, cohort_year, value_quadrant
- VIEW `v_customer_rfm` створено у PostgreSQL для reusability
- RFM розподіл (804 customers):
  - Need Attention: 248
  - Lost/Hibernating: 120
  - Champions: 108
  - Loyal Customers: 96
  - Potential Loyalists: 72
  - New Customers: 58
  - Cant Lose Them: 55
  - At Risk: 47

## ✅ Tableau Dashboards (in progress)

### Dashboard 1: Executive Overview — ✅ ЗІБРАНО
**8 sheets:**
1. KPI_TotalSales ($2.33M)
2. KPI_TotalProfit ($292.30K)
3. KPI_ProfitMargin (12.56%)
4. KPI_Customers (804)
5. Monthly_Sales_&_Profit_Trend (dual axis Sales+Profit)
6. Sales_by_Category (3 horizontal bars, Furniture в red)
7. Profit_by_SubCategory (17 sub-categories, diverging red-green)
8. Profit_by_State (filled US map, Texas dark red, California dark green)

**Layout:** Vertical container → Title + Horizontal(4 KPI) + Trend + Horizontal(Map | Vertical(Category + SubCat))
**Розмір:** 1366 × 800 fixed
**Status:** ✅ Готовий, збережено локально як `.twb`

### Dashboard 2: Customer Intelligence — 2 з 4 sheets готово
**Data source:** `customer_summary.csv` підключено як 2-й data source

**Sheets:**
1. ✅ **RFM_Segments** — horizontal bar, 8 сегментів, color-coded
2. ✅ **Top10_Customers** — horizontal bar, sorted by Total Sales DESC, color by Profit Margin (Center=0.10)
   - Top 10 концентрують $153,811 = 6.6% revenue з 1.2% customer base
   - **Sean Miller #1** ($25K sales, -7.91% margin) — storytelling killer insight
   - **Ken Lonsdale #6** ($14K sales, 5.69% margin) — secondary warning
   - **Tamara Chand #2** ($19K, 47% margin) — healthy "big spender" baseline
3. 🔜 **Customer_Value_Quadrant** — scatter (Recency × Monetary, color=Frequency)
4. 🔜 **CLV_Deciles** — Pareto bar (10 деци, % revenue per decile)

## 🔜 Наступний крок (наступна сесія)

**Dashboard 2 завершення (~1.5 години):**
1. Sheet 3: Value Quadrant scatter — Recency (X) × Monetary (Y), color = Frequency
2. Sheet 4: CLV Deciles Pareto — 10 деци, висота = avg CLV, label = % cumulative revenue
3. Зібрати Dashboard 2 (2×2 grid layout: RFM | Top10 // Quadrant | Deciles)

**Далі (deadline 15.05.2026):**
- [ ] GitHub repo + README з insights
- [ ] Опублікувати на Tableau Public
- [ ] Записати video selfie (5 хв, 3 питання)
- [ ] Submit form до SKELAR

## Roadmap (deferred — після дедлайну)
- Етап 5: Product Analysis SQL deep-dive
- Етап 6: Advanced cohort retention matrix у SQL
- Етап 7: NDR / Net Dollar Retention обрахунок
