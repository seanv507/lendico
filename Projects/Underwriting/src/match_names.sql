select 
	ldata.loan_nr l_loan_nr,
	lrdata.loan_request_nr lr_loan_request_nr, 
	ldata.last_name l_last_name, 
	ldata.first_name l_first_name,
	lrdata.last_name lr_last_name, 
	lrdata.first_name lr_first_name
from 


(select l.loan_nr, l.fk_user,ua.last_name,ua.first_name, ua.birthday,ua.fk_person

from base.loan l
join base.user_account ua on 
l.dwh_country_id=ua.dwh_country_id and 
l.fk_user=ua.id_user
where 
ua.dwh_country_id=1 and 
l.state<>'canceled' 

) ldata

join
(select lr.loan_request_nr, lr.fk_user,ua.last_name,ua.first_name, ua.birthday,ua.fk_person
from base.loan_request lr
join base.user_account ua on 
lr.dwh_country_id=ua.dwh_country_id and 
lr.fk_user=ua.id_user
where ua.dwh_country_id=1

) lrdata

on 
	-- allow for name alt or Alt
	lower(regexp_replace(lrdata.last_name,'([\- ]alt$)|(^alt$)','','i')) =lower(ldata.last_name) and
	--ldata.first_name=lrdata.first_name and multiple first names
	ldata.birthday=lrdata.birthday
where 
	lrdata.loan_request_nr<> ldata.loan_nr
order by 
	ldata.last_name,ldata.first_name