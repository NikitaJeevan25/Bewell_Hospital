{{
  config(
    materialized='table',
    schema='dl3_hospital',
    tags=['dl3', 'dimensions'],
    unique_id='dim_insurance_id'
  )
}}

/*
    DIM_INSURANCE - Insurance Provider Dimension Table
    Contains unique insurance provider records.
*/

WITH staging AS (
    SELECT DISTINCT
        Insurance_Provider_Std,
        COUNT(*) AS claim_count,
        SUM(Insurance_Coverage_Adj) AS total_coverage,
        AVG(Insurance_Coverage_Adj) AS avg_coverage
    FROM {{ ref('stg_hospital_admission') }}
    WHERE Insurance_Provider_Std IS NOT NULL
    GROUP BY Insurance_Provider_Std
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['Insurance_Provider_Std']) }} AS dim_insurance_id,
    Insurance_Provider_Std AS insurance_provider,
    claim_count,
    total_coverage,
    avg_coverage,
    CASE WHEN Insurance_Provider_Std = 'Uninsured' THEN 1 ELSE 0 END AS is_uninsured_flag,
    CURRENT_TIMESTAMP() AS created_at,
    CURRENT_TIMESTAMP() AS updated_at
FROM staging
