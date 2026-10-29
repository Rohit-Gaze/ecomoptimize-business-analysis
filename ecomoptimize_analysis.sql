-- EcomOptimize: E-commerce Business Performance Analysis
-- SQL dialect: SQLite
-- Purpose: Portfolio practice using synthetic data only.
-- This script creates sample tables, inserts synthetic records, and runs analysis queries.
-- No real customer or company data is included.

PRAGMA foreign_keys = ON;

-- =========================================================
-- 1. RESET TABLES
-- =========================================================
DROP VIEW IF EXISTS vw_monthly_checkout_performance;
DROP VIEW IF EXISTS vw_payment_performance;
DROP VIEW IF EXISTS vw_returns_refunds;
DROP TABLE IF EXISTS returns_refunds;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS checkout_sessions;

-- =========================================================
-- 2. TABLES
-- =========================================================
CREATE TABLE checkout_sessions (
    session_id TEXT PRIMARY KEY,
    session_date TEXT NOT NULL,             -- ISO format: YYYY-MM-DD
    device_type TEXT NOT NULL CHECK (device_type IN ('Mobile', 'Desktop', 'Tablet')),
    traffic_source TEXT NOT NULL,
    customer_type TEXT NOT NULL CHECK (customer_type IN ('New', 'Returning')),
    cart_value REAL NOT NULL CHECK (cart_value >= 0),
    shipping_fee REAL NOT NULL DEFAULT 0 CHECK (shipping_fee >= 0),
    coupon_used INTEGER NOT NULL DEFAULT 0 CHECK (coupon_used IN (0, 1)),
    checkout_stage_reached TEXT NOT NULL CHECK (
        checkout_stage_reached IN ('Cart', 'Address', 'Shipping', 'Payment', 'Confirmation')
    ),
    payment_method TEXT,
    payment_outcome TEXT NOT NULL CHECK (
        payment_outcome IN ('Not Attempted', 'Success', 'Failed')
    ),
    order_completed INTEGER NOT NULL CHECK (order_completed IN (0, 1)),
    order_id TEXT UNIQUE
);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL UNIQUE,
    order_date TEXT NOT NULL,
    order_value REAL NOT NULL CHECK (order_value >= 0),
    delivery_date TEXT,
    order_status TEXT NOT NULL CHECK (
        order_status IN ('Processing', 'Shipped', 'Delivered', 'Cancelled')
    ),
    FOREIGN KEY (session_id) REFERENCES checkout_sessions(session_id)
);

CREATE TABLE returns_refunds (
    return_id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    return_reason TEXT NOT NULL,
    return_request_date TEXT NOT NULL,
    refund_request_date TEXT,
    refund_completion_date TEXT,
    refund_status TEXT NOT NULL CHECK (
        refund_status IN ('Not Requested', 'Pending', 'Completed', 'Rejected')
    ),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CHECK (
        refund_completion_date IS NULL
        OR (refund_request_date IS NOT NULL AND refund_completion_date >= refund_request_date)
    )
);

CREATE INDEX idx_sessions_date ON checkout_sessions(session_date);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_returns_order ON returns_refunds(order_id);

-- =========================================================
-- 3. SMALL SYNTHETIC SAMPLE DATA
-- Replace or extend these rows with your larger generated dataset.
-- =========================================================
INSERT INTO checkout_sessions VALUES
('S001','2026-01-03','Mobile','Social','New',1200,60,1,'Confirmation','UPI','Success',1,'O001'),
('S002','2026-01-03','Desktop','Search','Returning',2400,0,0,'Confirmation','Card','Success',1,'O002'),
('S003','2026-01-04','Mobile','Social','New',850,60,0,'Payment','UPI','Failed',0,NULL),
('S004','2026-01-05','Tablet','Email','Returning',1600,40,1,'Address',NULL,'Not Attempted',0,NULL),
('S005','2026-01-06','Mobile','Search','Returning',3100,0,0,'Confirmation','UPI','Success',1,'O003'),
('S006','2026-01-07','Desktop','Direct','New',700,60,0,'Payment','Card','Failed',0,NULL),
('S007','2026-02-02','Mobile','Search','New',1950,40,1,'Confirmation','Wallet','Success',1,'O004'),
('S008','2026-02-03','Desktop','Email','Returning',4200,0,0,'Confirmation','Card','Success',1,'O005'),
('S009','2026-02-04','Mobile','Social','New',1100,60,0,'Shipping',NULL,'Not Attempted',0,NULL),
('S010','2026-02-06','Tablet','Direct','Returning',2750,0,1,'Confirmation','UPI','Success',1,'O006'),
('S011','2026-03-01','Mobile','Search','Returning',1350,60,0,'Payment','UPI','Failed',0,NULL),
('S012','2026-03-02','Desktop','Social','New',2250,0,0,'Confirmation','Card','Success',1,'O007');

