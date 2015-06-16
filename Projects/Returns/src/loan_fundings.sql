select * , coalesce(investment_fee,1.0) investment_fee_def
from base.loan_funding 
where 
	(state='funded' or close_reason is not null)