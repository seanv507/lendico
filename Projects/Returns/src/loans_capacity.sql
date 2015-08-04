select  
  l.*, 
  left(l.rating,1) as rating_base,
  
  gblrc.user_campaign, 
  gblrc.credit_agency_score, 
  gblrc.pd, 
  gblrc.pd_original, 
  gblrc.lgd, 
  
  gblrc.in_arrears_since, 
  gblrc.auto_in_arrears_since auto_in_arrears_since_g, 
  gblrc.in_arrears_since_combined,
  
  gblrc.date_of_first_loan_offer,
  
  lp.state payback_state,
  lp.auto_in_arrears_since, lp.in_arrears_since in_arrears_since_man,
  
  lp.payout_date,
  lp.payback_day,
  lppi_first.first_payback_date,
  
  gblrc.rating, 
  gblrc.rating_mapped,
  left(gblrc.rating_mapped,1) as gblrc_rating_mapped_base,
  
  ranking.rating as ranking_rating, 
  ranking.pd_start as ranking_pd_start, 
  ranking.pd_end as ranking_pd_end,
  ranking.targeted_yield,
  pp.interval_payment
  
  from base.loan l 
  join il.global_borrower_loan_requests_cohort gblrc 
    on (l.dwh_country_id=gblrc.dwh_country_id and l.loan_nr=gblrc.loan_request_nr)
  left join backend.ranking ranking on 
    l.dwh_country_id=ranking.dwh_country_id and 
	l.fk_ranking=ranking.id_ranking
  join base.loan_payback lp on 
	  l.dwh_country_id=lp.dwh_country_id and 
	  l.id_loan=lp.fk_loan
  join base.loan_payment_plan pp on 
	l.dwh_country_id=pp.dwh_country_id and 
	l.id_loan=pp.fk_loan
  join (
		select dwh_country_id, fk_loan, min(interval_payback_date) as first_payback_date
		from base.loan_payment_plan_item 
		group by dwh_country_id, fk_loan
		) lppi_first
	on 
		l.dwh_country_id=lppi_first.dwh_country_id and 
		l.id_loan=lppi_first.fk_loan
  where 
	l.dwh_country_id=1 and 
	id_loan not in (3,4,6,8,11,14) and 
	l.loan_nr not in  (94479925,182766269,312403183,345557011,379731992,421384595,509393088,546756655,727207610,11204373,142735577,765881911,803090308,895824248,650534649,382135828,556358891)
	and l.state!='canceled'
