SECTION 1 — Schema & TABLE CREATION

CREATE SCHEMA ECOMMERCE; 
CREATE database ECommerce_Project;
USE ECommerce_ProjecT;

CREATE TABLE ECOMMERCE (
InvoiceNO Varchar(20),
StockCode varchar(20),
Description Varchar(200),
Quantity INT,
InvoiceDate Datetime,
UnitPrice Decimal(10,2),
CustomerID INT,
Country Varchar(20),
Revenue Decimal(10,2),
Date DATE,
HOUR INT,
MONTH VARCHAR(20),
DAYOFWEEK VARCHAR(20) );

SECTION 2 — IMPORT DATA

 SECTION 3 — DATA QUALITY CHECKS
 
USE ecommerce_project;
SELECT COUNT(*) FROM `e-commerce_clean`;

SELECT CUSTOMERID FROM `e-commerce_clean` 
where CUSTOMERID is null;

SELECT * FROM `e-commerce_clean`
WHERE InvoiceNo LIKE 'C%' OR Quantity < 0;

SELECT * FROM `e-commerce_clean`
WHERE UnitPrice <0;

SECTION 4 — MONTHLY REVENUE TREND + MoM GROWTH %

SELECT 
MONTH ,
SUM(Revenue)  AS Monthly_Revenue,
LAG(SUM(REVENUE)) OVER (ORDER BY MIN(Month)) AS Prev_month_revenue,
ROUND(
        (SUM(revenue) - LAG(SUM(revenue)) OVER (ORDER BY MIN(Month)))
        / LAG(SUM(revenue)) OVER (ORDER BY MIN(Month)) * 100,2)
        AS MOM_GR0WTH_PERCT
FROM `e-commerce_clean` 
GROUP BY Month
ORDER BY MIN(Month);

SECTION 5 — TOP & BOTTOM PRODUCT
         Top 10 products by revenue

SELECT Description, ROUND(SUM(Revenue),2) AS total_revenue
FROM `e-commerce_clean`
GROUP BY Description
Order BY total_revenue  desc
LIMIT 10;

Bottom 10 products by revenue

SELECT Description, Round(SUM(Revenue),2) AS Total_Revenue
FROM `e-commerce_clean`
Group by Description
Order BY Total_Revenue asc
LIMIT 10;

Top 10 products by quantity sold (volume leaders can differ from revenue leaders)

SELECT Description, COUNT(Quantity) AS Total_Quantity
FROM `e-commerce_clean`
GROUP BY Description
ORDER BY Total_Quantity DESC
LIMIT 10 ;

Bottom 10 products by quantity sold (volume leaders can differ from revenue leaders)

SELECT Description, COUNT(Quantity) AS Total_Quantity
FROM `e-commerce_clean`
GROUP BY Description
ORDER BY Total_Quantity asc
LIMIT 10;


SECTION 6 — CUSTOMER LIFECYCLE FUNNEL

