SELECT * FROM Customers

SELECT * FROM order_details

SELECT * FROM orders

SELECT * FROM products

UPDATE orders
SET order_date = date_format(str_to_date(order_date, '%d-%m-%Y'), '%Y-%m-%d')

SELECT COUNT(DISTINCT customer_id) FROM customers
SELECT COUNT(DISTINCT customer_id) FROM orders

SELECT c.customer_id, c.location, SUM(total_amount) AS Revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 10

-----customer segmentation----


CREATE TABLE rfm AS
WITH base_data AS (
   SELECT c.customer_id, c.location,
     COUNT(o.order_id) AS frequency,
     SUM(o.total_amount) AS monetary,
	MIN(o.order_date) AS first_order_date,
     MAX(o.order_date) AS last_order_date
FROM Customers c
JOIN Orders o ON c.customer_id = o.customer_id
GROUP BY 1, 2
),
maxdate AS (
SELECT *, MAX(last_order_date) OVER () AS max_date
FROM base_data)
SELECT customer_id,
DATEDIFF(max_date, last_order_date) AS recency,
frequency, monetary
FROM maxdate

SELECT * FROM rfm
ORDER BY monetary DESC

CREATE TABLE rfm_segmented AS
SELECT customer_id, recency, frequency, monetary,
CASE 
	WHEN recency <= 60 THEN 'H'
	WHEN recency <= 180 THEN 'M'
	ELSE 'L'
    END AS recency_segment,
CASE 
	WHEN frequency >= 5 THEN 'H'
	WHEN frequency >= 3 THEN 'M'
	ELSE 'L'
    END AS frequency_segment,
CASE 
	WHEN monetary >= 300000 THEN 'H'
	WHEN monetary >= 150000 THEN 'M'
	ELSE 'L'
    END AS monetary_segment
from rfm

CREATE TABLE rfm_Score AS 
SELECT customer_id, recency, frequency, monetary,
CASE
	WHEN recency <= 30 THEN 5
	WHEN recency <= 60 THEN 4
	WHEN recency <= 120 THEN 3
	WHEN recency <= 180 THEN 2
	ELSE 1
    END AS recency_score,
CASE
	WHEN frequency >= 5 THEN 5
	WHEN frequency = 4 THEN 4
	WHEN frequency = 3 THEN 3
	WHEN frequency = 2 THEN 2
	ELSE 1
    END AS frequency_score,
CASE
        WHEN monetary >= 400000 THEN 5
        WHEN monetary >= 300000 THEN 4
        WHEN monetary >= 200000 THEN 3
        WHEN monetary >= 100000 THEN 2
        ELSE 1
    END AS monetary_score
FROM rfm;

CREATE TABLE Customer_Segment2
SELECT customer_id,
CASE
	WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'     
	WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
	WHEN recency_score = 5 AND frequency_score <= 2 THEN 'Potential Loyalist'
	WHEN recency_score <= 2 AND frequency_score >= 3 THEN 'At Risk'
	WHEN recency_score = 1 THEN 'Lost'
	ELSE 'Other'
    END AS segment
FROM rfm_score

SELECT segment, count(*) AS No_of_customers
FROM Customer_Segment2
GROUP BY 1


SELECT location, COUNT(*) AS No_of_Customers
FROM customers
GROUP BY 1




SELECT COUNT(DISTINCT product_id) FROM products

SELECT p.product_id, p.name, p.category,
SUM(od.quantity) AS total_units_sold,
SUM(od.quantity * od.price_per_unit) AS total_revenue
FROM Order_Details od
JOIN Products p ON od.product_id = p.product_id
GROUP BY p.product_id, p.name, p.category
ORDER BY total_revenue DESC

-------product perfomance--------

