---
name: de_payments
schema: base
type: table

dependencies: []
target: intelligence
---


CREATE TEMP TABLE t_temp_payments (
  dwh_country_id INTEGER,
  fk_user INTEGER,
  fk_loan INTEGER,
  loan_request_nr INTEGER,
  iso_date DATE,
  expected_amount_cum NUMERIC(12,2),
  actual_amount_cum NUMERIC(12,2),
  in_arrears_flag INTEGER
  );

--#######################################################START WITH#######################################################--
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
	left join  backend.loan l 		 on   l.id_loan=a.fk_loan and l.dwh_country_id=a.dwh_country_id and l.state!='canceled' --why left join when no data used from l??
	left join  backend.loan_request lr 	 on   lr.id_loan_request=l.fk_loan_request and lr.dwh_country_id=l.dwh_country_id
),


-- min and max 
paymentplan_mm as
(
select dwh_country_id,fk_user,fk_loan,loan_request_nr,min(intervalPaybackDate) as min,max(intervalPaybackDate) as max
from
	(
	select 
		a.dwh_country_id
		, a.fk_user
		, a.fk_loan
		, lr.loan_request_nr
		, intervalPaybackDate
	from paymentplan a
	left join  backend.loan l 		 on   l.id_loan=a.fk_loan and l.dwh_country_id=a.dwh_country_id and l.state='payback' --not cancelled?
	left join  backend.loan_request lr 	 on   lr.id_loan_request=l.fk_loan_request and lr.dwh_country_id=l.dwh_country_id
	)a
group by 1,2,3,4 -- dwh_country_id,fk_user,fk_loan,loan_request_nr,
),

actual_payments as (
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

-- find min and max actual payment dates

actual_payments_mm as (
select 
	dwh_country_id
	, loan_request_nr
	, CASE 
		WHEN loan_request_nr=745156648 THEN '2014-01-01'::date 
		WHEN loan_request_nr=509393088 THEN '2014-11-01'::date
		WHEN loan_request_nr=226539522 THEN '2014-02-15'::date
	ELSE  min END AS min
	, max
from
	(
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
		, min(il.parse_date(valuta)) min
		, max(il.parse_date(valuta)) max
	from backend_accounting.transaction_queue_in t 
	WHERE
	    account_number_receiver in (select account_number from backend_accounting.account WHERE type ='global_payback' group by 1)
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
			))<= (select length(max(loan_request_nr)::character(255)) from backend.loan_request)
	and account_name!='51230800/0000059662 Payback Konto'
	--and booking_info_1!='Alice Capital I GmbH'
	group by 1,2
	)a
)
--#######################################################END WITH#######################################################--

--#######################################################START TEMPORARY TABLE#######################################################--
INSERT INTO t_temp_payments
select 
	pp.dwh_country_id
	, fk_user
	, fk_loan
	, pp.loan_request_nr
	, d.iso_date
	, expected_amount_cum 
	, coalesce(sum(actual_amount) OVER (partition by pp.dwh_country_id, pp.loan_request_nr ORDER BY d.iso_date),0) as actual_amount_cum
	, case when coalesce(sum(actual_amount) OVER (partition by pp.dwh_country_id, pp.loan_request_nr ORDER BY d.iso_date),0)<expected_amount_cum then 1 else 0 end as in_arrears_flag
	
from il.date d
join
	(
	select 
		a.dwh_country_id
		, a.fk_user
		, a.fk_loan
		, a.loan_request_nr
		, d.iso_date as date
		, lead(d.iso_date) OVER (PARTITION BY a.dwh_country_id, a.loan_request_nr ORDER BY d.iso_date ASC) as next_date
		, intervalPaybackDate 
		, paymentAmount as expected_amount
		, sum(paymentAmount ) OVER (partition by a.dwh_country_id, a.loan_request_nr ORDER BY iso_date) as expected_amount_cum
		, min
		, max
	from il.date d
	join paymentplan_mm a on min<=iso_date and iso_date<=max 
	-- iso date=min  payment_plan
	-- iso date>=min  payment_plan
	-- iso date>=min  payment_plan
	-- iso date=max  payment_plan
	 
	left join paymentplan b on a.dwh_country_id=b.dwh_country_id and a.loan_request_nr=b.loan_request_nr and b.intervalPaybackDate =d.iso_date  
	-- add expected payback (sum over single date) where exact date
	
	where  paymentAmount>0 
	order by 4,5 --loan_request_nr,  date
	) pp on pp.date<=d.iso_date and d.iso_date<pp.next_date
	-- ?? 
	
left join
	(
	select d.*, a.dwh_country_id, a.loan_request_nr, sum(actual_amount)actual_amount
	from il.date d
	join actual_payments_mm a on min<=iso_date and iso_date<=max 
	left join actual_payments b on a.dwh_country_id=b.dwh_country_id and a.loan_request_nr=b.loan_request_nr and b.created_at=d.iso_date 
	group by 1,2,3
	order by iso_date
	)ap on pp.dwh_country_id=ap.dwh_country_id and pp.loan_request_nr=ap.loan_request_nr and d.iso_date=ap.iso_date
	
where case when max<current_date then d.iso_date <=max else d.iso_date <=current_date end 
;

--#######################################################END TEMPORARY TABLE#######################################################--

$load_operation

with  ld as (
select dwh_country_id, fk_user, loan_request_nr, expected_amount_cum, lead(expected_amount_cum) OVER (PARTITION BY dwh_country_id, loan_request_nr ORDER BY date ASC) as next_expected_amount_cum,date
from
(
select dwh_country_id, fk_user, loan_request_nr, MAX(iso_date) date, expected_amount_cum 
from
	(
	select dwh_country_id, fk_user, loan_request_nr, expected_amount_cum ,max(iso_date)as iso_date
	from t_temp_payments
	GROUP BY 1,2,3,4

	UNION ALL
	select dwh_country_id, fk_user, loan_request_nr, 0, MIN(iso_date)-1 iso_date
	from t_temp_payments 
	GROUP BY 1,2,3,4
	
	order by iso_date
	)a	
group by 1,2,3,5
)a  
)


SELECT t.*
, case when date < min then min else date+1 end as in_arrears_since
, iso_date-case when date < min then min else date+1 end as in_arrears_since_days
FROM t_temp_payments t
JOIN (select dwh_country_id, fk_user, loan_request_nr, min(iso_date) as min from t_temp_payments GROUP BY 1,2,3) m ON t.dwh_country_id=m.dwh_country_id AND t.loan_request_nr=m.loan_request_nr
LEFT JOIN LD ON t.dwh_country_id=ld.dwh_country_id AND t.loan_request_nr=ld.loan_request_nr AND LD.expected_amount_cum<=t.actual_amount_cum AND t.actual_amount_cum<LD.next_expected_amount_cum and in_arrears_flag=1
WHERE
t.dwh_country_id=1 AND 
t.loan_request_nr not in(540765776,263922873,297916060,820448399)
ORDER BY t.iso_date;


