-- Olist e-commerce analysis: delivery and reviews
-- Run after 02_load_data.sql:
--   mysql --login-path=patents < sql/06_delivery_and_reviews.sql
--
-- An order is late when the customer received it after the estimated delivery
-- date shown at checkout. 8 of the 96,478 delivered orders have no delivery date
-- recorded and are excluded, since neither lateness nor duration can be measured
-- for them. Every delivered order does have an estimate.

USE olist;


-- What share of delivered orders arrived after the promised date?
WITH delivered AS (
    SELECT o.order_id,
           o.order_delivered_customer_date > o.order_estimated_delivery_date AS is_late
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT CASE WHEN is_late = 1 THEN 'late' ELSE 'on time' END AS delivery_result,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM delivered
GROUP BY is_late
ORDER BY orders DESC;


-- Which states are worst for late delivery?
-- SUM(is_late) works because the comparison returns 1 or 0.
WITH delivered AS (
    SELECT c.customer_state,
           o.order_delivered_customer_date > o.order_estimated_delivery_date AS is_late
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT customer_state,
       COUNT(*)      AS delivered_orders,
       SUM(is_late)  AS late_orders,
       ROUND(100.0 * SUM(is_late) / COUNT(*), 1) AS late_pct
FROM delivered
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY late_pct DESC;


-- How long does delivery actually take, against what was promised?
SELECT ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 1) AS avg_days_actual,
       ROUND(AVG(DATEDIFF(order_estimated_delivery_date, order_purchase_timestamp)), 1) AS avg_days_promised,
       ROUND(AVG(DATEDIFF(order_estimated_delivery_date, order_delivered_customer_date)), 1) AS avg_days_early,
       MIN(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)) AS fastest_days,
       MAX(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)) AS slowest_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


-- How does delivery time vary by state?
SELECT c.customer_state,
       COUNT(*) AS delivered_orders,
       ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_days_actual,
       ROUND(AVG(DATEDIFF(o.order_estimated_delivery_date, o.order_purchase_timestamp)), 1) AS avg_days_promised
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 500
ORDER BY avg_days_actual DESC;


-- Do late deliveries actually cost you review scores?
-- 547 orders carry more than one review row, so the counts below are review
-- rows rather than orders, and the average is taken across those rows.
WITH delivery AS (
    SELECT o.order_id,
           o.order_delivered_customer_date > o.order_estimated_delivery_date AS is_late
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT CASE WHEN d.is_late = 1 THEN 'late' ELSE 'on time' END AS delivery_result,
       COUNT(*) AS reviews,
       ROUND(AVG(r.review_score), 2) AS avg_review_score,
       ROUND(100.0 * SUM(r.review_score <= 2) / COUNT(*), 1) AS pct_one_or_two_star,
       ROUND(100.0 * SUM(r.review_score = 5) / COUNT(*), 1)  AS pct_five_star
FROM delivery d
JOIN order_reviews r ON d.order_id = r.order_id
GROUP BY d.is_late
ORDER BY avg_review_score DESC;
