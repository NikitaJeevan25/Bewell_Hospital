# Data Pipeline Architecture

## Pipeline Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INPUT LAYER                                  │
│  Hospital_Management_Data.CSV (Raw patient, doctor, insurance data) │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          │ LOAD
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     PSA LAYER (Raw + Audit)                         │
│                psa_hospital_admission (TABLE)                        │
│                                                                      │
│  • Patient_ID, Patient_Name, Age, Gender, City (AS-IS)             │
│  • Department, Doctor_Name, Diagnosis (AS-IS)                      │
│  • Admission_Date, Discharge_Date, Diagnosis (AS-IS)              │
│  • Insurance_Provider, Insurance_Coverage (AS-IS)                  │
│  • Total_Bill, Payment_Done, Payment_Method (AS-IS)               │
│  + loaded_at, updated_at, source_file, source_hash                │
│                                                                      │
│  Purpose: Audit trail, recovery, data lineage                      │
│  Materialization: TABLE (persistent storage)                       │
│  Records: Same as input (raw data preserved)                       │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          │ STANDARDIZE + VALIDATE
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    STAGING LAYER (Transformed)                       │
│              stg_hospital_admission (VIEW)                          │
│                                                                      │
│  STANDARDIZATION:                                                   │
│    • Gender → Male/Female/Unknown                                   │
│    • City → Bangalore/Chennai/Mumbai/Delhi/Hyderabad/Unknown       │
│    • Department → Std names (Cardiology, Pediatrics, etc.)        │
│    • Insurance_Provider → Provider name or 'Uninsured'            │
│    • Payment_Method → Std names (UPI, Debit Card, etc.)           │
│    • Doctor_Name → Remove invalid entries                         │
│    • Diagnosis → Replace NULL with 'Unknown'                      │
│    • Dates → YYYY-MM-DD format                                    │
│    • Age → Valid range 0-120                                      │
│                                                                      │
│  DERIVED METRICS:                                                   │
│    • Length_of_Stay = Discharge_Date - Admission_Date              │
│    • Insurance_Ratio = Insurance / Bill                            │
│    • Expected_Payment = Bill - Insurance                           │
│    • Revenue_Category = Low/<10K / Medium/10K-30K / High/>30K      │
│    • Age_Group = Child/13-59/Adult/60+/Senior                     │
│                                                                      │
│  DATA QUALITY FLAGS:                                                │
│    • is_invalid_age (Age < 0 or > 120)                           │
│    • is_bill_negative (Bill < 0)                                   │
│    • is_insurance_exceeds_bill (Insurance > Bill)                 │
│    • is_payment_mismatch (Payment ≠ Expected)                     │
│    • is_invalid_date (Discharge < Admission)                      │
│    • is_uninsured (No insurance provider)                         │
│    • is_missing_demographics (Missing ID or name)                 │
│    • data_quality_score (0.0 - 1.0)                               │
│                                                                      │
│  Purpose: Single source of truth, business logic applied           │
│  Materialization: VIEW (on-the-fly calculation)                    │
│  Records: Same as PSA (1:1 mapping)                                │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          │ JOIN WITH DIMENSIONS
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      DL3 LAYER (Analytics Ready)                     │
│                    Star Schema Design                               │
│                                                                      │
│              DIMENSION TABLES (Slowly Changing, Unique)            │
│              ────────────────────────────────────────              │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────┐      │
│  │  DIM_PATIENT     │  │   DIM_DOCTOR     │  │ DIM_LOCATION│      │
│  ├──────────────────┤  ├──────────────────┤  ├─────────────┤      │
│  │ dim_patient_id   │  │ dim_doctor_id    │  │ dim_loc_id  │      │
│  │ patient_src_id   │  │ doctor_name      │  │ city_name   │      │
│  │ patient_name     │  │ visit_count      │  │ patient_cnt │      │
│  │ age              │  │ created_at       │  │ created_at  │      │
│  │ gender           │  │ updated_at       │  │ updated_at  │      │
│  │ age_group        │  └──────────────────┘  └─────────────┘      │
│  │ city             │                                               │
│  │ created_at       │  ┌──────────────────┐  ┌──────────────────┐ │
│  │ updated_at       │  │DIM_INSURANCE     │  │ DIM_DEPARTMENT   │ │
│  │ is_current       │  ├──────────────────┤  ├──────────────────┤ │
│  └────────┬─────────┘  │ dim_insurance_id │  │ dim_department_id│ │
│           │            │ insurance_prov   │  │ department_name  │ │
│           │            │ claim_count      │  │ visit_count      │ │
│           │            │ total_coverage   │  │ unique_patients  │ │
│           │            │ avg_coverage     │  │ created_at       │ │
│           │            │ is_uninsured_flg │  │ updated_at       │ │
│           │            │ created_at       │  └──────────────────┘ │
│           │            │ updated_at       │                        │
│           │            └────────┬─────────┘                        │
│           │                     │                                  │
│           └─────────┬───────────┘                                  │
│                     │                                               │
│           FACT TABLE (Transactional)                              │
│           ────────────────────────────                            │
│                                                                      │
│              ┌────────────────────────────────┐                    │
│              │  FACT_PATIENT_VISIT (TABLE)    │                    │
│              ├────────────────────────────────┤                    │
│              │ • fact_patient_visit_id (PK)   │                    │
│              │ • dim_patient_id (FK)          │                    │
│              │ • dim_doctor_id (FK)           │                    │
│              │ • dim_location_id (FK)         │                    │
│              │ • dim_insurance_id (FK)        │                    │
│              │ • dim_department_id (FK)       │                    │
│              │                                │                    │
│              │ DATES:                         │                    │
│              │ • admission_date               │                    │
│              │ • discharge_date               │                    │
│              │ • admission_date_key           │                    │
│              │ • admission_month_key          │                    │
│              │                                │                    │
│              │ MEASURES (Additive):           │                    │
│              │ • total_bill_amount            │                    │
│              │ • payment_done_amount          │                    │
│              │ • insurance_coverage_amount    │                    │
│              │ • expected_payment_amount      │                    │
│              │ • insurance_ratio              │                    │
│              │ • length_of_stay_days          │                    │
│              │                                │                    │
│              │ DIMENSIONS:                    │                    │
│              │ • revenue_category             │                    │
│              │ • age_group                    │                    │
│              │ • gender                       │                    │
│              │ • diagnosis                    │                    │
│              │ • data_quality_score           │                    │
│              │                                │                    │
│              │ QUALITY FLAGS:                 │                    │
│              │ • is_invalid_age               │                    │
│              │ • is_bill_negative             │                    │
│              │ • is_insurance_exceeds_bill    │                    │
│              │ • is_payment_mismatch          │                    │
│              │ • is_invalid_date              │                    │
│              │ • is_uninsured                 │                    │
│              │ • is_missing_demographics      │                    │
│              │                                │                    │
│              │ Grain: 1 row per patient visit │                    │
│              │ Indexed on: admission_date     │                    │
│              └────────────────────────────────┘                    │
│                                                                      │
│  Purpose: Analytics-ready business metrics                        │
│  Materialization: TABLE (denormalized for performance)            │
│  Records: De-duplicated (1 per visit)                            │
└─────────────────────────┬───────────────────────────────────────────┘
                          │
                          │ QUERY
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        OUTPUT LAYER                                  │
│              (Analytics, Dashboards, Reports)                       │
│                                                                      │
│  • Revenue Analysis by City                                         │
│  • Insurance Coverage Analysis                                      │
│  • Department Performance Dashboard                                 │
│  • Patient Demographics Report                                      │
│  • Data Quality Monitoring                                          │
│  • Financial KPI Dashboard                                          │
│  • Length of Stay Analysis                                          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Database Schema Structure

