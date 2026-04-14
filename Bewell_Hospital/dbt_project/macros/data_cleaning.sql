{# Standardize gender values #}
{% macro standardize_gender(gender_column) %}
  CASE 
    WHEN UPPER(TRIM({{ gender_column }})) IN ('M', 'MALE') THEN 'Male'
    WHEN UPPER(TRIM({{ gender_column }})) IN ('F', 'FEMALE') THEN 'Female'
    ELSE 'Unknown'
  END
{% endmacro %}

{# Standardize city names #}
{% macro standardize_city(city_column) %}
  CASE 
    WHEN UPPER(TRIM({{ city_column }})) IN ('CHENNAI', 'TENDOLLYWOOD') THEN 'Chennai'
    WHEN UPPER(TRIM({{ city_column }})) IN ('BLR', 'BANGALORE') THEN 'Bangalore'
    WHEN UPPER(TRIM({{ city_column }})) = 'MUMBAI' THEN 'Mumbai'
    WHEN UPPER(TRIM({{ city_column }})) = 'HYDERABAD' THEN 'Hyderabad'
    WHEN UPPER(TRIM({{ city_column }})) = 'DELHI' THEN 'Delhi'
    ELSE COALESCE(NULLIF(TRIM({{ city_column }}), ''), 'Unknown')
  END
{% endmacro %}

{# Standardize department names #}
{% macro standardize_department(dept_column) %}
  CASE 
    WHEN UPPER(TRIM({{ dept_column }})) IN ('CARDIO', 'CARDIOLOGY') THEN 'Cardiology'
    WHEN UPPER(TRIM({{ dept_column }})) = 'PEDIATRICS' THEN 'Pediatrics'
    WHEN UPPER(TRIM({{ dept_column }})) = 'ORTHOPEDICS' THEN 'Orthopedics'
    WHEN UPPER(TRIM({{ dept_column }})) = 'NEUROLOGY' THEN 'Neurology'
    WHEN UPPER(TRIM({{ dept_column }})) = 'GENERAL' THEN 'General'
    WHEN COALESCE(NULLIF(TRIM({{ dept_column }}), ''), NULL) IS NULL THEN 'General'
    ELSE TRIM({{ dept_column }})
  END
{% endmacro %}

{# Standardize diagnosis #}
{% macro standardize_diagnosis(diag_column) %}
  COALESCE(NULLIF(TRIM({{ diag_column }}), ''), 'Unknown')
{% endmacro %}

{# Standardize doctor name #}
{% macro standardize_doctor(doctor_column) %}
  CASE 
    WHEN TRIM({{ doctor_column }}) = 'Dr.None' THEN 'Dr. Unknown'
    WHEN TRIM({{ doctor_column }}) = 'Dr.' THEN 'Dr. Unknown'
    WHEN COALESCE(NULLIF(TRIM({{ doctor_column }}), ''), NULL) IS NULL THEN 'Dr. Unknown'
    ELSE TRIM({{ doctor_column }})
  END
{% endmacro %}

{# Standardize insurance provider #}
{% macro standardize_insurance(insurance_column) %}
  CASE 
    WHEN COALESCE(NULLIF(TRIM({{ insurance_column }}), ''), NULL) IS NULL THEN 'Uninsured'
    WHEN UPPER(TRIM({{ insurance_column }})) = 'NONE' THEN 'Uninsured'
    ELSE TRIM({{ insurance_column }})
  END
{% endmacro %}

{# Standardize payment method #}
{% macro standardize_payment_method(payment_column) %}
  CASE 
    WHEN UPPER(TRIM({{ payment_column }})) IN ('UPI', 'UPI') THEN 'UPI'
    WHEN UPPER(TRIM({{ payment_column }})) = 'DEBIT CARD' THEN 'Debit Card'
    WHEN UPPER(TRIM({{ payment_column }})) = 'CREDIT CARD' THEN 'Credit Card'
    WHEN UPPER(TRIM({{ payment_column }})) = 'CASH' THEN 'Cash'
    WHEN UPPER(TRIM({{ payment_column }})) = 'INSURANCE' THEN 'Insurance'
    ELSE 'Unknown'
  END
{% endmacro %}

{# Validate and standardize age #}
{% macro validate_age(age_column) %}
  CASE 
    WHEN {{ age_column }} < 0 OR {{ age_column }} > {{ var('max_age') }} THEN NULL
    ELSE {{ age_column }}
  END
{% endmacro %}

{# Categorize age group #}
{% macro categorize_age_group(age_column) %}
  CASE 
    WHEN {{ age_column }} >= 0 AND {{ age_column }} <= 12 THEN 'Child'
    WHEN {{ age_column }} > 12 AND {{ age_column }} < 60 THEN 'Adult'
    WHEN {{ age_column }} >= 60 THEN 'Senior'
    ELSE 'Unknown'
  END
{% endmacro %}

{# Categorize revenue #}
{% macro categorize_revenue(bill_column) %}
  CASE 
    WHEN {{ bill_column }} < 10000 THEN 'Low'
    WHEN {{ bill_column }} >= 10000 AND {{ bill_column }} < 30000 THEN 'Medium'
    WHEN {{ bill_column }} >= 30000 THEN 'High'
    ELSE 'Unknown'
  END
{% endmacro %}
