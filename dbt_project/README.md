# Bewell Hospital - Data Engineering Pipeline

A production-grade data engineering solution for hospital admission data using Snowflake and dbt.

## 📊 Project Overview

This project implements a complete data pipeline architecture for hospital admission data with insurance tracking:

```
Raw Data (CSV)
    ↓
PSA Layer (Persistent Staging Area - Raw + Audit)
    ↓
Staging Layer (Transformations + Business Logic)
    ↓
DL3 Layer (Dimension & Fact Tables - Analytics Ready)
```

## 🏗️ Architecture

### Layers

1. **PSA (Persistent Staging Area)**
   - Raw data from source CSV
   - Added audit columns (loaded_at, source_file, source_hash)
   - Materialized as table
   - Used for data recovery and lineage tracking

2. **Staging**
   - Data standardization and cleaning
   - Data quality checks with flag columns
   - Derived metrics and calculations
   - Materialized as view

3. **DL3 (Data Lake Layer 3)**
   - Star schema with dimension and fact tables
   - Business-ready aggregated data
   - Materialized as tables with indexes

## 📋 Business Logic Implemented

### Data Standardization
- ✅ **Gender**: Normalized to Male/Female/Unknown
- ✅ **City**: Standardized naming (Chennai, Bangalore, Mumbai, etc.)
- ✅ **Department**: Mapped to standard names (Cardiology, Pediatrics, etc.)
- ✅ **Insurance Provider**: Standardized with "Uninsured" flag
- ✅ **Payment Method**: Normalized format
- ✅ **Doctor Name**: Cleaned invalid entries (Dr.None → Dr. Unknown)

### Data Quality Checks
- Age validation (0-120 range)
- Bill amount validation (>0)
- Date consistency (Admission ≤ Discharge)
- Insurance coverage validation (≤ Total Bill)
- Payment mismatch detection
- Missing demographic flags

### Derived Metrics
- **Length of Stay** = Discharge_Date - Admission_Date
- **Insurance Ratio** = Insurance_Coverage / Total_Bill
- **Expected Payment** = Total_Bill - Insurance_Coverage
- **Revenue Category** = Low (<10K) / Medium (10K-30K) / High (>30K)
- **Age Group** = Child / Adult / Senior
- **Data Quality Score** = Calculated from validation flags

### Financial Rules
- Insurance coverage cannot exceed total bill (auto-capped)
- Expected payment calculated from bill and coverage
- Payment discrepancies flagged for review
- Out-of-pocket payment tracked

## 🛢️ Tables

### PSA Layer
- **psa_hospital_admission**: Raw data with audit columns

### Staging Layer
- **stg_hospital_admission**: Transformed data with QA flags

### DL3 Layer - Dimensions
- **dim_patient**: Patient demographics
- **dim_doctor**: Doctor/Provider details
- **dim_location**: City/Location information
- **dim_insurance**: Insurance provider details
- **dim_department**: Hospital departments

### DL3 Layer - Facts
- **fact_patient_visit**: Core transactional fact table with financial metrics

## 🚀 Getting Started

### Prerequisites
- Snowflake account with warehouse and database
- DBT CLI installed (`pip install dbt-snowflake`)
- Python 3.8+

### Setup

1. **Install dependencies**
   ```bash
   cd dbt_project
   pip install -r requirements.txt
   ```

2. **Configure Snowflake connection**
   ```bash
   cp profiles.yml ~/.dbt/profiles.yml
   # Edit profiles.yml with your Snowflake credentials
   ```

3. **Load source data**
   ```sql
   -- Create database and schema
   CREATE DATABASE BEWELL_HOSPITAL_DB;
   CREATE SCHEMA BEWELL_HOSPITAL_DB.raw_data;
   
   -- Load CSV into Snowflake
   PUT file:///path/to/hospital_management_data.csv 
   @BEWELL_HOSPITAL_DB.raw_data.stage_path;
   
   COPY INTO raw_hospital_admission
   FROM @BEWELL_HOSPITAL_DB.raw_data.stage_path/hospital_management_data.csv
   FILE_FORMAT = (TYPE = 'CSV', SKIP_HEADER = 1);
   ```