```
BEWELL_HOSPITAL_DB (Database)
│
├── raw_hospital (Schema - Raw Data)
│   └── hospital_management_data (TABLE - Input CSV)
│
├── psa_hospital (Schema - Persistent Staging Area)
│   └── psa_hospital_admission (TABLE - Raw + Audit)
│
├── stg_hospital (Schema - Staging)
│   └── stg_hospital_admission (VIEW - Transformed)
│
└── dl3_hospital (Schema - Data Lake Layer 3)
    ├── Dimensions/
    │   ├── dim_patient (TABLE)
    │   ├── dim_doctor (TABLE)
    │   ├── dim_location (TABLE)
    │   ├── dim_insurance (TABLE)
    │   └── dim_department (TABLE)
    └── Facts/
        └── fact_patient_visit (TABLE - Star Schema Center)
```

---

## Data Volume & Grain

| Layer | Record Count | Grain | Type | Update Frequency |
|-------|---|---|---|---|
| Raw Input | ~49 | Patient visit (raw) | File | One-time |
| PSA | ~49 | Patient visit (raw + audit) | Table | Additive |
| Staging | ~49 | Patient visit (1:1) | View | On-demand |
| DIM_PATIENT | Unique patients | One per patient | Table | Daily |
| DIM_DOCTOR | Unique doctors | One per doctor | Table | Daily |
| DIM_LOCATION | Unique cities | One per city | Table | Daily |
| DIM_INSURANCE | Insurance types | One per provider | Table | Daily |
| DIM_DEPARTMENT | Departments | One per dept | Table | Daily |
| FACT_PATIENT_VISIT | Patient visits | One per visit | Table | Daily |

