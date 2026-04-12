{{
  config(
    materialized='table',
    schema='psa_hospital',
    tags=['psa', 'raw_data']
  )
}}

/*
    PSA Layer - Persistent Staging Area
    This layer stores raw data from the source with added audit columns.
    All data is preserved as-is from the source, with minimal transformations.
    Used for data lineage, recovery, and audit purposes.
*/

SELECT
    -- Source columns (as-is)
    Patient_ID,
    Patient_Name,
    Age,
    Gender,
    City,
    Department,
    Doctor_Name,
    Admission_Date,
    Discharge_Date,
    Diagnosis,
    Insurance_Provider,
    Insurance_Coverage,
    Total_Bill,
    Payment_Done,
    Payment_Method,
    
    -- Audit columns
    CURRENT_TIMESTAMP() AS loaded_at,
    CURRENT_TIMESTAMP() AS updated_at,
    'hospital_management_data.csv' AS source_file,
    MD5(CONCAT(
        COALESCE(Patient_ID, 'NULL'), '_',
        COALESCE(Patient_Name, 'NULL'), '_',
        COALESCE(Admission_Date, 'NULL')
    )) AS source_hash,
    1 AS is_active
    
FROM {{ source('bewell_hospital_raw', 'hospital_management_data') }}
