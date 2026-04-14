# Bewell Hospital ETL Pipeline - Complete Setup Guide

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Snowflake Setup](#snowflake-setup)
3. [dbt Installation](#dbt-installation)
4. [Data Loading](#data-loading)
5. [Running the Pipeline](#running-the-pipeline)
6. [Validation and Testing](#validation-and-testing)
7. [Query Examples](#query-examples)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements
- Windows 10+ / macOS / Linux
- Python 3.8 or higher
- Git (optional)
- Snowflake account with:
  - ACCOUNTADMIN or equivalent role
  - Ability to create databases and warehouses

### Tools to Install
1. **Python** - Download from [python.org](https://www.python.org/downloads/)
2. **pip** - Usually comes with Python
3. **dbt CLI** - Install via pip

### Check Installation
```bash
python --version
pip --version
```

---

## Snowflake Setup

### Step 1: Create Database & Warehouse

Log into Snowflake web console and run:

```sql
-- Create database
CREATE DATABASE BEWELL_HOSPITAL_DB;
CREATE DATABASE BEWELL_HOSPITAL_PROD;

-- Create warehouse
CREATE WAREHOUSE COMPUTE_WH
WITH
  WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

-- Create role
CREATE ROLE TRANSFORMER;

-- Grant permissions
GRANT USAGE ON DATABASE BEWELL_HOSPITAL_DB TO ROLE TRANSFORMER;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE TRANSFORMER;
GRANT CREATE SCHEMA ON DATABASE BEWELL_HOSPITAL_DB TO ROLE TRANSFORMER;

-- Assign role to your user
GRANT ROLE TRANSFORMER TO USER <your_username>;
```

### Step 2: Create Raw Data Schema

```sql
-- Create schema for raw data
CREATE SCHEMA BEWELL_HOSPITAL_DB.raw_hospital;

-- Create stage for file uploads
CREATE STAGE BEWELL_HOSPITAL_DB.raw_hospital.hospital_stage;

-- Grant permissions
GRANT ALL ON SCHEMA BEWELL_HOSPITAL_DB.raw_hospital TO ROLE TRANSFORMER;
```

### Step 3: Gather Snowflake Connection Details

You'll need:
- Account ID (e.g., `xy12345.us-east-1`)
- Username
- Password
- Warehouse name: `COMPUTE_WH`
- Database: `BEWELL_HOSPITAL_DB`
- Role: `TRANSFORMER`

---

## dbt Installation

### Step 1: Install dbt and Dependencies

```bash
# Navigate to project directory
cd dbt_project

# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install requirements
pip install -r requirements.txt
```
#Or use below for installation
pip install dbt-snowflake

### Step 2: Configure Snowflake Connection

Create/Edit `~/.dbt/profiles.yml` (or copy from project):

```yaml
bewell_hospital:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: xy12345.us-east-1  # Your account ID
      user: your_username
      password: your_password
      role: TRANSFORMER
      database: BEWELL_HOSPITAL_DB
      schema: public
      threads: 4
      client_session_keep_alive: False
      warehouse: COMPUTE_WH
    prod:
      type: snowflake
      account: xy12345.us-east-1
      user: your_username
      password: your_password
      role: TRANSFORMER
      database: BEWELL_HOSPITAL_PROD
      schema: public
      threads: 8
      client_session_keep_alive: False
      warehouse: COMPUTE_WH
```

### Step 3: Test Connection

```bash
dbt debug

# Output should show:
# All checks passed! ✓
```

If you see errors, check:
- Snowflake credentials are correct
- Warehouse is running
- Role has correct permissions
- Network connectivity to Snowflake

---

## Data Loading

### Step 1: Upload CSV to Snowflake

**Option A: Using Snowflake Web UI**
1. Log into Snowflake
2. Navigate to Data → Databases → BEWELL_HOSPITAL_DB
3. Go to raw_hospital schema
4. Click hospital_stage
5. Upload `hospital_management_data.csv`

**Option B: Using SnowSQL**
```bash
cd /path/to/hospital_management_data.csv_location

snowsql -a xy12345.us-east-1 -u your_username

-- Inside SnowSQL:
USE DATABASE BEWELL_HOSPITAL_DB;
USE SCHEMA raw_hospital;

PUT file:///path/to/hospital_management_data.csv 
    @hospital_stage/;
```

**Option C: Using Python/Snowflake connector**
```python
from snowflake.connector import connect

conn = connect(
    account='xy12345.us-east-1',
    user='your_username',
    password='your_password',
    warehouse='COMPUTE_WH',
    database='BEWELL_HOSPITAL_DB',
    schema='raw_hospital'
)

# Upload using PUT
cursor = conn.cursor()
cursor.execute("""
    PUT file:///path/to/hospital_management_data.csv 
    @hospital_stage
""")
```

### Step 2: Create Raw Table

Run in Snowflake:

```sql
CREATE TABLE BEWELL_HOSPITAL_DB.raw_hospital.hospital_management_data (
    Patient_ID FLOAT,
    Patient_Name VARCHAR,
    Age FLOAT,
    Gender VARCHAR,
    City VARCHAR,
    Department VARCHAR,
    Doctor_Name VARCHAR,
    Admission_Date VARCHAR,
    Discharge_Date VARCHAR,
    Diagnosis VARCHAR,
    Insurance_Provider VARCHAR,
    Insurance_Coverage FLOAT,
    Total_Bill FLOAT,
    Payment_Done FLOAT,
    Payment_Method VARCHAR
);

-- Load data from stage
COPY INTO BEWELL_HOSPITAL_DB.RAW_HOSPITAL.HOSPITAL_MANAGEMENT_DATA
FROM @BEWELL_HOSPITAL_DB.RAW_HOSPITAL.HOSPITAL_STAGE/hospital_management_data.csv
FILE_FORMAT = (
    TYPE = 'CSV',
    SKIP_HEADER = 1,
    FIELD_DELIMITER = ','
)
ON_ERROR = CONTINUE;


-- Verify
SELECT COUNT(*) FROM BEWELL_HOSPITAL_DB.RAW_HOSPITAL.HOSPITAL_MANAGEMENT_DATA;
```

### Step 3: Update Sources in dbt

Edit `models/sources.yml` if your source location differs from above.

---

## Running the Pipeline

### Step 1: Parse Project

```bash
dbt parse

# Verifies dbt can read all files
```

### Step 2: Run Models

```bash
# Run all models
dbt run

# Run specific model
dbt run -s psa_hospital_admission

# Run models in specific directory
dbt run -s path:models/staging

# Run with full refresh
dbt run --full-refresh
```

### Step 3: Build (Run + Test)

```bash
# Run all models and tests
dbt build

# With specific selection
dbt build -s fact_patient_visit
```

### Expected Output

```
Running with dbt==1.8.0
Compiling...
  psa_hospital_admission
  stg_hospital_admission
  dim_patient
  dim_doctor
  dim_location
  dim_insurance
  dim_department
  fact_patient_visit

Running with dbt==1.8.0
Creating table BEWELL_HOSPITAL_DB.psa_hospital.psa_hospital_admission ... [OK in 2.15s]
Creating view BEWELL_HOSPITAL_DB.stg_hospital.stg_hospital_admission ... [OK in 1.50s]
Creating table BEWELL_HOSPITAL_DB.dl3_hospital.dim_patient ... [OK in 1.20s]
Creating table BEWELL_HOSPITAL_DB.dl3_hospital.dim_doctor ... [OK in 0.95s]
Creating table BEWELL_HOSPITAL_DB.dl3_hospital.dim_location ... [OK in 0.80s]
Creating table BEWELL_HOSPITAL_DB.dl3_hospital.dim_insurance ... [OK in 0.85s]
Creating table BEWELL_HOSPITAL_DB.dl3_hospital.dim_department ... [OK in 0.90s]
Creating table BEWELL_HOSPITAL_DB.dl3_hospital.fact_patient_visit ... [OK in 2.50s]

Done. [8 created in 15.23s]
```

---

## Validation and Testing

### Run Data Quality Tests

```bash
dbt test

# Test specific model
dbt test -s stg_hospital_admission

# Show test results
dbt test --store-failures
```

### Query to Validate Data

```sql
-- Check record counts
SELECT 'PSA' as layer, COUNT(*) as record_count 
FROM BEWELL_HOSPITAL_DB.PUBLIC_PSA_HOSPITAL.psa_hospital_admission

UNION ALL

SELECT 'Staging', COUNT(*) 
FROM BEWELL_HOSPITAL_DB.PUBLIC_STG_HOSPITAL.stg_hospital_admission

UNION ALL

SELECT 'Fact Table', COUNT(*) 
FROM BEWELL_HOSPITAL_DB.PUBLIC_DL3_HOSPITAL.fact_patient_visit;

-- Check data quality
SELECT 
    COUNT(*) as total,
    SUM(is_invalid_age) as invalid_ages,
    SUM(is_bill_negative) as negative_bills,
    SUM(is_payment_mismatch) as mismatches,
    ROUND(AVG(data_quality_score), 2) as avg_quality
FROM BEWELL_HOSPITAL_DB.dl3_hospital.fact_patient_visit;
```

### Generate Documentation

```bash
# Generate dbt documentation
dbt docs generate

# Serve documentation locally
dbt docs serve

# Access at http://localhost:8000
```

---

## Query Examples

### 1. Revenue Analysis by City

```sql
SELECT 
    loc.city_name,
    COUNT(*) as visit_count,
    SUM(fv.total_bill_amount) as total_revenue,
    AVG(fv.total_bill_amount) as avg_bill,
    SUM(fv.payment_done_amount) as total_collected
FROM BEWELL_HOSPITAL_DB.dl3_hospital.fact_patient_visit fv
JOIN BEWELL_HOSPITAL_DB.dl3_hospital.dim_location loc 
    ON fv.dim_location_id = loc.dim_location_id
GROUP BY loc.city_name
ORDER BY total_revenue DESC;
```

### 2. Insurance Coverage Analysis

```sql
SELECT 
    ins.insurance_provider,
    COUNT(*) as claims,
    SUM(fv.insurance_coverage_amount) as total_paid,
    SUM(fv.total_bill_amount) as total_billed,
    ROUND(SUM(fv.insurance_coverage_amount) / SUM(fv.total_bill_amount), 2) as coverage_ratio
FROM BEWELL_HOSPITAL_DB.dl3_hospital.fact_patient_visit fv
JOIN BEWELL_HOSPITAL_DB.dl3_hospital.dim_insurance ins 
    ON fv.dim_insurance_id = ins.dim_insurance_id
WHERE ins.insurance_provider != 'Uninsured'
GROUP BY ins.insurance_provider
ORDER BY total_billed DESC;
```

### 3. Department Performance

```sql
SELECT 
    dept.department_name,
    COUNT(*) as total_visits,
    ROUND(AVG(fv.total_bill_amount), 2) as avg_bill,
    ROUND(AVG(fv.length_of_stay_days), 1) as avg_los,
    COUNT(DISTINCT fv.dim_patient_id) as unique_patients
FROM BEWELL_HOSPITAL_DB.dl3_hospital.fact_patient_visit fv
JOIN BEWELL_HOSPITAL_DB.dl3_hospital.dim_department dept 
    ON fv.dim_department_id = dept.dim_department_id
GROUP BY dept.department_name
ORDER BY total_visits DESC;
```

### 4. Patient Demographics

```sql
SELECT 
    fv.age_group,
    fv.gender,
    COUNT(*) as visit_count,
    ROUND(AVG(fv.total_bill_amount), 2) as avg_bill,
    ROUND(AVG(fv.length_of_stay_days), 1) as avg_los
FROM BEWELL_HOSPITAL_DB.dl3_hospital.fact_patient_visit fv
GROUP BY fv.age_group, fv.gender
ORDER BY age_group, gender;
```

### 5. Data Quality Dashboard

```sql
SELECT 
    COUNT(*) as total_records,
    ROUND(100.0 * SUM(is_invalid_age) / COUNT(*), 2) as pct_invalid_age,
    ROUND(100.0 * SUM(is_bill_negative) / COUNT(*), 2) as pct_negative_bill,
    ROUND(100.0 * SUM(is_payment_mismatch) / COUNT(*), 2) as pct_mismatch,
    ROUND(100.0 * SUM(is_invalid_date) / COUNT(*), 2) as pct_invalid_date,
    ROUND(AVG(data_quality_score), 3) as avg_quality_score
FROM BEWELL_HOSPITAL_DB.dl3_hospital.fact_patient_visit;
```

---

## Troubleshooting

### Issue: Connection Failed
**Error**: `Database Error in profile.yml`

**Solution**:
```bash
# Test credentials
dbt debug

# Verify:
# 1. Account ID format (e.g., xy12345.us-east-1)
# 2. Username exists and has TRANSFORMER role
# 3. Password is correct
# 4. Warehouse is running
# 5. Network can reach Snowflake (try web console first)
```

### Issue: Model Fails with "Source Not Found"
**Error**: `Description "source 'bewell_hospital_raw'" not found`

**Solution**:
```bash
# Verify source table exists:
# 1. Check table name in sources.yml matches Snowflake
# 2. Run: SELECT * FROM raw_hospital.hospital_management_data LIMIT 1
# 3. Recreate table if needed
```

### Issue: dbt-utils Not Found
**Error**: `Module dbt_utils not found`

**Solution**:
```bash
pip install dbt-utils==1.1.1
dbt deps  # Install dbt dependencies
dbt run   # Try again
```

### Issue: Staging Table Returns 0 Rows
**Error**: Staging table is empty despite data in PSA

**Solution**:
```sql
-- Check if data exists in PSA
SELECT COUNT(*) FROM psa_hospital.psa_hospital_admission;

-- Check for errors in transformation
SELECT * FROM psa_hospital.psa_hospital_admission 
LIMIT 5;

-- Look for NULL values causing filters
SELECT COUNT(DISTINCT patient_id_std) FROM stg_hospital.stg_hospital_admission;
```

### Issue: Duplicate Key Errors in DL3
**Error**: `Expression error ... PRIMARY KEY ... but duplicate value found`

**Solution**:
```bash
# Run with full refresh to rebuild tables
dbt run --full-refresh -s path:models/dl3

# Or manually drop and recreate
dbt run --full-refresh
```

### Issue: Performance/Timeout
**Error**: Model runs very slowly or times out

**Solution**:
```yaml
# Increase warehouse size in profiles.yml
WAREHOUSE_SIZE = 'MEDIUM'  # instead of SMALL

# Or increase query timeout
dbt run --timeout 300  # 5 minutes
```

---

## Maintenance

### Regular Checks

```bash
# Weekly: Run full pipeline refresh
dbt run --full-refresh
dbt test

# Monthly: Review data quality
# Run the 'Data Quality Dashboard' query above

# As needed: Update business logic
# Edit models/staging/stg_hospital_admission.sql
# Rerun: dbt run -s stg_hospital_admission+
```

### Adding New Transformations

1. Edit the appropriate model file
2. Test changes locally: `dbt run -s <model_name>`
3. Validate with: `dbt test -s <model_name>`
4. Document in schema.yml

---

## Support & Resources

- dbt Documentation: https://docs.getdbt.com/
- Snowflake Documentation: https://docs.snowflake.com/
- Project README: See README.md in project root
- Questions? Check the macros and models for inline comments

---

## Timeline Example

**First-time setup (assuming Snowflake account exists): ~30 minutes**
- Snowflake setup: 10 min
- dbt installation: 5 min
- Data loading: 5 min
- Running pipeline: 10 min

**Ongoing runs: ~1-2 minutes**
