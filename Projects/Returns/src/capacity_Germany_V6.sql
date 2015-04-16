SELECT 
	c.id_loan_request
	,c.total_net_income
	,CASE WHEN c.cost_of_living_flat > c.cost_of_living_relative * c.total_net_income THEN c.cost_of_living_flat ELSE c.cost_of_living_relative * c.total_net_income END AS cost_of_living
	,CASE WHEN c.cost_of_accomodation_flat > c.cost_of_accomodation_relative * c.total_net_income THEN c.cost_of_accomodation_flat ELSE c.cost_of_accomodation_relative * c.total_net_income END +
		CASE c.user_expenses_home WHEN 'own' THEN c.mortgage ELSE 0	END AS cost_of_accomodation
	,c.expenses_alimony
	,c.expenses_current_loans
	,c.expenses_leasing
FROM 
(
	SELECT
		gblrc.*
		,CASE WHEN gblrc.event_date <= '2014-08-06' THEN CASE
			WHEN gblrc.income_employment_status IN ('house_wife_husband', 'student', 'without_employment', 'retired') 
				THEN COALESCE((ua.attributes -> 'user_income_net_income_if_any')::real, 0) / 100.0
			WHEN gblrc.income_employment_status IN ('manual_worker', 'public_official', 'salaried', 'soldier') 
				THEN COALESCE((ua.attributes -> 'user_income_net_income')::real, 0) / 100.0 
					+ COALESCE((ua.attributes -> 'user_income_net_income_other')::real, 0) / 100.0
			WHEN gblrc.income_employment_status IN ('self_employed', 'freelancer')
				THEN COALESCE((ua.attributes -> 'user_income_net_income_from_business')::real, 0) / 100.0 * CASE 
					WHEN COALESCE((ua.attributes -> 'user_income_net_income_from_business')::real, 0) / 100.0< 2084 THEN 0.7
					WHEN COALESCE((ua.attributes -> 'user_income_net_income_from_business')::real, 0) / 100.0 < 4167 THEN 0.65
					WHEN COALESCE((ua.attributes -> 'user_income_net_income_from_business')::real, 0) / 100.0 < 6250 THEN 0.6
					ELSE .55
				END
				+ COALESCE((ua.attributes -> 'user_income_net_income_other')::real, 0) / 100.0
		END 
		ELSE
			COALESCE((ua.attributes -> 'user_income_net_income')::real, 0) / 100.0 + 
			COALESCE((ua.attributes -> 'user_income_child_benefit')::real, 0)  + 
			COALESCE((ua.attributes -> 'user_income_alimony')::real, 0) / 100.0 +
			COALESCE((ua.attributes -> 'user_income_pension')::real, 0) / 100.0 + 
			COALESCE((ua.attributes -> 'user_income_net_income')::real, 0) / 100.0 + 
			COALESCE((ua.attributes -> 'user_income_rent')::real, 0) / 100.0 * 0.70 + 
			COALESCE((ua.attributes -> 'user_income_net_income_other')::real, 0) / 100.0 +
			COALESCE((ua.attributes -> 'user_income_net_income_from_business')::real, 0) / 100.0 * CASE 
					WHEN COALESCE((ua.attributes -> 'user_income_net_income_from_business')::real, 0) / 100.0< 2084 THEN 0.7
					WHEN COALESCE((ua.attributes -> 'user_income_net_income_from_business')::real, 0) / 100.0 < 4167 THEN 0.65
					WHEN COALESCE((ua.attributes -> 'user_income_net_income_from_business')::real, 0) / 100.0 < 6250 THEN 0.6
					ELSE .55
				END -
			COALESCE((ua.attributes -> 'user_expenses_health_insurance')::real, 0) / 100.0 
		END AS total_net_income
		,CASE 
			WHEN gblrc.marital_status IN ('single', 'separated', 'divorced', 'widowed') THEN 503
			ELSE 794
		END + COALESCE(gblrc.user_expenses_children::integer, 0) * 212
		AS cost_of_living_flat
		,0.3 AS cost_of_living_relative
		,CASE gblrc.user_expenses_home
			WHEN 'own' THEN 212
			WHEN 'rent' THEN 
				CASE WHEN 265 > COALESCE((ua.attributes -> 'user_expenses_monthly_rent')::real, 0) / 100.0 
					THEN 265 
					ELSE COALESCE((ua.attributes -> 'user_expenses_monthly_rent')::real, 0) / 100.0 
				END
			WHEN 'living_with_parents' THEN 
				CASE WHEN 53 > COALESCE((ua.attributes -> 'user_expenses_monthly_rent')::real, 0) / 100.0 
					THEN 53 
					ELSE COALESCE((ua.attributes -> 'user_expenses_monthly_rent')::real, 0) / 100.0 
				END
		END	AS cost_of_accomodation_flat
		,CASE gblrc.user_expenses_home
			WHEN 'own' THEN 0.1
			WHEN 'rent' THEN  0.2
			WHEN 'living_with_parents' THEN 0.05
		END	AS cost_of_accomodation_relative
		,COALESCE((ua.attributes -> 'user_expenses_monthly_mortgage')::real, 0) / 100.0 AS mortgage
		,COALESCE((ua.attributes -> 'user_expenses_monthly_rent')::real, 0) / 100.0 AS rent
		,COALESCE((ua.attributes -> 'user_expenses_alimony')::real, 0) / 100.0 AS expenses_alimony
		,COALESCE((ua.attributes -> 'user_expenses_current_loans')::real, 0) / 100.0 AS expenses_current_loans
		,COALESCE((ua.attributes -> 'user_expenses_leasing')::real, 0) / 100.0 AS expenses_leasing		
	FROM il.global_borrower_loan_requests_cohort gblrc
	LEFT JOIN il.user_attribute_etl_global ua
	ON gblrc.id_user = ua.fk_user
	WHERE 
		gblrc.country = 'Germany'
		AND ua.country_id = 1
		AND gblrc.user_type <> 'test_user'
		AND gblrc.id_user <> 59048
		
) c