4. **Run dbt**
   ```bash
   dbt debug          # Test connection
   dbt run           # Run all models
   dbt test          # Run data quality tests
   dbt docs generate # Generate documentation
   dbt docs serve    # View docs
   ```

## 📊 Querying Examples

### Most common diagnoses
```sql
SELECT diagnosis, COUNT(*) as visit_count
FROM dl3_hospital.fact_patient_visit
GROUP BY diagnosis
ORDER BY visit_count DESC;
```

### Revenue analysis by location
```sql
SELECT 
    loc.city_name,
    SUM(fv.total_bill_amount) as total_revenue,
    AVG(fv.total_bill_amount) as avg_bill,
    COUNT(*) as visit_count
FROM dl3_hospital.fact_patient_visit fv
JOIN dl3_hospital.dim_location loc ON fv.dim_location_id = loc.dim_location_id
GROUP BY loc.city_name
ORDER BY total_revenue DESC;
```

### Insurance coverage analysis
```sql
SELECT 
    ins.insurance_provider,
    COUNT(*) as claims,
    SUM(fv.insurance_coverage_amount) as total_coverage,
    SUM(fv.total_bill_amount) as total_billed,
    ROUND(SUM(fv.insurance_coverage_amount) / SUM(fv.total_bill_amount), 2) as coverage_ratio
FROM dl3_hospital.fact_patient_visit fv
JOIN dl3_hospital.dim_insurance ins ON fv.dim_insurance_id = ins.dim_insurance_id
WHERE ins.insurance_provider != 'Uninsured'
GROUP BY ins.insurance_provider;
```

### Data quality dashboard
```sql
SELECT 
    COUNT(*) as total_records,
    SUM(is_invalid_age) as invalid_ages,
    SUM(is_bill_negative) as negative_bills,
    SUM(is_payment_mismatch) as payment_mismatches,
    SUM(is_invalid_date) as invalid_dates,
    ROUND(AVG(data_quality_score), 2) as avg_quality_score
FROM dl3_hospital.fact_patient_visit;
```

## 🔍 Data Quality

Each record includes quality flags:
- `is_invalid_age`: Age outside 0-120 range
- `is_bill_negative`: Negative bill amount
- `is_insurance_exceeds_bill`: Insurance > Bill
- `is_payment_mismatch`: Payment mismatch detected
- `is_invalid_date`: Discharge before admission
- `is_uninsured`: Patient has no insurance
- `is_missing_demographics`: Missing names or IDs
- `data_quality_score`: Overall quality (0-1 scale)

## 📁 File Structure

```
dbt_project/
├── dbt_project.yml          # Project configuration
├── profiles.yml             # Snowflake connection config
├── models/
│   ├── sources.yml          # Source definitions
│   ├── psa/
│   │   └── psa_hospital_admission.sql
│   ├── staging/
│   │   └── stg_hospital_admission.sql
│   └── dl3/
│       ├── dimensions/
│       │   ├── dim_patient.sql
│       │   ├── dim_doctor.sql
│       │   ├── dim_location.sql
│       │   ├── dim_insurance.sql
│       │   └── dim_department.sql
│       └── facts/
│           └── fact_patient_visit.sql
├── macros/
│   └── data_cleaning.sql    # Standardization macros
├── tests/
│   └── assertions/          # Data quality tests
├── data/                    # Seed data and mappings
└── README.md
```

## 🔄 Continuous Integration

The pipeline includes:
- Automatic data validation
- Quality score tracking
- Error flagging and logging
- Audit trail with timestamps

## 📝 Notes

- All dates are standardized to YYYY-MM-DD format
- Null values in key fields are handled gracefully
- Deduplication based on Patient_ID + Admission_Date
- Nulls in categorical data are replaced with "Unknown"
- Invalid values are flagged rather than dropped

## 👥 Contributing

For issues or improvements, please update:
1. Transformation logic in staging layer
2. Dimension definitions in DL3
3. Data quality rules in macros

## 📞 Support

For questions about the pipeline, refer to:
- Business logic: See comments in stg_hospital_admission.sql
- Data quality: Check data_cleaning.sql macros
- Schema documentation: Run `dbt docs serve`
