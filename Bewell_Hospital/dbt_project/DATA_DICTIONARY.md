# Data Dictionary - Complete Field Reference

## PSA Layer - psa_hospital_admission

| Column Name | Data Type | Nullable | Source | Description |
|---|---|---|---|---|
| Patient_ID | NUMBER | N | CSV | Raw patient ID from source |
| Patient_Name | VARCHAR | Y | CSV | Patient full name (as received) |
| Age | NUMBER | Y | CSV | Patient age in years (raw) |
| Gender | VARCHAR | Y | CSV | Patient gender (raw - M/F/Male/Female/etc) |
| City | VARCHAR | Y | CSV | Patient city of residence (raw) |
| Department | VARCHAR | Y | CSV | Hospital department (raw - cardio/Cardiology/etc) |
| Doctor_Name | VARCHAR | Y | CSV | Treating doctor name (raw - may have invalid entries) |
| Admission_Date | VARCHAR | Y | CSV | Hospital admission date (raw - multiple formats) |
| Discharge_Date | VARCHAR | Y | CSV | Hospital discharge date (raw - multiple formats) |
| Diagnosis | VARCHAR | Y | CSV | Primary diagnosis/reason for admission |
| Insurance_Provider | VARCHAR | Y | CSV | Insurance company name (raw) |
| Insurance_Coverage | NUMBER | Y | CSV | Amount covered by insurance |
| Total_Bill | NUMBER | Y | CSV | Total hospital bill amount |
| Payment_Done | NUMBER | Y | CSV | Amount paid by patient/insurance |
| Payment_Method | VARCHAR | Y | CSV | Payment method used (raw) |
| loaded_at | TIMESTAMP | N | System | When record was loaded to PSA |
| updated_at | TIMESTAMP | N | System | When record was last updated |
| source_file | VARCHAR | N | System | Name of source file |
| source_hash | VARCHAR | N | System | MD5 hash for change detection |
| is_active | NUMBER | N | System | Always 1 in PSA layer |

---

## Staging Layer - stg_hospital_admission

| Column Name | Data Type | Nullable | Source | Description | Transformation |
|---|---|---|---|---|---|
| Patient_ID_Std | NUMBER | N | PSA | Standardized patient ID | Null values get surrogate key |
| Patient_Name_Std | VARCHAR | N | PSA | Standardized patient name | Null → 'Unknown' |
| Age_Std | NUMBER | Y | PSA | Validated age | Invalid (< 0 or > 120) → NULL |
| Gender_Std | VARCHAR | N | PSA | Standardized gender | M→Male, F→Female, else→Unknown |
| Age_Group | VARCHAR | N | PSA | Age category | 0-12: Child, 13-59: Adult, 60+: Senior |
| City_Std | VARCHAR | N | PSA | Standardized city name | Normalize: Chennai, Bangalore, Mumbai, etc. |
| Department_Std | VARCHAR | N | PSA | Standardized department | Normalize: Cardiology, Pediatrics, etc. |
| Doctor_Name_Std | VARCHAR | N | PSA | Standardized doctor name | Remove Dr.None → Dr. Unknown |
| Diagnosis_Std | VARCHAR | N | PSA | Standardized diagnosis | Null/blank → 'Unknown' |
| Admission_Date_Std | DATE | Y | PSA | Standardized admission date | Convert all to YYYY-MM-DD |
| Discharge_Date_Std | DATE | Y | PSA | Standardized discharge date | Convert all to YYYY-MM-DD |
| Length_of_Stay | NUMBER | Y | PSA | Days between admission & discharge | Discharge - Admission, if valid |
| Insurance_Provider_Std | VARCHAR | N | PSA | Standardized insurance provider | Null/'None' → 'Uninsured' |
| Insurance_Coverage_Adj | NUMBER | N | PSA | Adjusted insurance coverage | Capped at Total_Bill |
| Total_Bill | NUMBER | Y | PSA | Total hospital bill | Preserved as-is |
| Payment_Done | NUMBER | Y | PSA | Amount paid by patient | Preserved as-is |
| Expected_Payment | NUMBER | N | PSA | Expected patient payment | Bill - Insurance_Coverage_Adj |
| Insurance_Ratio | NUMBER | N | PSA | Insurance as % of bill | Insurance_Coverage / Total_Bill (0-1) |
| Revenue_Category | VARCHAR | N | PSA | Revenue classification | Low(<10K)/Medium(10K-30K)/High(≥30K) |
| Payment_Method_Std | VARCHAR | N | PSA | Standardized payment method | Normalize: UPI, Debit Card, Cash, etc. |
| is_invalid_age | NUMBER | N | PSA | Age validation flag | 1 if Age < 0 or > 120, else 0 |
| is_bill_negative | NUMBER | N | PSA | Bill validation flag | 1 if Total_Bill < 0, else 0 |
| is_insurance_exceeds_bill | NUMBER | N | PSA | Insurance validation flag | 1 if Insurance > Bill, else 0 |
| is_payment_mismatch | NUMBER | N | PSA | Payment validation flag | 1 if \|Payment - Expected\| > 100, else 0 |
| is_invalid_date | NUMBER | N | PSA | Date validation flag | 1 if Discharge < Admission, else 0 |
| is_uninsured | NUMBER | N | PSA | Insurance status flag | 1 if Insurance_Provider = 'Uninsured', else 0 |
| is_missing_demographics | NUMBER | N | PSA | Demographics check | 1 if Patient_ID null or Name='Unknown', else 0 |
| data_quality_score | NUMBER(3,2) | N | PSA | Overall quality (0-1) | Avg of 5 validation checks |
| source_file | VARCHAR | N | PSA | Source file name | Preserved from PSA |
| loaded_at | TIMESTAMP | N | PSA | Load timestamp | Preserved from PSA |
| transformed_at | TIMESTAMP | N | System | Transformation timestamp | Generated at transform time |

