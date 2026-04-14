# Quick Reference Card

## 🚀 Essential Commands

### First-Time Setup
```bash
cd dbt_project
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt
dbt debug              # Test connection
```

### Running the Pipeline
```bash
dbt run                # Run all models
dbt run -s stg_*       # Run staging models only
dbt run --full-refresh # Rebuild all tables
dbt test               # Run quality tests
dbt build              # Run + test
dbt parse              # Check for syntax errors
```

### Documentation
```bash
dbt docs generate      # Create docs
dbt docs serve         # View in browser (http://localhost:8000)
dbt run-operation ... # Run custom operations
```

### Debugging
```bash
dbt debug              # Test Snowflake connection
dbt compile            # Compile SQL (no run)
dbt test --store-failures  # Keep test failures
dbt test -s model_name --show  # Show test results
```

---

## 📊 Data Model Overview

### Tables by Layer

| Layer | Schema | Tables | Type | Row Count |
|-------|--------|--------|------|-----------|
| **Raw** | raw_hospital | 1 | CSV → Table | Input |
| **PSA** | psa_hospital | 1 | Table | Same as input |
| **Staging** | stg_hospital | 1 | View | Same as input |
| **DL3** | dl3_hospital | 6 | Tables | ~49 (fact) |

### Dimension Tables
- `dim_patient`: Unique patients (≤49 rows)
- `dim_doctor`: Unique doctors (≤20 rows)
- `dim_location`: Cities (≤5 rows)
- `dim_insurance`: Providers (≤10 rows)
- `dim_department`: Departments (≤10 rows)

### Fact Table
- `fact_patient_visit`: Patient visits with all metrics (≤49 rows)

---

## 🔧 Key Configuration Values

### In `dbt_project.yml`
```yaml
max_age: 120          # Max valid patient age
max_los: 365          # Max length of stay (days)
max_bill_amount: 999999  # Max bill amount
```

### In `profiles.yml`
```yaml
account: xy12345.region.cloud  # Your Snowflake account
user: your_username
password: your_password
role: TRANSFORMER
database: BEWELL_HOSPITAL_DB
warehouse: COMPUTE_WH
schema: public
threads: 4            # Parallel processing
```

---

## 📁 File Locations

### Configuration
- Project settings: `dbt_project.yml`
- Snowflake credentials: `profiles.yml` (in ~/.dbt/)
- Dependencies: `requirements.txt`

### Models
- PSA: `models/psa/psa_hospital_admission.sql`
- Staging: `models/staging/stg_hospital_admission.sql`
- Dimensions: `models/dl3/dimensions/dim_*.sql` (5 files)
- Fact: `models/dl3/facts/fact_patient_visit.sql`

### Support
- Source definitions: `models/sources.yml`
- Data dictionary: `models/schema.yml`
- Transformations: `macros/data_cleaning.sql`
- Tests: `tests/data_quality_tests.yml`

### Documentation
- Setup: `SETUP_GUIDE.md`
- Business rules: `BUSINESS_LOGIC.md`
- Architecture: `ARCHITECTURE.md`
- Project overview: `README.md`
- This file: `QUICK_REFERENCE.md`

---

## 📈 Business Metrics

### Revenue Categories
- LOW: < ₹10,000
- MEDIUM: ₹10,000 - ₹29,999
- HIGH: ≥ ₹30,000

### Age Groups
- Child: 0-12 years
- Adult: 13-59 years
- Senior: 60+ years

### Data Quality Score
- Excellent: 0.8-1.0
- Good: 0.6-0.8
- Fair: 0.4-0.6
- Poor: < 0.4

---

## ✅ Data Quality Flags

| Flag | Meaning | Action |
|------|---------|--------|
| `is_invalid_age` | Age outside 0-120 | Review patient data |
| `is_bill_negative` | Bill < 0 | Accounting review |
| `is_insurance_exceeds_bill` | Insurance > Bill | Cap and investigate |
| `is_payment_mismatch` | Payment differs from expected by >$100 | Financial review |
| `is_invalid_date` | Discharge < Admission | Date verification |
| `is_uninsured` | No insurance provider | Revenue category |
| `is_missing_demographics` | Missing ID or name | Data quality review |

---

## 🔌 Common Queries

### Record Counts
```sql
SELECT COUNT(*) FROM dl3_hospital.fact_patient_visit;
```

### Quality Check
```sql
SELECT 
  COUNT(*) total,
  SUM(is_invalid_age) bad_ages,
  ROUND(AVG(data_quality_score), 2) quality
FROM dl3_hospital.fact_patient_visit;
```

### Revenue by City
```sql
SELECT city_name, SUM(total_bill_amount) revenue
FROM dl3_hospital.fact_patient_visit fv
JOIN dl3_hospital.dim_location dl ON fv.dim_location_id = dl.dim_location_id
GROUP BY city_name ORDER BY revenue DESC;
```

