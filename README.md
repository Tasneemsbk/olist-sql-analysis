# Olist E-Commerce (MySQL)

About 99,000 orders from Olist, a Brazilian online marketplace, placed between September 2016 and
October 2018. I loaded the nine CSVs into MySQL, checked the data, then looked at sales, customers,
delivery and reviews. Data: [Kaggle - Brazilian E-Commerce by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).

Revenue here means the sum of item prices on delivered orders. Freight is kept separate. Customers
are counted by `customer_unique_id`, because `customer_id` changes with every order.

## What I found

- Revenue was R$13.2M across 96,478 delivered orders, plus R$2.2M freight.
- Sao Paulo is 38.3% of revenue but has the lowest average order value (R$125). Paraiba has the
  highest (R$218), probably because of freight costs, though the data can't prove that.
- Only 3.0% of customers ever ordered twice. So the "top 10 spenders" are really the 10 biggest
  single purchases, not loyal customers.
- The top 3.9% of customers by spend bring in 25.5% of revenue.
- Late deliveries hurt reviews badly: 4.29 out of 5 on time vs 2.57 when late. One and two star
  reviews jump from 9.2% to 54.0%.
- Orders arrive in 12.5 days on average against a 24.4 day estimate, and 91.9% arrive on time.
  The estimates are padded most where delivery is least reliable (Para: quoted 37.8 days, still
  late 12.4% of the time).
- Credit card is used on 77% of orders, averaging 3.5 instalments. Boleto is 19.9%.

## Problems I had to fix when loading

- Empty dates became `0000-00-00`, which broke date maths. I converted them to NULL.
- Some files use Windows line endings and some don't, so each load sets its own.
- One review comment ends in a backslash, which made MySQL silently merge it with the next row.
  Turning off escaping (`ESCAPED BY ''`) fixed it.
- 814 reviews share an ID with another review, so that table has no primary key.
- 610 products have no category and two categories have no English name, so category joins are
  LEFT JOINs.
- 775 orders have no items, but none were delivered, so revenue isn't affected.

## Files

`sql/01-02` create the tables and load the data, `03` checks, `04` sales, `05` customers, `06`
delivery and reviews. Output is in `results/`.

To run: put the CSVs in `data/`, then run the scripts in order with `mysql -u root -p --table`
(`02` also needs `--local-infile=1`). Needs MySQL 8.0+.
