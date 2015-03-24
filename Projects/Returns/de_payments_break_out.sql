with paymentplan as
(
select 
 a.dwh_country_id
 , a.fk_user
 , a.fk_loan
 , lr.loan_request_nr
 , cast(h[1]  as int) as payment_interval
 , cast(h[2]  as date) as intervalPaybackDate
 , round(((cast(h[3] as decimal))/100),2) as paymentAmount
 , round(((cast(h[4] as decimal))/100),2) as interestAmount
 , round(((cast(h[5] as decimal))/100),2) as principalAmount
 , round(((cast(h[6] as decimal))/100),2) as  initialPrincipalAmount
 , round(((cast(h[7] as decimal))/100),2) as residualPrincipalAmount
 , round(((cast(h[8] as decimal))/100),2) as residualDebtAmount
from 
 (
 SELECT dwh_country_id, fk_user, fk_loan, 
 json_flatten(unnest(json_explode_array(plan)), 
  '{"interval","intervalPaybackDate","paymentAmount","interestAmount", "principalAmount","initialPrincipalAmount","residualPrincipalAmount","residualDebtAmount"}' ) h
 FROM backend.loan_payment_plan 
 )a
 left join  backend.loan l    on   l.id_loan=a.fk_loan and l.dwh_country_id=a.dwh_country_id and l.state!='canceled' --why left join when no data used from l??
 left join  backend.loan_request lr   on   lr.id_loan_request=l.fk_loan_request and lr.dwh_country_id=l.dwh_country_id
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
 , coalesce(pp.fk_user, ap.fk_user) as fk_user
 , coalesce(pp.fk_loan, ap.fk_loan) as fk_loan
 , coalesce(pp.loan_request_nr,ap.loan_request_nr) as loan_request_nr
 , coalesce(pp.date,ap.date) as date
 , next_date 
 , expected_amount
 , expected_interest_amount
 , expected_principal_amount
 , expected_initial_principal_amount
 , expected_residual_principal_amount  
 , sum(coalesce(expected_amount,0) ) OVER (partition by coalesce(pp.dwh_country_id,ap.dwh_country_id), coalesce(pp.loan_request_nr,ap.loan_request_nr) ORDER BY coalesce(pp.date,ap.date))::float as expected_amount_cum
 , sum(coalesce(expected_interest_amount,0) ) OVER (partition by coalesce(pp.dwh_country_id,ap.dwh_country_id), coalesce(pp.loan_request_nr,ap.loan_request_nr) ORDER BY coalesce(pp.date,ap.date))::float as expected_interest_amount_cum
 , sum(coalesce(expected_principal_amount,0) )  OVER (partition by coalesce(pp.dwh_country_id,ap.dwh_country_id), coalesce(pp.loan_request_nr,ap.loan_request_nr) ORDER BY coalesce(pp.date,ap.date))::float  as expected_principal_amount_cum
 , actual_amount
 , sum(coalesce(actual_amount,0)) OVER (partition by coalesce(pp.dwh_country_id,ap.dwh_country_id), coalesce(pp.loan_request_nr,ap.loan_request_nr) ORDER BY coalesce(pp.date,ap.date))::float as actual_amount_cum
 
 
from
 (
 select 
  b.dwh_country_id
  , b.fk_user
  , b.fk_loan
  , b.loan_request_nr
  , b.intervalPaybackDate as date
  , lead(b.intervalPaybackDate) OVER (PARTITION BY b.dwh_country_id, b.loan_request_nr ORDER BY b.intervalPaybackDate ASC) as next_date
  , intervalPaybackDate 
  , paymentAmount as expected_amount
  , interestAmount as expected_interest_amount
  , principalAmount as expected_principal_amount
  , initialPrincipalAmount as expected_initial_principal_amount
  , residualPrincipalAmount as expected_residual_principal_amount  
 
  
 from paymentplan b -- add expected payback (sum over single date) where exact date
 
 where  paymentAmount>0 
 order by 4,5 --loan_request_nr,  date
 ) pp
 
 
full outer join
 (
 select bd.date, dwh_country_id, fk_loan, fk_user,loan_request_nr, actual_amount
 from ( 
  select b.created_at as date, b.dwh_country_id, fk_loan, fk_user,b.loan_request_nr, sum(actual_amount)actual_amount
  from actual_payments b  
  group by 1,2,3,4,5
  order by b.created_at
 )bd
 )ap
on (pp.dwh_country_id=ap.dwh_country_id and pp.loan_request_nr=ap.loan_request_nr and ap.date=pp.date) 
where  coalesce(pp.date,ap.date) <=current_date

order by dwh_country_id,fk_loan,date 
;

