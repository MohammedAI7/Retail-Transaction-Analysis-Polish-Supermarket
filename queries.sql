-- ============================================================
-- Retail Transaction Analysis — Polish Supermarket
-- Tool: MySQL
-- Data Source: MDPI Open Dataset (https://www.mdpi.com/2306-5729/4/2/67/htm)
-- ============================================================


-- ------------------------------------------------------------
-- SETUP: Create tables and load data
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pos_transactions (
    id INT,
    end_date_time DATETIME,
    amount DECIMAL(10,2),
    basket_size INT,
    t_cash BOOLEAN,
    t_card BOOLEAN
);

CREATE TABLE IF NOT EXISTS pos_operator_logs (
    operator_id INT,
    begin_date_time DATETIME
);

-- Load transactions data
LOAD DATA INFILE '/path/to/pos_transactions.csv'
INTO TABLE pos_transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Load operator logs data
LOAD DATA INFILE '/path/to/pos_operator_logs.csv'
INTO TABLE pos_operator_logs
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Add indexes to improve query performance on date and amount columns
CREATE INDEX idx_date_amount
ON pos_transactions(end_date_time, amount);

CREATE INDEX idx_date_basket
ON pos_transactions(end_date_time, basket_size);


-- ============================================================
-- TASK 1
-- Business question: What does the raw data look like?
-- Before any analysis, understand the structure and contents
-- of both tables to know what we are working with.
-- ============================================================

SELECT * FROM pos_transactions LIMIT 100;

SELECT * FROM pos_operator_logs LIMIT 100;


-- ============================================================
-- TASK 2
-- Business question: Do more customers pay by card or cash?
-- Knowing the split helps decide what checkout equipment to
-- invest in and how to design the payment experience.
-- ============================================================

SELECT
    COUNT(CASE WHEN t_cash THEN 1 END) AS cash_transactions,
    COUNT(CASE WHEN t_card THEN 1 END) AS card_transactions
FROM pos_transactions;


-- ============================================================
-- TASK 3
-- Business question: Do card users spend more than cash users?
-- Higher average spend per payment type informs security
-- arrangements and marketing decisions around payment methods.
-- ============================================================

SELECT
    AVG(CASE WHEN t_cash AND NOT t_card THEN amount END) AS avg_cash_spend,
    AVG(CASE WHEN t_card AND NOT t_cash THEN amount END) AS avg_card_spend
FROM pos_transactions;

-- Alternative: separate queries for clarity
SELECT AVG(amount) AS avg_cash_spend
FROM pos_transactions
WHERE t_cash AND NOT t_card;

SELECT AVG(amount) AS avg_card_spend
FROM pos_transactions
WHERE t_card AND NOT t_cash;


-- ============================================================
-- TASK 4
-- Business question: Which Sundays had trading activity?
-- Poland's 2018 Sunday trading ban meant some Sundays were
-- open and some were closed. Identifying which week numbers
-- had Sunday trading is the foundation for the revenue
-- comparison in Task 6.
-- ============================================================

-- Working Sundays: 24 Feb (week 8), 31 Mar (week 13)
-- Non-working Sundays: 17 Feb (week 7), 7 Apr (week 14) — will not appear in results

SELECT
    WEEK(end_date_time) AS week_num,
    DATE(end_date_time) AS end_date
FROM pos_transactions
WHERE YEAR(end_date_time) >= 2019
    AND DATE(end_date_time) IN (
        '2019-02-24',
        '2019-03-31',
        '2019-02-17',
        '2019-04-07'
    )
GROUP BY end_date
ORDER BY end_date DESC;


-- ============================================================
-- TASK 5
-- Business question: Which days are busiest — and by how much?
-- Daily transaction volume, revenue, and basket size patterns
-- directly inform staff scheduling and financial planning.
-- Note: MySQL does not support PERCENTILE_CONT natively.
-- Median is calculated using ROW_NUMBER() window function.
-- ============================================================

-- Daily sales trends with average basket size
SELECT
    WEEK(end_date_time) AS week_num,
    DATE(end_date_time) AS end_date,
    COUNT(id) AS total_transactions,
    SUM(amount) AS total_sales,
    AVG(amount) AS avg_sale_amount,
    AVG(basket_size) AS avg_basket_size
FROM pos_transactions
WHERE YEAR(end_date_time) >= 2019
GROUP BY DATE(end_date_time)
ORDER BY week_num;

-- Median sale amount per day (custom MySQL implementation)
-- Uses ROW_NUMBER() to rank transactions by amount per day,
-- then selects the middle row(s) to find the true median.
SELECT
    end_date,
    AVG(amount) AS median_sale_amount
FROM (
    SELECT
        DATE(end_date_time) AS end_date,
        amount,
        ROW_NUMBER() OVER (
            PARTITION BY DATE(end_date_time)
            ORDER BY amount
        ) AS row_num,
        COUNT(*) OVER (
            PARTITION BY DATE(end_date_time)
        ) AS total_rows
    FROM pos_transactions
    WHERE YEAR(end_date_time) >= 2019
) ranked
WHERE row_num IN (
    FLOOR((total_rows + 1) / 2),
    CEIL((total_rows + 1) / 2)
)
GROUP BY end_date
ORDER BY end_date;

-- Median basket size per day (same approach)
SELECT
    end_date,
    AVG(basket_size) AS median_basket_size
FROM (
    SELECT
        DATE(end_date_time) AS end_date,
        basket_size,
        ROW_NUMBER() OVER (
            PARTITION BY DATE(end_date_time)
            ORDER BY basket_size
        ) AS row_num,
        COUNT(*) OVER (
            PARTITION BY DATE(end_date_time)
        ) AS total_rows
    FROM pos_transactions
    WHERE YEAR(end_date_time) >= 2019
) ranked
WHERE row_num IN (
    FLOOR((total_rows + 1) / 2),
    CEIL((total_rows + 1) / 2)
)
GROUP BY end_date
ORDER BY end_date;


-- ============================================================
-- TASK 6
-- Business question: Should the supermarket open on Sundays?
-- Comparing total weekly revenue between a week with Sunday
-- trading (week 8) and a week without (week 14) tells us
-- whether Sunday opening actually generates extra revenue —
-- or whether customers simply shift their spend to Saturday.
-- ============================================================

SELECT
    WEEK(end_date_time) AS week_num,
    SUM(amount) AS total_weekly_revenue
FROM pos_transactions
WHERE YEAR(end_date_time) >= 2019
    AND WEEK(end_date_time) IN (8, 14)
GROUP BY WEEK(end_date_time);

-- Result: Both weeks generate PLN 1.7M — Sunday closure
-- has zero measurable impact on weekly revenue.


-- ============================================================
-- TASK 7
-- Business question: How much does Sunday labor cost?
-- If Sunday closures have no revenue impact, the next step
-- is to quantify the cost saving from not opening.
-- Counting operators per day gives us the staffing cost input.
-- ============================================================

SELECT
    DATE(begin_date_time) AS working_day,
    COUNT(DISTINCT operator_id) AS operators_on_shift,
    WEEK(begin_date_time) AS week_num
FROM pos_operator_logs
WHERE YEAR(begin_date_time) >= 2019
GROUP BY DATE(begin_date_time)
ORDER BY working_day;

-- Result: 18 operators on Sunday 24 Feb, 20 on Sunday 31 Mar.
-- Estimated saving per Sunday:
-- ~19 staff (avg) x 8 hours x hourly rate = direct labor saving
-- Multiply by ~52 Sundays per year for annual saving estimate.
-- Additional savings: energy costs, system overhead, consumables.