CREATE TABLE Product_Segment AS 
WITH base_data as (
        SELECT p.product_id, p.name, p.category, 
SUM(od.quantity) AS total_units_sold,
SUM(od.quantity * od.price_per_unit) AS total_revenue
FROM Order_Details od
JOIN Products p ON od.product_id = p.product_id
GROUP BY p.product_id, p.name, p.category
ORDER BY total_revenue DESC
)
SELECT product_id, name, Category, total_units_sold, total_revenue,
CASE
	WHEN total_units_sold >= 120 AND total_revenue >= 5000000 THEN 'High Performer'                            -- High revenue and units sold
	WHEN total_units_sold >= 110 AND total_revenue BETWEEN 1000000 AND 5000000 THEN 'Mid-Tier Opportunity'     -- Moderate revenue and unit sales
    WHEN total_units_sold >= 120 AND total_revenue < 1000000 THEN 'Low-Margin Volume'                          -- High volume but low revenue (low-margin)
	ELSE 'Low Performer'                                                                                       -- Low revenue, lower-mid volume
    END AS performance_segment
FROM base_data


SELECT category,
    SUM(total_units_sold) AS total_units_sold,
    SUM(total_revenue) AS total_revenue,
    ROUND(SUM(total_revenue) / SUM(total_units_sold), 2) AS avg_price_per_unit
FROM product_segment
GROUP BY category
ORDER BY total_revenue DESC;

SELECT performance_segment, COUNT(product_id) as No_of_Products
FROM product_segment
GROUP BY 1

SELECT * FROM product_segment

with ordercount as (
select customer_id, count(order_id) as NumberOfOrders
from orders
group by 1
)
select NumberOfOrders, count(customer_id) as customercount
from ordercount
group by 1
order by 1


------sales trends-----

SELECT 
SUBSTRING_INDEX(order_date, '-', 2) AS MONTH,
SUM(o.total_amount) AS total_sales
FROM order_details od
JOIN orders o ON od.order_id = o.order_id
GROUP BY month
ORDER BY 1


WITH monthly_sales AS (
SELECT 
SUBSTRING_INDEX(order_date, '-', 2) AS MONTH,
SUM(total_amount) AS total_sales
FROM orders
GROUP BY month
),
sales_with_change AS (
    SELECT month, total_sales,
LAG(total_sales) OVER (ORDER BY month) AS prev_month_sales
FROM monthly_sales
)
SELECT month, total_sales, prev_month_sales,
ROUND(CASE 
		WHEN prev_month_sales IS NULL THEN NULL
		ELSE ((total_sales - prev_month_sales) / prev_month_sales) * 100
        END, 2) AS percent_change
FROM sales_with_change
ORDER BY month;


WITH monthly_product_sales AS (
  SELECT 
    SUBSTRING_INDEX(order_date, '-', 2) AS Month,
    p.Category,
    p.name AS Product_name,
    SUM(od.quantity * od.price_per_unit) AS Product_sales
  FROM order_details od
  JOIN orders o ON od.order_id = o.order_id
  JOIN products p ON od.product_id = p.product_id
  GROUP BY month, p.category, p.name
)
SELECT *
FROM monthly_product_sales
ORDER BY month, product_sales DESC;

-----Inventory management-------

SELECT 
  DATE_FORMAT(o.order_date, '%Y-%m') AS month,
  p.name,
  SUM(od.quantity) AS total_units_sold
FROM order_details od
JOIN orders o ON od.order_id = o.order_id
JOIN products p ON od.product_id = p.product_id
GROUP BY month, p.name
ORDER BY p.name, month;


WITH Units_sold AS (
     SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS month,
p.name AS Product_name,
SUM(od.quantity) AS total_units_sold
FROM order_details od
JOIN orders o ON od.order_id = o.order_id
JOIN products p ON od.product_id = p.product_id
GROUP BY 1, 2
ORDER BY 2 DESC
)
SELECT Product_name,
ROUND(SUM(total_units_sold) / count(DISTINCT month), 2) AS Sales_Frequency
FROM units_sold
GROUP BY 1
ORDER BY 2 DESC


SELECT P.product_id, name AS Product_name,
count(*) AS Sales_frequency
FROM order_details od
JOIN products p ON od.product_id = p.product_id
GROUP BY 1, 2
ORDER BY 3 DESC