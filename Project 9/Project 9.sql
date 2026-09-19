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
-- create scd type 1 customer dimension
create or replace table dim_customer_type1 (
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
segment varchar(50),
effective_date date
);
-- load initial data into scd type 1 table
copy into dim_customer_type1 (
customer_id,
customer_name,
city,
state,
membership,
segment
)
from (
select $1,$2,$3,$4,$5,$6
from @enterprise_stage/customers_initial.csv
)
file_format = enterprise_csv_format
on_error = 'continue';
-- display initial type 1 records
select
customer_id,
customer_name,
city,
state,
membership,
segment
from dim_customer_type1
order by customer_id;
-- load customer updates
copy into customer_updates
from @enterprise_stage/customer_updates.csv
file_format = enterprise_csv_format
on_error = 'continue';
-- display update records
select
customer_id,
customer_name,
city,
state,
membership,
segment,
effective_date
from customer_updates
order by customer_id;
-- apply scd type 1 updates
update dim_customer_type1 d
set
customer_name = u.customer_name,
city = u.city,
state = u.state,
membership = u.membership,
segment = u.segment
from customer_updates u
where d.customer_id = u.customer_id;
-- display scd type 1 result
select
customer_id,
customer_name,
city,
state,
membership,
segment
from dim_customer_type1
order by customer_id;
-- demonstrate type 1 history loss for customer 101
select
customer_id,
city,
state,
membership
from dim_customer_type1
where customer_id = 101;
-- create scd type 2 customer dimension
create or replace table dim_customer_type2 (
customer_key int autoincrement start 1 increment 1,
customer_id int,
customer_name varchar(100),
city varchar(100),
state varchar(100),
membership varchar(50),
segment varchar(50),
effective_date date,
expiry_date date,
is_current boolean
);
-- load initial records into scd type 2 table
copy into dim_customer_type2 (
customer_id,
customer_name,
city,
state,
membership,
segment,
effective_date,
expiry_date,
is_current
)
from (
select$1,$2,$3,$4,$5,$6,
to_date('2026-01-01'),
to_date('9999-12-31'),
true
from @enterprise_stage/customers_initial.csv
)
file_format = enterprise_csv_format
on_error = 'continue';
-- verify initial type 2 records
select
count(*) as total_records,
count_if(is_current = true) as current_records
from dim_customer_type2;
-- expire existing records for changed customers
update dim_customer_type2 d
set
expiry_date = dateadd(day, -1, u.effective_date),
is_current = false
from customer_updates u
where d.customer_id = u.customer_id
and d.is_current = true
and (
d.city <> u.city
or d.state <> u.state
or d.membership <> u.membership
or d.segment <> u.segment
);
-- insert new versions for changed customers
insert into dim_customer_type2 (
customer_id,
customer_name,
city,
state,
membership,
segment,
effective_date,
expiry_date,
is_current
)
select
u.customer_id,
u.customer_name,
u.city,
u.state,
u.membership,
u.segment,
u.effective_date,
to_date('9999-12-31'),
true
from customer_updates u;
-- display customer 101 type 2 history
select
customer_id,
city,
membership,
effective_date,
expiry_date,
is_current
from dim_customer_type2
where customer_id = 101
order by effective_date;
-- display customer 103 type 2 history
select
customer_id,
city,
membership,
effective_date,
expiry_date,
is_current
from dim_customer_type2
where customer_id = 103
order by effective_date;
-- display customer 104 type 2 history
select
customer_id,
city,
membership,
effective_date,
expiry_date,
is_current
from dim_customer_type2
where customer_id = 104
order by effective_date;
-- display complete type 2 history
select
customer_id,
customer_name,
city,
state,
membership,
segment,
effective_date,
expiry_date,
is_current
from dim_customer_type2
order by customer_id, effective_date;
-- display current customer records
select
customer_id,
customer_name,
city,
state,
membership,
segment
from dim_customer_type2
where is_current = true
order by customer_id;
-- historical customer analysis
-- customer 101 membership on march 15, 2026
select
customer_id,
customer_name,
membership,
city,
effective_date,
expiry_date
from dim_customer_type2
where customer_id = 101
and to_date('2026-03-15') between effective_date and expiry_date;
-- compare scd type 1 and type 2
select
'SCD TYPE 1' as scd_type,
'Old Value' as feature,
'Overwritten' as result
union all
select
'SCD TYPE 1',
'History',
'Not Preserved'
union all
select
'SCD TYPE 1',
'New Row',
'No'
union all
select
'SCD TYPE 2',
'Old Value',
'Preserved'
union all
select
'SCD TYPE 2',
'History',
'Preserved'
union all
select
'SCD TYPE 2',
'New Row',
'Yes'
union all
select
'SCD TYPE 2',
'Effective Date',
'Yes'
union all
select
'SCD TYPE 2',
'Expiry Date',
'Yes'
union all
select
'SCD TYPE 2',
'IS_CURRENT',
'Yes';
-- scd type 1 record count
select
count(*) as scd_type1_record_count
from dim_customer_type1;
-- scd type 2 total record count
select
count(*) as scd_type2_record_count
from dim_customer_type2;
-- scd type 2 current record count
select
count(*) as scd_type2_current_record_count
from dim_customer_type2
where is_current = true;
-- scd type 2 historical record count
select
count(*) as scd_type2_historical_record_count
from dim_customer_type2
where is_current = false;
-- final validation
select
(select count(*) from dim_customer_type1) as scd_type1_records,
(select count(*) from dim_customer_type2) as scd_type2_records,
(select count(*) from dim_customer_type2 where is_current = true) as scd_type2_current_records,
(select count(*) from dim_customer_type2 where is_current = false) as scd_type2_historical_records;