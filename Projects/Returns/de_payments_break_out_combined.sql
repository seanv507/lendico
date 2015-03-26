with paymentplan as
(
        SELECT pp.dwh_country_id, pp.fk_loan, pp.fk_loan_request,  l.loan_nr as loan_request_nr,
        pp.fk_user_investor, pp.fk_user_borrower, pp.country_name, pp.nominal_interest_percentage, pp.promo_interest_percentage, pp.has_promo_flag, 
        pp.is_repaid_flag, pp.payout_date, pp.interval, pp.interval_payback_date, pp.next_interval_payback_date, pp.loan_coverage, 
        pp.payment_amount_borrower, pp.principal_amount_borrower, pp.interest_amount_borrower, pp.initial_principal_amount_borrower, pp.sum_interval_interest_amount_borrower, 
        pp.residual_interest_amount_borrower, pp.residual_principal_amount_borrower, pp.payment_amount_promo, pp.principal_amount_promo, pp.interest_amount_promo, pp.initial_principal_amount_promo, 
        pp.sum_interval_interest_amount_promo, pp.residual_interest_amount_promo, pp.residual_principal_amount_promo, pp.calc_service_fee,
        pp.payment_amount_investor, pp.principal_amount_investor, pp.interest_amount_investor, pp.initial_principal_amount_investor, pp.sum_interval_interest_amount_investor, 
        pp.residual_interest_amount_investor, pp.residual_principal_amount_investor, pp.eur_payment_amount_borrower, pp.eur_principal_amount_borrower, pp.eur_interest_amount_borrower, 
        pp.eur_initial_principal_amount_borrower, pp.eur_sum_interval_interest_amount_borrower, pp.eur_residual_interest_amount_borrower, pp.eur_residual_principal_amount_borrower, 
        pp.eur_payment_amount_promo, pp.eur_principal_amount_promo, pp.eur_interest_amount_promo, pp.eur_initial_principal_amount_promo, pp.eur_sum_interval_interest_amount_promo, 
        pp.eur_residual_interest_amount_promo, pp.eur_residual_principal_amount_promo, pp.eur_calc_service_fee, pp.eur_payment_amount_investor, pp.eur_principal_amount_investor, 
        pp.eur_interest_amount_investor, pp.eur_initial_principal_amount_investor, pp.eur_sum_interval_interest_amount_investor,
        pp.eur_residual_interest_amount_investor, pp.eur_residual_principal_amount_investor 
        FROM base.loan_payment_plan_combined_item pp

 left join   base.loan l    
 on     l.id_loan=pp.fk_loan and l.dwh_country_id=pp.dwh_country_id  
 left join  base.loan_funding lf   on   
 pp.dwh_country_id=lf.dwh_country_id and pp.fk_loan=lf.fk_loan and pp.fk_user_investor=lf.fk_user
where pp.dwh_country_id=1 and lf.state='funded' and l.state!='canceled'
),



