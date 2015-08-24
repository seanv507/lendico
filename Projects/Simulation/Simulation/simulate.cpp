#define _CRTDBG_MAP_ALLOC
#include <stdlib.h>
#include <crtdbg.h>

#include <new>
#include <vector>
#include <math.h>
#include <random>
#include <algorithm>
#include "loan.h"
#include "investment.h"

const double kLiquidityReserve = 25;

typedef std::vector<Loan> LoanList;

/* __stdcall is ignored for 64 bits 
https://msdn.microsoft.com/en-us/library/zxk0tw93(v=vs.140).aspx
*/

extern "C"  __declspec(dllexport) int __stdcall times(int x, double y){
	return x*y;
}


extern "C" __declspec(dllexport) int square(int ny, double * y){
	for (int i = 0; i < ny; i++){
		y[i] *= y[i];
	}
	return 0;
}



extern "C" __declspec(dllexport)  int  simulate( int n_paths, int days_to_invest, int max_investment_per_loan, int seed,
		int n_loan_categories, double * loan_category_table,
		int n_periods, double * period_table, double * payments, double * epsilon){
	// init loan categories
	Loan * loan_categories = new Loan[n_loan_categories];
	int * loan_category_counts = new int[n_loan_categories];
	int * loan_category_counts_state = new int[n_loan_categories];
	
	double * loan_max_probability = new double[n_loan_categories]; // for selecting loans uniformly at random
	for (int i = 0; i < n_loan_categories; i++){
		loan_categories[i] = Loan(loan_category_table[i + n_loan_categories * k_loan_id], loan_category_table[i + n_loan_categories * k_sme] , -1, loan_category_table[i + n_loan_categories * k_amount], loan_category_table[i + n_loan_categories *k_duration],
			loan_category_table[i + n_loan_categories *k_pd], loan_category_table[i + n_loan_categories *k_nominal_rate], loan_category_table[i + n_loan_categories *k_lender_fee]);
		loan_category_counts[i] = loan_category_table[i + n_loan_categories * k_counts];

		loan_max_probability[i] = loan_category_counts[i];
		if (i > 0){
			loan_max_probability[i] += loan_max_probability[i-1];
		}
	}

	for (int i = 0; i < n_loan_categories; i++) loan_max_probability[i] /= double(loan_max_probability[n_loan_categories - 1]);


	// init periods
	Period * periods = new Period[n_periods];
	for (int i = 0; i < n_periods; i++){
		periods[i] = Period(period_table[i + n_periods * k_period_id], period_table[i + n_periods * k_month], period_table[i + n_periods * k_fresh_money], period_table[i + n_periods * k_reinvest]);
	}

	double money_to_invest;
	double loan_paybacks;
	double loan_payback;
	
	std::default_random_engine generator;
	std::uniform_real_distribution<double> distribution(0.0, 1.0);
	std::uniform_int_distribution<int> uniform_categories_distribution(0, n_loan_categories-1);


	
	for (int i_path = 0; i_path < n_paths; i_path++){
		LoanList loans;
		for (int i_period = 0; i_period < n_periods; i_period++){
			loan_paybacks = 0;
			for (int i_loan = 0; i_loan < loans.size(); i_loan++){
				Loan * l = &loans[i_loan];
				if (l->state_ == kLive){
					double urand=distribution(generator);
					if (urand < l->pd_monthly_) {
						l->set_state(kDefaulted, i_period);
						loan_payback = l->recover(i_period);
					}
					else{
						if (l->start_ == i_period - 1){
							// vorlaufzinsen
							loan_payback = l->bid_amount_ * l->nominal_rate_ / 12.0 * (30 - days_to_invest) / 30.0;
						}
						else{
							// full installment
							loan_payback = l->bid_amount_ * l->installment_;
							if (i_period - l->start_ - 1 == l->duration_){
								// index ??
								l->state_ = kPaidBack;
							}
						}
					}
					loan_paybacks += loan_payback * (1 - l->lender_fee_);
				}
			}
			// calculate money to invest
			// calculate payments
			Period * p = &periods[i_period];
			
			
			if (!p->reinvest_){
				money_to_invest = p->fresh_money_;
				payments[i_path + n_paths * i_period] = -p->fresh_money_ + loan_paybacks;
			}
			else{
				money_to_invest = p->fresh_money_ + loan_paybacks;
				payments[i_path + n_paths * i_period] = -p->fresh_money_;
			}

			// select loans
			for (int i_loan_category = 0; i_loan_category < n_loan_categories; i_loan_category++){
				loan_category_counts_state[i_loan_category] = loan_category_counts[i_loan_category];
			}
			while (money_to_invest >= kLiquidityReserve){

				double urand = distribution(generator);
				// int i_loan_category = std::upper_bound(&loan_max_probability[0], &loan_max_probability[n_loan_categories], urand) - &loan_max_probability[0];

				int i_loan_category = uniform_categories_distribution(generator);
				Loan * l = &loan_categories[i_loan_category];
				int amount = loan_category_min_amount[i_loan_category] + ceil((loan_category_max_amount[i_loan_category] - loan_category_min_amount[i_loan_category])*urand / 100.0) * 100;
				int bid_amount = std::min(amount, max_investment_per_loan);
				if (bid_amount > money_to_invest){
					bid_amount = ceil(money_to_invest / kLiquidityReserve)*kLiquidityReserve;
					// !! should we use liquididty reserve or something else?
				}
				money_to_invest -= bid_amount;
				Loan loan(i_loan_category, bid_amount, amount, l->duration_, l->pd_, l->nominal_rate_, l->lender_fee_);
				loan.set_state(kLive, i_period);
				loans.insert(loans.end(), loan);





			}
			

		}
	}

	delete[] periods;
	delete[] loan_categories;
	delete[] loan_category_counts;
	delete[] loan_category_counts_state;
	delete[] loan_category_min_amount;
	delete[] loan_category_max_amount;

	delete[] loan_max_probability;
	_CrtDumpMemoryLeaks();
	return 0;
}


extern "C" __declspec(dllexport)  int  dummy(int n_paths, int days_to_invest, int max_investment_per_loan, int seed,
	int n_loan_categories, double * loan_category_table,
	int n_periods, double * period_table, double * payments
	){
	for (int i = 0; i < 10; i++){
		payments[i] = period_table[i] + loan_category_table[i];
	}
	
	return 0;
}
