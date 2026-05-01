# Retail Transaction Analysis — Polish Supermarket
 
**Tools:** MySQL · SQL   
**Data Source:** [MDPI Open Dataset — Point-of-Sale Transactions](https://www.mdpi.com/2306-5729/4/2/67/htm)  
**Type:** Exploratory & Operational Analysis
 
---
 
## Business Problem
 
A supermarket chain in Poland has thousands of checkout transactions happening every week — but no one is using that data to make decisions. Staff are scheduled by intuition, payment infrastructure decisions are made without evidence, and the store stays open on Sundays despite a 2018 government trading ban — without knowing if it's actually worth the cost.
 
This project uses SQL to answer four real operational questions:
 
- Do customers spend more when paying by card or cash?
- Which days of the week generate the most revenue and transactions?
- Does opening on Sundays actually generate additional revenue?
- How much does Sunday labor cost — and is it justified?
---
 
## Dataset
 
| Table | Description |
|---|---|
| `pos_transactions` | ~10,000 rows of checkout transactions including amount, basket size, payment method, and timestamps |
| `pos_operator_logs` | Staff shift logs with operator ID and shift start times |
 
Data sourced from a peer-reviewed research paper published in the MDPI Data journal. This is real-world point-of-sale data — not a synthetic or toy dataset.
 
---
 
## Analysis & Key Findings
 
### 1. Payment behavior — card vs cash
 
Card-only transactions averaged a higher spend per transaction than cash-only transactions. This has direct implications for payment infrastructure investment and security arrangements at checkout.
 
```sql
SELECT
  AVG(CASE WHEN t_cash AND NOT t_card THEN amount END) AS avg_cash,
  AVG(CASE WHEN t_card AND NOT t_cash THEN amount END) AS avg_card
FROM pos_transactions;
```
 
---
 
### 2. Daily and weekly sales trends
 
Thursday, Friday, and Saturday are consistently the busiest days — generating approximately 25% more transactions and 40% more revenue than Monday, Tuesday, and Wednesday.
 
```sql
SELECT
  WEEK(end_date_time) AS week_num,
  DATE(end_date_time) AS end_date,
  COUNT(id) AS total_transactions,
  SUM(amount) AS total_sales,
  AVG(amount) AS avg_sale_amount,
  AVG(basket_size) AS avg_basket_size
FROM pos_transactions
WHERE YEAR(end_date_time) >= 2019
GROUP BY end_date
ORDER BY week_num;
```
 
**Insight:** Staff scheduling should be heavily weighted toward Thu–Sat. Scheduling the same headcount across all 7 days is inefficient.
 
---
 
### 3. Sunday trading — is it worth it?
 
Poland introduced a Sunday trading ban in 2018, gradually restricting which Sundays stores could open. The dataset includes two working Sundays (24 Feb, 31 Mar) and two non-working Sundays (17 Feb, 7 Apr).
 
Comparing Week 8 (with Sunday trading) vs Week 14 (without Sunday trading):
 
| Week | Sunday Open? | Total Revenue |
|---|---|---|
| Week 8 | Yes | PLN 1.7M |
| Week 14 | No | PLN 1.7M |
 
**Both weeks generated identical revenue.** Customers simply shifted their Sunday shopping to the preceding Saturday. The store lost zero revenue by closing.
 
```sql
SELECT
  WEEK(end_date_time) AS week_num,
  SUM(amount) AS total_revenue
FROM pos_transactions
WHERE YEAR(end_date_time) >= 2019
  AND WEEK(end_date_time) IN (8, 14)
GROUP BY week_num;
```
 
---
 
### 4. Sunday labor cost quantification
 
On each working Sunday, between 18 and 20 operators were on shift — a full day of staffing cost with no incremental revenue benefit.
 
```sql
SELECT
  DATE(begin_date_time) AS working_day,
  COUNT(DISTINCT operator_id) AS operators_on_shift,
  WEEK(begin_date_time) AS week_num
FROM pos_operator_logs
WHERE YEAR(begin_date_time) >= 2019
GROUP BY working_day;
```
 
---
 
## Business Recommendation
 
**Close on Sundays.**
 
The data shows no revenue loss from Sunday closures — customers redistribute their spend to Saturday. Closing on Sundays eliminates one full day of operating costs including 18–20 staff shifts, energy costs, and checkout system overhead.
 
The savings from a single Sunday closure can be estimated as:
 
> ~19 staff × 8 hours × hourly rate = direct labor saving per Sunday
 
Multiply across 52 Sundays per year — the annual saving is significant with zero revenue impact.
 
---
 
## SQL Skills Demonstrated
 
- Conditional aggregations with `CASE WHEN`
- Window functions — `ROW_NUMBER()`, `COUNT() OVER()`, `NTILE()`
- Date functions — `WEEK()`, `YEAR()`, `DATE()`
- Custom median calculation (MySQL workaround for missing `PERCENTILE_CONT`)
- CTEs and subqueries
- `GROUP BY` with multi-column aggregations
- Joining operator logs with transaction data
---
 
## Repository Structure
 
```
├── README.md               — This file
├── queries.sql             — All analysis queries with comments
├── findings.md             — Summary of insights and recommendations
├── data/
│   ├── pos_transactions.csv
│   └── pos_operator_logs.csv
```
 
---
 
## How to Run
 
1. Load both CSV files into MySQL using `LOAD DATA INFILE` or MySQL Workbench Import Wizard
2. Run `queries.sql` in order — each query is labelled by task
3. Refer to `findings.md` for interpretation of results
---
 
## Data Source
 
Rykaczewski, M. (2019). *Point-of-Sale Transaction Dataset from a Polish Supermarket.* MDPI Data, 4(2), 67.  
[https://www.mdpi.com/2306-5729/4/2/67/htm](https://www.mdpi.com/2306-5729/4/2/67/htm)
 
