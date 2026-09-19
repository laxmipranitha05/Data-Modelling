-- create warehouse
create or replace warehouse retail_wh warehouse_size='xsmall' auto_suspend=60 auto_resume=true;
use warehouse retail_wh;
-- create database
create or replace database retail_db;
use database retail_db;
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
-- create lookup tables
create or replace table dim_region (
region_id int autoincrement start 1 increment 1 primary key,
region_name varchar
);
create or replace table dim_state (
state_id int autoincrement start 1 increment 1 primary key,
state_name varchar,
region_id int
);
create or replace table dim_city (
city_id int autoincrement start 1 increment 1 primary key,
city_name varchar,
state_id int
);
create or replace table dim_category (
category_id int autoincrement start 1 increment 1 primary key,
category_name varchar
);
create or replace table dim_brand (
brand_id int autoincrement start 1 increment 1 primary key,
brand_name varchar,
category_id int
);
create or replace table dim_year (
year_id int primary key,
year int
);
create or replace table dim_quarter (
quarter_id int autoincrement start 1 increment 1 primary key,
quarter_name varchar,
year_id int
);
create or replace table dim_month (
month_id int autoincrement start 1 increment 1 primary key,
month_name varchar,
quarter_id int
);
-- create normalized dimension tables
create or replace table dim_customer (
customer_id int primary key,
customer_name varchar,
city_id int,
membership varchar
);
create or replace table dim_product (
product_id int primary key,
product_name varchar,
brand_id int,
price number(12,2)
);
create or replace table dim_branch (
branch_id int primary key,
branch_name varchar,
city_id int,
manager_name varchar
);
create or replace table dim_date (
date_id int primary key,
date date,
day int,
day_name varchar,
week_no int,
month_id int,
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
-- create staging tables
create or replace table stg_customers (
customer_id int,
customer_name varchar,
city varchar,
state varchar,
membership varchar
);
create or replace table stg_products (
product_id int,
product_name varchar,
category varchar,
brand varchar,
price number(12,2)
);
create or replace table stg_branches (
branch_id int,
branch_name varchar,
city varchar,
state varchar,
region varchar,
manager_name varchar
);
create or replace table stg_calendar (
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
create or replace table stg_sales (
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
-- load staging tables
copy into stg_customers from @retail_stage/customers.csv;
copy into stg_products from @retail_stage/products.csv;
copy into stg_branches from @retail_stage/branches.csv;
copy into stg_calendar from @retail_stage/calendar.csv on_error=continue;
copy into stg_sales from @retail_stage/sales.csv;
-- load region lookup
insert into dim_region(region_name)
select distinct region from stg_branches;
-- load state lookup
insert into dim_state(state_name,region_id)
select distinct b.state,r.region_id
from stg_branches b
join dim_region r on b.region=r.region_name;
-- load city lookup
insert into dim_city(city_name,state_id)
select distinct x.city,s.state_id
from (
select city,state from stg_customers
union
select city,state from stg_branches
) x
join dim_state s on x.state=s.state_name;
-- load category lookup
insert into dim_category(category_name)
select distinct category from stg_products;
-- load brand lookup
insert into dim_brand(brand_name,category_id)
select distinct p.brand,c.category_id
from stg_products p
join dim_category c on p.category=c.category_name;
-- load year lookup
insert into dim_year(year_id,year)
select distinct year,year from stg_calendar;
-- load quarter lookup
insert into dim_quarter(quarter_name,year_id)
select distinct quarter,year
from stg_calendar;
-- load month lookup
insert into dim_month(month_name,quarter_id)
select distinct c.month,q.quarter_id
from stg_calendar c
join dim_quarter q on c.quarter=q.quarter_name
join dim_year y on c.year=y.year;
-- load customer dimension
insert into dim_customer(customer_id,customer_name,city_id,membership)
select c.customer_id,c.customer_name,ct.city_id,c.membership
from stg_customers c
join dim_city ct on c.city=ct.city_name
join dim_state s on c.state=s.state_name and ct.state_id=s.state_id;
-- load product dimension
insert into dim_product(product_id,product_name,brand_id,price)
select p.product_id,p.product_name,b.brand_id,p.price
from stg_products p
join dim_category c on p.category=c.category_name
join dim_brand b on p.brand=b.brand_name and b.category_id=c.category_id;
-- load branch dimension
insert into dim_branch(branch_id,branch_name,city_id,manager_name)
select b.branch_id,b.branch_name,c.city_id,b.manager_name
from stg_branches b
join dim_region r on b.region=r.region_name
join dim_state s on b.state=s.state_name and s.region_id=r.region_id
join dim_city c on b.city=c.city_name and c.state_id=s.state_id;
-- load date dimension
insert into dim_date(date_id,date,day,day_name,week_no,month_id,is_weekend)
select c.date_id,c.date,c.day,c.day_name,c.week_no,m.month_id,c.is_weekend
from stg_calendar c
join dim_year y on c.year=y.year
join dim_quarter q on c.quarter=q.quarter_name and q.year_id=y.year_id
join dim_month m on c.month=m.month_name and m.quarter_id=q.quarter_id;
-- load fact sales
insert into fact_sales
select * from stg_sales;
-- verify normalized tables
select * from dim_region;
select * from dim_state;
select * from dim_city;
select * from dim_category;
select * from dim_brand;
select * from dim_year;
select * from dim_quarter;
select * from dim_month;
select * from dim_customer;
select * from dim_product;
select * from dim_branch;
select * from dim_date;
select * from fact_sales;
-- customer-wise sales report
select c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
order by revenue desc;
-- product-wise revenue report
select p.product_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
group by p.product_name
order by revenue desc;
-- brand-wise revenue report
select b.brand_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
join dim_brand b on p.brand_id=b.brand_id
group by b.brand_name
order by revenue desc;
-- category-wise revenue report
select c.category_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
join dim_brand b on p.brand_id=b.brand_id
join dim_category c on b.category_id=c.category_id
group by c.category_name
order by revenue desc;
-- city-wise sales report
select c.city_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer cu on f.customer_id=cu.customer_id
join dim_city c on cu.city_id=c.city_id
group by c.city_name
order by revenue desc;
-- state-wise revenue report
select s.state_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_branch b on f.branch_id=b.branch_id
join dim_city c on b.city_id=c.city_id
join dim_state s on c.state_id=s.state_id
group by s.state_name
order by revenue desc;
-- region-wise revenue report
select r.region_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_branch b on f.branch_id=b.branch_id
join dim_city c on b.city_id=c.city_id
join dim_state s on c.state_id=s.state_id
join dim_region r on s.region_id=r.region_id
group by r.region_name
order by revenue desc;
-- monthly revenue report
select m.month_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_date d on f.date_id=d.date_id
join dim_month m on d.month_id=m.month_id
group by m.month_name
order by revenue desc;
-- quarterly revenue report
select q.quarter_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_date d on f.date_id=d.date_id
join dim_month m on d.month_id=m.month_id
join dim_quarter q on m.quarter_id=q.quarter_id
group by q.quarter_name
order by revenue desc;
-- top 10 customers
select c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
order by revenue desc
limit 10;
-- top 10 products
select p.product_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
group by p.product_name
order by revenue desc
limit 10;
-- top 10 branches
select b.branch_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_branch b on f.branch_id=b.branch_id
group by b.branch_name
order by revenue desc
limit 10;
-- customer purchase trend
select c.customer_name,d.date,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
join dim_date d on f.date_id=d.date_id
group by c.customer_name,d.date
order by c.customer_name,d.date;
-- product performance dashboard
select p.product_name,sum(f.quantity) as quantity,sum(f.total_amount) as revenue
from fact_sales f
join dim_product p on f.product_id=p.product_id
group by p.product_name
order by revenue desc;
-- regional sales dashboard
select r.region_name,sum(f.quantity) as quantity,sum(f.total_amount) as revenue
from fact_sales f
join dim_branch b on f.branch_id=b.branch_id
join dim_city c on b.city_id=c.city_id
join dim_state s on c.state_id=s.state_id
join dim_region r on s.region_id=r.region_id
group by r.region_name
order by revenue desc;
-- customer ranking
select customer_name,revenue,rank() over(order by revenue desc) as customer_rank
from (
select c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_name
);
-- running revenue
select d.date,sum(f.total_amount) as daily_revenue,
sum(sum(f.total_amount)) over(order by d.date) as running_revenue
from fact_sales f
join dim_date d on f.date_id=d.date_id
group by d.date
order by d.date;
-- create customer revenue view
create or replace view customer_revenue as
select c.customer_id,c.customer_name,sum(f.total_amount) as revenue
from fact_sales f
join dim_customer c on f.customer_id=c.customer_id
group by c.customer_id,c.customer_name;
-- display customer revenue view
select * from customer_revenue order by revenue desc;
-- create branch revenue materialized view
create or replace materialized view branch_revenue as
select branch_id,sum(total_amount) as revenue
from fact_sales
group by branch_id;
-- display materialized view
select * from branch_revenue order by revenue desc;
-- verify record counts
select count(*) as total_regions from dim_region;
select count(*) as total_states from dim_state;
select count(*) as total_cities from dim_city;
select count(*) as total_categories from dim_category;
select count(*) as total_brands from dim_brand;
select count(*) as total_customers from dim_customer;
select count(*) as total_products from dim_product;
select count(*) as total_branches from dim_branch;
select count(*) as total_dates from dim_date;
select count(*) as total_sales from fact_sales;
