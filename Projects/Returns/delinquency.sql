select dp.*, originated_since, interval_payback_date, ceil(in_arrears_since_days/30)::int  from de_payments dp
join loan_payment_plan_item lp on

        dp.fk_loan=lp.fk_loan and     
        dp.dwh_country_id=lp.dwh_country_id
join loan on
        dp.fk_loan=loan.id_loan and     
        dp.dwh_country_id=loan.dwh_country_id

where iso_date='2015-03-19' --and in_arrears_since is not null 
and dp.dwh_country_id=1 and 
    lp.interval=1

order by in_arrears_since_days desc