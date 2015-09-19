select 
	latest.dwh_country_id
	latest.fk_loan,
	latest.loan_request_nr, 
	latest.fk_loan_request, 
	latest.payout_date,
	iso_date eom 
	SELECT EXTRACT(YEAR FROM age) * 12 + EXTRACT(MONTH FROM age) AS months_between
		FROM age(payout_date, eom) AS t(age);
	
from 
	il.iso_date
join 
	
	
	(select 
		latest.fk_loan,
		latest.loan_request_nr, 
		latest.fk_loan_request, 
		latest.payout_date,
		earliest_date earliest_date_EOM,
		latest_date latest_date_EOM,
		in_arrears_since_days_7_plus_first in_arrears_since_days_7_plus_first_EOM,
		in_arrears_since_days_14_plus_first in_arrears_since_days_14_plus_first_EOM, 
		in_arrears_since_days_30_plus_first in_arrears_since_days_30_plus_first_EOM,
		in_arrears_since_days_60_plus_first in_arrears_since_days_60_plus_first_EOM,
		in_arrears_since_days_90_plus_first in_arrears_since_days_90_plus_first_EOM, 
		coalesce(in_arrears_since_days_7_plus_first,latest_date)-payout_date as surv_time_7_EOM,
		coalesce(in_arrears_since_days_14_plus_first,latest_date)-payout_date as surv_time_14_EOM,
		coalesce(in_arrears_since_days_30_plus_first,latest_date)-payout_date as surv_time_30_EOM,
		coalesce(in_arrears_since_days_60_plus_first,latest_date)-payout_date as surv_time_60_EOM,
		coalesce(in_arrears_since_days_90_plus_first,latest_date)-payout_date as surv_time_90_EOM,
		(in_arrears_since_days_7_plus_first is not null)::int as late_7_EOM,
		(in_arrears_since_days_14_plus_first is not null)::int as late_14_EOM,
		(in_arrears_since_days_30_plus_first is not null)::int as late_30_EOM,
		(in_arrears_since_days_60_plus_first is not null)::int as late_60_EOM,
		(in_arrears_since_days_90_plus_first is not null)::int as late_90_EOM
	FROM (
		select  
			p.fk_loan, 
			p.loan_request_nr, 
			l.fk_loan_request,
			min(iso_date) earliest_date, 
			max(iso_date) latest_date,
			lp.payout_date::date
		from 
			base.de_payments  p
		join
			base.loan_payback lp
		on
			p.dwh_country_id=lp.dwh_country_id and 
			p.fk_loan=lp.fk_loan
		join
			base.loan l
		on
			p.dwh_country_id=l.dwh_country_id and 
			p.fk_loan=l.id_loan
		where 
			lp.state <>'payback_complete' and
			iso_date= (date_trunc('MONTH', iso_date) + INTERVAL '1 MONTH - 1 day')::DATE
		group by 
			p.fk_loan, 
			p.loan_request_nr, 
			l.fk_loan_request,	
			lp.payout_date
	) latest

	left join 	(
		select  
			fk_loan, 
			min(iso_date) in_arrears_since_days_7_plus_first 
		from 
			base.de_payments 
		where 
			in_arrears_since_days>7 and
			iso_date= (date_trunc('MONTH', iso_date) + INTERVAL '1 MONTH - 1 day')::DATE
		group by fk_loan 
	) f7  
	on 
		(latest.fk_loan=f7.fk_loan)
		
	left join (
		select  
			fk_loan, 
			min(iso_date) in_arrears_since_days_14_plus_first 
		from 
			base.de_payments 
		where 
			in_arrears_since_days>14 and
			iso_date= (date_trunc('MONTH', iso_date) + INTERVAL '1 MONTH - 1 day')::DATE
		group by fk_loan 
	) f14 
	on 
		(latest.fk_loan=f14.fk_loan)
		
	left join (
		select  
			fk_loan, 
			min(iso_date) in_arrears_since_days_30_plus_first 
		from 
			base.de_payments 
		where 
			in_arrears_since_days>31 and
			iso_date= (date_trunc('MONTH', iso_date) + INTERVAL '1 MONTH - 1 day')::DATE
		group by fk_loan 
	) f30 
	on 
		(latest.fk_loan=f30.fk_loan)
		
	left join (
		select  
			fk_loan, 
			min(iso_date) in_arrears_since_days_60_plus_first 
		from 
			base.de_payments 
		where 
			in_arrears_since_days>62 and
			iso_date= (date_trunc('MONTH', iso_date) + INTERVAL '1 MONTH - 1 day')::DATE
		group by fk_loan 
	) f60 
	on 
		(latest.fk_loan=f60.fk_loan)
		
	left join (
		select  
			fk_loan, 
			min(iso_date) in_arrears_since_days_90_plus_first 
		from base.de_payments 
		where 
			in_arrears_since_days>93 and
			iso_date= (date_trunc('MONTH', iso_date) + INTERVAL '1 MONTH - 1 day')::DATE
		group by fk_loan 
	) f90 
	on 
		(latest.fk_loan=f90.fk_loan)
	order by fk_loan
	) first_lates_EOM

on 
iso_date>=earliest_date_EOM and 
iso_date<=least(latest_date_EOM,in_arrears_since_days_90_plus_first_EOM) and 
where iso_date= (date_trunc('MONTH', iso_date) + INTERVAL '1 MONTH - 1 day')::DATE