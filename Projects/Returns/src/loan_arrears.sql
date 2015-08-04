-- Code to identify loans arrears state at each month end, together with time from first_payout.
-- questions: should we calculate from payout_date or 1st 


select 
	p.dwh_country_id,
	p.fk_loan,
	p.iso_date,
	lp.payout_date,
	extract(year  from age(p.iso_date, lp.payout_date))*360 + 
	extract(month from age(p.iso_date, lp.payout_date))*30 + 
	least(extract(day from age(p.iso_date,lp.payout_date)),29) elapsed_days_30360,
	p.in_arrears_since,
	-- todo define 30360? february/ ...31 days
	extract(year  from age(p.iso_date, p.in_arrears_since))*360 + 
	extract(month from age(p.iso_date, p.in_arrears_since))*30 + 
	least(extract(day from age(p.iso_date, p.in_arrears_since)),29) 	in_arrears_since_days_30360
	
from 
	base.payments p
join 
	base.loan_payback lp
on
	p.dwh_country_id=lp.dwh_country_id and 
	p.fk_loan=lp.fk_loan

where 
	--EOM
	iso_date=(date_trunc('MONTH', p.iso_date) + INTERVAL '1 MONTH - 1 day')::date 
order by
	dwh_country_id, fk_loan, iso_date

