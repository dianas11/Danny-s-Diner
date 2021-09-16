CREATE SCHEMA dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);


INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

 CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

SELECT *
FROM dbo.members;

SELECT *
FROM dbo.menu;

SELECT *
FROM dbo.sales;



----------------------------------------WHAT IS THE TOTAL AMOUNT EACH CUSTOMER SPENT AT THE RESTAURANT?--------------------------------------------


SELECT  
   s.customer_id,
   SUM(price) AS total_sales
FROM sales AS S
JOIN menu AS M
ON S.product_id = M.product_id
GROUP BY customer_id;



----------------------------------------HOW MANY DAYS HAS EACH CUSTOMER VISITED THE RESTAURANT?----------------------------------------------------


SELECT 
customer_id,
COUNT(DISTINCT(order_date)) AS visit_date
FROM sales
GROUP BY customer_id;



---------------------------------------WHAT WAS THE FIRST ITEM FROM THE MENU PURCHASED BY EACH CUSTOMER?--------------------------------------------



WITH order_sales AS
(
  SELECT 
  customer_id,
  order_date,
  product_name,
     DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rank
	 FROM sales as s
	 JOIN menu as m
	 ON s.product_id = m.product_id
)
SELECT 
   customer_id,
   product_name
FROM order_sales
WHERE rank = 1
GROUP BY customer_id, product_name;




-----------------------------WHAT IS THE MOST PURCHASED ITEM ON THE MENU AND HOW MANY TIMES WAS IT PURCHASED BY ALL CUSTOMERS?----------------------



SELECT 
  TOP 1 (COUNT(s.product_id)) AS most_purchased, 
  product_name
FROM dbo.sales AS s
JOIN dbo.menu AS m
  ON s.product_id = m.product_id
GROUP BY s.product_id, product_name
ORDER BY most_purchased DESC;



------------------------------WHAT ITEM WAS THE MOST POPULAR FOR EACH CUSTOMER?--------------------------------------------------------------------



WITH fav_item AS
(
SELECT 
     s.customer_id,
	 m.product_name,
	 COUNT(m.product_id) as order_count,
	 DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY COUNT(s.customer_id) DESC) AS rank
FROM menu AS m
JOIN sales AS s
	ON m.product_id = s.product_id
GROUP BY s.customer_id, m.product_name
)

SELECT 
  customer_id, 
  product_name, 
  order_count
FROM fav_item
WHERE rank = 1;



-----------------------------------WHICH ITEM WAS PURCHASED FIRST BY THE CUSTOMER AFTER THEY BECAME A MEMBER?---------------------------------------



WITH first_purchased AS
(
    SELECT 
	   s.customer_id,
	   m.join_date,
	   s.order_date,
	   s.product_id,
	   DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rank
	FROM members AS m
	JOIN sales AS s
	ON m.customer_id = s.customer_id
   WHERE s.order_date >= m.join_date
)
SELECT 
  s.customer_id, 
  s.order_date, 
  m2.product_name 
FROM first_purchased AS s
JOIN menu AS m2
	ON s.product_id = m2.product_id
WHERE rank = 1;




------------------------------------WHICH ITEM WAS FIRST PURCHASED JUST BEFORE THE CUSTOMER BECAME A MEMBER?----------------------------------------



WITH before_membership_purchase AS
(
   SELECT 
     s.customer_id,
	 m.join_date,
	 s.order_date,
	 s.product_id,
	 DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rank
   FROM members AS m
   JOIN sales AS s
   ON m.customer_id = s.customer_id
   WHERE m.join_date > s.order_date
)

SELECT
   b.customer_id,
   b.order_date,
   m2.product_name
FROM before_membership_purchase AS b
JOIN menu as m2
ON b.product_id = m2.product_id
WHERE rank = 1




-----------------------------------WHAT IS THE TOTAL ITEMS AND AMOUNT SPENT BY EACH MEMBER BEFORE THEY BECAME A MEMBER?-----------------------------



SELECT
   s.customer_id,
   COUNT(DISTINCT s.product_id) AS unique_menu_item,
   SUM(m.price) AS Total_sales
FROM sales AS s
JOIN members AS mm 
   ON s.customer_id = mm.customer_id
JOIN menu as m
   ON s.product_id = m.product_id
WHERE s.order_date < mm.join_date
GROUP BY s.customer_id



---------------------------------IF EACH $1 SPENT EQUATES TO 10 POINTS AND SUSHI HAS A 2X POINTS MULTIPLIER - HOW MANY POINTS WOULD EACH CUSTOMER HAVE?-----------------



WITH total_points_cte AS
(
   SELECT *,
      CASE WHEN product_name = 'sushi' THEN price * 20
	  ELSE price * 10 END AS points
   FROM menu
)
SELECT s.customer_id,
       SUM(t.points) AS total_points
FROM total_points_cte AS t
JOIN sales AS s
 ON t.product_id = s.product_id
 GROUP BY s.customer_id




/********IN THE FIRST WEEK AFTER A CUSTOMER JOINS THE PROGRAM(INCLUDING THIER JOIN DATE) 
THEY EARN 2X POINTS ON ALL ITEMS, NOT JUST SUSHI-HOW MANY POINTS DO CUSTOMER A AND B HAVE AT THE END OF JANUARY*********/




WITH dated_cte AS
(
   SELECT *,
   DATEADD(DAY, 6, join_date) AS valid_date,
   EOMONTH('2021-01-31') AS last_date
   FROM members AS m
)
SELECT
  d.customer_id, 
  s.order_date, 
  d.join_date, 
  d.valid_date, 
  d.last_date, 
  m.product_name, 
  m.price,
	SUM( 
    CASE WHEN m.product_name = 'sushi' THEN 2 * 10 * m.price
		WHEN s.order_date BETWEEN d.join_date AND d.valid_date THEN 2 * 10 * m.price
		ELSE 10 * m.price END) AS points
FROM dated_cte AS d
JOIN sales AS s
	ON d.customer_id = s.customer_id
JOIN menu AS m
	ON s.product_id = m.product_id
WHERE s.order_date < d.last_date
GROUP BY d.customer_id, s.order_date, d.join_date, d.valid_date, d.last_date, m.product_name, m.price





















 