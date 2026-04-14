{{
  config(
    materialized='table',
    schema='dl3_hospital',
    tags=['dl3', 'dimensions'],
    unique_id='dim_location_id'
  )
}}

/*
    DIM_LOCATION - Location/City Dimension Table
    Contains unique city records with metadata.
*/

WITH staging AS (
    SELECT DISTINCT
        City_Std,
        COUNT(*) AS patient_count
    FROM {{ ref('stg_hospital_admission') }}
    WHERE City_Std IS NOT NULL 
        AND City_Std != 'Unknown'
    GROUP BY City_Std
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['City_Std']) }} AS dim_location_id,
    City_Std AS city_name,
    patient_count,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM staging
