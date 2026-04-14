# Business Logic Reference Guide

## Overview

This document outlines all business logic, data quality rules, and transformations applied throughout the pipeline.

---

## 1. Data Standardization Rules

### 1.1 Gender Standardization

| Input | Output |
|-------|--------|
| M, Male, MALE | Male |
| F, Female, FEMALE | Female |
| NULL, blank, invalid | Unknown |

**Location**: `stg_hospital_admission` → `Gender_Std`

**Macro**: `standardize_gender()`

---

### 1.2 City Standardization

| Input Pattern | Output |
|---|---|
| chennai, CHENNAI, Tendollywood | Chennai |
| blr, BLR, bangalore, BANGALORE | Bangalore |
| mumbai, MUMBAI | Mumbai |
| hyderabad, HYDERABAD | Hyderabad |
| delhi, DELHI | Delhi |
| NULL, blank | Unknown |
| Other | Keep original (trimmed) |

**Location**: `stg_hospital_admission` → `City_Std`

**Macro**: `standardize_city()`

**Business Reason**: Normalize data for location-based analytics and reporting.

---

### 1.3 Department Mapping

| Input | Output |
|---|---|
| cardio, Cardiology | Cardiology |
| pediatrics, Pediatrics (case-insensitive) | Pediatrics |
| orthopedics | Orthopedics |
| neurology | Neurology |
| General | General |
| NULL, blank | General |
| Other | Keep original (trimmed) |

**Location**: `stg_hospital_admission` → `Department_Std`

**Macro**: `standardize_department()`

**Business Reason**: Ensure consistent department names for revenue and workload analysis.

---

### 1.4 Diagnosis Standardization

| Input | Output |
|---|---|
| NULL, empty string | Unknown |
| Any non-null value | Trimmed value |

**Location**: `stg_hospital_admission` → `Diagnosis_Std`

**Macro**: `standardize_diagnosis()`

---

### 1.5 Doctor Name Cleaning

| Input | Output |
|---|---|
| Dr.None, Dr. (only) | Dr. Unknown |
| NULL, empty string | Dr. Unknown |
| Valid name | Trimmed value |

**Location**: `stg_hospital_admission` → `Doctor_Name_Std`

**Macro**: `standardize_doctor()`

**Business Reason**: Remove invalid placeholder values and ensure consistent doctor records.

---

### 1.6 Insurance Provider Standardization

| Input | Output |
|---|---|
| None, NULL, empty string | Uninsured |
| Valid provider name | Trimmed provider name |

**Standardized Providers**:
- Star Health
- ICICI Lombard
- HDFC Ergo
- New India Assurance

**Location**: `stg_hospital_admission` → `Insurance_Provider_Std`

**Macro**: `standardize_insurance()`

**Business Reason**: Identify uninsured patients and group insurance analytics.

---

### 1.7 Payment Method Standardization

| Input | Output |
|---|---|
| upi, UPI | UPI |
| debit card, Debit Card | Debit Card |
| credit card, Credit Card | Credit Card |
| cash, Cash | Cash |
| insurance, Insurance | Insurance |
| NULL, blank, other | Unknown |

**Location**: `stg_hospital_admission` → `Payment_Method_Std`

**Macro**: `standardize_payment_method()`

---

## 2. Data Validation Rules

### 2.1 Age Validation

**Valid Range**: 0 - 120 years

**Rules**:
- Age < 0 → Set to NULL and flag `is_invalid_age = 1`
- Age > 120 → Set to NULL and flag `is_invalid_age = 1`
- Valid age → Keep as-is

**Location**: `stg_hospital_admission` → `Age_Std`, `is_invalid_age`

**Macro**: `validate_age()`

**Impact**: Invalid ages are excluded from age-based analysis; flagged for data quality investigation.

---

### 2.2 Bill Amount Validation

**Valid Range**: > 0

**Rules**:
- Total_Bill < 0 → Flag `is_bill_negative = 1`
- Total_Bill = 0 → Allow (may indicate waived/complimentary visit)
- Total_Bill = NULL → Keep NULL, don't flag (may be pending)

**Location**: `stg_hospital_admission` → `is_bill_negative`

**Business Reason**: Negative bills indicate data entry errors; flagged for accounting review.

---

### 2.3 Date Validation

**Rules**:
1. **Format Standardization**: Convert all formats to YYYY-MM-DD
   - YYYY-MM-DD → Keep
   - DD-MM-YYYY → Convert
   - YYYY/MM/DD → Convert
   - Other formats → Try to parse, set to NULL if fails

2. **Logical Consistency**: Admission_Date ≤ Discharge_Date
   - If Discharge_Date < Admission_Date → Flag `is_invalid_date = 1`
   - If Discharge_Date = NULL → Treat as ongoing admission (length_of_stay = NULL)

