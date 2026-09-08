-- project 1: customer sales analytics
-- phase 1: snowflake environment setup
-- task 1: create warehouse
create warehouse sales_wh
with
warehouse_size = 'x-small'
auto_suspend = 60
auto_resume = true;
use warehouse sales_wh;
-- task 2: create database
create database customer_sales_db;
-- task 3: create schema
create schema customer_sales_db.sales_schema;
-- task 4: select database and schema
use database customer_sales_db;
use schema sales_schema;
-- task 5: create csv file format
create file format sales_csv_format
type = 'csv'
field_delimiter = ','
skip_header = 1
field_optionally_enclosed_by = '"'
null_if = ('null', 'NULL');
-- task 6: create internal stage
create stage sales_stage
file_format = sales_csv_format;
-- phase 2: data loading
-- task 7: upload csv files
-- upload customers.csv, fooditems.csv and orders.csv into sales_stage
-- task 8: create customers table
create table customers (
    customer_id integer,
    first_name varchar(50),
    last_name varchar(50),
    email varchar(100),
    phone varchar(20),
    address varchar(100)
);
-- create fooditems table
create table fooditems (
    food_id integer,
    name varchar(100),
    price number(10,2),
    category varchar(50),
    availability varchar(50)
);
-- create orders table
create table orders (
    order_id integer,
    customer_id integer,
    food_id integer,
    quantity integer,
    order_date timestamp,
    status varchar(50),
    total_amount number(10,2)
);
-- check created tables
show tables;
-- task 9: load customers csv file
copy into customers
from @sales_stage/customers.csv
file_format = (format_name = sales_csv_format);
-- load fooditems csv file
copy into fooditems
from @sales_stage/fooditems.csv
file_format = (format_name = sales_csv_format);
-- load orders csv file
copy into orders
from @sales_stage/orders.csv
file_format = (format_name = sales_csv_format);
-- task 10: verify loaded data
select * from customers;
select * from fooditems;
select * from orders;
-- phase 3: data analysis
-- task 11: display all customer details
select * from customers;
-- task 12: display all food item details
select * from fooditems;
-- task 13: display all order details
select * from orders;
-- task 14: customer-wise sales report
select
    c.customer_id,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    sum(o.total_amount) as total_amount_spent
from customers c
join orders o
    on c.customer_id = o.customer_id
group by
    c.customer_id,
    c.first_name,
    c.last_name
order by total_amount_spent desc;
-- task 15: highest spending customer
select
    c.customer_id,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    sum(o.total_amount) as total_amount_spent
from customers c
join orders o
    on c.customer_id = o.customer_id
group by
    c.customer_id,
    c.first_name,
    c.last_name
order by total_amount_spent desc
limit 1;
-- task 16: total business revenue
select sum(total_amount) as total_business_revenue
from orders;
-- task 17: category-wise revenue report
select
    f.category,
    sum(o.total_amount) as total_revenue
from fooditems f
join orders o
    on f.food_id = o.food_id
group by f.category
order by total_revenue desc;
-- task 18: order status-wise revenue report
select
    status as order_status,
    sum(total_amount) as total_revenue
from orders
group by status
order by total_revenue desc;
-- task 19: top three customers
select
    row_number() over (order by sum(o.total_amount) desc) as rank,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    sum(o.total_amount) as total_spent
from customers c
join orders o
    on c.customer_id = o.customer_id
group by
    c.customer_id,
    c.first_name,
    c.last_name
order by total_spent desc
limit 3;
-- task 20: customer purchase frequency report
select
    c.customer_id,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    count(o.order_id) as orders_placed
from customers c
left join orders o
    on c.customer_id = o.customer_id
group by
    c.customer_id,
    c.first_name,
    c.last_name
order by c.customer_id;
-- task 21: display delivered orders only
select *
from orders
where status = 'Delivered';
-- task 22: display orders placed after 12 july 2026
select
    o.order_id,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    o.order_date,
    o.status,
    o.total_amount
from orders o
join customers c
    on o.customer_id = c.customer_id
where o.order_date > '2026-07-12 23:59:59'
order by o.order_date;
-- phase 4: views
-- task 23: create customer sales report view
create or replace view customer_sales_report as
select
    c.customer_id,
    concat(c.first_name, ' ', c.last_name) as customer_name,
    sum(o.total_amount) as total_amount_spent
from customers c
join orders o
    on c.customer_id = o.customer_id
group by
    c.customer_id,
    c.first_name,
    c.last_name;
-- task 24: retrieve all records from the view
select *
from customer_sales_report;
-- task 25: sort view data in descending order
select *
from customer_sales_report
order by total_amount_spent desc;
-- additional verification queries
-- check warehouse
show warehouses;
-- check database
show databases;
-- check schemas
show schemas;
-- check stages
show stages;
-- check files uploaded in stage
list @sales_stage;
-- check total customers
select count(*) as total_customers
from customers;
-- check total food items
select count(*) as total_fooditems
from fooditems;
-- check total orders
select count(*) as total_orders
from orders;

