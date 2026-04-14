{{
  config(
    materialized='table',
    schema='dl3_hospital',
    tags=['dl3', 'dimensions'],
    meta={
      'unique_id': 'dim_doctor_id'
    }
  )
}}

/*
    DIM_DOCTOR - Doctor/Provider Dimension Table
    Contains unique doctor records with standardized names.
*/

WITH staging AS (
    SELECT DISTINCT
        Doctor_Name_Std,
        COUNT(*) AS visit_count
    FROM {{ ref('stg_hospital_admission') }}
    WHERE Doctor_Name_Std IS NOT NULL 
        AND Doctor_Name_Std != 'Dr. Unknown'
    GROUP BY Doctor_Name_Std
),

with_surrogate_key AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY Doctor_Name_Std) AS dim_doctor_id,
        Doctor_Name_Std,
        visit_count,
        CURRENT_TIMESTAMP() AS created_at,
        CURRENT_TIMESTAMP() AS updated_at
    FROM staging
)

SELECT * FROM with_surrogate_key
