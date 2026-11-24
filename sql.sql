CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    phone VARCHAR(25),
    city VARCHAR(60) NOT NULL,
    loyalty_tier VARCHAR(20) CHECK (loyalty_tier IN ('Bronze', 'Silver', 'Gold', 'Platinum')),
    registration_date DATE NOT NULL
);
CREATE TABLE stores (
    store_id INT PRIMARY KEY,
    store_name VARCHAR(100) NOT NULL,
    city VARCHAR(60) NOT NULL,
    state VARCHAR(60) NOT NULL,
    region VARCHAR(20) CHECK (region IN ('North', 'South', 'East', 'West')),
    manager_name VARCHAR(100) NOT NULL,
    opened_date DATE NOT NULL
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(120) NOT NULL,
    category VARCHAR(50) NOT NULL,
    sub_category VARCHAR(50) NOT NULL,
    unit_cost NUMERIC(10,2) NOT NULL CHECK (unit_cost > 0),
    selling_price NUMERIC(10,2) NOT NULL CHECK (selling_price >= unit_cost),
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    store_id INT NOT NULL REFERENCES stores(store_id),
    order_date DATE NOT NULL,
    payment_mode VARCHAR(30) CHECK (payment_mode IN ('UPI', 'Credit Card', 'Debit Card', 'Cash')),
    order_status VARCHAR(20) CHECK (order_status IN ('Completed', 'Returned', 'Cancelled'))
);

CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    discount_pct INT DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 50)
);

SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL
SELECT 'stores', COUNT(*) FROM stores
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;
SELECT current_database(), current_schema();
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_name;

SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL
SELECT 'stores', COUNT(*) FROM stores
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'Fresh Sales', COUNT(*) FROM "Fresh Sales"
UNION ALL
SELECT 'Retail Sales', COUNT(*) FROM "Retail Sales"
UNION ALL
SELECT 'customer', COUNT(*) FROM customer;

SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL
SELECT 'stores', COUNT(*) FROM stores
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items;

INSERT INTO customers (customer_id, full_name, email, phone, city, loyalty_tier, registration_date)
VALUES (151, 'Raghav Kapoor', 'raghav.kapoor151@example.com', '+91-9811223344', 'Greater Noida', 'Silver', '2026-11-24');

UPDATE customers
SET loyalty_tier = 'Gold'
WHERE customer_id = 151;

SELECT * FROM customers WHERE customer_id = 151;


SELECT customer_id, full_name, email, COALESCE(phone, 'Not Provided') AS cleaned_phone
FROM customers
WHERE phone IS NULL;


UPDATE customers
SET phone = 'Not Provided'
WHERE phone IS NULL OR TRIM(phone) = '';

SELECT email, COUNT(*) AS duplicate_count
FROM customers
GROUP BY email
HAVING COUNT(*) > 1;

SELECT 
    o.order_id,
    o.order_date,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS net_order_value,
    CASE 
        WHEN SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) >= 15000 THEN 'High-Value Order'
        WHEN SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) >= 5000 THEN 'Medium-Value Order'
        ELSE 'Small-Value Order'
    END AS order_segment
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Completed'
GROUP BY o.order_id, o.order_date
ORDER BY net_order_value DESC
LIMIT 15;

SELECT 
    s.region,
    s.store_name,
    s.city,
    COUNT(DISTINCT o.order_id) AS completed_orders,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS net_revenue,
    ROUND(SUM(oi.quantity * p.unit_cost), 2) AS total_cogs,
    ROUND(SUM(oi.quantity * (oi.unit_price * (1 - oi.discount_pct / 100.0) - p.unit_cost)), 2) AS net_profit
FROM stores s
JOIN orders o ON s.store_id = o.store_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'Completed'
GROUP BY s.region, s.store_name, s.city
ORDER BY net_profit DESC;


