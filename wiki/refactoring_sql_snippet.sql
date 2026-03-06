

-- 1: Setup Databases
USE ROLE sysadmin;
CREATE DATABASE raw; -- OPTIONAL: You will likely have your RAW source databases already setup
CREATE DATABASE analytics_1;

-- 2: Setup Warehouses

CREATE WAREHOUSE transform_wh
warehouse_size = small
auto_suspend = 60
auto_resume = true
initially_suspended = true;

-- 3: Setup Roles

USE ROLE securityadmin;
CREATE ROLE transformer_1;

-- 4: Grant Permissions

-- 4A: Grant warehouse usage permissions to new role
GRANT ALL ON WAREHOUSE transform_wh to role transformer_1;

-- 4B: Grant read permissions in the Source DBs to the new role
GRANT USAGE ON DATABASE raw TO ROLE transformer_1; --List out other source DBs that your team would need read access to within dbt

GRANT USAGE ON ALL SCHEMAS IN DATABASE raw TO ROLE transformer_1;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE raw TO ROLE transformer_1;

GRANT SELECT ON ALL TABLES IN DATABASE raw TO ROLE transformer_1;
GRANT SELECT ON FUTURE TABLES IN DATABASE raw TO ROLE transformer_1;

GRANT SELECT ON ALL VIEWS IN DATABASE raw TO ROLE transformer_1;
GRANT SELECT ON FUTURE VIEWS IN DATABASE raw TO ROLE transformer_1;

GRANT IMPORTED PRIVILEGES ON DATABASE snowflake_sample_data TO ROLE transformer_1; -- OPTIONAL: This additional statement is required to read from Snowflake Shared DBs



-- 4C: Grant read + write permissions in the Target DB to the new role

GRANT ALL ON DATABASE analytics_1 TO ROLE transformer_1;

GRANT ALL ON ALL SCHEMAS IN DATABASE analytics_1 TO ROLE transformer_1;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE analytics_1 TO ROLE transformer_1;

GRANT ALL ON ALL TABLES IN DATABASE analytics_1 TO ROLE transformer_1;
GRANT ALL ON FUTURE TABLES IN DATABASE analytics_1 TO ROLE transformer_1;

GRANT ALL ON ALL VIEWS IN DATABASE analytics_1 TO ROLE transformer_1;
GRANT ALL ON FUTURE VIEWS IN DATABASE analytics_1 TO ROLE transformer_1;

-- 4D: Grant new role with permission to dbt users
GRANT ROLE transformer_1 to user dbt_platform_user; -- replace user with relevant user names that require developer access in dbt platform


-- 5: Validate permissions for new role

USE ROLE TRANSFORMER_1;
USE SECONDARY ROLES NONE;

-- Warehouse usage

USE WAREHOUSE transform_wh;

-- Read capabilities

SELECT * FROM RAW.JAFFLE_SHOP.PRODUCTS LIMIT 10 -- replace with a table from your source database defined in Step #4B

-- Write capabilities

USE DATABASE analytics_1

CREATE OR REPLACE SCHEMA dbt_test_user;

CREATE TABLE analytics_1.dbt_test_user.test_table 
AS SELECT 1 AS id, 'sample' AS name;

-- Clean up
DROP SCHEMA dbt_test_user cascade;