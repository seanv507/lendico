select 
 de_first.dwh_country_id as dwh_country_id_first,
 de_second.dwh_country_id as dwh_country_id_second ,
 de_first.fk_user as fk_user_first,
 de_second.fk_user  as fk_user_second,
 de_first.fk_loan as fk_loan_first,
 de_second.fk_loan as fk_loan_second, 
 de_first.loan_request_nr as loan_request_nr_first,
 de_second.loan_request_nr as loan_request_nr_second,
 de_first.iso_date as iso_date_first, 
 de_first.expected_amount_cum expected_amount_cum_first, 
 de_first.actual_amount_cum as actual_amount_cum_first,
 de_first.expected_amount_cum-de_first.actual_amount_cum as outstanding_first,
 de_first.in_arrears_flag as in_arrears_flag_first,
 de_first.in_arrears_since as in_arrears_since_first, 
 de_first.in_arrears_since_days as  in_arrears_since_days_first,
 ceil(coalesce(de_first.in_arrears_since_days/30.0,0)) as bkt_first,
 de_second.iso_date as iso_date_second, 
 de_second.expected_amount_cum expected_amount_cum_second, 
 de_second.actual_amount_cum as actual_amount_cum_second,
 de_second.expected_amount_cum-de_second.actual_amount_cum as outstanding_second,
 de_second.in_arrears_flag as in_arrears_flag_second,
 de_second.in_arrears_since as in_arrears_since_second, 
 de_second.in_arrears_since_days as  in_arrears_since_days_second, 
 ceil(coalesce(de_second.in_arrears_since_days/30.0)) as bkt_second
 from base.de_payments as de_first  full  outer join base.de_payments as de_second  
       
       on de_first.dwh_country_id=de_second.dwh_country_id and 
       de_first.fk_loan=de_second.fk_loan where
	   extract(day from de_first.iso_date)=1 and de_second.iso_date=de_first.iso_date+ interval '1 month - 1 day'
-- https://wiki.postgresql.org/wiki/Date_LastDay



select 
 de_first.dwh_country_id as dwh_country_id_first,

 de_first.fk_user as fk_user_first,

 de_first.fk_loan as fk_loan_first,

 de_first.loan_request_nr as loan_request_nr_first,

 de_first.iso_date as iso_date_first, 
 de_first.expected_amount_cum expected_amount_cum_first, 
 de_first.actual_amount_cum as actual_amount_cum_first,
 de_first.expected_amount_cum-de_first.actual_amount_cum as outstanding_first,
 de_first.in_arrears_flag as in_arrears_flag_first,
 de_first.in_arrears_since as in_arrears_since_first, 
 de_first.in_arrears_since_days as  in_arrears_since_days_first,
least( ceil(coalesce(de_first.in_arrears_since_days,0)/30.0),4) as bkt_first,


 from base.de_payments as de_first  full  outer join 
       base.de_payments as de_second  
       on de_first.dwh_country_id=de_second.dwh_country_id and 
       de_first.fk_loan=de_second.fk_loan where   extract(day from de_first.iso_date)=1 and de_second.iso_date=de_first.iso_date+ interval '1 month - 1 day'
-- https://wiki.postgresql.org/wiki/Date_LastDay
---------------------------------------------------

select 
 de_first.dwh_country_id as dwh_country_id_first,
 de_second.dwh_country_id as dwh_country_id_second ,
 de_first.fk_user as fk_user_first,
 de_second.fk_user  as fk_user_second,
 de_first.fk_loan as fk_loan_first,
 de_second.fk_loan as fk_loan_second, 
 de_first.loan_request_nr as loan_request_nr_first,
 de_second.loan_request_nr as loan_request_nr_second,
 de_first.iso_date as iso_date_first, 
 de_first.expected_amount_cum expected_amount_cum_first, 
 de_first.actual_amount_cum as actual_amount_cum_first,
 de_first.expected_amount_cum-de_first.actual_amount_cum as outstanding_first,
 de_first.in_arrears_flag as in_arrears_flag_first,
 de_first.in_arrears_since as in_arrears_since_first, 
 de_first.in_arrears_since_days as  in_arrears_since_days_first,
