select 
	l.*, 
	left(l.rating,1) as rating_base,
	gblrc.user_campaign,
	gblrc.credit_agency_score, 
	gblrc.pd, 
	gblrc.pd_original, 
	gblrc.lgd, 
	
	gblrc.in_arrears_since,
    gblrc.date_of_first_loan_offer,
    ranking.rating as ranking_rating, 
	gblrc.rating as gblrc_rating,
	gblrc.rating_mapped as gblrc_rating_mapped,
	left(gblrc.rating_mapped,1) as gblrc_rating_mapped_base,
	ranking.pd_start as ranking_pd_start, 
	ranking.pd_end as ranking_pd_end,
	ranking.targeted_yield,
	ranking_new.pd_start,
	ranking_new.pd_end,
	ranking_new.amount_start,
	ranking_new.amount_end,
	ranking_new.total_rate,
    lp.payback_day,
	lp.payout_date,
	case when lp.payout_date>='2014-01-01' then
		to_char(lp.payout_date,'YYYY_"Q"Q')
	else
		'2014_Q1'
	end	as payout_quarter,
	lp.state as payback_state, 
	lp.auto_in_arrears_since, 
	lp.in_arrears_since in_arrears_since_man,
	lpp.eur_interval_payment,
	lppi.eur_payment_amount,
	round(l.eur_principal_amount*(total_rate/1200)*power(1+l.total_rate/1200.0,duration/30)/(power(1+total_rate/1200.0,duration/30)-1),2) as eur_interval_payment_new
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
join base.loan_payment_plan lpp on 
	l.dwh_country_id=lpp.dwh_country_id and 
	l.id_loan=lpp.fk_loan
join base.loan_payment_plan_item lppi on 
	l.dwh_country_id=lppi.dwh_country_id and 
	l.id_loan=lppi.fk_loan and 
	lppi.interval=1
	
join backend.ranking ranking_new on 
	l.dwh_country_id=ranking_new.dwh_country_id and 
	gblrc.pd>=ranking_new.pd_start and 
	gblrc.pd<=ranking_new.pd_end and 
	l.principal_amount*100>=ranking_new.amount_start and 
	l.principal_amount*100<=ranking_new.amount_end and 
	l.duration>=ranking_new.maturity_start*30 and 
	l.duration<=ranking_new.maturity_end*30 and
	ranking_new.valid_from>'20150301' and 
	coalesce(ranking_new.fk_loan_request_type,1) =1
where
	l.state!='canceled' and
	l.sme_flag=0 and
	originated_since is not null
