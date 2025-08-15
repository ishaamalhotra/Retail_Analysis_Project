DESCRIBE sales_transaction;
DESCRIBE customer_profiles;
DESCRIBE product_inventory;

-- Objective 1: Clean the sales_transaction table by identifying and removing duplicate entries to maintain data quality
SELECT transactionID, COUNT(*) AS count_transaction
FROM Sales_transaction
GROUP BY transactionID
HAVING COUNT(*)> 1;

-- Objective 2: Create a new table containing only unique records, then replace the original table by renaming the new one to maintain consistency in table naming.
CREATE TABLE Sales_transaction_Unique AS
SELECT DISTINCT * FROM Sales_transaction;

DROP TABLE Sales_transaction;

ALTER TABLE Sales_transaction_Unique RENAME TO Sales_transaction;

SELECT * FROM Sales_transaction;

-- Objective 3: Identify and resolve pricing discrepancies between the sales_transaction and product_inventory tables by aligning the transaction prices with the correct inventory prices for the same products.
SELECT st.TransactionID, st.price AS TransactionPrice, pi.price AS InventoryPrice
FROM sales_transaction st 
JOIN product_inventory pi ON st.productID = pi.productID
WHERE st.price <> pi.price;

UPDATE sales_transaction st 
JOIN product_inventory pi ON st.productID = pi.productID
SET st.price = pi.price
WHERE st.price <> pi.price;

SELECT st.TransactionID, st.CustomerID, st.ProductID, st.QuantityPurchased, st.TransactionDate, st.Price
FROM sales_transaction st;

-- Objective 4: To identify Null values in the dataset and replace it with "Unknown"
SELECT count(*) location_null_count
from customer_profiles 
WHERE TRIM(location) = ''; 

SET SQL_SAFE_UPDATES = 0;

UPDATE customer_profiles 
SET Location = "Unknown" 
WHERE TRIM(Location) = ''; 

SELECT count(*) AS location_null_count
from customer_profiles 
WHERE TRIM(location) = ''; 

SELECT * FROM customer_profiles;

-- Objective 5: Clean and correct the data type of the DATE column from TEXT to a standard DATE format and
CREATE TABLE sales_transaction_updated AS
SELECT *, STR_TO_DATE(TransactionDate, '%d-%m-%Y') AS TransactionDate_updated
FROM sales_transaction;

DROP TABLE sales_transaction;

ALTER TABLE sales_transaction_updated 
RENAME TO sales_transaction;

SELECT * FROM sales_transaction;

-- Objective 6: Summarize the total sales and quantities sold per product by the company.
SELECT productID, SUM(QuantityPurchased) TotalUnitsSold , SUM(QuantityPurchased * Price) AS TotalSales
FROM sales_transaction
GROUP BY productID
ORDER BY TotalSales DESC;

-- Objective 7: To count the number of transactions per customer to understand purchase frequency.
SELECT CustomerID,  COUNT(*) AS NumberOfTransactions
FROM sales_transaction
GROUP BY CustomerID
ORDER BY NumberOfTransactions DESC;

-- Objective 8: To evaluate the performance of the product categories based on the total sales.
SELECT pi.Category, SUM(st.QuantityPurchased) TotalUnitsSold , ROUND(SUM(st.quantitypurchased * st.price),0) TotalSales
FROM sales_transaction st 
JOIN product_inventory pi ON pi.productID = st.productID
GROUP BY pi.Category
ORDER BY TotalSales DESC;

-- Objective 9: Identify the top 10 products by total sales revenue to inform strategic decisions aimed at increasing company revenue.
SELECT productID, ROUND(SUM(quantitypurchased * price),0) TotalRevenue
FROM sales_transaction
GROUP BY productID
ORDER BY TotalRevenue DESC
LIMIT 10;

-- Objective 10: Identify the 10 least-selling products to inform strategies for improving their sales performance or considering product discontinuation.
SELECT productID, ROUND(SUM(quantitypurchased),0) AS TotalUnitsSold
FROM Sales_transaction
GROUP BY productID
HAVING SUM(quantitypurchased) > 0
ORDER BY TotalUnitsSold ASC
LIMIT 10;

-- Objective 11: To identify the sales trend to understand the revenue pattern of the company.      
SELECT TransactionDate_updated AS DateTrans, COUNT(transactionID) Transaction_count, 
SUM(quantitypurchased) TotalUnitsSold, SUM(quantitypurchased * price) TotalSales
FROM sales_transaction
GROUP BY DateTrans
ORDER BY DateTrans DESC;

