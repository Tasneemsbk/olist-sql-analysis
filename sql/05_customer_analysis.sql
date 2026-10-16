-- Olist e-commerce analysis: customers
-- Run after 02_load_data.sql:
--   mysql -u root -p < sql/05_customer_analysis.sql
--
-- Revenue means SUM(order_items.price) on delivered orders only.
-- Customers are counted by customer_unique_id. customer_id is one row per order,
-- so counting it would report every order as a separate person.

USE olist;


-- Which states generate the most revenue, among those with real volume?
-- HAVING filters on the aggregate, which WHERE cannot do: WHERE runs before
-- the rows are grouped, so the order count does not exist yet.
SELECT c.customer_state,
       COUNT(DISTINCT o.order_id)           AS orders,
       COUNT(DISTINCT c.customer_unique_id) AS customers,
       ROUND(SUM(oi.price), 2)              AS revenue,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN customers c    ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 500
ORDER BY revenue DESC;


-- Who are the ten biggest spenders?
WITH customer_spend AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS orders,
           ROUND(SUM(oi.price), 2)    AS total_spend
    FROM orders o
    JOIN customers c    ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT RANK() OVER (ORDER BY total_spend DESC) AS spend_rank,
       customer_unique_id,
       orders,
       total_spend
FROM customer_spend
ORDER BY spend_rank
LIMIT 10;


-- How is spend spread across low, medium and high value customers?
-- Cutoffs are round numbers either side of the median spend of R$89.73.
WITH customer_spend AS (
    SELECT c.customer_unique_id,
           SUM(oi.price) AS total_spend
    FROM orders o
    JOIN customers c    ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
segmented AS (
    SELECT customer_unique_id,
           total_spend,
           CASE WHEN total_spend < 100 THEN 'low'
                WHEN total_spend < 500 THEN 'medium'
                ELSE 'high'
           END AS spend_segment
    FROM customer_spend
)
SELECT spend_segment,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                 AS pct_of_customers,
       ROUND(SUM(total_spend), 2)                                        AS revenue,
       ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 1) AS pct_of_revenue,
       ROUND(AVG(total_spend), 2)                                        AS avg_spend
FROM segmented
GROUP BY spend_segment
ORDER BY MIN(total_spend);


-- How many customers come back for a second order?
WITH customer_orders AS (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT CASE WHEN orders = 1 THEN 'one-time' ELSE 'repeat' END AS customer_type,
       COUNT(*)    AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_customers,
       SUM(orders) AS orders
FROM customer_orders
GROUP BY customer_type
ORDER BY customers DESC;


-- What sells best in each state?
-- ROW_NUMBER with PARTITION BY restarts the numbering for every state, so
-- filtering to rn = 1 picks each state's top category in one pass.
WITH state_category AS (
    SELECT c.customer_state,
           COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           ROUND(SUM(oi.price), 2) AS revenue
    FROM orders o
    JOIN customers c    ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p     ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
           ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state, category
),
ranked AS (
    SELECT customer_state,
           category,
           revenue,
           ROW_NUMBER() OVER (PARTITION BY customer_state ORDER BY revenue DESC) AS category_rank
    FROM state_category
)
SELECT customer_state,
       category AS top_category,
       revenue
FROM ranked
WHERE category_rank = 1
ORDER BY revenue DESC;
