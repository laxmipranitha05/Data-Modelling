-- create warehouse
create or replace warehouse enterprise_wh
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
create or replace schema scd_schema;
-- use schema
use schema scd_schema;
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
-- upload the following files using snowflake ui : customers_initial.csv, customer_updates.csv
-- verify files in stage
list @enterprise_stage;
-- create customer dimension table
create or replace table dim_customer (
customer_key int autoincrement start 1 increment 1,
customer_id int,
customer_name varchar(100),
city varchar(100),
state varchar(100),
membership varchar(50),
segment varchar(50)
);
-- create customer updates staging table
create or replace table customer_updates (
customer_id int,
customer_name varchar(100),
city varchar(100),
state varchar(100),
membership varchar(50),
segment varchar(50)
);
-- load initial customer data
copy into dim_customer (
customer_id,
customer_name,
city,
state,
membership,
segment
)
from (
select $1,$2,$3,$4,$5,$6 from @enterprise_stage/customers_initial.csv
)
file_format = enterprise_csv_format
on_error = 'continue';
-- verify initial customer records loaded
select count(*) as total_customers
from dim_customer;
-- display initial customer dimension
select
customer_id,
customer_name,
city,
state,
membership,
segment
from dim_customer
order by customer_id;
-- load customer updates into staging table
copy into customer_updates
from @enterprise_stage/customer_updates.csv
file_format = enterprise_csv_format
on_error = 'continue';
-- verify customer update records loaded
select count(*) as records_received
from customer_updates;
-- display customer updates
select
customer_id,
customer_name,
city,
state,
membership,
segment
from customer_updates
order by customer_id;
-- identify changed customers
select
d.customer_id,
d.city as old_city,
u.city as new_city,
d.membership as old_membership,
u.membership as new_membership
from dim_customer d
join customer_updates u
on d.customer_id = u.customer_id
where d.city <> u.city
or d.state <> u.state
or d.membership <> u.membership
or d.segment <> u.segment
order by d.customer_id;
-- identify attribute changes
select
d.customer_id,
'city' as attribute,
d.city as old_value,
u.city as new_value
from dim_customer d
join customer_updates u
on d.customer_id = u.customer_id
where d.city <> u.city

union all

select
d.customer_id,
'state' as attribute,
d.state as old_value,
u.state as new_value
from dim_customer d
join customer_updates u
on d.customer_id = u.customer_id
where d.state <> u.state

union all

select
d.customer_id,
'membership' as attribute,
d.membership as old_value,
u.membership as new_value
from dim_customer d
join customer_updates u
on d.customer_id = u.customer_id
where d.membership <> u.membership

union all

select
d.customer_id,
'segment' as attribute,
d.segment as old_value,
u.segment as new_value
from dim_customer d
join customer_updates u
on d.customer_id = u.customer_id
where d.segment <> u.segment
order by customer_id, attribute;
-- update existing dimension records
-- this demonstrates the scd problem
update dim_customer d
set
customer_name = u.customer_name,
city = u.city,
state = u.state,
membership = u.membership,
segment = u.segment
from customer_updates u
where d.customer_id = u.customer_id;
-- display updated customer dimension
select
customer_id,
customer_name,
city,
state,
membership,
segment
from dim_customer
order by customer_id;
-- demonstrate historical data loss for customer 101
select
customer_id,
customer_name,
city,
state,
membership
from dim_customer
where customer_id = 101;
-- verify current information for customer 101
select
customer_id,
customer_name,
city as current_city,
state as current_state,
membership as current_membership
from dim_customer
where customer_id = 101;
-- business impact analysis
select
101 as customer_id,
'Hyderabad' as original_city,
'Bengaluru' as current_city,
'Silver' as original_membership,
'Gold' as current_membership;
-- demonstrate historical information lost
select
customer_id,
customer_name,
city,
state,
membership,
'historical information is not available because the original record was overwritten' as historical_status
from dim_customer
where customer_id = 101;
-- final dimension verification
select
customer_key,
customer_id,
customer_name,
city,
state,
membership,
segment
from dim_customer
order by customer_id;