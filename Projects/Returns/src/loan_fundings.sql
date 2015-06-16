select * 
from base.loan_funding 
where 
	(state='funded') -- or close_reason is not null)