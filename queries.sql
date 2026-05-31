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
    Workstation_Group_ID,
    begin_date_time DATETIME,
    end_date_time DATETIME,
    operators_ID,
    basket_size INT,
    t_cash BOOLEAN,
    t_card BOOLEAN
    amount DECIMAL(10,2),
);

CREATE TABLE IF NOT EXISTS pos_operator_logs (
    id INT,
    Workstation_Group_ID INT,
    Workstation_ID INT,
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


with cte1 as ( select *,
	case 
		when t_card = 1 then 'card'
		when t_cash = 1 then 'cash'
        ELSE 'Unkonwn'
	end as payment_method
from pos_transactions)


select payment_method,count(*) as no_of_transaction
from cte1 
group by payment_method;



-- ============================================================
-- TASK 3
-- Business question: Do card users spend more than cash users?
-- Higher average spend per payment type informs security
-- arrangements and marketing decisions around payment methods.
-- ============================================================
with cte1 as ( select *,
	case 
		when t_card = 1 then 'card'
		when t_cash = 1 then 'cash'
        ELSE 'Unkonwn'
	end as payment_method
from pos_transactions)


select payment_method,AVG(amount) as avg_transaction
from cte1 
group by payment_method;


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

with cte2 as (
			select * ,
			dayname(end_date_time) as day_name,
            weekofyear(end_date_time) as week_no
            from pos_transactions
            )
select * from cte2            

select distinct week_no
from cte2  
where day_name = 'Sunday'and year(end_date_time) >=2019;

-- ============================================================
-- TASK 5
-- Business question: Which days are busiest — and by how much?
-- Daily transaction volume, revenue, and basket size patterns
-- directly inform staff scheduling and financial planning.
-- Note: MySQL does not support PERCENTILE_CONT natively.
-- Median is calculated using ROW_NUMBER() window function.
-- ============================================================

WITH cte3 AS (
    SELECT *,
           DATE(end_date_time) AS txn_date,
           DAYNAME(end_date_time) AS day_name
    FROM pos_transactions
)
SELECT
    txn_date,day_name,
    COUNT(id) AS no_transaction,
    ROUND(SUM(amount),2) AS revenue,
    ROUND(AVG(basket_size),2) AS avg_basket_size
FROM cte3
GROUP BY txn_date,day_name;


-- ============================================================
-- TASK 6
-- Business question: Should the supermarket open on Sundays?
-- Comparing total weekly revenue between a week with Sunday
-- trading (week 8) and a week without (week 14) tells us
-- whether Sunday opening actually generates extra revenue —
-- or whether customers simply shift their spend to Saturday.
-- ============================================================

with cte2 as (
			select * ,
			dayname(end_date_time) as day_name,
            weekofyear(end_date_time) as week_no
            from pos_transactions
            )

select  week_no,day_name,round(sum(amount),3) as revenue
from cte2 
where week_no in(8,14) 
group by week_no,day_name ;

-- ============================================================
-- TASK 7
-- Business question: How much does Sunday labor cost?
-- If Sunday closures have no revenue impact, the next step
-- is to quantify the cost saving from not opening.
-- Counting operators per day gives us the staffing cost input.
-- ============================================================

with cte4 as( select * ,
			 date(begin_date_time) as date,
             dayname(begin_date_time) as day_name,
             weekofyear(begin_date_time) as week_no
             from pos_operator_logs
             )
             select date,day_name,week_no, count(distinct operator_id) as no_of_operator_working_that_day
             from cte4
             group by date,day_name,week_no;
-- ~19 staff (avg) x 8 hours x hourly rate = direct labor saving
-- Multiply by ~52 Sundays per year for annual saving estimate.
-- Additional savings: energy costs, system overhead, consumables.
