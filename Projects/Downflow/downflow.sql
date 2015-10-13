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

---------------------------------------------------------------------------

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

------------------------------------------------------------------------------------------------------------


select *, case 
 when bkt_first<bkt_second then 'down'
 when bkt_first>bkt_second then 'up'
 else 'stable' 
              end as bkt_move
from (

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
) as sub


select *, case 
 when bkt_first<bkt_second then 'down'
 when bkt_first>bkt_second then 'up'
 else 'stable' 
              end as bkt_move
from (

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
coalesce(de_first.iso_date,date_trunc('month',de_second.iso_date)- interval '1 day') ) as iso_date_first,
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
coalesce(de_second.iso_date,date_trunc('month',de_first.iso_date)+ interval '1 month - 1 day') as iso_date_second,
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
 de_second.iso_date=date_trunc('month',de_first.iso_date) + interval '1 month - 1 day'
where   coalesce(de_first.iso_date=date_trunc('month',de_first.iso_date)  + interval '1 month - 1 day',TRUE)
 and    coalesce(de_second.iso_date=date_trunc('month',de_second.iso_date)+ interval '1 month - 1 day',TRUE)
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay
) as sub


---------------------
select *, case 
 when bkt_first<bkt_second then 'down'
 when bkt_first>bkt_second then 'up'
 else 'stable' 
              end as bkt_move
from (

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
coalesce(de_first.iso_date,date_trunc('month',de_second.iso_date)- interval '1 day')  as iso_date_first,
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
coalesce(de_second.iso_date,date_trunc('month',de_first.iso_date)+ interval '1 month - 1 day') as iso_date_second,
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
 de_second.iso_date=date_trunc('month',de_first.iso_date) + interval '1 month - 1 day'
where   coalesce(de_first.iso_date=date_trunc('month',de_first.iso_date)  + interval '1 month - 1 day',TRUE)
 and    coalesce(de_second.iso_date=date_trunc('month',de_second.iso_date)+ interval '1 month - 1 day',TRUE)
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay
) as sub

-------------------------------------------------

with de_payments_eom as 
	(select * from base.de_payments where iso_date=(date_trunc('month',iso_date)+ interval '1 month - 1 day'))


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
coalesce(de_first.iso_date,date_trunc('month',de_second.iso_date)- interval '1 day')  as iso_date_first,
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
coalesce(de_second.iso_date,date_trunc('month',de_first.iso_date)+ interval '1 month - 1 day') as iso_date_second,
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
 from de_payments_eom as de_first  full outer join
       de_payments_eom as de_second  
on 
	de_first.dwh_country_id=de_second.dwh_country_id and 
	de_first.loan_request_nr=de_second.loan_request_nr and 
	de_second.iso_date=date_trunc('month',de_first.iso_date) + interval '1 month - 1 day'
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay
----------------------------------------------------------------------------------------------------


di aggregation of payments
select 
dwh_country_id_first,iso_date_first,bkt_first,dwh_country_id_second ,iso_date_second,bkt_second,
count(bkt_first) as bkt_first
sum(total_outstanding_first) as total_outstanding_first,
sum(total_outstanding_second) group by 
dwh_country_id_first,iso_date_first,bkt_first,dwh_country_id_second ,iso_date_second,bkt_second





from (
with de_payments_eom as 
 (

SELECT distinct on (pay.dwh_country_id, pay.fk_loan,pay.iso_date ) pay.dwh_country_id,pay.fk_user, pay.fk_loan, pay.loan_request_nr, pay.iso_date, 
       pay.expected_amount_cum, pay.actual_amount_cum, pay.in_arrears_flag, pay.in_arrears_since, 
       pay.in_arrears_since_days, plan.interval_payback_date, residual_principal_amount
  FROM base.de_payments as pay left join base.loan_payment_plan_item as plan
  on 
  pay.dwh_country_id=plan.dwh_country_id
  and pay.fk_loan = plan.fk_loan
  and pay.iso_date>= plan.interval_payback_date
where pay.iso_date=(date_trunc('month',pay.iso_date)+ interval '1 month - 1 day')

  order by  pay.dwh_country_id, pay.fk_loan,pay.iso_date,plan.interval_payback_date desc)

select 
 de_first.dwh_country_id as dwh_country_id_first,
 de_second.dwh_country_id as dwh_country_id_second ,
 de_first.fk_user as fk_user_first,
 de_second.fk_user  as fk_user_second,
 de_first.fk_loan as fk_loan_first,
 de_second.fk_loan as fk_loan_second, 
 de_first.loan_request_nr as loan_request_nr_first,
 de_second.loan_request_nr as loan_request_nr_second,
coalesce(de_first.iso_date,date_trunc('month',de_second.iso_date)- interval '1 day')  as iso_date_first,
 de_first.expected_amount_cum expected_amount_cum_first, 
 de_first.actual_amount_cum as actual_amount_cum_first,
 de_first.expected_amount_cum-de_first.actual_amount_cum as outstanding_first,
greatest(0,(de_first.expected_amount_cum-de_first.actual_amount_cum)::real) as outstanding_first_pos,
 de_first.in_arrears_flag as in_arrears_flag_first,
 de_first.in_arrears_since as in_arrears_since_first, 
 de_first.in_arrears_since_days as  in_arrears_since_days_first,
case when de_first.fk_loan is NULL then -1
 else
  least( ceil(coalesce(de_first.in_arrears_since_days,0)/30.0),4) 
 end as bkt_first,
coalesce(de_second.iso_date,date_trunc('month',de_first.iso_date)+ interval '1 month - 1 day') as iso_date_second,
 de_second.expected_amount_cum expected_amount_cum_second, 
 de_second.actual_amount_cum as actual_amount_cum_second,
 de_second.expected_amount_cum-de_second.actual_amount_cum as outstanding_second,
 greatest(0,(de_second.expected_amount_cum-de_second.actual_amount_cum)::real) as outstanding_pos_second,
de_first.residual_principal_amount as residual_principal_amount_first,
de_first.expected_amount_cum-de_first.actual_amount_cum + de_first.residual_principal_amount as total_outstanding_first,
de_second.residual_principal_amount as residual_principal_amount_second,
de_second.expected_amount_cum-de_second.actual_amount_cum + de_second.residual_principal_amount as total_outstanding_second,
 de_second.in_arrears_flag as in_arrears_flag_second,
 de_second.in_arrears_since as in_arrears_since_second, 
 de_second.in_arrears_since_days as  in_arrears_since_days_second, 
case when de_second.fk_loan is NULL then 
 -1
 else 
 least( ceil(coalesce(de_second.in_arrears_since_days,0)/30.0),4)
 end as bkt_second

 from de_payments_eom as de_first  full outer join
       de_payments_eom as de_second  
on 
 de_first.dwh_country_id=de_second.dwh_country_id and 
 de_first.loan_request_nr=de_second.loan_request_nr and 
 de_second.iso_date=date_trunc('month',de_first.iso_date) + interval '2 month - 1 day'
-- either 1 or both dates exist and 1st or last day of month
-- https://wiki.postgresql.org/wiki/Date_LastDay

) as sub