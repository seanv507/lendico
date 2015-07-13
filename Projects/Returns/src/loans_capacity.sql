select  
  l.*, 
  gblrc.user_campaign, 
  gblrc.credit_agency_score, 
  gblrc.pd, 
  gblrc.pd_original, 
  gblrc.lgd, 
  
  gblrc.in_arrears_since, 
  gblrc.auto_in_arrears_since auto_in_arrears_since_g, 
  gblrc.in_arrears_since_combined,
  
  gblrc.date_of_first_loan_offer,
  
  lp.auto_in_arrears_since, lp.in_arrears_since in_arrears_since_man,
  
  lp.payout_date,
  
  gblrc.rating, 
  gblrc.rating_mapped,
  
  ranking.rating as ranking_rating, 
  ranking.pd_start as ranking_pd_start, 
  ranking.pd_end as ranking_pd_end,
  
  pp.interval_payment,
  
  
  ac.net_income_precheck, 
  ac.net_income, 
  ac.expenses_precheck, 
  ac.expenses, 
  ac.expenses_current_loans, 
  ac.pre_capacity 
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
  join base.user_account ac on 
	l.dwh_country_id=ac.dwh_country_id and 
	l.fk_user=ac.id_user
  where 
	l.dwh_country_id=1 and 
	id_loan not in (3,4,6,8,11,14) and 
	l.loan_nr not in  (94479925,182766269,312403183,345557011,379731992,421384595,509393088,546756655,727207610,11204373,142735577,765881911,803090308,895824248,650534649,382135828,556358891)
	and l.state!='canceled'
