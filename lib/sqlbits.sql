

select s.next_created,*
from il.global_investor_bids_transaction t
left join 	(
select*
from
(
select * ,
lead(created_at) OVER (partition by dwh_country_id,identifier ORDER BY id_state_machine_history ASC)next_created,
lead(end_state) OVER (partition by dwh_country_id,identifier ORDER BY id_state_machine_history ASC) next_end_state
from backend.state_machine_history
where dwh_country_id=1
and schema_name='LoanRequest'
and( 
(start_state='bidding_strategy' and end_state='exclusive_for_bidding') or
(start_state='exclusive_for_bidding' and end_state='open_for_bidding') or 
(start_state='exclusive_for_bidding' and end_state='fully_funded') 
)--
 order by 4,2 
)a
where next_created is not null
	) s on s.dwh_country_id=t.dwh_country_id and s.identifier::int=t.id_loan_request and s.created_at<=transaction_date_timestamp and transaction_date_timestamp<next_created
where  t.dwh_country_id=1 and s.next_created is not null
order by 4