**Location**: `stg_hospital_admission` → `Admission_Date_Std`, `Discharge_Date_Std`, `is_invalid_date`

**Impact**: Invalid dates excluded from length-of-stay analysis.

---

### 2.4 Insurance Coverage Validation

**Rule**: Insurance_Coverage ≤ Total_Bill

**Action**:
```
IF Insurance_Coverage > Total_Bill THEN
  Insurance_Coverage_Adj = Total_Bill
  Flag: is_insurance_exceeds_bill = 1
ELSE
  Insurance_Coverage_Adj = Insurance_Coverage
```

**Location**: `stg_hospital_admission` → `Insurance_Coverage_Adj`, `is_insurance_exceeds_bill`

**Business Reason**: Insurance can't cover more than the bill; cap it and flag for investigation.

---

## 3. Derived Metrics

### 3.1 Length of Stay (LOS)

**Formula**: `Discharge_Date - Admission_Date` (in days)

**Conditions**:
- Both dates must be NOT NULL
- Discharge_Date ≥ Admission_Date
- Result must be ≥ 0

**Invalid Cases**:
- Missing Discharge_Date → LOS = NULL (ongoing case)
- Invalid dates → LOS = NULL
- Negative LOS → LOS = NULL (data error)

**Location**: `stg_hospital_admission` → `Length_of_Stay`

**Uses**: Hospital utilization analysis, average stay by department, bed planning.

---

### 3.2 Insurance Ratio

**Formula**: `Insurance_Coverage_Adj / Total_Bill`

**Result Range**: 0 to 1 (0% to 100%)

**Conditions**:
- Total_Bill > 0 (avoid division by zero)
- If Total_Bill = 0 → Insurance_Ratio = 0

**Location**: `stg_hospital_admission` → `Insurance_Ratio`

**Interpretation**:
- 0 = Fully out-of-pocket
- 0.5 = 50% covered by insurance
- 1.0 = Fully insured

---

### 3.3 Expected Patient Payment

**Formula**: `Total_Bill - Insurance_Coverage_Adj`

**Rule**: 
```
Expected_Payment = MAX(0, Total_Bill - Insurance_Coverage_Adj)
```

**Example**:
- Bill = $1000, Insurance = $600 → Expected = $400
- Bill = $1000, Insurance = $1000 → Expected = $0
- Bill = $1000, Insurance = 0 → Expected = $1000

**Location**: `stg_hospital_admission` → `Expected_Payment`

---

### 3.4 Payment Mismatch Detection

**Rule**: 
```
IF Actual_Payment differs significantly from Expected_Payment THEN
  Flag: is_payment_mismatch = 1
```

**Threshold**: Absolute difference > $100

**Conditions**:
- Only check if Total_Bill > 0
- Only check if Payment_Done > 0
- Compare: ABS(Payment_Done - Expected_Payment) > 100

**Location**: `stg_hospital_admission` → `is_payment_mismatch`

**Investigation**: May indicate:
- Discounts not recorded
- Additional charges not documented
- Data entry errors
- Underpayment or overpayment

---

### 3.5 Revenue Category

**Classification**:
| Total Bill | Category |
|---|---|
| < ₹10,000 | Low |
| ₹10,000 - ₹29,999 | Medium |
| ≥ ₹30,000 | High |

**Location**: `stg_hospital_admission` → `Revenue_Category`

**Use Cases**:
- Revenue segmentation analysis
- High-value case identification
- Resource allocation

---

### 3.6 Age Group Categorization

**Classification**:
| Age | Group |
|---|---|
| 0-12 | Child |
| 13-59 | Adult |
| 60+ | Senior |
| NULL/Invalid | Unknown |

**Location**: `stg_hospital_admission` → `Age_Group`

**Uses**: Demographic analysis, pediatric vs. geriatric workload.

---

## 4. Data Quality Flags

All quality flags are **binary (0 = pass, 1 = fail)**.

| Flag | Condition | Severity |
|---|---|---|
| `is_invalid_age` | Age < 0 OR Age > 120 | High |
| `is_bill_negative` | Total_Bill < 0 | High |
| `is_insurance_exceeds_bill` | Insurance_Coverage > Total_Bill | Medium |
| `is_payment_mismatch` | Payment differs from expected by > $100 | Medium |
| `is_invalid_date` | Discharge_Date < Admission_Date | High |
| `is_uninsured` | Insurance_Provider = 'Uninsured' | Low |
| `is_missing_demographics` | Patient_ID NULL OR Patient_Name = 'Unknown' | High |

---

## 5. Data Quality Score

**Formula**:
```
Quality_Score = (age_valid + bill_valid + coverage_valid + 
                 payment_valid + date_valid) / 5
```

**Scoring**:
- Valid check: +1.0
- Invalid check: +0.0
- Coverage exceeds bill: +0.5 (warning)

