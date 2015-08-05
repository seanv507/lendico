select 
 *
 , case 
  when eur_principal_amount > 20000 then 25000
  when eur_principal_amount > 15000 and eur_principal_amount <= 20000 then 20000
  when eur_principal_amount > 10000 and eur_principal_amount <= 15000 then 15000
  when eur_principal_amount >  5000 and eur_principal_amount <= 10000 then 10000
  when eur_principal_amount >=     0 and eur_principal_amount <= 5000 then 5000
 else null end as amount_bucket, 
 case 
  when lower(cancel_reason_new) like 'cancel%' or LEFT(cancel_reason_new,3) in ('D01','D02','D03','D04','D05','D06','R08','R09','V18') then 'user cancelation'--+R09
  when lower(cancel_reason_new) like 'reapplication%' OR LEFT(cancel_reason_new,3) in ('R19','R20','R21','R23','P01') then 'boundery model'
  when LEFT(cancel_reason_new,3) in ('R06','R11','R12','R13','R14','P02') then 'indebtness / affordibility'
  when lower(cancel_reason_new) like '%20%' or LEFT(cancel_reason_new,3) in ('R01','R02','R03','R04','R05','R07','R10') then 'credit bureau'
  when LEFT(cancel_reason_new,3) in ('R15','R16','R17','R18','R22','R24','R25','R26','R27','R28') then 'policy rules'--+24
  when lower(cancel_reason_new) like 'pending' then upper(cancel_reason_new)
  else 'other'
 end as category
from
 (
 select 
  initcap(case 
   when l.cancel_reason_comment like 'Reapplication failed%' then 'Reapplication'  
   when loan_state like '%cancel%' and (credit_agency_residual_debt_flag=1 or credit_agency_rating in ('N', 'O','P')) THEN 'R01 Negative Data'
   WHEN l.cancel_reason='R06' then 'R06 Maximum Customer Exposure'
   WHEN blrc.global_dwh_state like '%pending%' then 'PENDING'
  else COALESCE(cr.code||' '||replace(replace(REPLACE(REPLACE (initcap(reject_reason) , ': ' , ' ' ), '> ',''), '- ',''), '  ',' '),replace(replace(REPLACE(REPLACE (initcap(l.cancel_reason) , ': ' , ' ' ), '> ',''), '- ',''), '  ',' '),event) end)  as cancel_reason_new
  --COALESCE(cr.code||' '||reject_reason,REPLACE(REPLACE (l.cancel_reason , ': ' , '' ), '> ',''),event) as cancel_reason_new
  , credit_agency_residual_debt_flag, credit_agency_rating
  , l.cancel_reason--
  , l.cancel_reason_comment--
  , loan_state--
  , documents_activity_flag
  ,blrc.user_campaign
  ,left(blrc.rating,1) lendico_class
  ,left(blrc.rating_mapped,1) lendico_class_new
  ,rating
  ,blrc.global_dwh_state
  ,blrc.country
  ,blrc.id_loan_request
  ,blrc.loan_request_nr
  ,blrc.id_user
  ,blrc.event_date
  ,blrc.event_week
  ,blrc.event_month
  ,blrc.eur_principal_amount
  ,blrc.was_loan_request_complete_flag
  ,blrc.was_precheck_successful_flag
  ,blrc.was_fraud_check_successful_flag
  ,blrc.was_loan_offer_flag
  ,blrc.was_loan_offer_accepted_flag
  ,blrc.was_listed_flag
  ,blrc.was_listed_and_verified_flag
  ,blrc.was_fully_funded_flag
  ,blrc.was_fully_funded_and_verified_flag
  ,blrc.contract_was_accepted_flag
  ,blrc.was_funds_collected_flag
  ,blrc.was_payout_complete_flag
  ,rating_new
  ,in_arrears_since_combined as in_arrears_since
  ,income_employment_status
  ,user_age
  ,user_expenses_home
  , coalesce( unsaleable,0) unsaleable
  ,case 
   when COALESCE(il.parse_date(ua.attributes -> 'user_income_employment_length'),il.parse_date(ua.attributes -> '')) < current_date 
   then (current_date - COALESCE(il.parse_date(ua.attributes -> 'user_income_employment_length'), il.parse_date(ua.attributes -> 'user_income_employment_length3')))/365 
  else null end employment_length_years
  ,case 
   when COALESCE(il.parse_date(ua.attributes -> 'user_income_employment_length'), il.parse_date(ua.attributes -> 'user_income_employment_length3')) < current_date 
   then COALESCE(il.parse_date(ua.attributes -> 'user_income_employment_length'), il.parse_date(ua.attributes -> 'user_income_employment_length3')) 
  else null end employment_start_date
  ,ua.attributes -> 'user_income_employment_length' user_income_employment_length1
  ,ua.attributes -> 'user_income_employment_length3' user_income_employment_length3
  ,in_arrears_since_bucket AS arrears_bucket
  ,case when lp.state='payback_complete'  and coalesce( unsaleable,0)=0  and loan_state not like '%cancel%'  then 1 else 0 end as repayed_flag
  , case when was_payout_complete_flag=1 and loan_state like '%cancel%' then 1 else 0 end canceled_after_payout_flag
 from il.global_borrower_loan_requests_cohort blrc
 left join base.m_rating r on blrc.dwh_country_id=r.dwh_country_id and r.pd_start<=coalesce(pd,100) and coalesce(pd,100) < pd_end and valid_from<=current_date and current_date<valid_until
 join il.countries c on c.country_name = blrc.country
 left join il.user_attribute_etl_global ua on ua.country_id = blrc.dwh_country_id and ua.fk_user = blrc.id_user
 left join backend.loan_request l on l.dwh_country_id = c.dwh_country_id and l.loan_request_nr = blrc.loan_request_nr
 left join base.m_cancelreason cr on left(l.cancel_reason,3)=old_code
 left join 
  (
  select p.dwh_country_id,p.loan_request_nr, monthly_installment, case when actual_amount_cum/monthly_installment<2 and  expected_amount_cum/monthly_installment>=2 and in_arrears_since_days>=90 then 1 else 0 end unsaleable
  from base.de_payments p
  join (select dwh_country_id,fk_loan, max(principal_amount) monthly_installment from base.loan_return_plan_item group by 1,2) r on   p.dwh_country_id=r.dwh_country_id and p.fk_loan=r.fk_loan
  where iso_date=current_date and in_arrears_flag=1
  ) p on blrc.dwh_country_id=p.dwh_country_id and blrc.loan_request_nr=p.loan_request_nr
 left join 
  (
  select * 
  from 
   (
   SELECT
    ROW_NUMBER () OVER (PARTITION BY identifier ORDER BY id_state_machine_history DESC) AS RANK,
    CAST (identifier AS INT) as identifier,
    dwh_country_id,
    event
   FROM backend.state_machine_history
   WHERE SCHEMA_NAME LIKE 'LoanRequest'
   ) a
  where a.rank = 1 and a.event = 'CancelByUser'
  ) z on z.dwh_country_id = c.dwh_country_id and z.identifier = blrc.id_loan_request
 left join base.loan_payback lp on lp.dwh_country_id = blrc.dwh_country_id and lp.fk_loan_request = blrc.id_loan_request
 where blrc.user_type in ('rocket_lendico', 'regular_user') 
 and blrc.event_date >= '2013-12-01'
 AND blrc.sme_flag = 0
 ) x
order by 3,6--1,2,3 ,4 --232036
