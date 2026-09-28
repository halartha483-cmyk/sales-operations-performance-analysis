-- Sales & Operations Performance Analysis
-- Dataset: Olist Brazilian E-Commerce Public Dataset
-- Purpose: SQL analysis supporting the Power BI dashboard

-- 1. Order Status Summary
SELECT
  order_status,
  COUNT(*) AS order_count
FROM `olist_orders_dataset`
GROUP BY order_status
ORDER BY order_count DESC;


-- 2. Monthly Order Trend
SELECT
  DATE_TRUNC(DATE(order_purchase_timestamp), MONTH) AS order_month,
  COUNT(DISTINCT order_id) AS total_orders
FROM `olist_orders_dataset`
GROUP BY order_month
ORDER BY order_month;


-- 3. Monthly Delivered Revenue
SELECT
  DATE_TRUNC(DATE(o.order_purchase_timestamp), MONTH) AS order_month,
  ROUND(SUM(oi.price), 2) AS delivered_revenue
FROM `olist_orders_dataset` o
JOIN `olist_order_items_dataset` oi
  ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_month
ORDER BY order_month;


-- 4. Product Category Revenue
SELECT
  p.product_category_name,
  ROUND(SUM(oi.price), 2) AS delivered_revenue
FROM `olist_order_items_dataset` oi
JOIN `olist_products_dataset` p
  ON oi.product_id = p.product_id
JOIN `olist_orders_dataset` o
  ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name
ORDER BY delivered_revenue DESC;


-- 5. Customer Purchase Frequency
-- customer_unique_id identifies the underlying customer across orders.
SELECT
  customer_purchase_frequency,
  COUNT(*) AS customer_count
FROM (
  SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count,
    CASE
      WHEN COUNT(DISTINCT o.order_id) = 1 THEN 'One-time'
      ELSE 'Repeat'
    END AS customer_purchase_frequency
  FROM `olist_customers_dataset` c
  JOIN `olist_orders_dataset` o
    ON c.customer_id = o.customer_id
  GROUP BY c.customer_unique_id
)
GROUP BY customer_purchase_frequency
ORDER BY customer_count DESC;


-- 6. Repeat vs One-time Customer Revenue
SELECT
  customer_type,
  COUNT(DISTINCT customer_unique_id) AS customers,
  ROUND(SUM(revenue), 2) AS revenue
FROM (
  SELECT
    c.customer_unique_id,
    CASE
      WHEN COUNT(DISTINCT o.order_id) = 1 THEN 'One-time'
      ELSE 'Repeat'
    END AS customer_type,
    SUM(oi.price) AS revenue
  FROM `olist_customers_dataset` c
  JOIN `olist_orders_dataset` o
    ON c.customer_id = o.customer_id
  JOIN `olist_order_items_dataset` oi
    ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
)
GROUP BY customer_type
ORDER BY revenue DESC;


-- 7. Delivery Performance
SELECT
  CASE
    WHEN order_delivered_customer_date > order_estimated_delivery_date
      THEN 'Late'
    ELSE 'On Time'
  END AS delivery_performance,
  COUNT(*) AS delivered_orders,
  ROUND(
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
    2
  ) AS percentage_of_delivered_orders
FROM `olist_orders_dataset`
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_performance
ORDER BY delivered_orders DESC;


-- 8. Late Delivery Rate and Average Days Late
SELECT
  COUNT(*) AS late_delivery_orders,
  ROUND(
    COUNT(*) * 100.0 /
    (
      SELECT COUNT(*)
      FROM `olist_orders_dataset`
      WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_estimated_delivery_date IS NOT NULL
    ),
    2
  ) AS late_delivery_rate,
  ROUND(
    AVG(
      DATE_DIFF(
        DATE(order_delivered_customer_date),
        DATE(order_estimated_delivery_date),
        DAY
      )
    ),
    2
  ) AS average_days_late
FROM `olist_orders_dataset`
WHERE order_status = 'delivered'
  AND order_delivered_customer_date > order_estimated_delivery_date;


-- 9. Customer Satisfaction by Delivery Performance
SELECT
  CASE
    WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
      THEN 'Late'
    ELSE 'On Time'
  END AS delivery_performance,
  COUNT(r.review_id) AS reviewed_orders,
  ROUND(AVG(r.review_score), 2) AS average_review_score
FROM `olist_orders_dataset` o
JOIN `olist_order_reviews_dataset` r
  ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_performance
ORDER BY average_review_score DESC;


-- 10. Late Delivery Rate by State
SELECT
  c.customer_state,
  COUNT(DISTINCT o.order_id) AS delivered_orders,
  COUNT(DISTINCT CASE
    WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
      THEN o.order_id
  END) AS late_delivery_orders,
  ROUND(
    COUNT(DISTINCT CASE
      WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN o.order_id
    END) * 100.0 /
    COUNT(DISTINCT o.order_id),
    2
  ) AS late_delivery_rate
FROM `olist_orders_dataset` o
JOIN `olist_customers_dataset` c
  ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_delivery_rate DESC;


-- 11. Top States by Late Delivery Orders
SELECT
  c.customer_state,
  COUNT(DISTINCT o.order_id) AS late_delivery_orders
FROM `olist_orders_dataset` o
JOIN `olist_customers_dataset` c
  ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date > o.order_estimated_delivery_date
GROUP BY c.customer_state
ORDER BY late_delivery_orders DESC
LIMIT 10;


-- 12. Top States by Average Order Value
SELECT
  c.customer_state,
  ROUND(
    SUM(oi.price) / COUNT(DISTINCT o.order_id),
    2
  ) AS average_order_value
FROM `olist_orders_dataset` o
JOIN `olist_customers_dataset` c
  ON o.customer_id = c.customer_id
JOIN `olist_order_items_dataset` oi
  ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY average_order_value DESC
LIMIT 10;


-- 13. Average Review Score by State
SELECT
  c.customer_state,
  ROUND(AVG(r.review_score), 2) AS average_review_score,
  COUNT(DISTINCT o.order_id) AS reviewed_orders
FROM `olist_orders_dataset` o
JOIN `olist_customers_dataset` c
  ON o.customer_id = c.customer_id
JOIN `olist_order_reviews_dataset` r
  ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY average_review_score DESC;


-- 14. Overall Review Score
SELECT
  ROUND(AVG(review_score), 2) AS overall_average_review_score
FROM `olist_order_reviews_dataset`;


-- 15. Delivered Revenue by State
SELECT
  c.customer_state,
  ROUND(SUM(oi.price), 2) AS delivered_revenue
FROM `olist_orders_dataset` o
JOIN `olist_customers_dataset` c
  ON o.customer_id = c.customer_id
JOIN `olist_order_items_dataset` oi
  ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY delivered_revenue DESC;