**Range**: 0.0 to 1.0
- 0.6-1.0 = Acceptable
- 0.4-0.6 = Review recommended
- < 0.4 = Potential data issues

**Location**: `stg_hospital_admission` → `data_quality_score`

---

## 6. Deduplication Logic

### Duplicate Definition
A record is considered a duplicate if:
```
Patient_ID_Std = Previous Patient_ID_Std
AND Admission_Date_Std = Previous Admission_Date_Std
AND Doctor_Name_Std = Previous Doctor_Name_Std
```

### Handling
**Current approach**: Keep **latest** record (by `loaded_at`)

**Alternative approaches** (if business requires):
1. Aggregate multiple entries
2. Mark as duplicate and keep both with flags
3. Manual reconciliation required

**Location**: Dimension tables (dim_patient, etc.) use `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY loaded_at DESC)` to keep only latest.

---

## 7. Null Value Handling

| Field | Null Handling | Reason |
|---|---|---|
| Patient_ID | Generate surrogate key if NULL | Ensure unique ID |
| Patient_Name | Replace with 'Unknown' | Maintain referential integrity |
| Age | Set to NULL if invalid | Keep only valid values |
| Gender | Replace with 'Unknown' | Standardize output |
| City | Replace with 'Unknown' | Consistent location tracking |
| Department | Replace with 'General' | Default department |
| Doctor_Name | Replace with 'Dr. Unknown' | Maintain doctor records |
| Admission_Date | Keep NULL | Critical field, mark if missing |
| Discharge_Date | Keep NULL, treat as ongoing | Normal for active admits |
| Diagnosis | Replace with 'Unknown' | Ensure consistency |
| Insurance_Provider | Replace with 'Uninsured' | Business logic |
| Insurance_Coverage | Default to 0 | No coverage = $0 |
| Total_Bill | Keep NULL | Mark invalid bills |
| Payment_Done | Default to 0 | Track unfunded |
| Payment_Method | Replace with 'Unknown' | Maintain payment tracking |

---

## 8. Layer-Specific Rules

### PSA Layer (Raw + Audit)
- **No transformations**
- Data preserved as-is from source
- Added columns: `loaded_at`, `updated_at`, `source_file`, `source_hash`, `is_active`
- Purpose: Audit trail and recovery

### Staging Layer (Transformations)
- All standardization applied
- All validations applied
- All derived metrics calculated
- All quality flags populated
- **No joins to dimensions yet**
- Purpose: Single source of clean truth

### DL3 Layer (Analytics-Ready)
- **Dimension tables**: Unique values with aggregates
- **Fact table**: Joined to all dimensions via surrogate keys
- No raw values, all standardized
- Ready for analytics/BI tools
- Purpose: Optimized for queries and reporting

---

## 9. Financial Rules Summary

**Golden Rules**:
1. Insurance Coverage ≤ Total Bill (auto-capped)
2. Expected Payment = Total Bill - Insurance Coverage
3. Expected Payment ≥ 0 (never negative)
4. All bills must be > 0 (negative bills flagged)
5. Payment mismatches flagged for review

**Payment Logic**:
```
Uninsured patient: 
  Expected = Total_Bill
  Insurance_Coverage = $0

Insured patient:
  Expected = Total_Bill - Insurance_Coverage
  Insurance_Ratio = Insurance_Coverage / Total_Bill

Overpaid case (Insurance > Bill):
  Adjusted_Insurance = Total_Bill
  Expected = $0
  Flag: is_insurance_exceeds_bill
```

---

## 10. Fact Table Grain

**Primary Keys**: 
- `Patient_ID + Admission_Date`

**Uniqueness**: 
- One record per patient visit
- If multiple records for same visit, keep latest

**Storage**: 
- Surrogate key: `fact_patient_visit_id` (generated from natural keys)
- All measures are additive

---

## 11. Configuration Variables

In `dbt_project.yml`:
```yaml
vars:
  max_age: 120           # Maximum valid age
  min_age: 0             # Minimum valid age
  max_los: 365           # Maximum length of stay (optional)
  max_bill_amount: 999999 # Maximum bill (optional)
```

Modify as per business requirements.

---

## 12. Maintenance Notes

**When Adding New Business Logic**:
1. Update macro in `macros/data_cleaning.sql`
2. Update transformation in `stg_hospital_admission.sql`
3. Add corresponding test in `tests/data_quality_tests.yml`
4. Update this documentation
5. Run `dbt test` to validate changes

**When Changing Rules**:
1. Document the change here
2. Update dbt models
3. Run with `--full-refresh` if changing dimension logic
4. Retest all dependent models

**Approval Process**:
- Data standardization changes: Technical approval
- Financial rules changes: Finance + Ops approval
- Quality threshold changes: Data governance approval

---

## Questions?

Refer to:
- Inline comments in SQL models
- Schema documentation: `dbt docs serve`
- This guide for detailed business logic