least( ceil(coalesce(de_first.in_arrears_since_days,0)/30.0),4) as bkt_first,
 de_second.iso_date as iso_date_second, 
 de_second.expected_amount_cum expected_amount_cum_second, 
 de_second.actual_amount_cum as actual_amount_cum_second,
 de_second.expected_amount_cum-de_second.actual_amount_cum as outstanding_second,
 de_second.in_arrears_flag as in_arrears_flag_second,
 de_second.in_arrears_since as in_arrears_since_second, 
 de_second.in_arrears_since_days as  in_arrears_since_days_second, 
least( ceil(coalesce(de_second.in_arrears_since_days,0)/30.0),4) as bkt_second
 from base.de_payments as de_first  full  outer join 
       base.de_payments as de_second  
       on de_first.dwh_country_id=de_second.dwh_country_id and 
       de_first.fk_loan=de_second.fk_loan and 
	   extract(day from de_first.iso_date)=1 
	   and de_second.iso_date=de_first.iso_date+ interval '1 month - 1 day'
	   where   coalesce(extract(day from de_first.iso_date),1)=1 
	   and    coalesce(de_second.iso_date=date_trunc('month',de_second.iso_date)+ interval '1 month - 1 day',TRUE)
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay
	   




select 
 de_first.dwh_country_id as dwh_country_id_first,
 de_second.dwh_country_id as dwh_country_id_second ,
 de_first.fk_user as fk_user_first,
 de_second.fk_user  as fk_user_second,
 de_first.fk_loan as fk_loan_first,
 de_second.fk_loan as fk_loan_second, 
 de_first.loan_request_nr as loan_request_nr_first,
 de_second.loan_request_nr as loan_request_nr_second,
 de_first.iso_date as iso_date_first, 
 de_first.expected_amount_cum expected_amount_cum_first, 
 de_first.actual_amount_cum as actual_amount_cum_first,
 de_first.expected_amount_cum-de_first.actual_amount_cum as outstanding_first,
 de_first.in_arrears_flag as in_arrears_flag_first,
 de_first.in_arrears_since as in_arrears_since_first, 
 de_first.in_arrears_since_days as  in_arrears_since_days_first,
least( ceil(coalesce(de_first.in_arrears_since_days,0)/30.0),4) as bkt_first,
 de_second.iso_date as iso_date_second, 
 de_second.expected_amount_cum expected_amount_cum_second, 
 de_second.actual_amount_cum as actual_amount_cum_second,
 de_second.expected_amount_cum-de_second.actual_amount_cum as outstanding_second,
 de_second.in_arrears_flag as in_arrears_flag_second,
 de_second.in_arrears_since as in_arrears_since_second, 
 de_second.in_arrears_since_days as  in_arrears_since_days_second, 
least( ceil(coalesce(de_second.in_arrears_since_days,0)/30.0),4) as bkt_second
 from base.de_payments as de_first  full  outer join 
       base.de_payments as de_second  
       on (de_first.dwh_country_id=de_second.dwh_country_id and 
       de_first.fk_loan=de_second.fk_loan and 
	   date_trunc('month',de_first.iso_date)=date_trunc('month',de_second.iso_date))
	   
	   where   coalesce(extract(day from de_first.iso_date),1)=1 
	   and    coalesce(de_second.iso_date,date_trunc('month',de_second.iso_date)+ interval '1 month - 1 day')=date_trunc('month',de_second.iso_date)+ interval '1 month - 1 day'
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay













select 
 de_first.dwh_country_id as dwh_country_id_first,
 de_second.dwh_country_id as dwh_country_id_second ,
 de_first.fk_user as fk_user_first,
 de_second.fk_user  as fk_user_second,
 de_first.fk_loan as fk_loan_first,
 de_second.fk_loan as fk_loan_second, 
 de_first.loan_request_nr as loan_request_nr_first,
 de_second.loan_request_nr as loan_request_nr_second,
 de_first.iso_date as iso_date_first, 
 de_first.expected_amount_cum expected_amount_cum_first, 
 de_first.actual_amount_cum as actual_amount_cum_first,
 de_first.expected_amount_cum-de_first.actual_amount_cum as outstanding_first,
 de_first.in_arrears_flag as in_arrears_flag_first,
 de_first.in_arrears_since as in_arrears_since_first, 
 de_first.in_arrears_since_days as  in_arrears_since_days_first,