actual_payments_1 as (
 select 
  dwh_country_id
  , COALESCE
   (
     
     CASE 
    WHEN lower(reference_text_2) like '%x%' AND lower(reference_text_2) not like '%62x%' then SUBSTRING(lower(reference_text_2) FROM 'x([aA-zZ0-9]+)x')
    WHEN lower(reference_text_1) like '%81x%' then SUBSTRING(lower(reference_text_1) FROM '81x([aA-zZ0-9]+)x')
    WHEN lower(reference_text_2) like '%81x%' then SUBSTRING(lower(reference_text_2) FROM '81x([aA-zZ0-9]+)x[aA-zZ0-9]{2}')
    WHEN lower(reference_text_1) like '%81x%' then SUBSTRING(lower(reference_text_1) FROM '81x([aA-zZ0-9]+)x[aA-zZ0-9]{2}')
    WHEN lower(reference_text_1) like '%svwz+81x%' then SUBSTRING(lower(reference_text_1) from 'svwz\+(?!81x)([0-9]+)')
    WHEN lower(reference_text_1) like '%svwz+%' then SUBSTRING(lower(reference_text_1) FROM 'svwz\+([0-9]+)')
    WHEN lower(reference_text_1) like '%mref+%' then SUBSTRING(lower(reference_text_1) FROM 'mref\+([0-9]+)')
    WHEN lower(reference_text_1) like '%eref+%' then SUBSTRING(lower(reference_text_1) FROM 'eref\+([0-9]+)')
   else null end
   , SUBSTRING(reference_text_1 FROM '[0-9]{1,}')
   )::int as loan_request_nr
   
  , il.parse_date(valuta) as created_at
  
  , (amount/100+coalesce(replace(substring(reference_text_1 from 'Fremdentgelte:\s(\d{1,},\d{1,})'),',', '.')::numeric,0))::numeric(12,2) actual_amount
  
 from backend_accounting.transaction_queue_in t 
 WHERE
     account_number_receiver in (select account_number from backend_accounting.account WHERE type ='global_payback' group by 1) -- only accounts in global payback state
 and length(COALESCE
   (
     
     CASE 
    WHEN lower(reference_text_2) like '%x%' AND lower(reference_text_2) not like '%62x%' then SUBSTRING(lower(reference_text_2) FROM 'x([aA-zZ0-9]+)x')
    WHEN lower(reference_text_1) like '%81x%' then SUBSTRING(lower(reference_text_1) FROM '81x([aA-zZ0-9]+)x')
    WHEN lower(reference_text_2) like '%81x%' then SUBSTRING(lower(reference_text_2) FROM '81x([aA-zZ0-9]+)x[aA-zZ0-9]{2}')
    WHEN lower(reference_text_1) like '%81x%' then SUBSTRING(lower(reference_text_1) FROM '81x([aA-zZ0-9]+)x[aA-zZ0-9]{2}')
    WHEN lower(reference_text_1) like '%svwz+81x%' then SUBSTRING(lower(reference_text_1) from 'svwz\+(?!81x)([0-9]+)')
    WHEN lower(reference_text_1) like '%svwz+%' then SUBSTRING(lower(reference_text_1) FROM 'svwz\+([0-9]+)')
    WHEN lower(reference_text_1) like '%mref+%' then SUBSTRING(lower(reference_text_1) FROM 'mref\+([0-9]+)')
    WHEN lower(reference_text_1) like '%eref+%' then SUBSTRING(lower(reference_text_1) FROM 'eref\+([0-9]+)')
   else null end
   , SUBSTRING(reference_text_1 FROM '[0-9]{1,}')
   ))<= (select length(max(loan_request_nr)::character(255)) from backend.loan_request) -- and "loan_account_nr" <= max loan_request_nr ?? 
 and account_name!='51230800/0000059662 Payback Konto'
 and dwh_country_id=1
UNION ALL
SELECT 1,745156648,'2014-01-01'::date, 0.63 -- ??
UNION ALL
SELECT 1,509393088,'2014-11-01'::date, 7.70 
UNION ALL
SELECT 1,226539522,'2014-02-15'::date, 6.95
UNION ALL
SELECT 1,302372403,'2015-01-02'::date, 51.02
),

actual_payments as (
select a.*,l.id_loan as fk_loan, l.fk_user as fk_user 
from actual_payments_1 as a
join 
backend.loan_request lr  on   (a.loan_request_nr=lr.loan_request_nr and a.dwh_country_id=lr.dwh_country_id)
join
backend.loan l  on lr.id_loan_request=l.fk_loan_request and l.dwh_country_id=lr.dwh_country_id and l.state!='canceled' --why left join when no data used from l??
 
)

--#######################################################END WITH#######################################################--


select 

 
 coalesce(pp.dwh_country_id,ap.dwh_country_id) as dwh_country_id
 , coalesce(pp.fk_user_borrower, ap.fk_user_borrower) as fk_user_borrower
 ,coalesce(pp.fk_user_investor,ap.fk_user_investor) as fk_user_investor
 , coalesce(pp.fk_loan, ap.fk_loan) as fk_loan
 , pp.fk_loan_request
 , coalesce(pp.loan_request_nr,ap.loan_request_nr) as loan_request_nr
 , coalesce(pp.interval_payback_date,ap.date) as date,
 
 