---

## DL3 Dimensions

### dim_patient

| Column Name | Data Type | Nullable | Grain | Description |
|---|---|---|---|---|
| dim_patient_id | VARCHAR | N | Patient (surrogate) | Surrogate key |
| patient_source_id | NUMBER | N | Patient (source) | Source system patient ID |
| patient_name_std | VARCHAR | Y | Patient | Patient name |
| age_std | NUMBER | Y | Patient | Patient age (0-120) |
| gender_std | VARCHAR | N | Patient | Gender (Male/Female/Unknown) |
| age_group | VARCHAR | N | Patient | Age group (Child/Adult/Senior) |
| city_std | VARCHAR | N | Patient | City of residence |
| created_at | TIMESTAMP | N | System | Record creation time |
| updated_at | TIMESTAMP | N | System | Record update time |
| is_current_record | BOOLEAN | N | SCD Type 2 | Whether current version |

**Grain**: One row per unique patient (deduplicates)  
**Updated**: Daily or as data arrives  

---

### dim_doctor

| Column Name | Data Type | Nullable | Grain | Description |
|---|---|---|---|---|
| dim_doctor_id | VARCHAR | N | Doctor (surrogate) | Surrogate key |
| doctor_name_std | VARCHAR | N | Doctor (unique) | Doctor name (standardized) |
| visit_count | NUMBER | N | Doctor | Total visits from patient data |
| created_at | TIMESTAMP | N | System | Record creation time |
| updated_at | TIMESTAMP | N | System | Record update time |

**Grain**: One row per unique doctor name  
**Excludes**: Dr. Unknown  

---

### dim_location

| Column Name | Data Type | Nullable | Grain | Description |
|---|---|---|---|---|
| dim_location_id | VARCHAR | N | Location (surrogate) | Surrogate key |
| city_name | VARCHAR | N | City (unique) | City name (standardized) |
| patient_count | NUMBER | N | Location | Unique patients in location |
| created_at | TIMESTAMP | N | System | Record creation time |
| updated_at | TIMESTAMP | N | System | Record update time |

**Grain**: One row per unique city  
**Excludes**: Unknown locations  

---

### dim_insurance

| Column Name | Data Type | Nullable | Grain | Description |
|---|---|---|---|---|
| dim_insurance_id | VARCHAR | N | Provider (surrogate) | Surrogate key |
| insurance_provider | VARCHAR | N | Provider (unique) | Insurance provider name |
| claim_count | NUMBER | N | Provider | Total claims/visits |
| total_coverage | NUMBER | N | Provider | Total coverage amount |
| avg_coverage | NUMBER | Y | Provider | Average coverage per claim |
| is_uninsured_flag | NUMBER | N | Provider | 1 if Uninsured, else 0 |
| created_at | TIMESTAMP | N | System | Record creation time |
| updated_at | TIMESTAMP | N | System | Record update time |