WITH CUSTOMER_SEGMENT AS (
SELECT CustomerID,
COUNT(DISTINCT InvoiceNo) AS ORDER_COUNT,
ROUND(SUM(Revenue),2) AS TOTAL_REVENUE
FROM `e-commerce_clean`
WHERE CustomerID IS NOT NULL
GROUP BY CustomerID)
SELECT CustomerID,
  ORDER_COUNT , TOTAL_REVENUE,
  CASE
  WHEN ORDER_COUNT=1 THEN "ONE-TIME BUYER"
  WHEN ORDER_COUNT>=5 THEN "LOYAL CUSTOMER"
  ELSE "REPEAT BUYER" 
  END AS  CUSTOMER_SEGMENT,
	      ROUND((ORDER_COUNT*100)/SUM(ORDER_COUNT) OVER(),2) AS PERCENT_ORDER_COUNT,
      ROUND(SUM(TOTAL_REVENUE)*100 / SUM(SUM(TOTAL_REVENUE)) OVER(),2) AS PERCENT_REVENUE
      FROM CUSTOMER_SEGMENT
      GROUP BY CUSTOMERID
      ORDER BY TOTAL_REVENUE DESC;
      
      
      WITH CUSTOMER_SEGMENT AS (
      SELECT CustomerID, 
      Count(DISTINCT InvoiceNo) AS Order_Count,
      Round(sum(Revenue),2) AS Total_Revenue,
      CASE
      WHEN Count(DISTINCT InvoiceNo) =1 THEN "ONE-TIME BUYER"
      WHEN Count(DISTINCT InvoiceNo) >=5 THEN "LOYAL CUSTOMER"
      ELSE "REPEAT BUYER"
      END AS SEGMENT
      FROM `e-commerce_clean`
      WHERE CustomerID IS NOT NULL
      GROUP BY CustomerID )
      SELECT 
      SEGMENT,
      COUNT(CustomerID) AS Total_Customers,
      SUM(Order_Count) AS Total_Orders,
      Round((sum(Order_Count)*100) / sum(sum(Order_Count)) Over(),2) AS Percent_Total_Orders,
      ROUND(SUM(Total_Revenue),2) AS Segment_Revenue,
      Round(SUM(Total_Revenue)*100/SUM(SUM(Total_Revenue)) over(), 2) AS Percent_Total_Revenue
      FROM Customer_Segment
      GROUP BY SEGMENT
      ORDER BY FIELD(SEGMENT, 'ONE-TIME BUYER', 'REPEAT BUYER' , 'LOYAL CUSTOMER');
      
     
      
      WITH RFM_BASE AS (
      SELECT
      CustomerID,
      DATEDIFF((SELECT MAX(Date) FROM `e-commerce_clean`) , MAX(Date)) AS Recency_Days,
      COUNT(DISTINCT InvoiceNo) AS Frequency,
      SUM(Revenue) AS Monetary
      FROM `e-commerce_clean`
      WHERE CustomerID IS NOT NULL
      GROUP  BY CustomerID ),
      RFM_SCORED AS (
      SELECT
       CustomerID, recency_days, frequency, monetary,
        NTILE(3) OVER (ORDER BY recency_days DESC) AS r_score, 
        NTILE(3) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(3) OVER (ORDER BY monetary ASC)       AS m_score
    FROM RFM_BASE )
    
SELECT CustomerID, Recency_Days, Frequency, Monetary,
    r_score, f_score, m_score,
    (r_score + f_score + m_score) AS RFM_total,
    CASE
        WHEN (r_score + f_score + m_score)  =9 THEN 'Champions'
        WHEN(r_score + f_score + m_score) >= 7  THEN 'Loyal Customers'
        WHEN (r_score + f_score + m_score) >=5  THEN 'At Risk'
        ELSE 'LOST'
    END AS RFM_segment
FROM RFM_SCORED
ORDER BY RFM_total DESC;

ALTER TABLE `e-commerce_clean`
modify Date Date;
   
   UPDATE `e-commerce_clean`
   SET DATE = STR_TO_DATE(Date,'%m/%d/%Y');
    
    
    
 SECTION 8 — COHORT RETENTION


WITH first_purchase AS (
    SELECT CustomerID, DATE_FORMAT(MIN(Date), '%Y-%m-01') AS cohort_month
    FROM `e-commerce_clean`
    GROUP BY CustomerID
),
customer_activity AS (
    SELECT DISTINCT
        `e-commerce_clean`.CustomerID,
        DATE_FORMAT(`e-commerce_clean`.Date, '%Y-%m-01') AS activity_month,
        first_purchase.cohort_month
    FROM `e-commerce_clean`
    JOIN first_purchase ON `e-commerce_clean`.CustomerID = first_purchase.CustomerID
),
cohort_index AS (
    SELECT
        CustomerID,
        cohort_month,
        activity_month,
        PERIOD_DIFF(DATE_FORMAT(activity_month, '%Y%m'), DATE_FORMAT(cohort_month, '%Y%m')) AS month_number
    FROM customer_activity
)
SELECT
    cohort_month,
    month_number,
    COUNT(DISTINCT CustomerID) AS active_customers
FROM cohort_index
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;


Section: 9 Peak Hours & Peak Days


SELECT 
    Hour,
    COUNT(DISTINCT InvoiceNo) AS Total_Orders,
    ROUND(SUM(Revenue), 2) AS Total_Revenue,
    ROUND(SUM(Revenue)/COUNT(DISTINCT InvoiceNo), 2) AS Avg_Order_Value
FROM `e-commerce_clean`
GROUP BY Hour
ORDER BY Total_Orders DESC;


SELECT 
    `Day Of the Week`,
    COUNT(DISTINCT InvoiceNo) AS Total_Orders,
    ROUND(SUM(Revenue), 2) AS Total_Revenue,
    ROUND(SUM(Revenue)/COUNT(DISTINCT InvoiceNo), 2) AS Avg_Order_Value
FROM `e-commerce_clean`
GROUP BY `Day Of the Week`
ORDER BY Total_Revenue DESC;







