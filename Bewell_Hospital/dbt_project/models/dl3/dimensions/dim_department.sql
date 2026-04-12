{{
  config(
    materialized='table',
    schema='dl3_hospital',
    tags=['dl3', 'dimensions'],
    unique_id='dim_department_id'
  )
}}

/*
    DIM_DEPARTMENT - Department/Specialty Dimension Table
    Contains unique hospital departments and specialties.
*/

WITH staging AS (
    SELECT DISTINCT
        Department_Std,
        COUNT(*) AS visit_count,
        COUNT(DISTINCT Patient_ID_Std) AS unique_patients
    FROM {{ ref('stg_hospital_admission') }}
    WHERE Department_Std IS NOT NULL 
        AND Department_Std != 'Unknown'
    GROUP BY Department_Std
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['Department_Std']) }} AS dim_department_id,
    Department_Std AS department_name,
    visit_count,
    unique_patients,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM staging