**Grain**: One row per unique insurance provider (includes Uninsured)  

---

### dim_department

| Column Name | Data Type | Nullable | Grain | Description |
|---|---|---|---|---|
| dim_department_id | VARCHAR | N | Department (surrogate) | Surrogate key |
| department_name | VARCHAR | N | Department (unique) | Department name |
| visit_count | NUMBER | N | Department | Total visits to department |
| unique_patients | NUMBER | N | Department | Unique patients treated |
| created_at | TIMESTAMP | N | System | Record creation time |
| updated_at | TIMESTAMP | N | System | Record update time |

**Grain**: One row per unique department  
**Excludes**: Unknown departments  

---

## DL3 Fact Table - fact_patient_visit

### Foreign Keys & Dimensions

| Column Name | Data Type | Table | Description |
|---|---|---|---|
| fact_patient_visit_id | VARCHAR | PRIMARY KEY | Surrogate key (natural key: Patient_ID + Admission_Date) |
| dim_patient_id | VARCHAR | FK→dim_patient | Link to patient dimension |
| dim_doctor_id | VARCHAR | FK→dim_doctor | Link to doctor dimension |
| dim_location_id | VARCHAR | FK→dim_location | Link to location dimension |
| dim_insurance_id | VARCHAR | FK→dim_insurance | Link to insurance dimension |
| dim_department_id | VARCHAR | FK→dim_department | Link to department dimension |

### Date Columns

| Column Name | Data Type | Description |
|---|---|---|
| admission_date | DATE | Admission date (standardized) |
| discharge_date | DATE | Discharge date (standardized, may be null) |
| admission_date_key | DATE | Date dimension key |
| admission_month_key | VARCHAR | Month dimension key (YYYYMM) |

### Fact Measures (Additive)

| Column Name | Data Type | Description |
|---|---|---|
| total_bill_amount | NUMBER | Total hospital bill |
| payment_done_amount | NUMBER | Amount paid by patient/insurance |
| insurance_coverage_amount | NUMBER | Amount covered by insurance |
| expected_payment_amount | NUMBER | Expected patient payment (Bill - Insurance) |
| insurance_ratio | NUMBER(3,2) | Insurance as % of bill (0.00-1.00) |
| length_of_stay_days | NUMBER | Days in hospital (Discharge - Admission) |

### Dimension Attributes (Non-Additive)

| Column Name | Data Type | Description |
|---|---|---|
| revenue_category | VARCHAR | Low/Medium/High |
| age_group | VARCHAR | Child/Adult/Senior |
| gender | VARCHAR | Male/Female/Unknown |
| diagnosis | VARCHAR | Primary diagnosis |

### Data Quality Flags

| Column Name | Data Type | Description |
|---|---|---|
| is_invalid_age | NUMBER | 1 if age outside 0-120 |
| is_bill_negative | NUMBER | 1 if bill < 0 |
| is_insurance_exceeds_bill | NUMBER | 1 if insurance > bill |
| is_payment_mismatch | NUMBER | 1 if payment differs by > $100 |
| is_invalid_date | NUMBER | 1 if discharge < admission |
| is_uninsured | NUMBER | 1 if no insurance |
| is_missing_demographics | NUMBER | 1 if missing ID or name |

### Metadata

| Column Name | Data Type | Description |
|---|---|---|
| data_quality_score | NUMBER(3,2) | Overall quality (0.00-1.00) |
| created_at | TIMESTAMP | Record creation time |
| updated_at | TIMESTAMP | Record update time |

**Grain**: One row per patient visit (Patient_ID + Admission_Date)  
**Update Frequency**: Daily or as data arrives  
**Indexed On**: admission_date, (dim_patient_id, admission_date)  

---

## Standardization Reference

### Gender Mapping
| Input | Output |
|-------|--------|
| M, Male, MALE | Male |
| F, Female, FEMALE | Female |
| NULL, blank | Unknown |

### City Mapping
| Input | Output |
|-------|--------|
| Chennai, CHENNAI, Tendollywood | Chennai |
| BLR, Bangalore, BANGALORE | Bangalore |
| Mumbai, MUMBAI | Mumbai |
| Hyderabad, HYDERABAD | Hyderabad |
| Delhi, DELHI | Delhi |
| NULL, blank | Unknown |

