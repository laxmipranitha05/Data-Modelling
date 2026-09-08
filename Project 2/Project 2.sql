-- create warehouse
create or replace warehouse retail_wh with
warehouse_size = 'xsmall'
auto_suspend = 60
auto_resume = true;
-- use warehouse
use warehouse retail_wh;
-- create database
create or replace database retail_db;
-- use database
use database retail_db;
-- create schema
create or replace schema sales_schema;
-- use schema
use schema sales_schema;
-- create csv file format
create or replace file format retail_csv_format
type = csv
field_delimiter = ','
skip_header = 1
field_optionally_enclosed_by = '"'
null_if = ('null', '');
-- create internal stage
create or replace stage retail_stage
file_format = retail_csv_format;
-- create customers table
create or replace table customers (
customer_id int,
customer_name varchar(100),
city varchar(100),
membership varchar(50)
);
-- create products table
create or replace table products (
product_id int,
product_name varchar(100),
category varchar(100),
price decimal(12,2)
);
-- create branches table
create or replace table branches (
branch_id int,
branch_name varchar(100),
city varchar(100)
);
-- create sales table
create or replace table sales (
sale_id int,
customer_id int,
product_id int,
branch_id int,
quantity int,
sale_date date,
total_amount decimal(12,2)
);
-- upload the following files using snowflake ui:customers.csv, products.csv, branches.csv, sales.csv
-- verify files available in stage
list @retail_stage;
-- load customers data
copy into customers
from @retail_stage/customers.csv
file_format = retail_csv_format
on_error = 'continue';
-- load products data
copy into products
from @retail_stage/products.csv
file_format = retail_csv_format
on_error = 'continue';
-- load branches data
copy into branches
from @retail_stage/branches.csv
file_format = retail_csv_format
on_error = 'continue';
-- load sales data
copy into sales
from @retail_stage/sales.csv
file_format = retail_csv_format
on_error = 'continue';
-- verify imported records
select * from customers;
select * from products;
select * from branches;
select * from sales;
-- verify record counts
select count(*) as total_customers from customers;
select count(*) as total_products from products;
select count(*) as total_branches from branches;
select count(*) as total_sales from sales;
-- all customers
select * from customers;
-- all products
select * from products;
-- all branches
select * from branches;
-- all sales transactions
select * from sales;
-- calculate total business revenue
select sum(total_amount) as total_business_revenue from sales;
-- customer-wise sales report
select
c.customer_id,
c.customer_name,
c.city,
c.membership,
sum(s.total_amount) as total_spending
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name,
c.city,
c.membership
order by total_spending desc;
-- branch-wise revenue report
select
b.branch_id,
b.branch_name,
b.city,
sum(s.total_amount) as total_revenue
from branches b
join sales s
on b.branch_id = s.branch_id
group by
b.branch_id,
b.branch_name,
b.city
order by total_revenue desc;
-- product-wise revenue report
select
p.product_id,
p.product_name,
p.category,
sum(s.total_amount) as total_revenue
from products p
join sales s
on p.product_id = s.product_id
group by
p.product_id,
p.product_name,
p.category
order by total_revenue desc;
-- category-wise revenue report
select
p.category,
sum(s.total_amount) as total_revenue
from products p
join sales s
on p.product_id = s.product_id
group by p.category
order by total_revenue desc;
-- highest revenue branch
select
b.branch_name,
sum(s.total_amount) as total_revenue
from branches b
join sales s
on b.branch_id = s.branch_id
group by b.branch_name
order by total_revenue desc
limit 1;
-- highest spending customer
select
c.customer_name,
sum(s.total_amount) as total_spending
from customers c
join sales s
on c.customer_id = s.customer_id
group by c.customer_name
order by total_spending desc
limit 1;
-- top three products by revenue
select
p.product_name,
p.category,
sum(s.total_amount) as total_revenue
from products p
join sales s
on p.product_id = s.product_id
group by
p.product_name,
p.category
order by total_revenue desc
limit 3;
-- top three customers by spending
select
c.customer_name,
sum(s.total_amount) as total_spending
from customers c
join sales s
on c.customer_id = s.customer_id
group by c.customer_name
order by total_spending desc
limit 3;
-- rank customers based on total spending
select
customer_id,
customer_name,
total_spending,
rank() over (order by total_spending desc) as customer_rank
from (
select
c.customer_id,
c.customer_name,
sum(s.total_amount) as total_spending
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name
);
-- rank branches based on total sales
select
branch_id,
branch_name,
total_sales,
rank() over (order by total_sales desc) as branch_rank
from (
select
b.branch_id,
b.branch_name,
sum(s.total_amount) as total_sales
from branches b
join sales s
on b.branch_id = s.branch_id
group by
b.branch_id,
b.branch_name
);
-- top-selling product in each category using row_number
select
product_id,
product_name,
category,
total_revenue
from (
select
p.product_id,
p.product_name,
p.category,
sum(s.total_amount) as total_revenue,
row_number() over (
partition by p.category
order by sum(s.total_amount) desc
) as row_num
from products p
join sales s
on p.product_id = s.product_id
group by
p.product_id,
p.product_name,
p.category
)
where row_num = 1;
-- calculate cumulative sales using sum over
select
sale_id,
sale_date,
total_amount,
sum(total_amount) over (
order by sale_date
rows between unbounded preceding and current row
) as cumulative_sales
from sales
order by sale_date;
-- calculate average sale amount using avg over
select
sale_id,
customer_id,
sale_date,
total_amount,
avg(total_amount) over () as average_sale_amount
from sales
order by sale_id;
-- customer-wise revenue using cte
with customer_revenue as (
select
c.customer_id,
c.customer_name,
sum(s.total_amount) as total_spending
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name
)
select *
from customer_revenue
order by total_spending desc;
-- customers whose spending is greater than average spending
with customer_revenue as (
select
c.customer_id,
c.customer_name,
sum(s.total_amount) as total_spending
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name
),
average_spending as (
select avg(total_spending) as avg_spending
from customer_revenue
)
select
cr.customer_id,
cr.customer_name,
cr.total_spending
from customer_revenue cr
cross join average_spending av
where cr.total_spending > av.avg_spending
order by cr.total_spending desc;
-- create sales report view
create or replace view sales_report as
select
s.sale_id,
s.sale_date,
c.customer_id,
c.customer_name,
c.city as customer_city,
c.membership,
p.product_id,
p.product_name,
p.category,
p.price,
b.branch_id,
b.branch_name,
b.city as branch_city,
s.quantity,
s.total_amount
from sales s
join customers c
on s.customer_id = c.customer_id
join products p
on s.product_id = p.product_id
join branches b
on s.branch_id = b.branch_id;
-- query sales report view
select *
from sales_report
order by sale_date;
-- create materialized view
create or replace materialized view top_customers as
select
customer_id,
sum(total_amount) as total_spending
from sales
group by customer_id;
-- query materialized view
select
tc.customer_id,
c.customer_name,
tc.total_spending
from top_customers tc
join customers c
on tc.customer_id = c.customer_id
order by tc.total_spending desc;
-- additional verification queries
-- verify total revenue
select sum(total_amount) as total_revenue
from sales;
-- verify customer revenue
select
customer_id,
sum(total_amount) as customer_revenue
from sales
group by customer_id
order by customer_revenue desc;
-- verify branch revenue
select
branch_id,
sum(total_amount) as branch_revenue
from sales
group by branch_id
order by branch_revenue desc;
-- verify product revenue
select
product_id,
sum(total_amount) as product_revenue
from sales
group by product_id
order by product_revenue desc;
-- verify category revenue
select
p.category,
sum(s.total_amount) as category_revenue
from sales s
join products p
on s.product_id = p.product_id
group by p.category
order by category_revenue desc;