INSERT INTO orders VALUES
('O001','S001','2026-01-03',1260,'2026-01-07','Delivered'),
('O002','S002','2026-01-03',2400,'2026-01-08','Delivered'),
('O003','S005','2026-01-06',3100,'2026-01-12','Delivered'),
('O004','S007','2026-02-02',1990,'2026-02-06','Delivered'),
('O005','S008','2026-02-03',4200,'2026-02-10','Delivered'),
('O006','S010','2026-02-06',2750,'2026-02-11','Delivered'),
('O007','S012','2026-03-02',2250,'2026-03-08','Delivered');

INSERT INTO returns_refunds VALUES
('R001','O002','Wrong size','2026-01-10','2026-01-11','2026-01-14','Completed'),
('R002','O003','Damaged item','2026-01-13','2026-01-14','2026-01-20','Completed'),
('R003','O005','Changed mind','2026-02-12','2026-02-13',NULL,'Pending'),
('R004','O006','Late delivery','2026-02-13','2026-02-14','2026-02-16','Completed');

-- =========================================================
-- 4. DATA QUALITY CHECKS
-- =========================================================

-- A. Check for duplicate session IDs (should return no rows because session_id is a primary key).
SELECT session_id, COUNT(*) AS record_count
FROM checkout_sessions
GROUP BY session_id
HAVING COUNT(*) > 1;

-- B. Check completed checkout sessions without a matching order.
SELECT s.session_id
FROM checkout_sessions s
LEFT JOIN orders o ON o.session_id = s.session_id
WHERE s.order_completed = 1 AND o.order_id IS NULL;

-- C. Check orders that do not link to a completed checkout.
SELECT o.order_id, o.session_id
FROM orders o
JOIN checkout_sessions s ON s.session_id = o.session_id
WHERE s.order_completed <> 1;

-- D. Check invalid date ordering for delivery dates.
SELECT order_id, order_date, delivery_date
FROM orders
WHERE delivery_date IS NOT NULL AND delivery_date < order_date;

-- E. Check refunds completed without a completion date.
SELECT return_id
FROM returns_refunds
WHERE refund_status = 'Completed' AND refund_completion_date IS NULL;

-- =========================================================
-- 5. KPI ANALYSIS
-- =========================================================

-- A. Overall checkout funnel.
-- Checkout starts are sessions that reached at least the Cart stage in this sample.
-- All rows represent checkout sessions, so the session count is the checkout-start count here.
SELECT
    COUNT(*) AS checkout_starts,
    SUM(order_completed) AS completed_orders,
    ROUND(100.0 * SUM(order_completed) / NULLIF(COUNT(*), 0), 2) AS conversion_rate_pct,
    ROUND(100.0 * (COUNT(*) - SUM(order_completed)) / NULLIF(COUNT(*), 0), 2) AS abandonment_rate_pct
FROM checkout_sessions;

-- B. Payment failure rate by attempts.
SELECT
    payment_method,
    SUM(CASE WHEN payment_outcome IN ('Success', 'Failed') THEN 1 ELSE 0 END) AS payment_attempts,
    SUM(CASE WHEN payment_outcome = 'Failed' THEN 1 ELSE 0 END) AS failed_attempts,
    ROUND(
        100.0 * SUM(CASE WHEN payment_outcome = 'Failed' THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN payment_outcome IN ('Success', 'Failed') THEN 1 ELSE 0 END), 0),
        2
    ) AS failure_rate_pct