### Department Mapping
| Input | Output |
|-------|--------|
| cardio, Cardiology | Cardiology |
| Pediatrics (any case) | Pediatrics |
| Orthopedics | Orthopedics |
| Neurology | Neurology |
| General | General |
| NULL, blank | General |

### Insurance Mapping
| Input | Output |
|-------|--------|
| NULL, blank, None | Uninsured |
| Any provider name | Trimmed name |

### Payment Method Mapping
| Input | Output |
|-------|--------|
| upi, UPI | UPI |
| Debit Card (any case) | Debit Card |
| Credit Card (any case) | Credit Card |
| Cash (any case) | Cash |
| Insurance, INSURANCE | Insurance |
| NULL, blank | Unknown |

---

## Validation Rules Reference

| Field | Rule | Threshold | Flag |
|-------|------|-----------|------|
| Age | Range | 0-120 years | is_invalid_age |
| Total_Bill | Positive | > 0 | is_bill_negative |
| Insurance | Maximum | ≤ Total_Bill | is_insurance_exceeds_bill |
| Payment | Match | ±$100 of expected | is_payment_mismatch |
| Dates | Logical | Discharge ≥ Admission | is_invalid_date |
| Insurance | Identified | Not 'Uninsured' | is_uninsured |
| Demographics | Complete | ID ≠ NULL & Name ≠ 'Unknown' | is_missing_demographics |

---

## Metric Calculations Reference

### Length of Stay
```
IF admission_date IS NOT NULL 
   AND discharge_date IS NOT NULL 
   AND discharge_date >= admission_date
THEN length_of_stay = DATEDIFF(DAY, admission_date, discharge_date)
ELSE length_of_stay = NULL
```

### Insurance Ratio
```
IF total_bill > 0
THEN insurance_ratio = insurance_coverage_adj / total_bill
ELSE insurance_ratio = 0
```

### Expected Payment
```
expected_payment = MAX(0, total_bill - insurance_coverage_adj)
```

### Data Quality Score
```
score = (age_valid + bill_valid + coverage_valid + 
         payment_valid + date_valid) / 5

Where each valid check = 1.0 or 0.0
AND coverage check = 0.5 if insurance > bill (warning)
```

### Revenue Category
```
IF total_bill < 10,000 THEN 'Low'
IF total_bill >= 10,000 AND < 30,000 THEN 'Medium'
IF total_bill >= 30,000 THEN 'High'
ELSE 'Unknown'
```

### Age Group
```
IF age >= 0 AND age <= 12 THEN 'Child'
IF age > 12 AND age < 60 THEN 'Adult'
IF age >= 60 THEN 'Senior'
ELSE 'Unknown'
```

---

## Record Count Expectations

| Table | Expected Rows | Notes |
|-------|---|---|
| hospital_management_data (RAW) | ~49 | Input CSV |
| psa_hospital_admission | ~49 | 1:1 with input |
| stg_hospital_admission | ~49 | 1:1 with input |
| dim_patient | ~45-49 | Unique patients (some duplicates removed) |
| dim_doctor | ~12-20 | Unique doctors |
| dim_location | ~5 | Unique cities |
| dim_insurance | ~8-10 | Unique providers |
| dim_department | ~8 | Unique departments |
| fact_patient_visit | ~45-49 | Unique visits (deduplicated) |

---

## NULL Handling Strategy

| Field | PSA | Staging | DL3 |
|-------|-----|---------|-----|
| Patient_ID | Preserved | Replace with surrogate | Not null |
| Patient_Name | Preserved | 'Unknown' | 'Unknown' |
| Age | Preserved | NULL if invalid | NULL if invalid |
| Gender | Preserved | 'Unknown' | 'Unknown' |
| City | Preserved | 'Unknown' | 'Unknown' |
| Department | Preserved | 'General' | 'General' |
| Doctor_Name | Preserved | 'Dr. Unknown' | 'Dr. Unknown' |
| Diagnosis | Preserved | 'Unknown' | 'Unknown' |
| Admission_Date | Preserved | Standardize or NULL | Standardize or NULL |
| Discharge_Date | Preserved | Standardize or NULL | Standardize or NULL |
| Insurance | Preserved | 'Uninsured' | 'Uninsured' |
| Bill | Preserved | Keep (may flag) | Keep (may flag) |
| Payment | Preserved | Keep default 0 | Keep |

---

**Last Updated**: April 12, 2026  
**Data Dictionary Version**: 1.0  
**Database**: BEWELL_HOSPITAL_DB  

