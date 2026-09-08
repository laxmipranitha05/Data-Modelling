-- create warehouse
create or replace warehouse retail_wh warehouse_size='xsmall' auto_suspend=60 auto_resume=true;
use warehouse retail_wh;
-- create database and schema
create or replace database retail_dw;
use database retail_dw;
create or replace schema sales_schema;
use schema sales_schema;
-- create file format and stage
create or replace file format csv_format type=csv skip_header=1 field_delimiter=',';
create or replace stage retail_stage file_format=csv_format;
-- create dimension tables
create or replace table dim_customer (
customer_id int primary key,
customer_name varchar,
city varchar,
state varchar,
membership varchar
);
create or replace table dim_product (
product_id int primary key,
product_name varchar,
category varchar,
brand varchar,
price number(12,2)
);
create or replace table dim_branch (
branch_id int primary key,
branch_name varchar,
city varchar,
state varchar,
region varchar,
manager_name varchar
);
create or replace table dim_date (
date_id int primary key,
date date,
day int,
day_name varchar,
week_no int,
month varchar,
quarter varchar,
year int,
is_weekend varchar
);
-- create fact table
create or replace table fact_sales (
sale_id int primary key,
customer_id int,
product_id int,
branch_id int,
date_id int,
quantity int,
total_amount number(12,2)
);
-- upload csv files to retail_stage using snowflake ui
list @retail_stage;
-- load dimension data
copy into dim_customer from @retail_stage/customers.csv;
copy into dim_product from @retail_stage/products.csv;
copy into dim_branch from @retail_stage/branches.csv;
copy into dim_date from @retail_stage/calendar.csv on_error = 'continue';
-- load fact data
copy into fact_sales from @retail_stage/sales.csv;
-- verify loaded data
select * from dim_customer;
select * from dim_product;
select * from dim_branch;
select * from dim_date;
select * from fact_sales;
-- verify record counts
select count(*) as customers from dim_customer;
select count(*) as products from dim_product;
select count(*) as branches from dim_branch;
select count(*) as dates from dim_date;
select count(*) as sales from fact_sales;
-- customer revenue report
select c.customer_name,sum(f.total_amount) as revenue
from fact_sales f join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
order by revenue desc;
-- product revenue report
select p.product_name,sum(f.total_amount) as revenue
from fact_sales f join dim_product p on f.product_id=p.product_id
group by p.product_name
order by revenue desc;
-- branch performance report
select b.branch_name,sum(f.total_amount) as revenue,sum(f.quantity) as quantity
from fact_sales f join dim_branch b on f.branch_id=b.branch_id
group by b.branch_name
order by revenue desc;
-- monthly revenue report
select d.month,d.year,sum(f.total_amount) as revenue
from fact_sales f join dim_date d on f.date_id=d.date_id
group by d.month,d.year
order by d.year,d.month;
-- state-wise sales report
select b.state,sum(f.total_amount) as revenue
from fact_sales f join dim_branch b on f.branch_id=b.branch_id
group by b.state
order by revenue desc;
-- category-wise revenue report
select p.category,sum(f.total_amount) as revenue
from fact_sales f join dim_product p on f.product_id=p.product_id
group by p.category
order by revenue desc;
-- top 10 customers
select c.customer_name,sum(f.total_amount) as revenue
from fact_sales f join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
order by revenue desc
limit 10;
-- top 10 products
select p.product_name,sum(f.total_amount) as revenue
from fact_sales f join dim_product p on f.product_id=p.product_id
group by p.product_name
order by revenue desc
limit 10;
-- top 10 branches
select b.branch_name,sum(f.total_amount) as revenue
from fact_sales f join dim_branch b on f.branch_id=b.branch_id
group by b.branch_name
order by revenue desc
limit 10;
-- sales trend analysis
select d.date,sum(f.total_amount) as daily_revenue
from fact_sales f join dim_date d on f.date_id=d.date_id
group by d.date
order by d.date;
-- customer purchase analysis
select c.customer_name,count(f.sale_id) as purchases,sum(f.quantity) as total_quantity,sum(f.total_amount) as total_spending
from fact_sales f join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
order by total_spending desc;
-- quarterly revenue analysis
select d.quarter,d.year,sum(f.total_amount) as revenue
from fact_sales f join dim_date d on f.date_id=d.date_id
group by d.quarter,d.year
order by d.year,d.quarter;
-- customer ranking
select customer_name,revenue,rank() over(order by revenue desc) as customer_rank
from (
select c.customer_name,sum(f.total_amount) as revenue
from fact_sales f join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
);
-- running revenue
select d.date,sum(f.total_amount) as daily_revenue,
sum(sum(f.total_amount)) over(order by d.date) as running_revenue
from fact_sales f join dim_date d on f.date_id=d.date_id
group by d.date
order by d.date;
-- create customer revenue view
create or replace view customer_revenue as
select c.customer_id,c.customer_name,sum(f.total_amount) as revenue
from fact_sales f join dim_customer c on f.customer_id=c.customer_id
group by c.customer_id,c.customer_name;
-- query customer revenue view
select * from customer_revenue order by revenue desc;
-- create product revenue view
create or replace view product_revenue as
select p.product_id,p.product_name,p.category,sum(f.total_amount) as revenue
from fact_sales f join dim_product p on f.product_id=p.product_id
group by p.product_id,p.product_name,p.category;
-- query product revenue view
select * from product_revenue order by revenue desc;
