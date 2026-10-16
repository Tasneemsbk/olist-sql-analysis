-- Olist e-commerce analysis: data quality checks
-- Run after 02_load_data.sql:
--   mysql -u root -p < sql/03_data_checks.sql
-- These run before any analysis so the numbers in the README can be trusted.

USE olist;


-- How many rows ended up in each table?
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews;


-- Which key columns contain NULLs, and how much of each column is missing?
SELECT 'orders.order_approved_at' AS column_name,
       SUM(order_approved_at IS NULL) AS null_rows,
       ROUND(100.0 * SUM(order_approved_at IS NULL) / COUNT(*), 1) AS null_pct
FROM orders
UNION ALL
SELECT 'orders.order_delivered_carrier_date',
       SUM(order_delivered_carrier_date IS NULL),
       ROUND(100.0 * SUM(order_delivered_carrier_date IS NULL) / COUNT(*), 1)
FROM orders
UNION ALL
SELECT 'orders.order_delivered_customer_date',
       SUM(order_delivered_customer_date IS NULL),
       ROUND(100.0 * SUM(order_delivered_customer_date IS NULL) / COUNT(*), 1)
FROM orders
UNION ALL
SELECT 'products.product_category_name',
       SUM(product_category_name IS NULL),
       ROUND(100.0 * SUM(product_category_name IS NULL) / COUNT(*), 1)
FROM products
UNION ALL
SELECT 'order_reviews.review_comment_message',
       SUM(review_comment_message IS NULL),
       ROUND(100.0 * SUM(review_comment_message IS NULL) / COUNT(*), 1)
FROM order_reviews;


-- Are there duplicate review ids, and how many extra rows do they add?
SELECT COUNT(*) AS review_ids_appearing_twice_or_more,
       SUM(times_seen - 1) AS extra_rows
FROM (
    SELECT review_id, COUNT(*) AS times_seen
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
) d;


-- What does a duplicated review id actually look like?
SELECT review_id, COUNT(*) AS times_seen, COUNT(DISTINCT order_id) AS distinct_orders
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY times_seen DESC, review_id
LIMIT 5;


-- customer_id is one row per order, so how many real people are behind it?
SELECT COUNT(*) AS customer_rows,
       COUNT(DISTINCT customer_unique_id) AS real_customers,
       COUNT(*) - COUNT(DISTINCT customer_unique_id) AS repeat_order_rows
FROM customers;


-- How are orders split across statuses?
SELECT order_status,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;


-- What period does the data cover?
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order,
       COUNT(DISTINCT DATE_FORMAT(order_purchase_timestamp, '%Y-%m')) AS months_covered
FROM orders;


-- Are there orders with no items? Those would be missing from any revenue total.
SELECT COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;


-- Which product categories have no English translation?
-- These need a LEFT JOIN in the sales analysis or the products drop out.
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
ORDER BY p.product_category_name;
