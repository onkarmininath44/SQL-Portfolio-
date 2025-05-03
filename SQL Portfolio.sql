create database projects;
use projects;
SELECT 
    *
FROM
    customer_orders;
describe customer_orders;
SELECT STR_TO_DATE('01-01-2025 18:05', '%d-%m-%Y %H:%i');
SET SQL_SAFE_UPDATES = 0;

UPDATE customer_orders
SET order_date = STR_TO_DATE(order_date, '%d-%m-%Y %H:%i')
WHERE STR_TO_DATE(order_date, '%d-%m-%Y %H:%i') IS NOT NULL;


SELECT 
    *
FROM
    drivers;
SELECT 
    *
FROM
    rolls;
SELECT 
    *
FROM
    rolls_recipes;
SELECT 
    *
FROM
    ingredients;

/*A.roll Metrics
B.driver and Customer Experience
C.Ingredient Optimisation
D.Pricing and Rating*/

-- Q1)How many rolls were orderd?SELECT 
select    *
FROM
    driver_orders;
SELECT 
    *
FROM
    customer_orders;
SELECT 
    COUNT(roll_id) AS no_of_rolls
FROM
    customer_orders;

-- Q2)How many unique customer orders were made?
SELECT 
    COUNT(DISTINCT (customer_id)) AS customers_number
FROM
    customer_orders;

-- Q3)How many successful orders were delivered by each driver?
SELECT 
    *
FROM
    driver_orders;
SELECT 
    driver_id, COUNT(order_id) successful_orders
FROM
    driver_orders
WHERE
    cancellation NOT IN ('cancellation' , 'Customer Cancellation')
GROUP BY driver_id;

-- Q4)How many of each type of roll was delivered?
SELECT 
    roll_id, COUNT(roll_id)
FROM
    customer_orders
WHERE
    order_id IN (SELECT 
            order_id
        FROM
            (SELECT 
                *,
                    CASE
                        WHEN cancellation IN ('cancellation' , 'Customer Cancellation') THEN 'c'
                        ELSE 'nc'
                    END AS order_cancel_details
            FROM
                driver_orders) a
        WHERE
            order_cancel_details = 'nc')
GROUP BY roll_id;

-- Q5)How many Veg and Non-Veg Rolls were ordered by each Customer?
SELECT 
    a.*, b.roll_number
FROM
    (SELECT 
        customer_id, roll_id, COUNT(roll_id) cnt
    FROM
        customer_orders
    GROUP BY customer_id , roll_id) a
        INNER JOIN
    rolls b ON a.roll_id = b.roll_id;

-- Q6)What was the maximum number of rolls delivered in a single order?
select * from (
select *,rank() over (order by cnt desc) rnk from
(select order_id,count(roll_id) cnt from (
select * from customer_orders where order_id in (
select order_id from
(select *,case when cancellation in ('cancellation','Customer Cancellation') then 'c' else 'nc' end as order_cancel_details from driver_orders) a
where order_cancel_details='nc')) b
group by order_id) c)d where rnk=1;

-- Q7)For each customer,how many delivered rolls had at least 1 change and how many had no changes?

with temp_customer_orders(order_id,customer_id,roll_id,not_include_items,extra_items_included,order_date) as 
(
select order_id,customer_id,roll_id,case when not_include_items = 'null' or not_include_items='' or not_include_items is null then '0' else not_include_items end as new_not_include_items,
case when extra_items_included = 'null' or extra_items_included='' or extra_items_included='NaN' or extra_items_included is null then '0' else extra_items_included end as new_extra_items_included,
order_date from customer_orders
),


temp_driver_orders(order_id,driver_id,pickup_time,distance,duration,cancellation) as
(
select order_id,driver_id,pickup_time,distance,duration,
case when cancellation in ('cancellation','customer cancellation') then 0 else 1 end as new_cancellation
from driver_orders
)
select customer_id,chg_no_chg,count(order_id) at_least_1_change from
(
select *,case when not_include_items='0' and extra_items_included='0' then 'no change' else 'change' end chg_no_chg from temp_customer_orders where order_id in (
select order_id from temp_driver_orders where cancellation!=0))a
group by customer_id,chg_no_chg;

-- 8)How many rolls were delivered that had both exclusions and extras?
with temp_customer_orders(order_id,customer_id,roll_id,not_include_items,extra_items_included,order_date) as 
(
select order_id,customer_id,roll_id,case when not_include_items = 'null' or not_include_items='' or not_include_items is null then '0' else not_include_items end as new_not_include_items,
case when extra_items_included = 'null' or extra_items_included='' or extra_items_included='NaN' or extra_items_included is null then '0' else extra_items_included end as new_extra_items_included,
order_date from customer_orders
),


