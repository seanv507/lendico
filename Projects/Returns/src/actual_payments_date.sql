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
		ap.expected_amount_cum - lag(expected_amount_cum,1,0.0) over W_pay expected_amount_change,
		ap.actual_amount_cum - lag(actual_amount_cum,1,0.0) over W_pay actual_amount_change
    from base.payments ap
    join base.loan_payback lp on 
		lp.dwh_country_id=ap.dwh_country_id and 
		lp.fk_loan=ap.fk_loan
	where 
		ap.iso_date=(date_trunc('MONTH', ap.iso_date) + INTERVAL '1 MONTH - 1 day')::date and 
		(lp.state!='payback_complete' or lp.in_arrears_since is not null or ap.iso_date <=lp.last_payment_date)
	WINDOW W_pay as ( partition by ap.dwh_country_id, ap.fk_loan  order by ap.iso_date)
    ),
    -- select End of month, excluding those that have now paid back ( apart from those that were paid back by lendico)
    -- find corresponding payment plan item.
    -- we find the maximum payment plan interval that has cum_payment<= actual_cum
    -- could also use distinct on?
    -- match only actual payments that have happened after plan date
    -- problem is overpayments [ ie where payment plan has not been updated with extra payment.. because
actual_payments_cum as (
	select
		ap.dwh_country_id, 
		ap.fk_loan,
		-- ap.iso_date as date,min(pp.interval) as interval, min(interval_payback_date) interval_payback_date--, ap.actual_amount_cum, pp.payment_amount_cum'
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
		ap.fk_loan=pp.fk_loan and -- we need this to exclude extra payments that have not been added to payment plan
		ap.iso_date>=pp.interval_payback_date and
		ap.actual_amount_cum>=pp.eur_payment_amount_cum
    group by ap.dwh_country_id, ap.fk_loan,  ap.iso_date
    --order by date, interval
),


paymentplan as (

	SELECT 
		pp.dwh_country_id, 
		pp.fk_user, 
		pp.fk_loan_request,
		pp.fk_loan, 
		l.loan_nr,
        pp.country_name, 
		interval, 
		interval_payback_date,
		next_interval_payback_date,
		eur_payment_amount, 
		pp.eur_interest_amount,
        pp.eur_principal_amount,
        eur_initial_principal_amount, 
		eur_sum_interval_interest_amount,
        eur_residual_interest_amount,
		eur_residual_principal_amount,
        sum(coalesce(eur_payment_amount,0) )  OVER W::float as eur_payment_amount_cum,
        sum(coalesce(pp.eur_interest_amount,0) ) OVER W::float as eur_interest_amount_cum,
        sum(coalesce(
            case when interval>0 then
                pp.eur_interest_amount
            end,0) ) OVER W::float as eur_interest_amount_cum_exc0,
        sum(coalesce(pp.eur_principal_amount,0) ) OVER W::float as eur_principal_amount_cum

    FROM base.loan_payment_plan_item pp
    join   base.loan l on     
		l.dwh_country_id=pp.dwh_country_id and
		l.id_loan=pp.fk_loan
    where  
         --pp.dwh_country_id=1 and 
		pp.interval_payback_date<=current_date
	WINDOW W as (partition by pp.dwh_country_id, pp.fk_loan ORDER BY pp.interval_payback_date)
)

select
	ap.dwh_country_id as dwh_country_id,
	ap.fk_user_borrower,
	ap.fk_loan as fk_loan,
	ap.loan_request_nr as loan_nr, --changed from pp.loan_nr
	ap.iso_date,
	pp.interval,
	pp.interval_payback_date,
	pp.eur_payment_amount, 
	pp.eur_payment_amount_cum,

	pp.eur_principal_amount, 
	pp.eur_interest_amount, 
	pp.eur_sum_interval_interest_amount,
	pp.eur_interest_amount_cum,
	pp.eur_interest_amount_cum_exc0,
	pp.eur_residual_interest_amount,
	pp.eur_principal_amount_cum,
	pp.eur_initial_principal_amount,
	pp.eur_residual_principal_amount,

	expected_amount_change, 
	expected_amount_cum,
	actual_amount_change, 
	actual_amount_cum,
	in_arrears_flag, 
	in_arrears_since,
	in_arrears_since_days
from actual_payments ap

left join actual_payments_cum ap_cum on
	ap.dwh_country_id=ap_cum.dwh_country_id and
	ap.fk_loan=ap_cum.fk_loan and
	ap.iso_date=ap_cum.iso_date

left join paymentplan pp on 
	pp.dwh_country_id=ap.dwh_country_id and
	pp.fk_loan=ap.fk_loan and
	ap_cum.interval=pp.interval

join base.loan l on 
	ap.dwh_country_id=l.dwh_country_id and 
	ap.fk_loan=l.id_loan
where  
	-- ap.dwh_country_id=1 and 
	ap.iso_date <=current_date
order by dwh_country_id,fk_loan,iso_date ;


