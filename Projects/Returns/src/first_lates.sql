select 
	latest.fk_loan,
	earliest_date,
	latest_date,
	in_arrears_since_days_7_plus_first,
	in_arrears_since_days_14_plus_first,
	in_arrears_since_days_30_plus_first,
	in_arrears_since_days_60_plus_first,
	coalesce(in_arrears_since_days_7_plus_first,latest_date)-earliest_date as surv_time_7
	coalesce(in_arrears_since_days_14_plus_first,latest_date)-earliest_date as surv_time_14,
	coalesce(in_arrears_since_days_30_plus_first,latest_date)-earliest_date as surv_time_30,
	coalesce(in_arrears_since_days_60_plus_first,latest_date)-earliest_date as surv_time_60,
	in_arrears_since_days_7_plus_first is not null as surv_7,
	in_arrears_since_days_14_plus_first is not null as surv_14,
	in_arrears_since_days_30_plus_first is not null as surv_30,
	in_arrears_since_days_60_plus_first is not null as surv_60,
FROM  (	
	select  
		fk_loan, 
		min(iso_date) earliest_date, 
		max(iso_date) latest_date 
	from 
		base.de_payments p
	join
	    base.loan_payback lp
	on
	    p.dwh_country_id=lp.dwh_country_id
	    p.fk_loan=lp.fk_loan
	where lp.state <>'payback_complete'
	group by 
		fk_loan
) latest

left join (
	select  
		fk_loan, 
		min(iso_date) in_arrears_since_days_7_plus_first 
	from 
		base.de_payments 
	where 
		in_arrears_since_days > 7 
	group by 
		fk_loan 
) f7  
on 
	latest.fk_loan = f7.fk_loan
	
left join (
	select  
		fk_loan, 
		min(iso_date) in_arrears_since_days_14_plus_first 
	from base.de_payments 
	where 
		in_arrears_since_days > 14 
	group by 
		fk_loan 
) f14 
on 
	latest.fk_loan = f14.fk_loan
	
left join 
	select  
		fk_loan, 
		min(iso_date) in_arrears_since_days_30_plus_first 
	from 
		base.de_payments 
	where 
		in_arrears_since_days > 30 
	group by 
		fk_loan 
) f30 on 
	latest.fk_loan = f30.fk_loan
	
left join (
	select  
		fk_loan, 
		min(iso_date) in_arrears_since_days_60_plus_first 
	from 
		base.de_payments 
	where in_arrears_since_days > 60 group by fk_loan 
) f60 on 
	latest.fk_loan = f60.fk_loan
	
order by 
	fk_loan
 