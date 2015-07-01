select
	pp.dwh_country_id, 
	pp.fk_loan_payment_plan, 
	pp.fk_user, 
	pp.fk_loan_request, 
	pp.fk_loan,
    pp.country_name, 
	pp.currency_code, 
	pp.loan_request_creation_date,
	lp.payout_date,
    interval, 
	interval_payback_date, 
	next_interval_payback_date,
	eur_payment_amount, 
	pp.eur_interest_amount, 
	pp.eur_principal_amount, 
    eur_initial_principal_amount, 
	eur_sum_interval_interest_amount, 
	eur_residual_interest_amount, 
	eur_residual_principal_amount
from base.loan_payment_plan_item pp
join base.loan l on          
	pp.dwh_country_id=l.dwh_country_id and 
	pp.fk_loan=l.id_loan
join base.loan_payback lp on 
	pp.dwh_country_id=lp.dwh_country_id and 
	pp.fk_loan=lp.fk_loan
where
    -- pp.dwh_country_id=1 and 
    l.state!='canceled'  and 
	l.originated_since is not null
 