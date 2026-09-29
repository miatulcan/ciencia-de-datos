-- ============================================================
-- NYC Yellow Taxi ELT Pipeline
-- Snowflake infrastructure setup
-- ============================================================
--
-- This script creates the Snowflake objects required by the
-- Bronze -> Silver -> Gold pipeline.
--
-- Run with a role that has sufficient administrative privileges
-- (for the lab environment, ACCOUNTADMIN can be used).
-- ============================================================


-- ------------------------------------------------------------
-- 1. COMPUTE WAREHOUSE
-- ------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS NYC_TAXI_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;


-- ------------------------------------------------------------
-- 2. DATABASE
-- ------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS NYC_TAXI;

USE DATABASE NYC_TAXI;


-- ------------------------------------------------------------
-- 3. MEDALLION ARCHITECTURE SCHEMAS
-- ------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS BRONZE;
CREATE SCHEMA IF NOT EXISTS SILVER;
CREATE SCHEMA IF NOT EXISTS GOLD;


-- ------------------------------------------------------------
-- 4. PIPELINE ROLE
-- ------------------------------------------------------------

CREATE ROLE IF NOT EXISTS NYC_TAXI_ROLE;

GRANT USAGE
    ON WAREHOUSE NYC_TAXI_WH
    TO ROLE NYC_TAXI_ROLE;

GRANT USAGE
    ON DATABASE NYC_TAXI
    TO ROLE NYC_TAXI_ROLE;

GRANT CREATE SCHEMA
    ON DATABASE NYC_TAXI
    TO ROLE NYC_TAXI_ROLE;


-- ------------------------------------------------------------
-- 5. SCHEMA PERMISSIONS
-- ------------------------------------------------------------

GRANT USAGE
    ON SCHEMA NYC_TAXI.BRONZE
    TO ROLE NYC_TAXI_ROLE;

GRANT USAGE
    ON SCHEMA NYC_TAXI.SILVER
    TO ROLE NYC_TAXI_ROLE;

GRANT USAGE
    ON SCHEMA NYC_TAXI.GOLD
    TO ROLE NYC_TAXI_ROLE;


GRANT CREATE TABLE, CREATE VIEW, CREATE STAGE, CREATE FILE FORMAT
    ON SCHEMA NYC_TAXI.BRONZE
    TO ROLE NYC_TAXI_ROLE;

GRANT CREATE TABLE, CREATE VIEW
    ON SCHEMA NYC_TAXI.SILVER
    TO ROLE NYC_TAXI_ROLE;

GRANT CREATE TABLE, CREATE VIEW
    ON SCHEMA NYC_TAXI.GOLD
    TO ROLE NYC_TAXI_ROLE;


-- ------------------------------------------------------------
-- 6. BRONZE FILE FORMAT
-- ------------------------------------------------------------

USE SCHEMA NYC_TAXI.BRONZE;

CREATE FILE FORMAT IF NOT EXISTS PARQUET_FORMAT
    TYPE = PARQUET;


-- ------------------------------------------------------------
-- 7. INTERNAL STAGE
-- ------------------------------------------------------------

CREATE STAGE IF NOT EXISTS YELLOW_TAXI_STAGE
    FILE_FORMAT = PARQUET_FORMAT;


-- ------------------------------------------------------------
-- 8. RAW BRONZE TABLE
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS YELLOW_TAXI_TRIPS_RAW (

    RAW_RECORD VARIANT,

    SOURCE_FILE VARCHAR,
    SOURCE_YEAR INTEGER,
    SOURCE_MONTH INTEGER,

    INGESTED_AT TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()

);


-- ------------------------------------------------------------
-- 9. GRANTS ON EXISTING BRONZE OBJECTS
-- ------------------------------------------------------------

GRANT SELECT, INSERT
    ON TABLE NYC_TAXI.BRONZE.YELLOW_TAXI_TRIPS_RAW
    TO ROLE NYC_TAXI_ROLE;

GRANT USAGE, READ, WRITE
    ON STAGE NYC_TAXI.BRONZE.YELLOW_TAXI_STAGE
    TO ROLE NYC_TAXI_ROLE;

GRANT USAGE
    ON FILE FORMAT NYC_TAXI.BRONZE.PARQUET_FORMAT
    TO ROLE NYC_TAXI_ROLE;


-- ------------------------------------------------------------
-- 10. FUTURE OBJECT GRANTS
-- ------------------------------------------------------------

GRANT SELECT
    ON FUTURE TABLES IN SCHEMA NYC_TAXI.BRONZE
    TO ROLE NYC_TAXI_ROLE;

GRANT SELECT
    ON FUTURE TABLES IN SCHEMA NYC_TAXI.SILVER
    TO ROLE NYC_TAXI_ROLE;

GRANT SELECT
    ON FUTURE TABLES IN SCHEMA NYC_TAXI.GOLD
    TO ROLE NYC_TAXI_ROLE;

GRANT SELECT
    ON FUTURE VIEWS IN SCHEMA NYC_TAXI.SILVER
    TO ROLE NYC_TAXI_ROLE;

GRANT SELECT
    ON FUTURE VIEWS IN SCHEMA NYC_TAXI.GOLD
    TO ROLE NYC_TAXI_ROLE;

SELECT
    'Snowflake infrastructure created successfully' AS status;