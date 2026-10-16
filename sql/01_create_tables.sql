-- Olist e-commerce analysis: schema setup
-- Run this first, then 02_load_data.sql.
-- Re-running is safe: the DROP statements clear the tables before recreating them.

CREATE DATABASE IF NOT EXISTS olist
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE olist;

-- Drop children before parents so the foreign keys do not block it
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_category_name_translation;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS customers;


-- One row per order placed. customer_unique_id is the real person behind repeat orders.
CREATE TABLE customers (
    customer_id              CHAR(32)    NOT NULL,
    customer_unique_id       CHAR(32)    NOT NULL,
    customer_zip_code_prefix CHAR(5)     NOT NULL,
    customer_city            VARCHAR(50) NOT NULL,
    customer_state           CHAR(2)     NOT NULL,
    PRIMARY KEY (customer_id),
    KEY idx_customers_unique_id (customer_unique_id),
    KEY idx_customers_state (customer_state)
) ENGINE = InnoDB;


CREATE TABLE sellers (
    seller_id              CHAR(32)    NOT NULL,
    seller_zip_code_prefix CHAR(5)     NOT NULL,
    seller_city            VARCHAR(50) NOT NULL,
    seller_state           CHAR(2)     NOT NULL,
    PRIMARY KEY (seller_id)
) ENGINE = InnoDB;


-- Portuguese category names, joined to English in product_category_name_translation
CREATE TABLE product_category_name_translation (
    product_category_name         VARCHAR(100) NOT NULL,
    product_category_name_english VARCHAR(100) NOT NULL,
    PRIMARY KEY (product_category_name)
) ENGINE = InnoDB;


-- product_category_name is left without a foreign key on purpose: 610 products have no
-- category, and 2 categories (pc_gamer, portateis_cozinha_e_preparadores_de_alimentos)
-- are missing from the translation file. 03_data_checks.sql reports this.
-- The lenght columns are misspelled in the source CSV; kept as-is to match the data.
CREATE TABLE products (
    product_id                 CHAR(32)     NOT NULL,
    product_category_name      VARCHAR(100) NULL,
    product_name_lenght        INT          NULL,
    product_description_lenght INT          NULL,
    product_photos_qty         INT          NULL,
    product_weight_g           INT          NULL,
    product_length_cm          INT          NULL,
    product_height_cm          INT          NULL,
    product_width_cm           INT          NULL,
    PRIMARY KEY (product_id),
    KEY idx_products_category (product_category_name)
) ENGINE = InnoDB;


-- The four delivery dates are NULL for orders that never reached that stage
CREATE TABLE orders (
    order_id                      CHAR(32)    NOT NULL,
    customer_id                   CHAR(32)    NOT NULL,
    order_status                  VARCHAR(20) NOT NULL,
    order_purchase_timestamp      DATETIME    NOT NULL,
    order_approved_at             DATETIME    NULL,
    order_delivered_carrier_date  DATETIME    NULL,
    order_delivered_customer_date DATETIME    NULL,
    order_estimated_delivery_date DATETIME    NULL,
    PRIMARY KEY (order_id),
    KEY idx_orders_customer (customer_id),
    KEY idx_orders_status (order_status),
    KEY idx_orders_purchase_date (order_purchase_timestamp),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE = InnoDB;


-- One row per item in an order, so an order with 3 items has 3 rows.
-- price is the revenue figure; freight_value is reported separately.
CREATE TABLE order_items (
    order_id            CHAR(32)      NOT NULL,
    order_item_id       INT           NOT NULL,
    product_id          CHAR(32)      NOT NULL,
    seller_id           CHAR(32)      NOT NULL,
    shipping_limit_date DATETIME      NULL,
    price               DECIMAL(10,2) NOT NULL,
    freight_value       DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    KEY idx_items_product (product_id),
    KEY idx_items_seller (seller_id),
    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id) REFERENCES sellers (seller_id)
) ENGINE = InnoDB;


-- An order can be paid with more than one method, one row per payment
CREATE TABLE order_payments (
    order_id             CHAR(32)      NOT NULL,
    payment_sequential   INT           NOT NULL,
    payment_type         VARCHAR(20)   NOT NULL,
    payment_installments INT           NOT NULL,
    payment_value        DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
) ENGINE = InnoDB;


-- No primary key here: 814 review_id values appear more than once in the source file.
-- 03_data_checks.sql counts them, so the duplicates stay visible instead of being hidden.
CREATE TABLE order_reviews (
    review_id               CHAR(32)     NOT NULL,
    order_id                CHAR(32)     NOT NULL,
    review_score            TINYINT      NOT NULL,
    review_comment_title    VARCHAR(255) NULL,
    review_comment_message  TEXT         NULL,
    review_creation_date    DATETIME     NULL,
    review_answer_timestamp DATETIME     NULL,
    KEY idx_reviews_review_id (review_id),
    KEY idx_reviews_order (order_id),
    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
) ENGINE = InnoDB;
