{{
  config(
    materialized='view',
    schema='raw_hospital',
    tags=['raw', 'data_cleaning']
  )
}}

/*
    Raw Hospital Cleaned - Data Cleaning Layer
    This layer cleans and standardizes messy raw data:
    - Standardizes categorical values (Gender, City, Department, Insurance, Payment Method)
    - Fixes date format inconsistencies
    - Handles NULL/empty values
    - Validates numeric values (Age, Bills, Payments)
    - Removes obviously invalid data (negative ages, negative bills)
    Used as input for PSA layer transformations
*/

WITH cleaned_data AS (
  SELECT
    -- Patient ID: Keep as is, will be standardized in staging
    CAST(Patient_ID AS INT) AS Patient_ID,
    
    -- Patient Name: Trim and handle nulls
    NULLIF(TRIM(Patient_Name), '') AS Patient_Name,
    
    -- Age: Validate (remove negative, cap at 120)
    CASE 
      WHEN Age < 0 OR Age > 120 THEN NULL
      ELSE Age
    END AS Age,
    
    -- Gender: Standardize using macro
    {{ standardize_gender('Gender') }} AS Gender,
    
    -- City: Standardize using macro
    {{ standardize_city('City') }} AS City,
    
    -- Department: Standardize using macro
    {{ standardize_department('Department') }} AS Department,
    
    -- Doctor Name: Standardize using macro
    {{ standardize_doctor('Doctor_Name') }} AS Doctor_Name,
    
    -- Admission Date: Handle format inconsistencies
    TRY_TO_DATE(
      CASE
        WHEN Admission_Date IS NULL OR TRIM(Admission_Date) = '' THEN NULL
        ELSE Admission_Date
      END,
      'AUTO'
    ) AS Admission_Date,
    
    -- Discharge Date: Handle format inconsistencies
    TRY_TO_DATE(
      CASE
        WHEN Discharge_Date IS NULL OR TRIM(Discharge_Date) = '' THEN NULL
        ELSE Discharge_Date
      END,
      'AUTO'
    ) AS Discharge_Date,
    
    -- Diagnosis: Standardize using macro
    {{ standardize_diagnosis('Diagnosis') }} AS Diagnosis,
    
    -- Insurance Provider: Standardize using macro
    {{ standardize_insurance('Insurance_Provider') }} AS Insurance_Provider,
    
    -- Insurance Coverage: Keep numeric, set negative to 0
    CASE
      WHEN Insurance_Coverage < 0 THEN 0
      ELSE Insurance_Coverage
    END AS Insurance_Coverage,
    
    -- Total Bill: Keep numeric, set negative to NULL
    CASE
      WHEN Total_Bill < 0 THEN NULL
      ELSE Total_Bill
    END AS Total_Bill,
    
    -- Payment Done: Keep numeric, set negative to NULL
    CASE
      WHEN Payment_Done < 0 THEN NULL
      ELSE Payment_Done
    END AS Payment_Done,
    
    -- Payment Method: Standardize using macro
    {{ standardize_payment_method('Payment_Method') }} AS Payment_Method,
    
    -- Metadata
    CURRENT_TIMESTAMP() AS cleaned_at
    
  FROM {{ source('bewell_hospital_raw', 'hospital_management_data') }}
)

SELECT * FROM cleaned_data
