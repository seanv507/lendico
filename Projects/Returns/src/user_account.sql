---
name: user_account
schema: base
type: table
target: intelligence
dependencies: [countries, user_attributes, exchange_rates, cleaned_state_machine_history, loan_state_annotations]
---

$load_operation

SELECT
  user_account.id_user,
  user_account.dwh_country_id,
  user_account.country_name,
  user_account.currency_code,
  user_account.creation_date,
  user_account.user_type,
  coalesce(user_account.webservice_consumer, user_account.user_campaign) AS user_campaign,
  user_account.account_type,
  user_account.acceptance_of_direct_debit,
  user_account.origin_country,
  user_account.origin_id_user,
  user_account.email,
  user_account.state,
  user_account.last_login,
  user_account.roles,
  user_account.loan_request_count,
  user_account.first_loan_request_created_at,
  user_account.bid_count,
  user_account.first_bid_created_at,
  user_account.enabled,
  user_account.verified,
  user_account.is_deactivated,
  user_account.is_deleted,
  user_account.acc_internal_account_id,
  user_account.first_name,
  user_account.last_name,
  user_account.gender,
  user_account.birthday,
  user_account.user_age,
  user_account.newsletter_subscription,
  user_account.net_income,
  user_account.income,
  user_account.income_if_any,
  user_account.income_business,
  user_account.income_net_income_other,
  user_account.income_employment_status,
  user_account.income_position,
  user_account.income_employer_name,
  user_account.income_industry,
  user_account.income_child_benefit,
  user_account.income_alimony,
  user_account.income_pension,
  user_account.income_rent,
  il.capacity_calculation(user_account.dwh_country_id, user_account.roles, user_account.net_income, user_account.expenses_rent, user_account.expenses_alimony, user_account.marital_status, user_account.expenses_children::NUMERIC, user_account.expenses_home, user_account.expenses_monthly_mortgage, user_account.expenses_leasing, user_account.expenses_current_loans, NULL::NUMERIC, NULL::TEXT, 'expenses'::TEXT) AS expenses_without_loans,
  il.capacity_calculation(user_account.dwh_country_id, user_account.roles, user_account.net_income, user_account.expenses_rent, user_account.expenses_alimony, user_account.marital_status, user_account.expenses_children::NUMERIC, user_account.expenses_home, user_account.expenses_monthly_mortgage, user_account.expenses_leasing, user_account.expenses_current_loans, NULL::NUMERIC, NULL::TEXT, 'pre_capacity'::TEXT) AS pre_capacity,
  user_account.expenses_current_loans,
  user_account.expenses_home,
  user_account.expenses_children,
  user_account.marital_status,
  user_account.street,
  user_account.street_number,
  user_account.city_residency,
  user_account.postal_code,
  user_account.landline_flag,
  user_account.voucher_code,
  user_account.loan_request_description,
  user_account.loan_request_title,
  user_account.confirmation_token,
  user_account.status_history,
  user_account.state_history,

  (user_account.net_income / exchange_rates.exchange_rate_value)::decimal(19,4) AS eur_net_income,
  (user_account.income / exchange_rates.exchange_rate_value)::decimal(19,4) AS eur_income,
  (user_account.income_if_any / exchange_rates.exchange_rate_value)::decimal(19,4) AS eur_income_if_any,
  (user_account.income_business / exchange_rates.exchange_rate_value)::decimal(19,4) AS eur_income_business,
  (user_account.income_net_income_other / exchange_rates.exchange_rate_value)::decimal(19,4) AS eur_income_net_income_other,
  (user_account.income_child_benefit / exchange_rates.exchange_rate_value)::decimal(19,4) AS eur_income_child_benefit,
  (user_account.income_alimony / exchange_rates.exchange_rate_value)::decimal(19,4) AS eur_income_alimony,
  (user_account.income_pension / exchange_rates.exchange_rate_value)::decimal(19,4) AS eur_income_pension,
  (user_account.income_rent / exchange_rates.exchange_rate_value)::decimal(19,4) AS eur_income_rent,

  user_account.created_at,
  user_account.updated_at,
  user_account.dwh_created,
  user_account.dwh_last_modified

