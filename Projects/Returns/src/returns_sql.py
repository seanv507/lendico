def get_sql_strings(exclude_loans=False):
    # combined payment plan has null for investor 
    # initial/residual principals ( for interval 0)
    # also if no match found for actual payment then
    # combined payment fields will nbe null in actual_payments...
    if exclude_loans:
        excluded_loans = (3,4,6,8,11,14,526,528,558,630,557,556,555,553,552,554,578,579,580,603,596,611,642)
    else:
        excluded_loans = "(-1)"

    d = dict()
    d['actual_payments_combined'] = """
    with
    actual_payments as (select
    dp.dwh_country_id, dp.fk_user as fk_user_borrower,
    dp.fk_loan, dp.loan_request_nr
     ,dp.iso_date
     ,dp.expected_amount_cum, dp.actual_amount_cum,
     in_arrears_flag, dp.in_arrears_since,in_arrears_since_days
     -- expected/actual payment over month (by taking diff of cumsum)
    ,dp.expected_amount_cum - lag(expected_amount_cum,1,0.0) 
    over ( partition by dp.dwh_country_id, dp.fk_loan  order by dp.iso_date) 
    expected_amount_month
    ,dp.actual_amount_cum - lag(actual_amount_cum,1,0.0)
    over ( partition by dp.dwh_country_id, dp.fk_loan order by iso_date)
    actual_amount_month
    from base.de_payments dp
    join base.loan_payback lp on 
    (lp.dwh_country_id=dp.dwh_country_id and lp.fk_loan=dp.fk_loan)
    where dp.iso_date=(date_trunc('MONTH', dp.iso_date) + INTERVAL '1 MONTH - 1 day')::date
    and (lp.state!='payback_complete' or lp.in_arrears_since is not null or dp.iso_date <=lp.last_payment_date)
    and dp.fk_loan not in {}
    ) ,
    -- select End of month, excluding those that have now paid back ( apart from those that were paid back by lendico)
    -- find corresponding payment plan item.
    -- we find the maximum payment plan interval that has cum_payment<= actual_cum
    -- could also use distinct on?
    -- match only actual payments that have happened after plan date
    -- problem is overpayments [ ie where payment plan has not been updated with extra payment.. because
    actual_payments_cum as (
    select
    ap.dwh_country_id, ap.fk_loan,
    -- dp.iso_date as date,min(pp.interval) as interval, min(interval_payback_date) interval_payback_date--, dp.actual_amount_cum, pp.payment_amount_cum'
    ap.iso_date,max(pp.interval) as interval

    from actual_payments ap

    join
    (select dwh_country_id, fk_loan, interval, interval_payback_date, sum(payment_amount)
        OVER (partition by dwh_country_id,fk_loan order by interval) payment_amount_cum
        from base.loan_payment_plan_item  where interval_payback_date<=current_date) pp
    on
     (ap.dwh_country_id=pp.dwh_country_id and
     ap.fk_loan=pp.fk_loan and -- we need this to exclude extra payments that have not been added to payment plan
     ap.iso_date>=pp.interval_payback_date and
     ap.actual_amount_cum>=pp.payment_amount_cum )

    group by ap.dwh_country_id, ap.fk_loan,  ap.iso_date
    --order by date, interval

    ),


     paymentplan as
    (
            SELECT pp.dwh_country_id, pp.fk_loan, pp.fk_loan_request,  l.loan_nr as loan_request_nr,
            pp.fk_user_investor, pp.fk_user_borrower, pp.country_name, 
            pp.nominal_interest_percentage, pp.promo_interest_percentage, pp.has_promo_flag,
            pp.is_repaid_flag, pp.payout_date,
            pp.interval, pp.interval_payback_date, pp.next_interval_payback_date, 
            pp.loan_coverage,
            pp.payment_amount_borrower, pp.principal_amount_borrower, pp.interest_amount_borrower,
            pp.initial_principal_amount_borrower, pp.sum_interval_interest_amount_borrower,
            pp.residual_interest_amount_borrower, pp.residual_principal_amount_borrower, 
            pp.payment_amount_promo, pp.principal_amount_promo, pp.interest_amount_promo, 
            pp.initial_principal_amount_promo, pp.sum_interval_interest_amount_promo, 
            pp.residual_interest_amount_promo, pp.residual_principal_amount_promo, pp.calc_service_fee,
            pp.payment_amount_investor,

            pp.principal_amount_investor, pp.interest_amount_investor,
            pp.initial_principal_amount_investor, pp.sum_interval_interest_amount_investor,
            pp.residual_interest_amount_investor, pp.residual_principal_amount_investor
            , sum(coalesce(payment_amount_investor,0) ) OVER W::float as payment_amount_investor_cum
            , sum(coalesce(pp.interest_amount_investor,0) ) OVER W::float as interest_amount_investor_cum
            , sum(coalesce(pp.principal_amount_investor,0) ) OVER W::float as principal_amount_investor_cum
            FROM base.loan_payment_plan_combined_item pp

     join   base.loan l
     on     l.id_loan=pp.fk_loan and l.dwh_country_id=pp.dwh_country_id
     join  base.loan_funding lf   on
     (pp.dwh_country_id=lf.dwh_country_id and pp.fk_loan=lf.fk_loan and pp.fk_user_investor=lf.fk_user)
    where pp.dwh_country_id=1 and  pp.interval_payback_date<=current_date and  (lf.state='funded' or lf.close_reason is not null) and l.state!='canceled'
    WINDOW W as (partition by pp.dwh_country_id, pp.fk_loan, pp.fk_user_investor ORDER BY pp.interval_payback_date)
    )

    select

     ap.dwh_country_id as dwh_country_id
     , ap.fk_user_borrower
     ,lf.fk_user as fk_user_investor
     , ap.fk_loan as fk_loan
     , ap.loan_request_nr
     , ap.iso_date,


    pp.nominal_interest_percentage, pp.promo_interest_percentage, pp.has_promo_flag,
    pp.is_repaid_flag, pp.payout_date, pp.interval, pp.interval_payback_date, pp.next_interval_payback_date, pp.loan_coverage,
    pp.payment_amount_borrower, pp.principal_amount_borrower, pp.interest_amount_borrower, 
    coalesce (pp.initial_principal_amount_borrower,l.principal_amount)
        as initial_principal_amount_borrower,
    pp.sum_interval_interest_amount_borrower,
    pp.residual_interest_amount_borrower,
    coalesce (pp.residual_principal_amount_borrower, l.principal_amount) 
         as residual_principal_amount_borrower,
    pp.calc_service_fee,

    pp.payment_amount_investor, pp.payment_amount_investor_cum,
    pp.payment_amount_investor_cum - lag(pp.payment_amount_investor_cum,1,0.0::float) over W payment_amount_investor_month,
    pp.principal_amount_investor, pp.interest_amount_investor, pp.sum_interval_interest_amount_investor,
    pp.interest_amount_investor_cum,
    pp.residual_interest_amount_investor,
    pp.principal_amount_investor_cum,
    coalesce (pp.initial_principal_amount_investor, lf.amount) 
        as initial_principal_amount_investor,
    coalesce (pp.residual_principal_amount_investor, lf.amount) 
        as residual_principal_amount_investor,

    expected_amount_month, expected_amount_cum,
    actual_amount_month, actual_amount_cum,
     in_arrears_flag, in_arrears_since,
     in_arrears_since_days


    from actual_payments ap
    left join actual_payments_cum ap_cum
       on(
      ap.dwh_country_id=ap_cum.dwh_country_id and
      ap.fk_loan=ap_cum.fk_loan and
      ap.iso_date=ap_cum.iso_date
       )

    join base.loan_funding lf on (
     ap.dwh_country_id=lf.dwh_country_id and
     ap.fk_loan=lf.fk_loan

    )
    join base.loan l on (
     ap.dwh_country_id=l.dwh_country_id and
     ap.fk_loan=l.id_loan

    )

    left join paymentplan pp on (
        pp.dwh_country_id=ap.dwh_country_id and
        pp.fk_user_investor = lf.fk_user and
        pp.fk_loan=ap.fk_loan and
        ap_cum.interval=pp.interval)
    where  ap.dwh_country_id=1 and ap.iso_date <=current_date and (lf.state='funded' or lf.close_reason is not null)
    WINDOW W as( partition by ap.dwh_country_id, ap.fk_loan, pp.fk_user_investor  order by ap.iso_date)
    order by dwh_country_id,fk_loan,iso_date
    ;""".format(excluded_loans)


    d['actual_payments']= """
    with
    actual_payments as (select
    dp.dwh_country_id, dp.fk_user as fk_user_borrower, dp.fk_loan, dp.loan_request_nr
     ,dp.iso_date
     ,dp.expected_amount_cum, dp.actual_amount_cum, in_arrears_flag, dp.in_arrears_since
     ,in_arrears_since_days
    -- expected/actual payment over month (by taking diff of cumsum)
    ,dp.expected_amount_cum - lag(expected_amount_cum,1,0.0) over ( partition by dp.dwh_country_id, dp.fk_loan  order by dp.iso_date)  expected_amount_month
    ,dp.actual_amount_cum - lag(actual_amount_cum,1,0.0) over ( partition by dp.dwh_country_id, dp.fk_loan order by iso_date)
     actual_amount_month
     from base.de_payments dp
     join base.loan_payback lp on (lp.dwh_country_id=dp.dwh_country_id and lp.fk_loan=dp.fk_loan)
    where dp.iso_date=(date_trunc('MONTH', dp.iso_date) + INTERVAL '1 MONTH - 1 day')::date
    and (lp.state!='payback_complete' or lp.in_arrears_since is not null or dp.iso_date <=lp.last_payment_date)
    and dp.fk_loan not in {0}
    ) ,
    -- select End of month, excluding those that have now paid back ( apart from those that were paid back by lendico)
    -- find corresponding payment plan item.
    -- we find the maximum payment plan interval that has cum_payment<= actual_cum
    -- could also use distinct on?
    -- match only actual payments that have happened after plan date
    -- problem is overpayments [ ie where payment plan has not been updated with extra payment.. because
    actual_payments_cum as (
    select
    ap.dwh_country_id, ap.fk_loan,
    -- dp.iso_date as date,min(pp.interval) as interval, min(interval_payback_date) interval_payback_date--, dp.actual_amount_cum, pp.payment_amount_cum'
    ap.iso_date,max(pp.interval) as interval

    from actual_payments ap

    join
    (select dwh_country_id, fk_loan, interval, interval_payback_date, sum(payment_amount) \
        OVER (partition by dwh_country_id,fk_loan order by interval) payment_amount_cum
        from base.loan_payment_plan_item where interval_payback_date<=current_date) pp
    on
     (ap.dwh_country_id=pp.dwh_country_id and
     ap.fk_loan=pp.fk_loan and -- we need this to exclude extra payments that have not been added to payment plan
     ap.iso_date>=pp.interval_payback_date and
     ap.actual_amount_cum>=pp.payment_amount_cum )

    group by ap.dwh_country_id, ap.fk_loan,  ap.iso_date
    --order by date, interval

    ),


     paymentplan as
    (

        SELECT pp.dwh_country_id, pp.fk_user, pp.fk_loan_request,pp.fk_loan, l.loan_nr
        ,pp.country_name, interval, payment_amount, pp.interest_amount
        ,pp.principal_amount,interval_payback_date,next_interval_payback_date,
        initial_principal_amount, sum_interval_interest_amount,
        residual_interest_amount,residual_principal_amount
        , sum(coalesce(payment_amount,0) )  OVER W::float as payment_amount_cum
        , sum(coalesce(pp.interest_amount,0) ) OVER W::float as interest_amount_cum
        , sum(coalesce(pp.principal_amount,0) ) OVER W::float as principal_amount_cum

     FROM base.loan_payment_plan_item pp


     join   base.loan l
     on     l.id_loan=pp.fk_loan and l.dwh_country_id=pp.dwh_country_id
     where  pp.dwh_country_id=1 and pp.interval_payback_date<=current_date
    WINDOW W as (partition by pp.dwh_country_id, pp.fk_loan ORDER BY pp.interval_payback_date)
    )

    select


     ap.dwh_country_id as dwh_country_id
     , ap.fk_user_borrower
     , ap.fk_loan as fk_loan
     , ap.loan_request_nr as loan_nr --changed from pp.loan_nr
     , ap.iso_date
     , pp.interval
     , pp.interval_payback_date
    ,pp.payment_amount, pp.payment_amount_cum,

    pp.principal_amount, pp.interest_amount, pp.sum_interval_interest_amount,
    pp.interest_amount_cum,
    pp.residual_interest_amount,
     pp.principal_amount_cum,
     pp.initial_principal_amount,
    pp.residual_principal_amount

    ,expected_amount_month, expected_amount_cum
    ,actual_amount_month, actual_amount_cum
    , in_arrears_flag, in_arrears_since
     ,in_arrears_since_days



    from actual_payments ap
    left join actual_payments_cum ap_cum
       on(
      ap.dwh_country_id=ap_cum.dwh_country_id and
      ap.fk_loan=ap_cum.fk_loan and
      ap.iso_date=ap_cum.iso_date
       )

    left join paymentplan pp

    on (pp.dwh_country_id=ap.dwh_country_id and
            pp.fk_loan=ap.fk_loan and
            ap_cum.interval=pp.interval)
    join base.loan l
    on (ap.dwh_country_id=l.dwh_country_id and ap.fk_loan=l.id_loan)
    where  ap.dwh_country_id=1 and ap.iso_date <=current_date and  ap.fk_loan not in {0}

    order by dwh_country_id,fk_loan,iso_date ;
    """.format(excluded_loans)

    d['payment_plans_combined']="""SELECT pp.dwh_country_id, pp.fk_loan, pp.fk_loan_request,l.loan_nr as loan_request_nr,
        pp.fk_user_investor, pp.fk_user_borrower, pp.country_name,
        pp.nominal_interest_percentage, pp.promo_interest_percentage, pp.has_promo_flag,
        pp.is_repaid_flag,
        pp.payout_date, pp.interval, pp.interval_payback_date, pp.next_interval_payback_date,
        pp.loan_coverage,

        pp.payment_amount_borrower,
        sum(pp.payment_amount_borrower) OVER wind as payment_amount_borrower_cum,

        pp.principal_amount_borrower,
        sum(pp.principal_amount_borrower) OVER wind as principal_amount_borrower_cum,

        pp.interest_amount_borrower,
        sum(pp.interest_amount_borrower) OVER wind as interest_amount_borrower_cum,

        pp.initial_principal_amount_borrower,
        pp.residual_interest_amount_borrower,
        pp.residual_principal_amount_borrower,

        pp.calc_service_fee,

        pp.payment_amount_investor,
        sum(pp.payment_amount_investor) OVER wind as payment_amount_investor_cum,

        pp.principal_amount_investor,
        sum(pp.principal_amount_investor) OVER wind as principal_amount_investor_cum,

        pp.interest_amount_investor,
        sum(pp.interest_amount_investor) OVER wind as interest_amount_investor_cum,

        coalesce( pp.initial_principal_amount_investor, lf.amount) 
            as initial_principal_amount_investor,
        pp.sum_interval_interest_amount_investor,
        pp.residual_interest_amount_investor, 
        coalesce( pp.residual_principal_amount_investor, lf.amount) 
            as residual_principal_amount_investor


        FROM base.loan_payment_plan_combined_item pp
        join base.loan l on (pp.dwh_country_id=l.dwh_country_id and pp.fk_loan=l.id_loan )
        join base.loan_funding lf on (pp.dwh_country_id=lf.dwh_country_id and pp.fk_loan=lf.fk_loan and pp.fk_user_investor=lf.fk_user)
        where pp.dwh_country_id=1 and
        l.state!='canceled'
        and l.id_loan not in {} and
        l.originated_since is not null and
        (lf.state='funded' or lf.close_reason is not null)
        WINDOW wind as (PARTITION BY pp.dwh_country_id, pp.fk_loan, pp.fk_user_investor order by interval)
        """.format(excluded_loans)

