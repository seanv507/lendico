with
actual_payments as (
	select 
		ap.dwh_country_id, 
		ap.fk_user as fk_user_borrower,
		ap.fk_loan, 
		ap.loan_request_nr, 
		ap.iso_date,
		ap.expected_amount_cum, 
		ap.actual_amount_cum,
		in_arrears_flag, 
		ap.in_arrears_since,
		in_arrears_since_days,
		-- expected/actual payment over month (by taking diff of cumsum)
		ap.expected_amount_cum - lag(expected_amount_cum,1,0.0) over W_pay
			expected_amount_change,
		ap.actual_amount_cum - lag(actual_amount_cum,1,0.0) over W_pay
			actual_amount_change
	from base.de_payments ap
	join base.loan_payback lp on 
		lp.dwh_country_id=ap.dwh_country_id and 
		lp.fk_loan=ap.fk_loan
	where 
		(lp.state!='payback_complete' or lp.in_arrears_since is not null or 
		 ap.iso_date <=lp.last_payment_date)
	WINDOW W_pay as ( partition by ap.dwh_country_id, ap.fk_loan order by ap.iso_date)
),

-- ( apart from those that were paid back by lendico)
-- find corresponding payment plan item.
-- we find the maximum payment plan interval that has 
-- cum_payment<= actual_cum
-- could also use distinct on?
-- match only actual payments that have happened after plan date
-- problem is overpayments [ ie where payment plan has not been updated with extra payment.. because
actual_payments_cum as (
	select 
		ap.dwh_country_id, 
		ap.fk_loan, 
		ap.iso_date,
		max(pp.interval) as interval 
	from actual_payments ap
	left join (
		select 
			dwh_country_id, 
			fk_loan, 
			interval, 
			interval_payback_date, 
			sum(eur_payment_amount) OVER W_plan eur_payment_amount_cum
		from base.loan_payment_plan_item  
		where 
			interval_payback_date<=current_date
		WINDOW W_plan as (partition by dwh_country_id,fk_loan order by interval)                
	) pp on
		ap.dwh_country_id=pp.dwh_country_id and
		ap.fk_loan=pp.fk_loan and 
		 -- we need this to exclude extra payments that have not been added to payment plan
		ap.iso_date>=pp.interval_payback_date and
		ap.actual_amount_cum>=pp.eur_payment_amount_cum
	where actual_amount_change<>0     
	group by ap.dwh_country_id, ap.fk_loan,  ap.iso_date

),


paymentplan as (
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
		pp.loan_coverage,
		pp.eur_payment_amount_borrower, 
		pp.eur_principal_amount_borrower, 
		pp.eur_interest_amount_borrower,
		pp.eur_initial_principal_amount_borrower, 
		pp.eur_sum_interval_interest_amount_borrower,
		pp.eur_residual_interest_amount_borrower, 
		pp.eur_residual_principal_amount_borrower, 
		 
		pp.calc_service_fee,
		pp.eur_payment_amount_investor,
		pp.eur_principal_amount_investor, 
		pp.eur_interest_amount_investor,
		pp.eur_initial_principal_amount_investor, 
		pp.eur_sum_interval_interest_amount_investor,
		pp.eur_residual_interest_amount_investor, 
		pp.eur_residual_principal_amount_investor,
		sum(coalesce(eur_payment_amount_investor,0) ) OVER W::float as eur_payment_amount_investor_cum,
		sum(coalesce(pp.eur_interest_amount_investor,0) ) OVER W::float as eur_interest_amount_investor_cum,
		sum(coalesce( 
					 case 
						 when interval>0 then pp.eur_interest_amount_investor
						 end,
					 0) 
		
		) OVER W::float as eur_interest_amount_investor_cum_exc0,
		sum(coalesce(pp.eur_principal_amount_investor,0) ) OVER W::float as eur_principal_amount_investor_cum
	FROM base.loan_payment_plan_combined_item pp

	join   base.loan l on 
		l.id_loan=pp.fk_loan and l.dwh_country_id=pp.dwh_country_id
	join  base.loan_funding lf   on
		pp.dwh_country_id=lf.dwh_country_id and 
		pp.fk_loan=lf.fk_loan and 
		pp.fk_user_investor=lf.fk_user
	where 
		--pp.dwh_country_id=1 and  
		pp.interval_payback_date<=current_date and  
		(lf.state='funded' ) and --or lf.close_reason is not null) and 
		l.state!='canceled'
	WINDOW W as (partition by pp.dwh_country_id, pp.fk_loan, pp.fk_user_investor ORDER BY pp.interval_payback_date)
)

select

	ap.dwh_country_id as dwh_country_id,
	ap.fk_user_borrower,
	lf.fk_user as fk_user_investor,
	ap.fk_loan as fk_loan,
	ap.loan_request_nr,
	ap.iso_date,
	pp.interval, 
	pp.interval_payback_date, 
	pp.next_interval_payback_date, 
	pp.loan_coverage,
	pp.eur_payment_amount_borrower, 
	pp.eur_principal_amount_borrower, 
	pp.eur_interest_amount_borrower, 
	pp.eur_initial_principal_amount_borrower,
	pp.eur_sum_interval_interest_amount_borrower,
	pp.eur_residual_interest_amount_borrower,
	pp.eur_residual_principal_amount_borrower,
	pp.calc_service_fee,

	pp.eur_payment_amount_investor, 
	pp.eur_payment_amount_investor_cum,        
	pp.eur_principal_amount_investor, 
	pp.eur_interest_amount_investor, 
	pp.eur_sum_interval_interest_amount_investor,
	pp.eur_interest_amount_investor_cum,
	pp.eur_interest_amount_investor_cum_exc0,
	pp.eur_residual_interest_amount_investor,
	pp.eur_principal_amount_investor_cum,
	pp.eur_initial_principal_amount_investor,
	pp.eur_residual_principal_amount_investor,

	expected_amount_cum,
	actual_amount_change, 
	actual_amount_cum,
	in_arrears_flag, 
	in_arrears_since,
	in_arrears_since_days

from actual_payments ap
join actual_payments_cum ap_cum on
	ap.dwh_country_id=ap_cum.dwh_country_id and
	ap.fk_loan=ap_cum.fk_loan and
	ap.iso_date=ap_cum.iso_date

join base.loan_funding lf on 
	ap.dwh_country_id=lf.dwh_country_id and
	ap.fk_loan=lf.fk_loan


join base.loan l on 
	ap.dwh_country_id=l.dwh_country_id and
	ap.fk_loan=l.id_loan

left join paymentplan pp on
	pp.dwh_country_id=ap.dwh_country_id and
	pp.fk_user_investor = lf.fk_user and
	pp.fk_loan=ap.fk_loan and
	ap_cum.interval=pp.interval
where  
	--ap.dwh_country_id=1 and 
	ap.iso_date <=current_date and 
	(lf.state='funded' ) --or lf.close_reason is not null)
WINDOW W as( partition by ap.dwh_country_id, ap.fk_loan, pp.fk_user_investor  order by ap.iso_date)
order by dwh_country_id,fk_loan,iso_date

