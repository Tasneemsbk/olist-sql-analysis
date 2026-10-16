-- Olist e-commerce analysis: sales
-- Run after 02_load_data.sql:
--   mysql --login-path=patents < sql/04_sales_analysis.sql
--
-- Revenue here means SUM(order_items.price) on delivered orders only.
-- Freight is reported separately and is never added into revenue.
--
-- The time series queries below start at 2017-01. The dataset opens with three
-- scattered pilot months (1 delivered order in 2016-09, 265 in 2016-10, nothing
-- in 2016-11, 1 in 2016-12) worth R$40,471 in total, which is 0.3 percent of
-- revenue. Left in, the gap at 2016-11 makes LAG compare December to October and
-- the tiny base months produce growth rates in the thousands of percent.
-- From 2017-01 the series is 20 consecutive months with no gaps.

USE olist;


-- Which product categories bring in the most revenue?
-- LEFT JOIN on the translation table because 2 categories have no English name
-- and 610 products have no category at all. An inner join would drop them.
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2)         AS revenue,
       ROUND(SUM(oi.freight_value), 2) AS freight
FROM order_items oi
JOIN orders o   ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;


-- How did revenue move month to month?
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
           COUNT(DISTINCT o.order_id) AS orders,
           ROUND(SUM(oi.price), 2)    AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
    GROUP BY month
),
with_previous AS (
    SELECT month,
           orders,
           revenue,
           LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue
    FROM monthly
)
SELECT month,
       orders,
       revenue,
       prev_month_revenue,
       ROUND(100.0 * (revenue - prev_month_revenue) / prev_month_revenue, 1) AS mom_growth_pct
FROM with_previous
ORDER BY month;


-- How did revenue accumulate over the analysis window?
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
           ROUND(SUM(oi.price), 2) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
    GROUP BY month
)
SELECT month,
       revenue,
       ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS running_total_revenue
FROM monthly
ORDER BY month;


-- What is the average order value by month?
-- Order totals are built first, then averaged. Averaging oi.price directly would
-- give the average item price, which is a different and smaller number.
WITH order_totals AS (
    SELECT o.order_id,
           DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
           SUM(oi.price) AS order_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
    GROUP BY o.order_id, month
)
SELECT month,
       COUNT(*)                   AS orders,
       ROUND(AVG(order_value), 2) AS avg_order_value
FROM order_totals
GROUP BY month
ORDER BY month;


-- Which payment methods do customers use, and how many instalments do they take?
-- An order can be paid with more than one method, so the shares add to slightly
-- over 100 percent. The denominator is delivered orders with a payment record.
SELECT pay.payment_type,
       COUNT(DISTINCT pay.order_id) AS orders,
       ROUND(100.0 * COUNT(DISTINCT pay.order_id)
             / (SELECT COUNT(DISTINCT pay2.order_id)
                FROM order_payments pay2
                JOIN orders o2 ON pay2.order_id = o2.order_id
                WHERE o2.order_status = 'delivered'), 1) AS pct_of_orders,
       ROUND(AVG(pay.payment_installments), 1) AS avg_installments,
       ROUND(SUM(pay.payment_value), 2)        AS total_paid
FROM order_payments pay
JOIN orders o ON pay.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY pay.payment_type
ORDER BY orders DESC;
