select l.loan_nr, lr.loan_request_nr, l.loan_nr
from base.loan_request lr
join base.loan l
on 
lr.fk_user=l.fk_user and
lr.dwh_country_id=l.dwh_country_id
where 
lr.dwh_country_id=1 and
lr.loan_request_nr<>l.loan_nr and
l.state<>'canceled'