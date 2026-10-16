# Olist E-Commerce SQL Analysis

SQL analysis of the Olist Brazilian e-commerce dataset, covering about 99,000 orders placed
between September 2016 and October 2018. The project loads nine raw CSVs into a MySQL schema,
checks the data for the problems that would quietly distort the results, and then answers a set
of business questions about sales, customers, delivery performance and reviews. Everything is
plain SQL run from the command line, in six scripts meant to be read in order.

**Revenue throughout means `SUM(order_items.price)` on delivered orders only.** Freight is
reported separately and never added into revenue. Customers are counted by `customer_unique_id`,
not `customer_id`, because the latter is one row per order rather than one row per person.

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
on Kaggle. Eight of the nine files are used; the geolocation file is not needed for these
questions and is skipped.

| Table | Rows | What it holds |
|---|---|---|
| `customers` | 99,441 | One row per order, with `customer_unique_id` identifying the person |
| `orders` | 99,441 | Order status and the purchase, approval and delivery timestamps |
| `order_items` | 112,650 | One row per item, with price and freight |
| `order_payments` | 103,886 | One row per payment, so an order can appear more than once |
| `order_reviews` | 99,224 | Review score and optional comment text |
| `products` | 32,951 | Product dimensions and Portuguese category name |
| `sellers` | 3,095 | Seller location |
| `product_category_name_translation` | 71 | Portuguese to English category names |

## Questions answered

**Data checks (`03`)** — row counts, NULLs in key columns, duplicate keys, order status
distribution, and the period the data covers.

**Sales (`04`)** — revenue and orders by product category, monthly revenue with
month-over-month growth, running total of revenue, average order value by month, and
payment method shares with average instalments.

**Customers (`05`)** — revenue by state for states with 500 or more orders, the ten
largest spenders, spend segments, repeat versus one-time customers, and the best-selling
category in each state.

**Delivery and reviews (`06`)** — share of orders delivered late against on time, overall
and by state, average delivery time in days, and average review score for late versus
on-time orders.

## Key findings

- **Revenue totals R$13,221,498 across 96,478 delivered orders**, with freight of a further
  R$2,198,276 reported separately. The usable monthly trend runs January 2017 to August 2018;
  the three months before that hold 267 orders between them and November 2016 has none at all.

- **São Paulo alone accounts for 38.3% of revenue** (R$5,067,633). Average order value runs
  inversely to market size, though: São Paulo has the lowest at R$125.12 while Paraíba, with
  517 orders, has the highest at R$217.77. Freight economics is the likely driver, but the
  data here is consistent with that explanation rather than proof of it.

- **Only 3.0% of customers ever order twice** (2,801 of 93,358). One consequence is that the
  ten largest spenders are nine single-order customers, so that ranking measures the biggest
  individual purchases rather than loyalty.

- **The top 3.9% of customers by spend generate 25.5% of revenue**, while the 57.3% who spend
  under R$100 generate 21.6%. Median customer spend is R$89.73 against a mean of R$141.62.

- **A late delivery costs 1.72 review points.** Orders delivered on time average 4.29 out of 5;
  late orders average 2.57. The share of one and two star reviews rises from 9.2% to 54.0%.
  The association is strong, but this is observational data and sellers who ship late may differ
  in other ways too, so it is not evidence of cause on its own.

- **Delivery takes 12.5 days on average against a 24.4 day estimate at checkout**, and 91.9% of
  orders arrive on time. The padding is largest where reliability is worst: Pará is quoted 37.8
  days, takes 23.7, and is still late 12.4% of the time, while São Paulo is quoted 19.8, takes
  8.7, and is late 5.9% of the time.

- **Credit card covers 77.0% of orders at an average of 3.5 instalments**, with boleto at 19.9%
  and always paid in one. Shares add to slightly over 100% because an order can be settled with
  more than one method.

## Data issues handled

- Empty strings in date columns are converted to `NULL` with `NULLIF` during the load. Left
  alone they become `0000-00-00`, which looks like a date and breaks `DATEDIFF` later.
- Two CSVs use CRLF line endings and six use LF, so `LINES TERMINATED BY` is set per file.
- One review comment ends in a backslash. With MySQL's default `ESCAPED BY '\\'` that backslash
  escapes the closing quote and swallows the following row, losing it silently. Every load uses
  `ESCAPED BY ''` instead.
- 814 rows share a `review_id` with another row, so `order_reviews` has no primary key.
- Two product categories have no English translation and 610 products have no category, so
  category joins are `LEFT JOIN` with a `COALESCE` fallback.
- 775 orders have no line items. All are `unavailable` or `canceled` and none are delivered,
  so revenue totals are unaffected.

## SQL skills shown

Joins including `LEFT JOIN` and anti-joins for orphan checks, CTEs including chained CTEs,
window functions (`LAG`, `RANK`, `ROW_NUMBER` with `PARTITION BY`, running totals and shares
with `SUM(...) OVER ()`), `CASE WHEN` segmentation, `GROUP BY` with `HAVING`, date handling with
`DATEDIFF` and `DATE_FORMAT`, NULL handling with `NULLIF` and `COALESCE`, and schema design with
primary keys, foreign keys and indexes.

## How to run it

Requires MySQL 8.0 or later. Download the dataset from Kaggle and put the CSVs in `data/`,
which is not committed.

```bash
# 1. create the database and tables
mysql -u root -p < sql/01_create_tables.sql

# 2. load the CSVs, run from the project root so the data/ paths resolve
mysql -u root -p --local-infile=1 < sql/02_load_data.sql

# 3. run the analysis in order
mysql -u root -p --table < sql/03_data_checks.sql
mysql -u root -p --table < sql/04_sales_analysis.sql
mysql -u root -p --table < sql/05_customer_analysis.sql
mysql -u root -p --table < sql/06_delivery_and_reviews.sql
```

`02_load_data.sql` needs `local_infile` enabled on both sides. The script sets the server
variable itself; `--local-infile=1` is the client half and has to be on the command line. If
you use a stored login path instead of `-u root -p`, put `--login-path=name` before the other
options or the client rejects it.

Saved output for each script is in `results/`.