SELECT 
    p.category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(CASE WHEN o.order_status = 'Completed' THEN oi.quantity ELSE 0 END) AS units_sold,
    ROUND(SUM(CASE WHEN o.order_status = 'Completed' 
        THEN oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0) ELSE 0 END), 2) AS completed_revenue,
    ROUND(
        100.0 * SUM(CASE WHEN o.order_status = 'Completed' 
            THEN oi.quantity * (oi.unit_price * (1 - oi.discount_pct / 100.0) - p.unit_cost) ELSE 0 END)
        / NULLIF(SUM(CASE WHEN o.order_status = 'Completed' 
            THEN oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0) ELSE 0 END), 0), 2
    ) AS profit_margin_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN o.order_status IN ('Returned', 'Cancelled') THEN o.order_id END) 
        / COUNT(DISTINCT o.order_id), 2) AS return_cancel_rate_pct
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
GROUP BY p.category
ORDER BY completed_revenue DESC;


SELECT 
    c.customer_id,
    c.full_name,
    c.city,
    c.loyalty_tier,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id, c.full_name, c.city, c.loyalty_tier
HAVING SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) > (
    SELECT AVG(customer_total)
    FROM (
        SELECT SUM(oi2.quantity * oi2.unit_price * (1 - oi2.discount_pct / 100.0)) AS customer_total
        FROM orders o2
        JOIN order_items oi2 ON o2.order_id = oi2.order_id
        WHERE o2.order_status = 'Completed'
        GROUP BY o2.customer_id
    ) sub
)
ORDER BY total_spent DESC;


WITH monthly_sales AS (
    SELECT 
        TO_CHAR(o.order_date, 'YYYY-MM') AS sales_month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY TO_CHAR(o.order_date, 'YYYY-MM')
)
SELECT 
    sales_month,
    total_orders,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY sales_month) AS prev_month_revenue,
    ROUND(
        100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY sales_month))
        / NULLIF(LAG(monthly_revenue) OVER (ORDER BY sales_month), 0), 2
    ) AS mom_growth_pct,
    SUM(monthly_revenue) OVER (ORDER BY sales_month) AS cumulative_ytd_revenue
FROM monthly_sales
ORDER BY sales_month;


WITH product_perf AS (
    SELECT 
        p.category,
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)), 2) AS total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY p.category 
            ORDER BY SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) DESC
        ) AS category_rank
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY p.category, p.product_name
)
SELECT * FROM product_perf
WHERE category_rank <= 3
ORDER BY category, category_rank;



CREATE OR REPLACE VIEW vw_payment_channel_insights AS
SELECT 
    payment_mode,
    COUNT(DISTINCT order_id) AS order_count,
    ROUND(AVG(order_val), 2) AS avg_order_value,
    ROUND(SUM(order_val), 2) AS total_channel_revenue
FROM (
    SELECT 
        o.order_id,
        o.payment_mode,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0)) AS order_val
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id, o.payment_mode
) sub
GROUP BY payment_mode
ORDER BY total_channel_revenue DESC;

SELECT * FROM vw_payment_channel_insights;


BEGIN;

INSERT INTO orders (order_id, customer_id, store_id, order_date, payment_mode, order_status)
VALUES (1151, 101, 1, '2026-11-24', 'UPI', 'Completed');

SAVEPOINT order_created;

INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price, discount_pct)
VALUES (5500, 1151, 201, 2, 1499.00, 10);

UPDATE products
SET stock_quantity = stock_quantity - 2
WHERE product_id = 201;




BEGIN;

INSERT INTO orders (order_id, customer_id, store_id, order_date, payment_mode, order_status)
VALUES (1151, 101, 1, '2026-11-24', 'UPI', 'Completed');

SAVEPOINT order_created;

INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price, discount_pct)
VALUES (5500, 1151, 201, 2, 1499.00, 10);

UPDATE products
SET stock_quantity = stock_quantity - 2
WHERE product_id = 201;

COMMIT;