### Insurance Analysis
```sql
SELECT 
  di.insurance_provider, 
  COUNT(*) claims,
  SUM(fv.insurance_coverage_amount) paid
FROM dl3_hospital.fact_patient_visit fv
JOIN dl3_hospital.dim_insurance di ON fv.dim_insurance_id = di.dim_insurance_id
GROUP BY di.insurance_provider;
```

### Data Issues
```sql
SELECT 
  COUNT(*) total,
  SUM(is_invalid_age) invalid_ages,
  SUM(is_bill_negative) negative_bills,
  SUM(is_payment_mismatch) mismatches
FROM dl3_hospital.fact_patient_visit
WHERE is_invalid_age = 1 OR is_bill_negative = 1;
```

---

## 🚨 Troubleshooting

### Connection Issues
```
Error: Cannot connect to Snowflake
→ Run: dbt debug
→ Check: account ID, username, password, warehouse status
```

### Model Errors
```
Error: Source not found
→ Verify: source table exists in raw_hospital
→ Check: SQL SELECT COUNT(*) FROM raw_hospital.hospital_management_data
```

### Test Failures
```
Error: Data quality test failed
→ Run: dbt test --store-failures
→ Check: /target/test_results/
→ Review: Specific quality flag that failed
```

### Performance Issues
```
Slow queries
→ Increase warehouse: WAREHOUSE_SIZE = 'MEDIUM'
→ Run refresh: dbt run --full-refresh
→ Check indexes on fact table
```

---

## 📋 Pre-Deployment Checklist

- [ ] All dbt commands run without errors
- [ ] `dbt test` passes all tests
- [ ] Snowflake connection working
- [ ] All 6 dbt models created
- [ ] Data quality flags populated
- [ ] Analytics queries return expected results
- [ ] Documentation reviewed
- [ ] Team trained on usage
- [ ] Backup of source data created

---

## 💾 Database Commands

### Check Model Status
```sql
USE DATABASE BEWELL_HOSPITAL_DB;

-- List all tables
SHOW TABLES IN SCHEMA psa_hospital;
SHOW TABLES IN SCHEMA dl3_hospital;

-- Check row counts
SELECT COUNT(*) FROM psa_hospital.psa_hospital_admission;
SELECT COUNT(*) FROM dl3_hospital.fact_patient_visit;
```

### Rebuild a Model
```bash
dbt run -s fact_patient_visit --full-refresh
```

### Delete Dbt Artifacts
```bash
dbt clean  # Removes target/ and dbt_packages/
```

---

## 🗂️ Project Structure
```
dbt_project/
├── models/
│   ├── psa/              # Raw data + audit
│   ├── staging/          # Transformations
│   ├── dl3/              # Analytics tables
│   ├── sources.yml       # Source definitions
│   └── schema.yml        # Data dictionary
├── macros/
│   └── data_cleaning.sql # Reusable functions
├── tests/
│   └── data_quality_tests.yml
├── dbt_project.yml       # Project config
├── profiles.yml          # Connection config
├── requirements.txt      # Python packages
└── docs/
    ├── README.md
    ├── SETUP_GUIDE.md
    ├── BUSINESS_LOGIC.md
    ├── ARCHITECTURE.md
    └── PROJECT_SUMMARY.md
```

---

## 🎯 Common Workflows

### Daily Operations
```bash
dbt run      # 2-3 minutes
dbt test     # 1-2 minutes
# Check quality dashboard
```

### Weekly Maintenance
```bash
dbt run --full-refresh
dbt test
dbt docs generate
# Review data quality metrics
```

### Adding Features
```bash
# Edit model file
dbt run -s changed_model
dbt test -s changed_model
dbt docs generate
```

---

## 📞 Quick Help

| Need | File |
|------|------|
| How to setup? | SETUP_GUIDE.md |
| How does it work? | ARCHITECTURE.md |
| What are the rules? | BUSINESS_LOGIC.md |
| What can I query? | README.md |
| What was created? | PROJECT_SUMMARY.md |
| Quick help? | This file (QUICK_REFERENCE.md) |

---

## 🔑 Key Concepts

**PSA**: Persistent Staging Area - raw data with audit trail  
**DL3**: Data Lake Layer 3 - analytics-ready tables  
**Fact**: Transactional table (patient visits)  
**Dimension**: Reference table (patients, locations, etc.)  
**Surrogate Key**: Generated ID (links facts to dimensions)  
**Quality Flag**: Binary column indicating data issues  
**Macro**: Reusable SQL function  

---

**Last Updated**: April 12, 2026  
**Version**: 1.0  
**Status**: Production Ready ✅

