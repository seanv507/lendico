require(xlxs)


  
cs<-list("addresslevel", "email_address_age_derived",
     "email_name_inconsistent","email_type", "industry_derived","no_online_presence","population_binned","positive_sentiment_about_merchant_binned","postcodecitymatch"                       
"twitter_followers_binned","validpostcodecountry","denied_before_credit","prediction","segment")

idx<-list("addresslevel", "email_address_age_derived", "email_name_inconsistent","email_type", "industry_derived","no_online_presence","population_binned","positive_sentiment_about_merchant_binned","postcodecitymatch","twitter_followers_binned","validpostcodecountry","segment")



# create multiple dataframes
# use rbindlist


require('RPostgreSQL')

drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, host="10.11.0.1",dbname="lendico", user="sviolante", password="3qcqHngX")
#SELECT denied_before_credit_bureau_check, risk_score, COUNT(*) FROM (
sql="SELECT
  gblrc.id_user
  ,gblrc.id_loan_request
  ,gblrc.event_date AS application_date
  ,u.email
  ,ua.attributes -> 'first_name' AS first_name
  ,ua.attributes -> 'last_name' AS last_name
  ,ua.attributes -> 'street' AS street
  ,ua.attributes -> 'postal_code' AS postal_code
  ,ua.attributes -> 'city' AS city
  ,ua.attributes -> 'province' AS province
  ,ua.attributes -> 'address_country' AS address_country
  ,ua.attributes -> 'landline' AS landline
  ,ua.attributes -> 'cellphone' AS cellphone
  ,gblrc.user_income_employer_name AS employer_name
  ,ua.attributes -> 'user_income_employment_status' AS employment_status
  ,ua.attributes -> 'nif_nie_number' AS nif_nie_number
  ,gblrc.contract_was_accepted_flag AS didVerify
  ,gblrc.was_loan_offer_flag AS didAccept
  ,gblrc.pd
  ,gblrc.date_of_first_payout_complete AS payout_date
  ,gblrc.in_arrears_since
  ,1 - gblrc.was_precheck_successful_flag AS denied_before_credit_bureau_check
  ,sr.risk_score
  ,sr.severity_score
  ,sr.asnef_presence_flag 
  ,sr.operations_count 
  ,sr.consumer_credit_operations_count 
  ,sr.mortgage_operations_count 
  ,sr.personal_loan_operations_count 
  ,sr.credit_card_operations_count 
  ,sr.other_unpaid_operations_count 
  ,sr.total_unpaid_balance 
  ,sr.own_entity_total_unpaid_balance 
  ,sr.other_entities_total_unpaid_balance 
  ,sr.consumer_credit_unpaid_balance 
  ,sr.mortgage_unpaid_balance 
  ,sr.personal_loan_unpaid_balance 
  ,sr.credit_card_unpaid_balance 
  ,sr.telecom_unpaid_balance 
  ,sr.other_products_unpaid_balance 
  ,sr.worst_unpaid_balance 
  ,sr.worst_situation 
  ,sr.worst_situation_days_count 
  ,sr.asnef_creditors_count 
  ,sr.deliquency_days_count 
  ,sr.persus_presence_flag 
  ,sr."precision" 
  ,sr.ident_verifier_exitence 
  ,sr.incidence_code 
  
  FROM il.global_borrower_loan_requests_cohort gblrc
  INNER JOIN il.countries c
  ON gblrc.country = c.country_name
  INNER JOIN backend.user u
  ON
  c.dwh_country_id = u.dwh_country_id
  AND gblrc.id_user = u.id_user
  LEFT JOIN il.user_attribute_etl_global ua
  ON 
  c.dwh_country_id=ua.country_id 
  AND gblrc.id_user = ua.fk_user
  LEFT JOIN base.es_scoring_result sr
  ON
  gblrc.id_credit_agency_score = id_scoring_result
  WHERE 
  gblrc.country = 'Spain' 
  AND gblrc.user_type = 'regular_user' 
  AND u.email NOT LIKE 'DELETED%DELETED'
  ORDER BY 
  gblrc.id_user
  ,gblrc.event_date"
 # --) t GROUP BY denied_before_credit_bureau_check, risk_score ORDER BY denied_before_credit_bureau_check, risk_score 