-- Objective 12: Analyze the company's month-over-month sales growth rate to identify key trends and measure business performance.  
WITH sales AS (
    SELECT 
        EXTRACT(MONTH FROM transactiondate_updated) AS month, ROUND(SUM(quantitypurchased * price), 2) AS total_sales
    FROM sales_transaction
    GROUP BY EXTRACT(MONTH FROM transactiondate_updated)
)
SELECT month, total_sales, LAG(total_sales, 1) OVER(ORDER BY month) AS previous_month_sales,
    ROUND(
        ((total_sales - LAG(total_sales, 1) OVER(ORDER BY month)) 
        / LAG(total_sales, 1) OVER(ORDER BY month)) * 100, 
    2) AS mom_growth_percentage
FROM sales
ORDER BY month;

-- Objective 13: Identify high-frequency customers by retrieving those with more than 10 transactions and a total spend exceeding 1000. 
-- The result should include the customer ID, total number of transactions, and total amount spent, ordered by total spend in descending order.
SELECT CustomerID, COUNT(*) NumberOfTransactions, SUM(QuantityPurchased * price) TotalSpent
FROM sales_transaction
GROUP BY CustomerID
HAVING COUNT(*) > 10 
    AND SUM(QuantityPurchased * Price) > 1000
ORDER BY TotalSpent DESC;

-- Objective 14: Calculate the time difference between each customer's first and last purchase to analyze customer loyalty and longevity.
SELECT CustomerID,
    MIN(STR_TO_DATE(TransactionDate, '%Y-%m-%d')) AS FirstPurchase,
    MAX(STR_TO_DATE(TransactionDate, '%Y-%m-%d')) AS LastPurchase,
    DATEDIFF(
        MAX(STR_TO_DATE(TransactionDate, '%Y-%m-%d')),
        MIN(STR_TO_DATE(TransactionDate, '%Y-%m-%d'))
    ) AS DaysBetweenPurchases
FROM sales_transaction
GROUP BY CustomerID
HAVING DaysBetweenPurchases > 0
ORDER BY DaysBetweenPurchases DESC;  



-- Objective 15: Segment customers into purchasing tiers based on the total quantity of products bought and count the number of customers in each segment. 
-- The goal is to develop targeted marketing strategies for each tier.
CREATE TABLE customer_segment AS
	SELECT CustomerID,
		CASE
			WHEN TotalQuantity BETWEEN 1 AND 10 THEN 'Low'
			WHEN TotalQuantity BETWEEN 11 AND 30 THEN 'Med'
			WHEN TotalQuantity > 30 THEN 'High'
            ELSE 'None'
		END AS CustomerSegment
	FROM (
		SELECT c.CustomerID, SUM(s.QuantityPurchased) AS TotalQuantity
		FROM customer_profiles c
        JOIN sales_transaction s
        ON c.CustomerID = s.CustomerID
        GROUP BY CustomerID
    ) AS customer_totals;
	
SELECT 
    CustomerSegment, COUNT(*) AS count_CusomterSegment
FROM customer_segment
GROUP BY CustomerSegment;

-- Objective 16: To identify customers who have previously purchased products that are currently low in stock. 
SELECT cp.CustomerID, cp.Gender, cp.Location, pi.ProductName, pi.Category, pi.StockLevel
FROM customer_profiles AS cp
LEFT JOIN sales_transaction AS st ON cp.CustomerID = st.CustomerID
LEFT JOIN product_inventory AS pi ON st.ProductID = pi.ProductID
WHERE pi.StockLevel <= 10
GROUP BY cp.CustomerID, cp.Gender, cp.Location, pi.ProductName, pi.Category, pi.StockLevel
ORDER BY cp.CustomerID, pi.StockLevel DESC;

-- Objective 17: To identify the top 3 most recent transactions for each customer. 
SELECT CustomerID, TransactionID, TransactionDate_updated, QuantityPurchased, Price
FROM (
    SELECT CustomerID, TransactionID, TransactionDate_updated, QuantityPurchased, Price,
        ROW_NUMBER() OVER(PARTITION BY CustomerID ORDER BY TransactionDate_updated DESC) as rn
    FROM sales_transaction
) AS ranked_transactions
WHERE rn <= 3;