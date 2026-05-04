-- Converted Loan_amount from TEXT to NUMERIC data type,
--to resolve errors and allow aggregation functions like SUM and ROUND to execute correctly.

ALTER TABLE loans 
ALTER COLUMN loan_amount TYPE NUMERIC 
USING loan_amount::NUMERIC;
-- Converted target_amount from TEXT to NUMERIC data type,
--to resolve errors and allow aggregation functions like SUM and ROUND to execute correctly.

ALTER TABLE Staff 
ALTER COLUMN target_amount TYPE NUMERIC 
USING target_amount::NUMERIC;

--Converted amount_paid from TEXT to NUMERIC data type,
--to resolve errors and allow aggregation functions like SUM and ROUND to execute correctly.

ALTER TABLE repayments 
ALTER COLUMN amount_paid TYPE NUMERIC 
USING amount_paid::NUMERIC;

--Converted payment_date from TEXT to DATE data type,
--to resolve errors and allow aggregation functions like SUM and ROUND to execute correctly.
ALTER TABLE repayments
ALTER COLUMN payment_date TYPE DATE
USING payment_date::DATE;

--Q1  Loan Summary by Type
--Find out how many loans we gave out and the total money spent for each type of loan (Personal, Business, SME)
SELECT loan_type,
COUNT (loan_id) AS total_no_of_loans,
ROUND(SUM(loan_amount),2) AS total_amount_disbursed,
ROUND(AVG(loan_amount),2) AS average_loan_amount
FROM loans
GROUP BY loan_type
ORDER BY total_amount_disbursed DESC;

--Q2 High-Value Defaulted Loans 
--Find the really big loans >2000000 where the customer has stopped paying back
SELECT loan_id, loan_type,
loan_amount, disbursement_date
FROM loans
WHERE loan_status = 'Defaulted'
AND loan_amount > 2000000
ORDER BY loan_amount DESC

-- Q3 Lagos Region Loans with JOIN
-- Get the list of all the loans given out by branches only located in Lagos
SELECT l.loan_id,
l.loan_type,
l.loan_amount,
l.loan_status,
b.branch_name
FROM loans l
JOIN branches b
ON l.branch_id = b.branch_id
WHERE b.city = 'Lagos'
ORDER BY loan_amount DESC;

-- Q4 Total Loans per Branch with Default Rate
-- Get the branches that has the highest percentage of bad loans compared to the total loans they gave out.
-- Using CTE
WITH Branch_loans AS(
SELECT b.branch_name,
b.city,
COUNT (l.loan_id) AS total_loans,
SUM (l.loan_amount) AS total_loan_amount,
COUNT (CASE WHEN l.loan_status = 'Defaulted' THEN 1 END) AS number_of_defaulted_loans
FROM branches b
JOIN loans l 
ON b.branch_id =l.branch_id
GROUP BY b.branch_name,
b.city)

SELECT branch_name, city, total_loans, total_loan_amount,
number_of_defaulted_loans,
ROUND((number_of_defaulted_loans * 100.0) / total_loans, 1) AS default_rate
FROM Branch_loans
WHERE total_loans > 5
ORDER BY default_rate DESC;

--Q5 Top 5 Relationship Managers
--Find the 5 best staffs based on the total money they loaned out (Active and Fully paid only)
WITH RM_Performance AS (
SELECT s.rm_name, b.branch_name,
COUNT (l.loan_id) AS count_of_loans,
SUM (l.loan_amount) AS total_loan_amount,
s.target_amount
FROM staff s 
JOIN branches b
ON s.branch_id = b.branch_id
JOIN loans l 
ON s.rm_id = l.rm_id
WHERE l.loan_status = 'Active' or l.loan_status = 'Fully Paid'
GROUP BY  s.rm_name, b.branch_name,s.target_amount
)

-- To Calculate the attainment percentage
SELECT rm_name, branch_name, 
count_of_loans, total_loan_amount,
target_amount,
ROUND((total_loan_amount / target_amount) * 100, 1) AS attainment_pct
FROM RM_Performance 
ORDER BY total_loan_amount DESC
LIMIT 5;

--Q6: Monthly Repayment Trend
--How much money does the bank collect from loan repayments each month, and people's payment status time.
SELECT 
TO_CHAR(payment_date, 'YYYY-MM') AS year_month,
SUM(amount_paid) AS total_amount_collected,
COUNT(CASE WHEN payment_status = 'On-Time' THEN 1 END) AS on_time_payments,
COUNT(CASE WHEN payment_status = 'Late' THEN 1 END) AS late_payments,
COUNT(CASE WHEN payment_status = 'Missed' THEN 1 END) AS missed_payments,
ROUND((COUNT(CASE WHEN payment_status = 'On-Time' THEN 1 END) * 100) / COUNT(repayment_id), 1) AS on_time_rate
FROM repayments
GROUP BY TO_CHAR(payment_date, 'YYYY-MM')
ORDER BY year_month ASC;

--Q7: Customer Segment Default Analysis (3-table JOIN)
-- Determine which intersection of customer demographics and geographic regions carries the highest credit risk.
-- Using CTE 
WITH Customer_Risk AS(
SELECT c.customer_segment,b.region,
COUNT(l.loan_id) AS total_loans,
SUM(l.loan_amount) AS total_loan_amount,
COUNT(CASE WHEN l.loan_status = 'Defaulted' THEN 1 END) AS defaulted_loan_count
-- 3-Tables JOIN to link loan status to customer profiles and branch locations
FROM loans l
JOIN customers c
ON l.customer_id = c.customer_id
JOIN branches b ON l.branch_id = b.branch_id
GROUP BY c.customer_segment,b.region)

SELECT customer_segment,region,
total_loans,total_loan_amount,
defaulted_loan_count,
ROUND((defaulted_loan_count * 100) / total_loans, 1) AS default_rate
FROM Customer_Risk
WHERE total_loans >= 3
ORDER BY default_rate DESC;

--The results show us exactly which customer segment and region is causing the bank to lose the most money due to unpaid loans.