case when de_first.fk_loan is NULL then -1
	else
		least( ceil(coalesce(de_first.in_arrears_since_days,0)/30.0),4) 
	end as bkt_first,
 de_second.iso_date as iso_date_second, 
 de_second.expected_amount_cum expected_amount_cum_second, 
 de_second.actual_amount_cum as actual_amount_cum_second,
 de_second.expected_amount_cum-de_second.actual_amount_cum as outstanding_second,
 de_second.in_arrears_flag as in_arrears_flag_second,
 de_second.in_arrears_since as in_arrears_since_second, 
 de_second.in_arrears_since_days as  in_arrears_since_days_second, 
case when de_first.fk_loan is NULL then 
		-1
	else 
		least( ceil(coalesce(de_second.in_arrears_since_days,0)/30.0),4)
	end as bkt_second
 from base.de_payments as de_first  full  outer join 
       base.de_payments as de_second  
on 
	de_first.dwh_country_id=de_second.dwh_country_id and 
       	de_first.fk_loan=de_second.fk_loan and 
	extract(day from de_first.iso_date)=1  and 
	de_second.iso_date=de_first.iso_date+ interval '1 month - 1 day'
where   coalesce(extract(day from de_first.iso_date),1)=1 
 and    coalesce(de_second.iso_date=date_trunc('month',de_second.iso_date)+ interval '1 month - 1 day',TRUE)
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay












select 
 de_first.dwh_country_id as dwh_country_id_first,
 de_second.dwh_country_id as dwh_country_id_second ,
 de_first.fk_user as fk_user_first,
 de_second.fk_user  as fk_user_second,
 de_first.fk_loan as fk_loan_first,
 de_second.fk_loan as fk_loan_second, 
 de_first.loan_request_nr as loan_request_nr_first,
 de_second.loan_request_nr as loan_request_nr_second,
 coalesce(de_first.iso_date,date_trunc('month',de_second.iso_date)) as iso_date_first,
 de_first.expected_amount_cum expected_amount_cum_first, 
 de_first.actual_amount_cum as actual_amount_cum_first,
 de_first.expected_amount_cum-de_first.actual_amount_cum as outstanding_first,
 de_first.in_arrears_flag as in_arrears_flag_first,
 de_first.in_arrears_since as in_arrears_since_first, 
 de_first.in_arrears_since_days as  in_arrears_since_days_first,
case when de_first.fk_loan is NULL then -1
	else
		least( ceil(coalesce(de_first.in_arrears_since_days,0)/30.0),4) 
	end as bkt_first,

 coalesce(de_second.iso_date,de_first.iso_date+ interval '1 month - 1 day') as iso_date_second,
 de_second.expected_amount_cum expected_amount_cum_second, 
 de_second.actual_amount_cum as actual_amount_cum_second,
 de_second.expected_amount_cum-de_second.actual_amount_cum as outstanding_second,
 de_second.in_arrears_flag as in_arrears_flag_second,
 de_second.in_arrears_since as in_arrears_since_second, 
 de_second.in_arrears_since_days as  in_arrears_since_days_second, 
case when de_second.fk_loan is NULL then 
		-1
	else 
		least( ceil(coalesce(de_second.in_arrears_since_days,0)/30.0),4)
	end as bkt_second
 from base.de_payments as de_first  full  outer join 
       base.de_payments as de_second  
on 
	de_first.dwh_country_id=de_second.dwh_country_id and 
       	de_first.fk_loan=de_second.fk_loan and 
	extract(day from de_first.iso_date)=1  and 
	de_second.iso_date=de_first.iso_date+ interval '1 month - 1 day'
where   coalesce(extract(day from de_first.iso_date),1)=1 
 and    coalesce(de_second.iso_date=de_second.iso_date+ interval '1 month - 1 day',TRUE)
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay



select 
 de_first.dwh_country_id as dwh_country_id_first,
 de_second.dwh_country_id as dwh_country_id_second ,
 de_first.fk_user as fk_user_first,
 de_second.fk_user  as fk_user_second,
 de_first.fk_loan as fk_loan_first,
 de_second.fk_loan as fk_loan_second, 
 de_first.loan_request_nr as loan_request_nr_first,
 de_second.loan_request_nr as loan_request_nr_second,