FROM (

  SELECT
    user_account.id_user AS id_user,
    user_account.dwh_country_id AS dwh_country_id,
    most_advanced_loan_annotations.fk_loan_request AS fk_most_advanced_loan_request,
    most_advanced_loan_annotations.fk_loan AS fk_most_advanced_loan,
    countries.country_name AS country_name,
    countries.currency_code AS currency_code,
    date_trunc('day', user_account.created_at) AS creation_date,

    CASE
      WHEN testuser.testuser = 1
        THEN 'test_user'
      WHEN testuser.testuser = 0
        THEN il.user_type(user_account.email)
      ELSE user_type.value
    END AS user_type,

    CASE
      WHEN user_account.roles LIKE '%LENDER%'
        THEN 'other'
      WHEN first_version.email IS NOT NULL AND first_version.email != '' 
        THEN il.user_campaign(lower(first_version.email))
      ELSE il.user_campaign(lower(user_account.email))
  
    END AS user_campaign,
  
    CASE
      WHEN user_account.roles LIKE '%BORROWER%'
        THEN 'borrower'
      WHEN user_account.acc_internal_account_id IS NOT NULL AND bank_account_overdraft_direct_debit IS NOT NULL AND user_attributes.bank_account_internal_direct_debit IS NOT NULL AND user_attributes.bank_account_external_direct_debit IS NOT NULL
	THEN 'prepay_lender_with_overdraft'
      WHEN user_account.acc_internal_account_id IS NOT NULL AND bank_account_internal_direct_debit IS NOT NULL
        THEN 'prepay_lender_with_direct_debit'
      WHEN user_account.acc_internal_account_id IS NOT NULL AND bank_account_internal_direct_debit IS NULL
        THEN 'prepay_lender_without_direct_debit'
      WHEN user_account.acc_internal_account_id IS NULL  AND bank_account_external_direct_debit IS NOT NULL
        THEN 'postpay_lender_with_direct_debit'
      WHEN user_account.acc_internal_account_id IS NULL  AND bank_account_external_direct_debit IS NULL
        THEN 'postpay_lender_without_direct_debit'  
    END AS account_type,

    CASE
      WHEN user_account.roles LIKE '%BORROWER%'
        THEN loan.date_of_signature
      WHEN user_account.acc_internal_account_id IS NOT NULL
        THEN bank_account_internal_direct_debit --prepay: all prepay lenders accepted direct debit but when this date is set it means that transactions does not have to be accepted first
      ELSE bank_account_external_direct_debit --postpay
  
    END AS acceptance_of_direct_debit,
    user_account.origin_country::int,
    user_account.origin_id_user::int,

    regexp_replace(lower(webservice_consumer.name), '\s+','_') AS webservice_consumer,

    coalesce(loan_request.count, 0)::integer AS loan_request_count,
    loan_request.min_created_at AS first_loan_request_created_at,
    coalesce(loan_request_funding.count, 0)::integer AS bid_count,
    loan_request_funding.min_created_at AS first_bid_created_at,
    user_account.email,
    user_account.state,
    user_account.last_login,
    user_account.roles,
    user_account.enabled,
    user_account.verified,
    user_account.is_deactivated,
    user_account.is_deleted,
    user_account.acc_internal_account_id,

    coalesce(user_attributes.first_name, user_attributes.initials) AS first_name,
    user_attributes.last_name,
    user_attributes.gender,
    user_account.birthday,
    date_part('year', age(user_account.created_at, user_account.birthday))::integer AS user_age,
    user_attributes.newsletter_subscription,

    --income
    CASE
      -- Germany
      WHEN user_account.dwh_country_id = 1
        THEN

          CASE
            WHEN user_account.roles LIKE '%BORROWER%'
              THEN
                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_child_benefit, 0.0::decimal)
              + coalesce(user_attributes.income_alimony, 0.0::decimal)
              + coalesce(user_attributes.income_pension, 0.0::decimal)
              + coalesce(user_attributes.income_rent, 0.0::decimal) * 0.70
              + CASE 
                  WHEN user_attributes.income_business < 2084
                    THEN coalesce(user_attributes.income_business, 0.0::decimal) * 0.75

                  WHEN user_attributes.income_business < 4167
                    THEN coalesce(user_attributes.income_business, 0.0::decimal) * 0.65
                
                  WHEN user_attributes.income_business < 6250
                    THEN coalesce(user_attributes.income_business, 0.0::decimal) * 0.60
                  
                  WHEN user_attributes.income_business >= 6250
                    THEN coalesce(user_attributes.income_business, 0.0::decimal) * 0.55

                  ELSE 0.0::decimal
                END
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_if_any, 0.0::decimal)
              - coalesce(user_attributes.expenses_health_insurance, 0.0::decimal)

             ELSE
                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_business, 0.0::decimal)

          END

      -- Austria
      WHEN user_account.dwh_country_id = 32
        THEN  

          CASE
            WHEN user_account.roles LIKE '%BORROWER%'
              THEN
 
                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_child_benefit, 0.0::decimal)
              + coalesce(user_attributes.income_alimony, 0.0::decimal)
              + coalesce(user_attributes.income_pension, 0.0::decimal)
              + coalesce(user_attributes.income_rent, 0.0::decimal) * 0.70
              + CASE 
                  WHEN user_attributes.income_business < 917
                    THEN coalesce(user_attributes.income_business, 0.0::decimal)

                  WHEN user_attributes.income_business < 2084
                    THEN coalesce(user_attributes.income_business, 0.0::decimal) * 0.64
                
                  WHEN user_attributes.income_business < 5000
                    THEN coalesce(user_attributes.income_business, 0.0::decimal) * 0.57
                  
                  WHEN user_attributes.income_business >= 5000
                    THEN coalesce(user_attributes.income_business, 0.0::decimal) * 0.50

                  ELSE 0.0::decimal
                END
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_if_any, 0.0::decimal)
              - coalesce(user_attributes.expenses_health_insurance, 0.0::decimal)

            ELSE
                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_if_any, 0.0::decimal)

          END

      -- Poland
      WHEN user_account.dwh_country_id = 16
        THEN  

          CASE
            WHEN user_account.roles LIKE '%BORROWER%'
              THEN

                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_pension, 0.0::decimal)
              + coalesce(user_attributes.income_rent, 0.0::decimal)
              + coalesce(user_attributes.income_business, 0.0::decimal)
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_if_any, 0.0::decimal)

            ELSE
                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_business, 0.0::decimal)
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_if_any, 0.0::decimal)
          END

      -- Spain
      WHEN user_account.dwh_country_id = 4
        THEN

          CASE
            WHEN user_account.roles LIKE '%BORROWER%'
              THEN

                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_pension, 0.0::decimal)
              + coalesce(user_attributes.income_business, 0.0::decimal)
              + coalesce(user_attributes.income_renta, 0.0::decimal) * 0.70
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_if_any, 0.0::decimal)

            ELSE
                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_pension, 0.0::decimal)
              + coalesce(user_attributes.income_renta, 0.0::decimal)
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_if_any, 0.0::decimal)
          END

      -- Netherlands
      WHEN user_account.dwh_country_id = 128
        THEN 
  
          CASE
            WHEN user_account.roles LIKE '%BORROWER%'
              THEN

                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_business, 0.0::decimal) * 0.50
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_if_any, 0.0::decimal)

            ELSE
              0.0::decimal
          END

      -- South Africa
      WHEN user_account.dwh_country_id = 64
        THEN  
 
          CASE
            WHEN user_account.roles LIKE '%BORROWER%'
              THEN

                coalesce(user_attributes.income_child_benefit, 0.0::decimal)
              + coalesce(user_attributes.income_alimony, 0.0::decimal)
              + coalesce(user_attributes.income_pension, 0.0::decimal)
              + coalesce(user_attributes.income_rent, 0.0::decimal) * 0.70
              + coalesce(user_attributes.income_unemployed, 0.0::decimal)
              + CASE 
                  WHEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) < 13800
                    THEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) * 0.82

                  WHEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) < 21563
                    THEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) * 0.79
                
                  WHEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) < 29843
                    THEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) * 0.77
 
                  WHEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) < 41745
                    THEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) * 0.73

                  WHEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) < 53217
                    THEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) * 0.70
                
                  WHEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) >= 53217
                    THEN coalesce(user_attributes.income, 0.0::decimal) + coalesce(user_attributes.income_business, 0.0::decimal) * 0.66

                  ELSE 0.0::decimal
                END
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_if_any, 0.0::decimal)
              + coalesce(user_attributes.income_any, 0.0::decimal)
              + coalesce(user_attributes.income_business_other, 0.0::decimal)

            ELSE

                coalesce(user_attributes.income, 0.0::decimal)
              + coalesce(user_attributes.income_unemployed, 0.0::decimal)
              + coalesce(user_attributes.income_net_income_other, 0.0::decimal)
              + coalesce(user_attributes.income_any, 0.0::decimal)
           
          END

      ELSE coalesce(coalesce(user_attributes.income, user_attributes.income_if_any), user_attributes.income_business)::decimal(19,2)
    END::decimal(19,2) AS net_income,

    user_attributes.income::decimal(19,2) AS income,
    user_attributes.income_if_any::decimal(19,2) AS income_if_any,
    user_attributes.income_any::decimal(19,2) AS income_any,
    user_attributes.income_business::decimal(19,2) AS income_business,
    user_attributes.income_business_other::decimal(19,2) AS income_business_other,
    user_attributes.income_net_income_other::decimal(19,2) AS income_net_income_other,

    user_attributes.income_child_benefit,
    user_attributes.income_unemployed::decimal(19,2) AS income_unemployed,
    user_attributes.income_alimony::decimal(19,2) AS income_alimony,
    user_attributes.income_pension::decimal(19,2) AS income_pension,
    user_attributes.income_rent::decimal(19,2) AS income_rent,
    user_attributes.income_renta::decimal(19,2) AS income_renta,


    user_attributes.income_employment_status,
    user_attributes.income_position,
    user_attributes.income_employer_name,
    user_attributes.income_industry,

    user_attributes.expenses_home,
    user_attributes.expenses_children,
    user_attributes.expenses_monthly_mortgage::decimal(19,2) AS expenses_monthly_mortgage,
    user_attributes.expenses_leasing::decimal(19,2) AS expenses_leasing,
    user_attributes.expenses_current_loans::decimal(19,2) AS expenses_current_loans,
    user_attributes.expenses_rent::decimal AS expenses_rent,
    user_attributes.expenses_alimony::decimal(19,2) AS expenses_alimony,
    COALESCE(loan.category, loan_request.category) AS use_of_loan,
    user_attributes.marital_status,
    user_attributes.street,
    user_attributes.street_number,
    user_attributes.city_residency,
    user_attributes.postal_code,
    user_attributes.landline_flag,
    user_attributes.voucher_code,
    user_attributes.loan_request_description,
    user_attributes.loan_request_title,
  /*
      borrower:
  
      lender:
      last_name - just for test,
      postal_code
      voucher_code
  */

    user_account.confirmation_token,
    coalesce(status_history.steps, (ARRAY[])::state_pair[])::state_pair[] AS status_history,
    state_history.steps AS state_history,
    user_account.created_at,
    user_account.updated_at,
    user_account.dwh_created,
    user_account.dwh_last_modified
  
  FROM backend."user" AS user_account
  
  JOIN (
    SELECT
      fk_user,
      dwh_country_id,
      (attributes -> 'first_name')::character varying AS first_name,
      (attributes -> 'initials')::character varying AS initials,
      (attributes -> 'last_name')::character varying AS last_name,
      (attributes -> 'gender')::character varying AS gender,
      (attributes -> 'user_income_net_income')::decimal / 100 AS income,
      (attributes -> 'user_income_net_income_if_any')::decimal / 100 AS income_if_any,
      (attributes -> 'user_income_net_income_any')::decimal / 100 AS income_any,
      (attributes -> 'user_income_net_income_from_business')::decimal / 100 AS income_business,
      (attributes -> 'user_income_net_income_from_business_other')::decimal / 100 AS income_business_other,
      (attributes -> 'user_income_income_unemployed')::decimal / 100 AS income_unemployed,
      (attributes -> 'user_income_alimony')::decimal / 100 AS income_alimony,
      (attributes -> 'user_income_rent')::decimal / 100 AS income_rent,
      (attributes -> 'user_income_renta')::decimal / 100 AS income_renta,
      (attributes -> 'user_income_child_benefit')::decimal AS income_child_benefit, -- that is correct no div by 100
      (attributes -> 'user_income_pension')::decimal / 100 AS income_pension,

      CASE
      WHEN attributes -> 'bank_account_internal_direct_debit' !~ '[0-9] '
      AND (attributes -> 'bank_account_internal_direct_debit') IS NOT NULL
      AND (attributes -> 'bank_account_external_direct_debit') != '0'
      THEN (to_timestamp((attributes -> 'bank_account_internal_direct_debit')::BIGINT)::TIMESTAMP without time zone)::DATE
      WHEN (attributes -> 'bank_account_internal_direct_debit') IS NOT NULL
      AND (attributes -> 'bank_account_external_direct_debit') != '0'     
      THEN ((attributes -> 'bank_account_internal_direct_debit')::TIMESTAMP without time zone)::DATE
      ELSE NULL
      END AS bank_account_internal_direct_debit,

      CASE
      WHEN attributes -> 'bank_account_external_direct_debit' !~ '[0-9] '
      AND (attributes -> 'bank_account_external_direct_debit') IS NOT NULL
      AND (attributes -> 'bank_account_external_direct_debit') != '0'
      THEN (to_timestamp((attributes -> 'bank_account_external_direct_debit')::BIGINT)::TIMESTAMP without time zone)::DATE
      WHEN (attributes -> 'bank_account_external_direct_debit') IS NOT NULL
      AND (attributes -> 'bank_account_external_direct_debit') != '0'
      THEN ((attributes -> 'bank_account_external_direct_debit')::TIMESTAMP without time zone)::DATE
      ELSE NULL
      END AS bank_account_external_direct_debit,
      attributes->'bank_account_overdraft_direct_debit'  AS bank_account_overdraft_direct_debit, 
      il.text_to_numeric(attributes -> 'user_income_net_income_other')::decimal / 100 AS income_net_income_other,

      CASE
        WHEN length((attributes -> 'newsletter_subscription')::text) = 0
          THEN 0
        ELSE coalesce((attributes -> 'newsletter_subscription')::integer, 0)::integer
        END AS newsletter_subscription,

      attributes -> 'user_income_employment_status' AS income_employment_status,
      attributes -> 'user_income_position' AS income_position,
      attributes -> 'user_income_employer_name' AS income_employer_name,
      attributes -> 'user_income_industry' AS income_industry,

      attributes -> 'user_expenses_home' AS expenses_home,
      attributes -> 'user_expenses_children' AS expenses_children,
      (attributes -> 'user_expenses_living_insurance')::decimal / 100 AS expenses_living_insurance,
      (attributes -> 'user_expenses_health_insurance')::decimal / 100 AS expenses_health_insurance,
      (attributes -> 'user_expenses_monthly_mortgage')::decimal / 100 AS expenses_monthly_mortgage,
      (attributes -> 'user_expenses_leasing')::decimal / 100 AS expenses_leasing,
      (attributes -> 'user_expenses_current_loans')::decimal / 100 AS expenses_current_loans,
      (attributes -> 'user_expenses_monthly_rent')::decimal / 100 AS expenses_rent,
      (attributes -> 'user_expenses_alimony')::decimal / 100 AS expenses_alimony,
      attributes -> 'marital_status' AS marital_status,
      attributes -> 'street' AS street,
      attributes -> 'street_number' AS street_number,
      attributes -> 'city' AS city_residency,
      attributes -> 'postal_code' AS postal_code,
      attributes -> 'voucher_code' AS voucher_code,
      CASE 
      WHEN (attributes -> 'landline') IS NOT NULL 
        THEN 1
      ELSE 0
      END AS landline_flag,

      attributes -> 'loan_request_description' AS loan_request_description, -- TODO: depricate
      attributes -> 'loan_request_title' AS loan_request_title -- TODO: depricate

    FROM base.user_attributes 
    ) AS user_attributes

    ON user_attributes.fk_user = user_account.id_user
    AND user_attributes.dwh_country_id = user_account.dwh_country_id
  
  LEFT JOIN (
    SELECT
      dwh_country_id,
      id_user,
      il.user_type_history_agg(user_type.user_type) AS value
  
    FROM (
      SELECT 
        dwh_country_id,
        id_user,
        il.user_type(email) AS user_type,
        updated_at
  
     FROM backend.user_version 
        ORDER BY id_user, updated_at
    ) AS user_type 
  
   GROUP BY user_type.dwh_country_id, user_type.id_user
  
  ) user_type 
    ON user_account.dwh_country_id = user_type.dwh_country_id 
    AND user_account.id_user = user_type.id_user
  
  LEFT JOIN backend.user_version AS first_version
    ON user_account.dwh_country_id = first_version.dwh_country_id
    AND user_account.id_user = first_version.id_user
    AND first_version.version = 1
  
  LEFT JOIN base.countries
    ON user_account.dwh_country_id = countries.dwh_country_id

  LEFT JOIN (
    SELECT
      dwh_country_id,
      fk_user,
      count(id_loan_request) AS count,
      min(created_at) AS min_created_at,
      first(fk_webservice_consumer ORDER BY created_at) AS fk_webservice_consumer,
      LAST(id_loan_request ORDER BY created_at) AS id_loan_request,
      LAST(category ORDER BY created_at) AS category

    FROM backend.loan_request
    GROUP BY dwh_country_id, fk_user

  ) AS loan_request
    ON user_account.id_user = loan_request.fk_user
    AND user_account.dwh_country_id = loan_request.dwh_country_id

  LEFT JOIN (
    SELECT
      dwh_country_id,
      fk_user,
      count(id_loan_request_funding) AS count,
      min(created_at) AS min_created_at

    FROM backend.loan_request_funding
    GROUP BY dwh_country_id, fk_user

  ) AS loan_request_funding
    ON user_account.id_user = loan_request_funding.fk_user
    AND user_account.dwh_country_id = loan_request_funding.dwh_country_id

  LEFT JOIN (
    SELECT
      dwh_country_id,
      fk_user,
      MIN(il.parse_date(date_of_signature)) AS date_of_signature,
      LAST(id_loan ORDER BY created_at) AS id_loan,
      LAST(category ORDER BY created_at) AS category

    FROM backend.loan
    GROUP BY dwh_country_id, fk_user

  ) AS loan
    ON user_account.id_user = loan.fk_user
    AND user_account.dwh_country_id = loan.dwh_country_id

  LEFT JOIN thing.testuser
    ON user_account.id_user = testuser.id_user
    AND user_account.dwh_country_id = testuser.dwh_country_id

  LEFT JOIN backend.webservice_consumer
    ON loan_request.fk_webservice_consumer = webservice_consumer.id_webservice_consumer
    AND loan_request.dwh_country_id = webservice_consumer.dwh_country_id

  LEFT JOIN (

    SELECT
      dwh_country_id,
      fk_user,
      array_agg((action, created_at)::state_pair
         ORDER BY id_user_status_history) AS steps

      FROM backend.user_status_history
      GROUP BY dwh_country_id, fk_user

  ) AS status_history
    ON user_account.id_user = status_history.fk_user
    AND user_account.dwh_country_id = status_history.dwh_country_id

  LEFT JOIN (
    SELECT
      dwh_country_id,
      fk_user,
      array_agg((state_history.step, state_history.event_timestamp)::state_pair
                ORDER BY id_state_machine_history) AS steps
    FROM (
      SELECT
        dwh_country_id,
        identifier::INTEGER AS fk_user,
        created_at AS event_timestamp,
        id_state_machine_history,
        end_state AS step

      FROM base.cleaned_state_machine_history

      WHERE schema_name = 'BorrowerRegistration'
        OR schema_name = 'LenderRegistration'

    ) AS state_history
    GROUP BY dwh_country_id, fk_user

  ) AS state_history
    ON state_history.fk_user = user_account.id_user
    AND state_history.dwh_country_id = user_account.dwh_country_id

  LEFT JOIN (
    SELECT 
      loan_state_annotations.dwh_country_id,
      loan_state_annotations.fk_loan_request,
      loan_state_annotations.fk_loan,
      loan_state_annotations.fk_user

    FROM (
      SELECT
        dwh_country_id,
        fk_loan_request,
        fk_loan,
        fk_user,
        states_flatten(document_submission_steps) AS document_submission_steps,
        states_flatten(funnel_steps) AS funnel_steps,

        -- We are taking here funnel advance order of each user's loan_request, 
        -- if funnel advance is ambiquous we take last loan (hence ordering).
        row_number() OVER (PARTITION BY dwh_country_id, fk_user
                           ORDER BY funnel_advance DESC,
                                    loan_request_created_at DESC,
                                    fk_loan_request DESC
        ) AS advance_rank

      FROM base.loan_state_annotations
    ) AS loan_state_annotations 

    WHERE advance_rank = 1
  ) AS most_advanced_loan_annotations
    ON user_account.id_user = most_advanced_loan_annotations.fk_user
    AND user_account.dwh_country_id = most_advanced_loan_annotations.dwh_country_id

) AS user_account

LEFT JOIN base.exchange_rates
  ON user_account.currency_code = exchange_rates.currency_code
  AND user_account.creation_date = exchange_rates.exchange_rate_date;

CREATE INDEX ON $schema.$table (dwh_country_id);
CREATE INDEX ON $schema.$table (id_user);

ALTER TABLE $schema.$table ADD PRIMARY KEY (dwh_country_id, id_user);