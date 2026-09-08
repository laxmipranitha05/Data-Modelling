-- create warehouse
create or replace warehouse enterprise_wh with
warehouse_size = 'xsmall'
auto_suspend = 60
auto_resume = true;
-- use warehouse
use warehouse enterprise_wh;
-- create database
create or replace database enterprise_db;
-- use database
use database enterprise_db;
-- create schema
create or replace schema sales_schema;
-- use schema
use schema sales_schema;
-- create csv file format
create or replace file format enterprise_csv_format
type = csv
field_delimiter = ','
skip_header = 1
field_optionally_enclosed_by = '"'
null_if = ('null', '');
-- create internal stage
create or replace stage enterprise_stage
file_format = enterprise_csv_format;
-- upload the following files using snowflake ui: customers.csv, products.csv, branches.csv, sales_history.csv, new_sales.csv
-- verify files in stage
list @enterprise_stage;
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
state varchar(100)
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
-- create staging table for new sales
create or replace table new_sales_staging (
sale_id int,
customer_id int,
product_id int,
branch_id int,
quantity int,
sale_date date,
total_amount decimal(12,2)
);
-- load customers data
copy into customers
from @enterprise_stage/customers.csv
file_format = enterprise_csv_format
on_error = 'continue';
-- load products data
copy into products
from @enterprise_stage/products.csv
file_format = enterprise_csv_format
on_error = 'continue';
-- load branches data
copy into branches
from @enterprise_stage/branches.csv
file_format = enterprise_csv_format
on_error = 'continue';
-- load historical sales data
copy into sales
from @enterprise_stage/sales_history.csv
file_format = enterprise_csv_format
on_error = 'continue';
-- verify loaded customers
select * from customers;
-- verify loaded products
select * from products;
-- verify loaded branches
select * from branches;
-- verify historical sales
select * from sales
order by sale_id;
-- verify record counts
select count(*) as total_customers
from customers;
select count(*) as total_products
from products;
select count(*) as total_branches
from branches;
select count(*) as historical_sales_count
from sales;
-- create stream on sales table
create or replace stream sales_stream
on table sales;
-- load new sales into staging table
copy into new_sales_staging
from @enterprise_stage/new_sales.csv
file_format = enterprise_csv_format
on_error = 'continue';
-- display newly loaded staging records
select *
from new_sales_staging
order by sale_id;
-- merge newly arrived records into sales table
merge into sales target
using new_sales_staging source
on target.sale_id = source.sale_id
when not matched then
insert (
sale_id,
customer_id,
product_id,
branch_id,
quantity,
sale_date,
total_amount
)
values (
source.sale_id,
source.customer_id,
source.product_id,
source.branch_id,
source.quantity,
source.sale_date,
source.total_amount
);
-- display newly inserted records using stream
select *
from sales_stream
where metadata$action = 'insert'
and metadata$isupdate = false;
-- count total newly inserted records
select count(*) as total_newly_inserted_records
from sales_stream
where metadata$action = 'insert'
and metadata$isupdate = false;
-- verify incremental load
select *
from sales
order by sale_id;
-- identify duplicate sale ids
select
sale_id,
count(*) as duplicate_count
from sales
group by sale_id
having count(*) > 1;
-- identify missing customer ids
select
s.sale_id,
s.customer_id
from sales s
left join customers c
on s.customer_id = c.customer_id
where c.customer_id is null;
-- display invalid product ids
select
s.sale_id,
s.product_id
from sales s
left join products p
on s.product_id = p.product_id
where p.product_id is null;
-- count total sales records
select count(*) as total_sales_records
from sales;
-- delete one sales record for time travel demonstration
delete from sales
where sale_id = 10;
-- verify deleted record
select * from sales
where sale_id = 10;
-- recover deleted record using time travel
insert into sales
select * from sales
before (statement => last_query_id())
where sale_id = 10;
-- verify recovery
select * from sales
where sale_id = 10;
-- create zero copy clone
create or replace table sales_test
clone sales;
-- display cloned records
select * from sales_test
order by sale_id;
-- insert new record into clone
insert into sales_test (
sale_id,
customer_id,
product_id,
branch_id,
quantity,
sale_date,
total_amount
)
values (
11,
1,
103,
1,
2,
'2026-07-11',
3000
);
-- verify clone after insertion
select * from sales_test
order by sale_id;
-- verify original table remains unchanged
select * from sales
order by sale_id;
-- compare original and clone record counts
select count(*) as original_sales_count
from sales;
select count(*) as cloned_sales_count
from sales_test;
-- create task for daily incremental loading
create or replace task incremental_sales_task
warehouse = enterprise_wh
schedule = 'using cron 0 0 * * * utc'
as
merge into sales target
using new_sales_staging source
on target.sale_id = source.sale_id
when not matched then
insert (
sale_id,
customer_id,
product_id,
branch_id,
quantity,
sale_date,
total_amount
)
values (
source.sale_id,
source.customer_id,
source.product_id,
source.branch_id,
source.quantity,
source.sale_date,
source.total_amount
);
-- resume task
alter task incremental_sales_task resume;
-- verify task status
show tasks;
-- verify task execution history
select *
from table(information_schema.task_history())
where name = 'INCREMENTAL_SALES_TASK'
order by scheduled_time desc;
-- customer revenue report
select
c.customer_id,
c.customer_name,
c.city,
c.membership,
sum(s.total_amount) as total_revenue
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name,
c.city,
c.membership
order by total_revenue desc;
-- branch revenue report
select
b.branch_id,
b.branch_name,
b.state,
sum(s.total_amount) as total_revenue
from branches b
join sales s
on b.branch_id = s.branch_id
group by
b.branch_id,
b.branch_name,
b.state
order by total_revenue desc;
-- product revenue report
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
-- monthly revenue report
select
date_trunc('month', sale_date) as sales_month,
sum(total_amount) as monthly_revenue
from sales
group by date_trunc('month', sale_date)
order by sales_month;
-- highest revenue customer
select
c.customer_id,
c.customer_name,
sum(s.total_amount) as total_revenue
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name
order by total_revenue desc
limit 1;
-- highest revenue branch
select
b.branch_id,
b.branch_name,
sum(s.total_amount) as total_revenue
from branches b
join sales s
on b.branch_id = s.branch_id
group by
b.branch_id,
b.branch_name
order by total_revenue desc
limit 1;
-- top five products
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
order by total_revenue desc
limit 5;
-- top five customers
select
c.customer_id,
c.customer_name,
sum(s.total_amount) as total_revenue
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name
order by total_revenue desc
limit 5;
-- customer purchase frequency
select
c.customer_id,
c.customer_name,
count(s.sale_id) as purchase_frequency
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name
order by purchase_frequency desc;
-- running revenue
select
sale_id,
sale_date,
total_amount,
sum(total_amount) over (
order by sale_date, sale_id
rows between unbounded preceding and current row
) as running_revenue
from sales
order by sale_date, sale_id;
-- customer ranking
select
customer_id,
customer_name,
total_revenue,
rank() over (
order by total_revenue desc
) as customer_rank
from (
select
c.customer_id,
c.customer_name,
sum(s.total_amount) as total_revenue
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name
);
-- customer revenue using cte
with customer_revenue_data as (
select
c.customer_id,
c.customer_name,
sum(s.total_amount) as total_revenue
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name
)
select *
from customer_revenue_data
order by total_revenue desc;
-- customers spending above average
with customer_revenue_data as (
select
c.customer_id,
c.customer_name,
sum(s.total_amount) as total_revenue
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name
)
select
customer_id,
customer_name,
total_revenue
from customer_revenue_data
where total_revenue > (
select avg(total_revenue)
from customer_revenue_data
)
order by total_revenue desc;
-- create customer revenue view
create or replace view customer_revenue as
select
c.customer_id,
c.customer_name,
c.city,
c.membership,
sum(s.total_amount) as total_revenue
from customers c
join sales s
on c.customer_id = s.customer_id
group by
c.customer_id,
c.customer_name,
c.city,
c.membership;
-- display customer revenue view
select * from customer_revenue
order by total_revenue desc;
-- create branch revenue materialized view
create or replace materialized view branch_revenue as
select
branch_id,
sum(total_amount) as total_revenue
from sales
group by branch_id;
-- display branch revenue materialized view
select
br.branch_id,
b.branch_name,
b.state,
br.total_revenue
from branch_revenue br
join branches b
on br.branch_id = b.branch_id
order by br.total_revenue desc;
-- additional verification queries
-- verify final sales records
select * from sales
order by sale_id;
-- verify final sales count
select count(*) as final_sales_count
from sales;
-- verify total business revenue
select sum(total_amount) as total_business_revenue
from sales;
-- verify stream records
select * from sales_stream;
-- verify customer revenue
select * from customer_revenue
order by total_revenue desc;
-- verify branch revenue
select * from branch_revenue
order by total_revenue desc;