FROM checkout_sessions
WHERE payment_method IS NOT NULL
GROUP BY payment_method
ORDER BY failure_rate_pct DESC;

-- C. Revenue and average order value.
SELECT
    COUNT(*) AS total_orders,
    ROUND(SUM(order_value), 2) AS gross_order_revenue_inr,
    ROUND(AVG(order_value), 2) AS average_order_value_inr
FROM orders
WHERE order_status <> 'Cancelled';

-- D. Conversion by device.
SELECT
    device_type,
    COUNT(*) AS checkout_starts,
    SUM(order_completed) AS completed_orders,
    ROUND(100.0 * SUM(order_completed) / NULLIF(COUNT(*), 0), 2) AS conversion_rate_pct
FROM checkout_sessions
GROUP BY device_type
ORDER BY conversion_rate_pct DESC;

-- E. Monthly checkout performance.
CREATE VIEW vw_monthly_checkout_performance AS
SELECT
    strftime('%Y-%m', session_date) AS month,
    COUNT(*) AS checkout_starts,
    SUM(order_completed) AS completed_orders,
    ROUND(100.0 * SUM(order_completed) / NULLIF(COUNT(*), 0), 2) AS conversion_rate_pct,
    ROUND(100.0 * (COUNT(*) - SUM(order_completed)) / NULLIF(COUNT(*), 0), 2) AS abandonment_rate_pct
FROM checkout_sessions
GROUP BY strftime('%Y-%m', session_date);

SELECT * FROM vw_monthly_checkout_performance ORDER BY month;

-- F. Return rate among delivered orders.
-- Denominator is delivered orders; numerator is distinct delivered orders with a return record.
SELECT
    COUNT(DISTINCT CASE WHEN o.order_status = 'Delivered' THEN o.order_id END) AS delivered_orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'Delivered' THEN rr.order_id END) AS returned_delivered_orders,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN o.order_status = 'Delivered' THEN rr.order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN o.order_status = 'Delivered' THEN o.order_id END), 0),
        2
    ) AS return_rate_pct
FROM orders o
LEFT JOIN returns_refunds rr ON rr.order_id = o.order_id;

-- G. Return reasons.
SELECT
    return_reason,
    COUNT(*) AS return_cases
FROM returns_refunds
GROUP BY return_reason
ORDER BY return_cases DESC;

-- H. Refund turnaround time for completed refunds only.
SELECT
    COUNT(*) AS completed_refunds,
    ROUND(AVG(julianday(refund_completion_date) - julianday(refund_request_date)), 2)
        AS avg_refund_turnaround_days
FROM returns_refunds
WHERE refund_status = 'Completed'
  AND refund_request_date IS NOT NULL
  AND refund_completion_date IS NOT NULL;

-- I. Refund status summary.
SELECT
    refund_status,
    COUNT(*) AS cases
FROM returns_refunds
GROUP BY refund_status
ORDER BY cases DESC;

-- J. Conversion by traffic source and customer type.
SELECT
    traffic_source,
    customer_type,
    COUNT(*) AS checkout_starts,
    SUM(order_completed) AS completed_orders,
    ROUND(100.0 * SUM(order_completed) / NULLIF(COUNT(*), 0), 2) AS conversion_rate_pct
FROM checkout_sessions
GROUP BY traffic_source, customer_type
ORDER BY conversion_rate_pct DESC;

-- =========================================================
-- 6. BUSINESS INTERPRETATION TEMPLATE
-- After running the queries, write insights only from the results:
-- 1. State the observed metric and segment.
-- 2. Explain why it may matter to the business.
-- 3. List alternative explanations and data limitations.
-- 4. Recommend a test or process change.
-- 5. Define the KPI to monitor after implementation.
-- =========================================================