# load german combined payment plan up to system date (very large), removing cancelled/non funded loans and loans created by lendico 'borrowers'
    d['payment_plans']="""select
    pp.dwh_country_id, pp.fk_loan_payment_plan, pp.fk_user, pp.fk_loan_request, pp.fk_loan,
    pp.country_name, pp.currency_code, pp.loan_request_creation_date,
    interval, payment_amount, pp.interest_amount, pp.principal_amount, interval_payback_date, next_interval_payback_date,
    initial_principal_amount, sum_interval_interest_amount, residual_interest_amount, residual_principal_amount
    from base.loan_payment_plan_item pp
    join base.loan l on          (pp.dwh_country_id=l.dwh_country_id and pp.fk_loan=l.id_loan )
    where pp.dwh_country_id=1 and l.state!='canceled'  and l.originated_since is not null
    and l.id_loan not in {}""".format(excluded_loans)
    # load german borrower payment plan , removing cancelled, not yet originated  loans and loans created by lendico 'borrowers'

    d['loans']="""select l.*, gblrc.credit_agency_score, gblrc.pd, gblrc.pd_original, gblrc.lgd, gblrc.in_arrears_since,
    gblrc.date_of_first_loan_offer,
    ranking.rating as ranking_rating, ranking.pd_start as ranking_pd_start, ranking.pd_end as ranking_pd_end,
    lp.payback_day,lp.payout_date, lp.state as payback_state, lp.auto_in_arrears_since, lp.in_arrears_since in_arrears_since_man
    from base.loan l
    join il.global_borrower_loan_requests_cohort gblrc
    on (l.dwh_country_id=gblrc.dwh_country_id and l.loan_nr=gblrc.loan_request_nr)
    left join backend.ranking ranking
    on (l.dwh_country_id=ranking.dwh_country_id and l.fk_ranking=ranking.id_ranking)
    join base.loan_payback lp
    on (l.dwh_country_id=lp.dwh_country_id and l.id_loan=lp.fk_loan)
    where
        l.dwh_country_id=1 and
        l.state!='canceled' and
        id_loan not in {} and
        originated_since is not null""".format(excluded_loans)


# load loans removing cancelled, not yet originated  loans and loans created by lendico 'borrowers'


    d['loan_fundings']="""select * from base.loan_funding where dwh_country_id=1
    and fk_loan not in {} and (state='funded' or close_reason is not null)""".format(excluded_loans)

    return d