pp.nominal_interest_percentage, pp.promo_interest_percentage, pp.has_promo_flag, 
pp.is_repaid_flag, pp.payout_date, pp.interval, pp.interval_payback_date, pp.next_interval_payback_date, pp.loan_coverage, 
pp.payment_amount_borrower, pp.principal_amount_borrower, pp.interest_amount_borrower, pp.initial_principal_amount_borrower, pp.sum_interval_interest_amount_borrower, 
pp.residual_interest_amount_borrower, pp.residual_principal_amount_borrower, pp.payment_amount_promo, pp.principal_amount_promo, pp.interest_amount_promo, pp.initial_principal_amount_promo, 
pp.sum_interval_interest_amount_promo, pp.residual_interest_amount_promo, pp.residual_principal_amount_promo, pp.calc_service_fee,
pp.payment_amount_investor, pp.principal_amount_investor, pp.interest_amount_investor, pp.initial_principal_amount_investor, pp.sum_interval_interest_amount_investor, 
pp.residual_interest_amount_investor, pp.residual_principal_amount_investor, pp.eur_payment_amount_borrower, pp.eur_principal_amount_borrower, pp.eur_interest_amount_borrower, 
pp.eur_initial_principal_amount_borrower, pp.eur_sum_interval_interest_amount_borrower, pp.eur_residual_interest_amount_borrower, pp.eur_residual_principal_amount_borrower, 
pp.eur_payment_amount_promo, pp.eur_principal_amount_promo, pp.eur_interest_amount_promo, pp.eur_initial_principal_amount_promo, pp.eur_sum_interval_interest_amount_promo, 
pp.eur_residual_interest_amount_promo, pp.eur_residual_principal_amount_promo, pp.eur_calc_service_fee, pp.eur_payment_amount_investor, pp.eur_principal_amount_investor, 
pp.eur_interest_amount_investor, pp.eur_initial_principal_amount_investor, pp.eur_sum_interval_interest_amount_investor, 
pp.eur_residual_interest_amount_investor, pp.eur_residual_principal_amount_investor

 
 
 , sum(coalesce(pp.payment_amount_borrower,0) ) OVER (partition by coalesce(pp.dwh_country_id,ap.dwh_country_id), coalesce(pp.loan_request_nr,ap.loan_request_nr),
        coalesce(pp.fk_user_investor,ap.fk_user_investor) 
 ORDER BY coalesce(pp.interval_payback_date,ap.date))::float as expected_amount_cum
 , sum(coalesce(pp.eur_interest_amount_investor,0) ) 
 OVER (partition by 
        coalesce(pp.dwh_country_id,ap.dwh_country_id), 
        coalesce(pp.loan_request_nr,ap.loan_request_nr), 
        coalesce(pp.fk_user_investor,ap.fk_user_investor)
ORDER BY coalesce(pp.interval_payback_date,ap.date))::float as eur_interest_amount_investor_cum

, sum(coalesce(pp.eur_principal_amount_investor,0) ) 
 OVER (partition by 
        coalesce(pp.dwh_country_id,ap.dwh_country_id), 
        coalesce(pp.loan_request_nr,ap.loan_request_nr), 
        coalesce(pp.fk_user_investor,ap.fk_user_investor)
ORDER BY coalesce(pp.interval_payback_date,ap.date))::float as eur_principal_amount_investor_cum

, sum(coalesce(pp.eur_initial_principal_amount_investor* pp.promo_interest_percentage/1200,0) ) 
 OVER (partition by 
        coalesce(pp.dwh_country_id,ap.dwh_country_id), 
        coalesce(pp.loan_request_nr,ap.loan_request_nr), 
        coalesce(pp.fk_user_investor,ap.fk_user_investor)
ORDER BY coalesce(pp.interval_payback_date,ap.date))::float as eur_promo_interest_amount_investor_cum
-- note that this is just an approximation of extra interest because of promo ( not the full interest from promo plan) 


 , actual_amount
 , sum(coalesce(actual_amount,0)) OVER (partition by coalesce(pp.dwh_country_id,ap.dwh_country_id), coalesce(pp.loan_request_nr,ap.loan_request_nr) ,
      coalesce(pp.fk_user_investor,ap.fk_user_investor)
        ORDER BY coalesce(pp.interval_payback_date,ap.date))::float as actual_amount_cum
 
 
   
 from paymentplan pp
 
 
full outer join
 (
         select bd.date, bd.dwh_country_id, bd.fk_loan, bd.fk_user as fk_user_borrower, lf.fk_user as fk_user_investor, loan_request_nr, actual_amount
         from ( 
          select b.created_at as date, b.dwh_country_id, fk_loan, fk_user,b.loan_request_nr, sum(actual_amount)actual_amount
          from actual_payments b  
          group by 1,2,3,4,5
          order by b.created_at
         )bd
         join 
         base.loan_funding lf
         on (
                bd.dwh_country_id=lf.dwh_country_id and
                bd.fk_loan = lf.fk_loan and
                lf.state='funded')
 )ap
on (pp.dwh_country_id=ap.dwh_country_id and 
        pp.fk_user_investor = ap.fk_user_investor and
        pp.loan_request_nr=ap.loan_request_nr and 
        ap.date=pp.interval_payback_date) 
where  coalesce(pp.interval_payback_date,ap.date) <=current_date and  coalesce(pp.loan_request_nr,ap.loan_request_nr)  not in (540765776,263922873,297916060,820448399)

order by dwh_country_id,fk_loan,date ;