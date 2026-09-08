-- create warehouse
create or replace warehouse retail_wh warehouse_size='xsmall' auto_suspend=60 auto_resume=true;
use warehouse retail_wh;
-- create database
create or replace database retail_dw;
use database retail_dw;
-- create schema
create or replace schema sales_schema;
use schema sales_schema;
-- create file format
create or replace file format csv_format
type=csv
skip_header=1
field_delimiter=',';
-- create internal stage
create or replace stage retail_stage
file_format=csv_format;
-- create customer dimension
create or replace table dim_customer (
customer_id int,
customer_name varchar,
city varchar,
state varchar,
membership varchar
);
-- create product dimension
create or replace table dim_product (
product_id int,
product_name varchar,
category varchar,
brand varchar,
price number(12,2)
);
-- create branch dimension
create or replace table dim_branch (
branch_id int,
branch_name varchar,
city varchar,
state varchar,
region varchar,
manager_name varchar
);
-- create date dimension
create or replace table dim_date (
date_id int,
date date,
day int,
day_name varchar,
week_no int,
month varchar,
quarter varchar,
year int,
is_weekend varchar
);
-- create fact sales table
create or replace table fact_sales (
sale_id int,
customer_id int,
product_id int,
branch_id int,
date_id int,
quantity int,
total_amount number(12,2)
);
-- upload csv files using snowflake ui
list @retail_stage;
-- load customer data
copy into dim_customer
from @retail_stage/customers.csv;
-- load product data
copy into dim_product
from @retail_stage/products.csv;
-- load branch data
copy into dim_branch
from @retail_stage/branches.csv;
-- load date data
copy into dim_date
from @retail_stage/calendar.csv;
-- load sales data
copy into fact_sales
from @retail_stage/sales.csv;
-- verify customer data
select * from dim_customer;
-- verify product data
select * from dim_product;
-- verify branch data
select * from dim_branch;
-- verify date data
select * from dim_date;
-- verify sales data
select * from fact_sales;
-- verify record counts
select count(*) as total_customers from dim_customer;
select count(*) as total_products from dim_product;
select count(*) as total_branches from dim_branch;
select count(*) as total_dates from dim_date;
select count(*) as total_sales from fact_sales;
-- customer revenue report
select c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
order by revenue desc;
-- branch revenue report
select b.branch_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_branch b on f.branch_id=b.branch_id
group by b.branch_name
order by revenue desc;
-- product revenue report
select p.product_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
group by p.product_name
order by revenue desc;
-- category revenue report
select p.category,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
group by p.category
order by revenue desc;
-- monthly revenue report
select d.month,d.year,sum(f.total_amount) as revenue
from fact_sales f
join dim_date d on f.date_id=d.date_id
group by d.month,d.year
order by d.year,d.month;
-- quarterly revenue report
select d.quarter,d.year,sum(f.total_amount) as revenue
from fact_sales f
join dim_date d on f.date_id=d.date_id
group by d.quarter,d.year
order by d.year,d.quarter;
-- state-wise sales report
select b.state,sum(f.total_amount) as revenue
from fact_sales f
join dim_branch b on f.branch_id=b.branch_id
group by b.state
order by revenue desc;
-- top customers
select c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
order by revenue desc
limit 10;
-- top products
select p.product_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
group by p.product_name
order by revenue desc
limit 10;
-- top branches
select b.branch_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_branch b on f.branch_id=b.branch_id
group by b.branch_name
order by revenue desc
limit 10;
-- daily sales trend
select d.date,sum(f.total_amount) as daily_revenue
from fact_sales f
join dim_date d on f.date_id=d.date_id
group by d.date
order by d.date;
-- customer purchase analysis
select c.customer_name,count(f.sale_id) as purchase_count,sum(f.quantity) as total_quantity,sum(f.total_amount) as total_spending
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
order by total_spending desc;
-- product quantity analysis
select p.product_name,sum(f.quantity) as total_quantity
from fact_sales f
join dim_product p on f.product_id=p.product_id
group by p.product_name
order by total_quantity desc;
-- customer ranking
select customer_name,revenue,rank() over(order by revenue desc) as customer_rank
from (
select c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
);
-- branch ranking
select branch_name,revenue,rank() over(order by revenue desc) as branch_rank
from (
select b.branch_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_branch b on f.branch_id=b.branch_id
group by b.branch_name
);
-- product ranking
select product_name,revenue,rank() over(order by revenue desc) as product_rank
from (
select p.product_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
group by p.product_name
);
-- running revenue
select d.date,sum(f.total_amount) as daily_revenue,
sum(sum(f.total_amount)) over(order by d.date) as running_revenue
from fact_sales f
join dim_date d on f.date_id=d.date_id
group by d.date
order by d.date;
-- average sales amount
select sale_id,total_amount,avg(total_amount) over() as average_sales
from fact_sales;
-- customer revenue using cte
with customer_revenue as (
select c.customer_id,c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_id,c.customer_name
)
select * from customer_revenue
order by revenue desc;
-- customers above average spending
with customer_revenue as (
select c.customer_id,c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_id,c.customer_name
)
select * from customer_revenue
where revenue>(select avg(revenue) from customer_revenue)
order by revenue desc;
-- create customer revenue view
create or replace view customer_revenue as
select c.customer_id,c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_id,c.customer_name;
-- display customer revenue view
select * from customer_revenue
order by revenue desc;
-- create product revenue view
create or replace view product_revenue as
select p.product_id,p.product_name,p.category,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
group by p.product_id,p.product_name,p.category;
-- display product revenue view
select * from product_revenue
order by revenue desc;
-- create branch revenue view
create or replace view branch_revenue as
select b.branch_id,b.branch_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_branch b on f.branch_id=b.branch_id
group by b.branch_id,b.branch_name;
-- display branch revenue view
select * from branch_revenue
order by revenue desc;
-- final verification
select * from fact_sales
order by sale_id;
select sum(total_amount) as total_business_revenue from fact_sales;

