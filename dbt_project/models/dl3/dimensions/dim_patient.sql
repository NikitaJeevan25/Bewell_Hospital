{{
  config(
    materialized='table',
    schema='dl3_hospital',
    tags=['dl3', 'dimensions'],
    meta={
      'unique_id': 'dim_patient_id'
    }
  )
}}

/*
    DIM_PATIENT - Patient Dimension Table
    Contains unique patient records with demographic and personal information.
    Slowly Changing Dimension (SCD) Type 2 ready (includes flags for historicization).
*/

WITH staging AS (
    SELECT
        Patient_ID_Std,
        Patient_Name_Std,
        Age_Std,
        Gender_Std,
        Age_Group,
        City_Std,
        ROW_NUMBER() OVER (
            PARTITION BY Patient_ID_Std 
            ORDER BY loaded_at DESC
        ) AS rn
    FROM {{ ref('stg_hospital_admission') }}
    WHERE Patient_ID_Std IS NOT NULL
),

with_surrogate_key AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY Patient_ID_Std) AS dim_patient_id,
        Patient_ID_Std AS patient_source_id,
        Patient_Name_Std,
        Age_Std,
        Gender_Std,
        Age_Group,
        City_Std,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at,
        TRUE AS is_current_record
    FROM staging
    WHERE rn = 1
)

SELECT * FROM with_surrogate_key