de_first.iso_date as iso_date_first,
-- coalesce(de_first.iso_date,date_trunc('month',de_second.iso_date)) as iso_date_first,
 de_first.expected_amount_cum expected_amount_cum_first, 
 de_first.actual_amount_cum as actual_amount_cum_first,
 de_first.expected_amount_cum-de_first.actual_amount_cum as outstanding_first,
 de_first.in_arrears_flag as in_arrears_flag_first,
 de_first.in_arrears_since as in_arrears_since_first, 
 de_first.in_arrears_since_days as  in_arrears_since_days_first,
case when de_first.fk_loan is NULL then -1
	else
		least( ceil(coalesce(de_first.in_arrears_since_days,0)/30.0),4) 
	end as bkt_first,
de_second.iso_date as iso_date_second,
-- coalesce(de_second.iso_date,de_first.iso_date+ interval '1 month - 1 day') as iso_date_second,
 de_second.expected_amount_cum expected_amount_cum_second, 
 de_second.actual_amount_cum as actual_amount_cum_second,
 de_second.expected_amount_cum-de_second.actual_amount_cum as outstanding_second,
 de_second.in_arrears_flag as in_arrears_flag_second,
 de_second.in_arrears_since as in_arrears_since_second, 
 de_second.in_arrears_since_days as  in_arrears_since_days_second, 
case when de_second.fk_loan is NULL then 
		-1
	else 
		least( ceil(coalesce(de_second.in_arrears_since_days,0)/30.0),4)
	end as bkt_second
 from base.de_payments as de_first  full  outer join 
       base.de_payments as de_second  
on 
	de_first.dwh_country_id=de_second.dwh_country_id and 
       	de_first.fk_loan=de_second.fk_loan and 
	extract(day from de_first.iso_date)=1  and 
	de_second.iso_date=de_first.iso_date+ interval '1 month - 1 day'
where   coalesce(extract(day from de_first.iso_date),1)=1 
 and    coalesce(de_second.iso_date=date_trunc('month',de_second.iso_date)+ interval '1 month - 1 day',TRUE)
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay



select 
 de_first.dwh_country_id as dwh_country_id_first,
 de_second.dwh_country_id as dwh_country_id_second ,
 de_first.fk_user as fk_user_first,
 de_second.fk_user  as fk_user_second,
 de_first.fk_loan as fk_loan_first,
 de_second.fk_loan as fk_loan_second, 
 de_first.loan_request_nr as loan_request_nr_first,
 de_second.loan_request_nr as loan_request_nr_second,
-- de_first.iso_date as iso_date_first,
coalesce(de_first.iso_date,date_trunc('month',de_second.iso_date)) as iso_date_first,
 de_first.expected_amount_cum expected_amount_cum_first, 
 de_first.actual_amount_cum as actual_amount_cum_first,
 de_first.expected_amount_cum-de_first.actual_amount_cum as outstanding_first,
 de_first.in_arrears_flag as in_arrears_flag_first,
 de_first.in_arrears_since as in_arrears_since_first, 
 de_first.in_arrears_since_days as  in_arrears_since_days_first,
case when de_first.fk_loan is NULL then -1
 else
  least( ceil(coalesce(de_first.in_arrears_since_days,0)/30.0),4) 
 end as bkt_first,
--de_second.iso_date as iso_date_second,
coalesce(de_second.iso_date,de_first.iso_date+ interval '1 month - 1 day') as iso_date_second,
 de_second.expected_amount_cum expected_amount_cum_second, 
 de_second.actual_amount_cum as actual_amount_cum_second,
 de_second.expected_amount_cum-de_second.actual_amount_cum as outstanding_second,
 de_second.in_arrears_flag as in_arrears_flag_second,
 de_second.in_arrears_since as in_arrears_since_second, 
 de_second.in_arrears_since_days as  in_arrears_since_days_second, 
case when de_second.fk_loan is NULL then 
  -1
 else 
  least( ceil(coalesce(de_second.in_arrears_since_days,0)/30.0),4)
 end as bkt_second
 from base.de_payments as de_first  full  outer join 
       base.de_payments as de_second  
on 
 de_first.dwh_country_id=de_second.dwh_country_id and 
        de_first.fk_loan=de_second.fk_loan and 
 extract(day from de_first.iso_date)=1  and 
 de_second.iso_date=de_first.iso_date+ interval '1 month - 1 day'
where   coalesce(extract(day from de_first.iso_date),1)=1 
 and    coalesce(de_second.iso_date=date_trunc('month',de_second.iso_date)+ interval '1 month - 1 day',TRUE)
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay








