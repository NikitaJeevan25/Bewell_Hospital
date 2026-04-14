{{
  config(
    materialized='table',
    schema='dl3_hospital',
    tags=['dl3', 'facts'],
    indexes=[
      {'columns': ['admission_date'], 'type': 'automatic'},
      {'columns': ['dim_patient_id', 'admission_date'], 'type': 'automatic'}
    ]
  )
}}

/*
    FACT_PATIENT_VISIT - Core Fact Table
    Transactional table containing patient visit details with measures.
    Connects to dimension tables via surrogate keys.
    Includes all financial metrics and KPIs.
*/

WITH staging AS (
    SELECT
        stg.Patient_ID_Std,
        stg.Admission_Date_Std,
        stg.Discharge_Date_Std,
        stg.Department_Std,
        stg.Doctor_Name_Std,
        stg.Insurance_Provider_Std,
        stg.City_Std,
        stg.Total_Bill,
        stg.Payment_Done,
        stg.Insurance_Coverage_Adj,
        stg.Expected_Payment,
        stg.Insurance_Ratio,
        stg.Length_of_Stay,
        stg.Revenue_Category,
        stg.Age_Std,
        stg.Gender_Std,
        stg.Age_Group,
        stg.Diagnosis_Std,
        stg.data_quality_score,
        -- Data Quality Flags
        stg.is_invalid_age,
        stg.is_bill_negative,
        stg.is_insurance_exceeds_bill,
        stg.is_payment_mismatch,
        stg.is_invalid_date,
        stg.is_uninsured,
        stg.is_missing_demographics,
        ROW_NUMBER() OVER (
            PARTITION BY stg.Patient_ID_Std, stg.Admission_Date_Std 
            ORDER BY stg.loaded_at DESC
        ) AS rn
    FROM {{ ref('stg_hospital_admission') }} AS stg
),

joined_dimensions AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY stg.Patient_ID_Std, stg.Admission_Date_Std) AS fact_patient_visit_id,
        
        -- Dimension Keys
        COALESCE(dim_pat.dim_patient_id, -1) AS dim_patient_id,
        COALESCE(dim_doc.dim_doctor_id, -1) AS dim_doctor_id,
        COALESCE(dim_loc.dim_location_id, -1) AS dim_location_id,
        COALESCE(dim_ins.dim_insurance_id, -1) AS dim_insurance_id,
        COALESCE(dim_dept.dim_department_id, -1) AS dim_department_id,
        
        -- Dates
        stg.Admission_Date_Std AS admission_date,
        stg.Discharge_Date_Std AS discharge_date,
        CAST(stg.Admission_Date_Std AS DATE) AS admission_date_key,
        YEAR(stg.Admission_Date_Std) || LPAD(MONTH(stg.Admission_Date_Std), 2, '0') AS admission_month_key,
        
        -- Measures
        COALESCE(stg.Total_Bill, 0) AS total_bill_amount,
        COALESCE(stg.Payment_Done, 0) AS payment_done_amount,
        COALESCE(stg.Insurance_Coverage_Adj, 0) AS insurance_coverage_amount,
        COALESCE(stg.Expected_Payment, 0) AS expected_payment_amount,
        COALESCE(stg.Insurance_Ratio, 0) AS insurance_ratio,
        COALESCE(stg.Length_of_Stay, 0) AS length_of_stay_days,
        
        -- Dimensions
        stg.Revenue_Category,
        stg.Age_Group,
        stg.Gender_Std AS gender,
        stg.Diagnosis_Std AS diagnosis,
        
        -- Data Quality Score
        stg.data_quality_score,
        
        -- Data Quality Flags
        stg.is_invalid_age,
        stg.is_bill_negative,
        stg.is_insurance_exceeds_bill,
        stg.is_payment_mismatch,
        stg.is_invalid_date,
        stg.is_uninsured,
        stg.is_missing_demographics,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
        
    FROM staging AS stg
    LEFT JOIN {{ ref('dim_patient') }} AS dim_pat 
        ON stg.Patient_ID_Std = dim_pat.patient_source_id
    LEFT JOIN {{ ref('dim_doctor') }} AS dim_doc 
        ON stg.Doctor_Name_Std = dim_doc.doctor_name_std
    LEFT JOIN {{ ref('dim_location') }} AS dim_loc 
        ON stg.City_Std = dim_loc.city_name
    LEFT JOIN {{ ref('dim_insurance') }} AS dim_ins 
        ON stg.Insurance_Provider_Std = dim_ins.insurance_provider
    LEFT JOIN {{ ref('dim_department') }} AS dim_dept 
        ON stg.Department_Std = dim_dept.department_name
    WHERE stg.rn = 1
)

SELECT
    fact_patient_visit_id,
    dim_patient_id,
    dim_doctor_id,
    dim_location_id,
    dim_insurance_id,
    dim_department_id,
    admission_date,
    discharge_date,
    admission_date_key,
    admission_month_key,
    total_bill_amount,
    payment_done_amount,
    insurance_coverage_amount,
    expected_payment_amount,
    insurance_ratio,
    length_of_stay_days,
    revenue_category,
    age_group,
    gender,
    diagnosis,
    data_quality_score,
    is_invalid_age,
    is_bill_negative,
    is_insurance_exceeds_bill,
    is_payment_mismatch,
    is_invalid_date,
    is_uninsured,
    is_missing_demographics,
    created_at,
    updated_at
FROM joined_dimensions