temp_driver_orders(order_id,driver_id,pickup_time,distance,duration,cancellation) as
(
select order_id,driver_id,pickup_time,distance,duration,
case when cancellation in ('cancellation','customer cancellation') then 0 else 1 end as new_cancellation
from driver_orders
)

select chg_no_chg,count(roll_id) as rolls from(
select *,case when not_include_items!='0' and extra_items_included!='0' then 'both_inc_exc' else 'either_1_inc_exc' end chg_no_chg from temp_customer_orders where order_id in (
select order_id from temp_driver_orders where cancellation!=0)) a group by chg_no_chg;

-- 9)What was the total number of rolls ordered for each hour of the day?
SELECT 
    hours_bucket,
    COUNT(*) AS order_count
FROM (
    SELECT 
        CONCAT(HOUR(order_date), '-', HOUR(order_date) + 1) AS hours_bucket
    FROM customer_orders
) AS s
GROUP BY hours_bucket
ORDER BY CAST(SUBSTRING_INDEX(hours_bucket, '-', 1) AS UNSIGNED);

-- 10)what was the number of orders for each day of the week?
SELECT 
  DAYNAME(order_date) AS dow,
  COUNT(DISTINCT order_id) AS total_orders
FROM customer_orders
GROUP BY DAYNAME(order_date);


-- 11)What was the average time in minutes it took for driver to arrive at the fasoos HQ to pickup the order?
select driver_id,sum(diff)/count(order_id) from
(select * from 
(select *,row_number() over (partition by order_id order by diff) rnk from
(select a.*,b.driver_id,b.pickup_time,b.distance,b.duration,b.cancellation,datediff(minute,a.order_date,b.pickup_time) diff from customer_orders a inner join driver_orders b on a.order_id=b.order_id
where b.pickup_time is not null)a)b where rnk=1)c group by driver_id;



-- 12) Is there any relationship betweeen the number of rolls and how long the order takes to prepare?
select order_id,count(roll_id),sum(diff)/count(roll_id) from
(select a.*,b.driver_id,b.pickup_time,b.distance,b.duration,b.cancellation,datediff(minute,a.order_date,b.pickup_time) diff from customer_orders a inner join driver_orders b on a.order_id=b.order_id
where b.pickup_time is not null)a
group by order_id;


-- to get relationship plot the graph of above query output in python or other dashboard,report platform like powerbi we can concluded the relationship between no_of_rolls as time takes to prepare is ratio 1:10 resp.

-- 13)what was the average distance travelled for each customer?
SELECT 
    customer_id,
    SUM(distance) / COUNT(b.order_id) AS avg_distance
FROM
    customer_orders a
        INNER JOIN
    driver_orders b USING (order_id)
GROUP BY customer_id;

SELECT 
    co.customer_id, AVG(d.distance) AS avg_distance
FROM
    customer_orders co
        INNER JOIN
    driver_orders d ON co.order_id = d.order_id
WHERE
    d.distance IS NOT NULL
GROUP BY co.customer_id;


-- 14)what was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration) - MIN(duration) AS diff
FROM (
    SELECT 
        CAST(
            CASE 
                WHEN duration LIKE '%s%' THEN SUBSTRING(duration, 1, LOCATE('s', duration) - 1)
                ELSE duration
            END 
        AS UNSIGNED) AS duration
    FROM driver_orders
    WHERE duration IS NOT NULL
) AS a;


-- 15)what was the average speed for each driver for each delivery and do you notice any trend for these values?
SELECT 
    a.order_id,
    a.driver_id,
    a.distance / a.duration AS speed,
    b.cnt
FROM (
    SELECT 
        order_id,
        driver_id,
        distance,
        CAST(
            CASE 
                WHEN duration LIKE '%s%' THEN SUBSTRING(duration, 1, LOCATE('s', duration) - 1)
                ELSE duration
            END AS UNSIGNED
        ) AS duration
    FROM driver_orders
    WHERE duration IS NOT NULL
) AS a
INNER JOIN (
    SELECT 
        order_id,
        COUNT(roll_id) AS cnt
    FROM customer_orders
    GROUP BY order_id
) AS b ON a.order_id = b.order_id;


-- we concluded that the speed is in the ratio 0.67.

-- 16)what is the successful delivery percentage for each driver?
SELECT 
    driver_id, (s * 1.0 / t) * 100 cancelled_per
FROM
    (SELECT 
        driver_id, SUM(can_per) s, COUNT(driver_id) t
    FROM
        (SELECT 
        *,
            CASE
                WHEN LOWER(cancellation) LIKE '%cancel%' THEN 0
                ELSE 1
            END AS can_per
    FROM
        driver_orders) a
    GROUP BY driver_id) b;





