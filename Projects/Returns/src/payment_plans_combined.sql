SELECT 
	pp.dwh_country_id, 
	pp.fk_loan, 
	pp.fk_loan_request,
	l.loan_nr as loan_request_nr,
	pp.fk_user_investor, 
	pp.fk_user_borrower, 
	pp.country_name,
	pp.payout_date, 
	pp.interval, 
	pp.interval_payback_date, 
	pp.next_interval_payback_date,
	pp.loan_coverage, -- was sometimes null

	pp.eur_payment_amount_borrower,
	sum(pp.eur_payment_amount_borrower) OVER wind as eur_payment_amount_borrower_cum,

	pp.eur_principal_amount_borrower,
	sum(pp.eur_principal_amount_borrower) OVER wind as eur_principal_amount_borrower_cum,

	pp.eur_interest_amount_borrower,
	sum(pp.eur_interest_amount_borrower) OVER wind as eur_interest_amount_borrower_cum,

	pp.eur_initial_principal_amount_borrower,
	pp.eur_residual_interest_amount_borrower,
	pp.eur_residual_principal_amount_borrower,
	pp.eur_payment_amount_investor,
	sum(pp.eur_payment_amount_investor) OVER wind as eur_payment_amount_investor_cum,

	pp.eur_principal_amount_investor,
	sum(pp.eur_principal_amount_investor) OVER wind as eur_principal_amount_investor_cum,

	pp.eur_interest_amount_investor,
	sum(pp.eur_interest_amount_investor) OVER wind as eur_interest_amount_investor_cum,

	pp.eur_initial_principal_amount_investor,
	pp.eur_sum_interval_interest_amount_investor,
	pp.eur_residual_interest_amount_investor, 
	pp.eur_residual_principal_amount_investor

	FROM base.loan_payment_plan_combined_item pp
	join base.loan l on 
		pp.dwh_country_id=l.dwh_country_id and 
		pp.fk_loan=l.id_loan
	join base.loan_funding lf on 
		pp.dwh_country_id=lf.dwh_country_id and
		pp.fk_loan=lf.fk_loan and 
		pp.fk_user_investor=lf.fk_user
	where 
	--pp.dwh_country_id=1 and
		l.state!='canceled' and 
		l.originated_since is not null and
		(lf.state='funded' ) --or lf.close_reason is not null)
	WINDOW wind as (PARTITION BY pp.dwh_country_id, pp.fk_loan, pp.fk_user_investor order by interval)
