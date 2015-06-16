select 
	l.*, 
	gblrc.credit_agency_score, 
	gblrc.pd, 
	gblrc.pd_original, 
	gblrc.lgd, 
	gblrc.in_arrears_since,
    gblrc.date_of_first_loan_offer,
    ranking.rating as ranking_rating, 
	ranking.pd_start as ranking_pd_start, 
	ranking.pd_end as ranking_pd_end,
    lp.payback_day,
	lp.payout_date, 
	lp.state as payback_state, 
	lp.auto_in_arrears_since, 
	lp.in_arrears_since in_arrears_since_man
from base.loan l
join il.global_borrower_loan_requests_cohort gblrc on 
	l.dwh_country_id=gblrc.dwh_country_id and 
	l.loan_nr=gblrc.loan_request_nr
left join backend.ranking ranking on 
	l.dwh_country_id=ranking.dwh_country_id and 
	l.fk_ranking=ranking.id_ranking
join base.loan_payback lp on 
	l.dwh_country_id=lp.dwh_country_id and 
	l.id_loan=lp.fk_loan
where
	l.state!='canceled' and
    originated_since is not null