---

## Data Quality Journey

```
Raw Data (Dirty)
  ├─ Invalid ages (-5, 150)
  ├─ Inconsistent formats (DD-MM-YYYY, YYYY/MM/DD)
  ├─ City case issues (chennai, CHENNAI, BLR)
  ├─ Negative bills (-500, -1000)
  ├─ Insurance > Bill
  ├─ Payment mismatches
  ├─ Invalid dates (discharge < admission)
  └─ Missing values (NULL, blanks, "None")
           │
           │ Trace through PSA (audit trail)
           ▼
PSA Layer (Raw preserved, Audit added)
           │
           │ Standardization Applied (macros/)
           │ Validation Applied (flags)
           │ Metrics Calculated
           ▼
Staging Layer (Clean, Quality Flagged)
  ├─ All values standardized
  ├─ All dates in YYYY-MM-DD
  ├─ Quality flags populated
  ├─ Derived metrics calculated
  └─ Ready for Analytics
           │
           │ Deduplication
           │ Dimension joins
           ▼
DL3 Layer (Analytics-Ready)
  ├─ Conformed dimensions
  ├─ Fact table with all KPIs
  ├─ Quality scores calculated
  └─ Ready for BI Tools
```

---

## Transformation Summary

```
                INPUT
                  │
         ┌────────▼────────┐
         │  STANDARDIZE    │
         │  - Genders      │
         │  - Cities       │ Macros/
         │  - Departments  │ Functions
         │  - Names        │
         │  - Dates        │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │  VALIDATE       │
         │  - Ages         │
         │  - Bills        │ Flags
         │  - Dates        │ / Tests
         │  - Coverage     │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │  CALCULATE      │
         │  - LOS          │
         │  - Insurance %  │ Derived
         │  - Expected Pay │ Fields
         │  - QA Score     │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │  INTEGRATE      │
         │  - Join Dims    │
         │  - Star Schema  │ Analytics
         │  - Aggregate    │ Ready
         └────────┬────────┘
                  │
              OUTPUT
```

---

## Key Design Decisions

### 1. **PSA as Table (Not View)**
- **Why**: Preserve raw data for audit and recovery
- **Benefit**: If staging logic changes, can re-transform from PSA
- **Trade-off**: Storage cost vs. data reliability

### 2. **Staging as View**
- **Why**: Don't duplicate standardized data; calculate on-demand
- **Benefit**: Faster development; changes immediately reflected
- **Trade-off**: Query performance (can materialize if needed)

### 3. **DL3 Dimensions as Tables**
- **Why**: Support SCD Type 2 (historicization) and optimal joins
- **Benefit**: Fast queries; support dimension changes over time
- **Trade-off**: Storage; need to manage updates

### 4. **DL3 Fact as Denormalized Table**
- **Why**: BI tools work best with flat, wide tables
- **Benefit**: Simple queries; fast aggregations
- **Trade-off**: Storage; redundancy

### 5. **Surrogate Keys in DL3**
- **Why**: Stable joins; support if source IDs change
- **Benefit**: Performance; flexibility
- **Trade-off**: Need to generate and maintain

---

## Data Quality Monitoring Flow

```
┌─────────────────────┐
│  Quality Metrics    │
├─────────────────────┤
│  Total Records      │
│  Invalid Ages       │
│  Negative Bills     │
│  Payment Mismatches │
│  Invalid Dates      │
│  Avg Quality Score  │
└──────────┬──────────┘
           │
    ┌──────▼──────┐
    │   Monitor   │
    │   Daily     │
    └──────┬──────┘
           │
      ┌────▼────┐
      │ Report  │
      │ Issues  │
      └─────────┘
```

---

## Performance Considerations

| Layer | Storage | Query Speed | Update Lag | Cost |
|-------|---------|---|---|---|
| Raw | Small | Slow (nested) | N/A | Low |
| PSA | Small | Fast (structured) | Minimal | Low |
| Staging | Medium | Medium (embedded calcs) | Real-time | Medium |
| DL3 | Large | Very Fast (indexed) | 1-2 min | Medium-High |

**Optimization Tips**:
- Cluster fact table on `admission_date`
- Index dimension tables on foreign keys
- Partition by admission month for large datasets
- Use materialized views for frequently-accessed staging data

---

## Extending the Pipeline

To add new transformations:

1. **Add logic to Staging** if it affects dimensions or measures
2. **Create new Dimension** if needed for analytics
3. **Update Fact table** if new measures/attributes added
4. **Update macros/** if standardization rules change
5. **Document in BUSINESS_LOGIC.md**
6. **Add tests in tests/** for validation

---
