{{
  config(
    materialized='view',
    schema='stg_hospital',
    tags=['staging', 'transformations']
  )
}}

/*
    STAGING LAYER - Hospital Admission Data
    This layer applies comprehensive business logic:
    - Data standardization (gender, city, department, etc.)
    - Data quality checks with flag columns
    - Date standardization and validation
    - Financial calculations and validations
    - Derived metrics (LOS, revenue category, etc.)
*/

WITH raw_data AS (
    SELECT * FROM {{ ref('psa_hospital_admission') }}
),

standardized AS (
    SELECT
        -- Primary Keys
        COALESCE(Patient_ID, ROW_NUMBER() OVER (ORDER BY loaded_at)) AS Patient_ID_Std,
        
        -- Demographics (Standardized)
        COALESCE(NULLIF(TRIM(Patient_Name), ''), 'Unknown') AS Patient_Name_Std,
        Age AS Age_Original,
        {{ validate_age('Age') }} AS Age_Std,
        {{ standardize_gender('Gender') }} AS Gender_Std,
        
        -- Age Group Categorization
        {{ categorize_age_group(validate_age('Age')) }} AS Age_Group,
        
        -- Location (Standardized)
        {{ standardize_city('City') }} AS City_Std,
        
        -- Clinical Data (Standardized)
        {{ standardize_department('Department') }} AS Department_Std,
        {{ standardize_doctor('Doctor_Name') }} AS Doctor_Name_Std,
        {{ standardize_diagnosis('Diagnosis') }} AS Diagnosis_Std,
        
        -- Dates (Already standardized from raw_hospital_cleaned)
        Admission_Date AS Admission_Date_Std,
        Discharge_Date AS Discharge_Date_Std,
        
        -- Insurance (Standardized)
        {{ standardize_insurance('Insurance_Provider') }} AS Insurance_Provider_Std,
        Insurance_Coverage,
        
        -- Financial Data
        Total_Bill,
        Payment_Done,
        {{ standardize_payment_method('Payment_Method') }} AS Payment_Method_Std,
        
        -- Source tracking
        source_file,
        source_hash,
        loaded_at,
        updated_at
        
    FROM raw_data
),

calculated_metrics AS (
    SELECT
        *,
        
        -- Length of Stay Calculation
        CASE 
            WHEN Admission_Date_Std IS NOT NULL AND Discharge_Date_Std IS NOT NULL 
                 AND Discharge_Date_Std >= Admission_Date_Std
            THEN DATEDIFF(DAY, Admission_Date_Std, Discharge_Date_Std)
            ELSE NULL
        END AS Length_of_Stay,
        
        -- Financial Calculations
        CASE 
            WHEN Total_Bill > 0 THEN 
                CASE 
                    WHEN Insurance_Coverage > Total_Bill THEN Total_Bill
                    ELSE Insurance_Coverage
                END
            ELSE 0
        END AS Insurance_Coverage_Adj,
        
        -- Expected Payment = Total Bill - Insurance Coverage
        CASE 
            WHEN Total_Bill > 0 THEN 
                GREATEST(0, Total_Bill - CASE 
                    WHEN Insurance_Coverage > Total_Bill THEN Total_Bill
                    ELSE COALESCE(Insurance_Coverage, 0)
                END)
            ELSE 0
        END AS Expected_Payment,
        
        -- Insurance Ratio
        CASE 
            WHEN Total_Bill > 0 THEN 
                (CASE 
                    WHEN Insurance_Coverage > Total_Bill THEN Total_Bill
                    ELSE COALESCE(Insurance_Coverage, 0)
                END) / Total_Bill
            ELSE 0
        END AS Insurance_Ratio,
        
        -- Revenue Category
        CASE 
            WHEN Total_Bill < 10000 THEN 'Low'
            WHEN Total_Bill >= 10000 AND Total_Bill < 30000 THEN 'Medium'
            WHEN Total_Bill >= 30000 THEN 'High'
            ELSE 'Unknown'
        END AS Revenue_Category
        
    FROM standardized
),

data_quality_flags AS (
    SELECT
        *,
        
        -- Data Quality Flags
        CASE WHEN Age_Std IS NULL AND Age_Original IS NOT NULL AND (Age_Original < 0 OR Age_Original > {{ var('max_age') }}) THEN 1 ELSE 0 END AS is_invalid_age,
        
        CASE WHEN Total_Bill < 0 THEN 1 ELSE 0 END AS is_bill_negative,
        
        CASE WHEN Total_Bill > 0 AND Insurance_Coverage > Total_Bill THEN 1 ELSE 0 END AS is_insurance_exceeds_bill,
        
        CASE 
            WHEN Total_Bill > 0 AND Payment_Done IS NOT NULL 
                 AND Payment_Done > 0
                 AND ABS(Payment_Done - Expected_Payment) > 100 THEN 1 ELSE 0 
        END AS is_payment_mismatch,
        
        CASE WHEN Admission_Date_Std IS NOT NULL AND Discharge_Date_Std IS NOT NULL 
                 AND Discharge_Date_Std < Admission_Date_Std THEN 1 ELSE 0 END AS is_invalid_date,
        
        CASE WHEN Insurance_Provider_Std = 'Uninsured' THEN 1 ELSE 0 END AS is_uninsured,
        
        CASE WHEN Patient_Name_Std = 'Unknown' OR Patient_ID_Std IS NULL THEN 1 ELSE 0 END AS is_missing_demographics,
        
        -- Overall data quality score
        (CASE WHEN is_invalid_age = 1 THEN 0 ELSE 1 END +
         CASE WHEN is_bill_negative = 1 THEN 0 ELSE 1 END +
         CASE WHEN is_insurance_exceeds_bill = 1 THEN 0.5 ELSE 1 END +
         CASE WHEN is_payment_mismatch = 1 THEN 0 ELSE 1 END +
         CASE WHEN is_invalid_date = 1 THEN 0 ELSE 1 END) / 5 AS data_quality_score
        
    FROM calculated_metrics
)

SELECT
    Patient_ID_Std,
    Patient_Name_Std,
    Age_Std,
    Gender_Std,
    Age_Group,
    City_Std,
    Department_Std,
    Doctor_Name_Std,
    Diagnosis_Std,
    Admission_Date_Std,
    Discharge_Date_Std,
    Length_of_Stay,
    Insurance_Provider_Std,
    Insurance_Coverage_Adj,
    Total_Bill,
    Payment_Done,
    Expected_Payment,
    Insurance_Ratio,
    Revenue_Category,
    Payment_Method_Std,
    -- Data Quality Flags
    is_invalid_age,
    is_bill_negative,
    is_insurance_exceeds_bill,
    is_payment_mismatch,
    is_invalid_date,
    is_uninsured,
    is_missing_demographics,
    data_quality_score,
    -- Metadata
    source_file,
    loaded_at,
    CURRENT_TIMESTAMP() AS transformed_at
FROM data_quality_flags
