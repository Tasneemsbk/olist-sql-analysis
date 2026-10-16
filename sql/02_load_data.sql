-- Olist e-commerce analysis: load the CSVs
-- Run 01_create_tables.sql first, then run this from the project root so the
-- relative data/ paths resolve:
--   mysql -u root -p --local-infile=1 < sql/02_load_data.sql
-- The --local-infile=1 flag is required on the client side even when the server
-- already has local_infile = ON. If you use a stored login path instead of
-- -u root -p, it has to come before the other options or the client rejects it.
--
-- ESCAPED BY '' on every load turns off backslash escaping. These CSVs are plain
-- quoted CSV with no escape character, and leaving the MySQL default in place
-- loses rows wherever a comment ends in a backslash.
--
-- Tables are loaded parents first, because the foreign keys reject a child row
-- whose parent is not in place yet.

USE olist;

SET GLOBAL local_infile = 1;


-- customers: no nullable columns, so a plain load
LOAD DATA LOCAL INFILE 'data/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, customer_unique_id, customer_zip_code_prefix,
 customer_city, customer_state);


LOAD DATA LOCAL INFILE 'data/olist_sellers_dataset.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(seller_id, seller_zip_code_prefix, seller_city, seller_state);


-- This file is CRLF, unlike most of the others
LOAD DATA LOCAL INFILE 'data/product_category_name_translation.csv'
INTO TABLE product_category_name_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(product_category_name, product_category_name_english);


-- 610 products have a blank category and the size columns are blank for some rows.
-- NULLIF turns those empty strings into real NULLs instead of 0 or ''.
LOAD DATA LOCAL INFILE 'data/olist_products_dataset.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, @category, @name_len, @desc_len, @photos_qty,
 @weight_g, @length_cm, @height_cm, @width_cm)
SET product_category_name      = NULLIF(@category, ''),
    product_name_lenght        = NULLIF(@name_len, ''),
    product_description_lenght = NULLIF(@desc_len, ''),
    product_photos_qty         = NULLIF(@photos_qty, ''),
    product_weight_g           = NULLIF(@weight_g, ''),
    product_length_cm          = NULLIF(@length_cm, ''),
    product_height_cm          = NULLIF(@height_cm, ''),
    product_width_cm           = NULLIF(@width_cm, '');


-- Orders that were cancelled or never shipped have empty date fields.
-- Without NULLIF those would load as 0000-00-00 and silently break DATEDIFF later.
LOAD DATA LOCAL INFILE 'data/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, order_purchase_timestamp,
 @approved_at, @carrier_date, @customer_date, @estimated_date)
SET order_approved_at             = NULLIF(@approved_at, ''),
    order_delivered_carrier_date  = NULLIF(@carrier_date, ''),
    order_delivered_customer_date = NULLIF(@customer_date, ''),
    order_estimated_delivery_date = NULLIF(@estimated_date, '');


LOAD DATA LOCAL INFILE 'data/olist_order_items_dataset.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, order_item_id, product_id, seller_id,
 @shipping_limit_date, price, freight_value)
SET shipping_limit_date = NULLIF(@shipping_limit_date, '');


LOAD DATA LOCAL INFILE 'data/olist_order_payments_dataset.csv'
INTO TABLE order_payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, payment_sequential, payment_type,
 payment_installments, payment_value);


-- This file is CRLF and 3852 of the comments contain a line break of their own.
-- ENCLOSED BY '"' is what keeps those breaks inside the field instead of starting
-- a new row. One comment also ends in a backslash, which swallowed the row after
-- it until ESCAPED BY '' was set, so the row count here is worth checking.
LOAD DATA LOCAL INFILE 'data/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(review_id, order_id, review_score,
 @comment_title, @comment_message, @creation_date, @answer_timestamp)
SET review_comment_title    = NULLIF(@comment_title, ''),
    review_comment_message  = NULLIF(@comment_message, ''),
    review_creation_date    = NULLIF(@creation_date, ''),
    review_answer_timestamp = NULLIF(@answer_timestamp, '');


-- Check the load: the actual column must match the expected column on every row
SELECT 'customers' AS table_name, COUNT(*) AS rows_loaded, 99441 AS rows_expected FROM customers
UNION ALL SELECT 'sellers', COUNT(*), 3095 FROM sellers
UNION ALL SELECT 'product_category_name_translation', COUNT(*), 71 FROM product_category_name_translation
UNION ALL SELECT 'products', COUNT(*), 32951 FROM products
UNION ALL SELECT 'orders', COUNT(*), 99441 FROM orders
UNION ALL SELECT 'order_items', COUNT(*), 112650 FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*), 103886 FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*), 99224 FROM order_reviews;
