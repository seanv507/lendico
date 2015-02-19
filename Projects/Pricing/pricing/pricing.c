#include <math.h>
#include <malloc.h>


int __stdcall calcSurvival(double *survival_rates, double * default_rates, int duration, double pd_year);
double __stdcall polyval(double * coefficients, int n_coefficients, double x, int min_order);
int __stdcall calcPayments(double * payments, double * survival_rates, double * default_rates, 
	int ir_bp, int duration, int amount, int * rr_thresholds, double * recovery_rates, int n_recovery_rates);
	
	
	
/**
 Calculate survival and default rates for each month of loan given yearly probability of default
 @param survival_rates output array of dimension duration, index 0=1st month
 @param default_rates output array of dimension duration, index 0=1st month 
 @param duration loan duration in months
 @param pd_year probability of default in 1 year
*/ 
int __stdcall calcSurvival(double *survival_rates,double *default_rates, int duration, double pd_year){
	double tau = 1/12.0;
	double periodSurvivalRate=pow(1-pd_year,tau); 
	double periodDefaultRate=1-periodSurvivalRate;
	double prev_survival=1;
	int i_d;
	for (i_d =0; i_d < duration; i_d++ ){
		default_rates[i_d]=prev_survival * periodDefaultRate;
		survival_rates[i_d]=prev_survival * periodSurvivalRate;
		prev_survival=survival_rates[i_d];
	}
	// survival_rate = (1 - PD_mid) .^ ((d:-1:1) / 12.0);
	//default_rate = (1 - PD_mid) .^ (((d - 1):-1:0) / 12.0) .* (1 - (1 - PD_mid) .^ (1 / 12.0));
	return 0;
}


/**
 evaluates polynomial using Hoerner's method
 @param coefficients  array of \f$x^(i+min_order)\f$, lowest order first
 @param n_coefficients length of array (order-min_order+1)
 @param x value to evaluate polynomial at
 @param min_order 
*/
double __stdcall polyval(double * coefficients, int n_coefficients, double x, int min_order){
	double value=coefficients[n_coefficients-1];
	int i_coefficient, i_order;
	for(i_coefficient = n_coefficients-2; i_coefficient>=0; i_coefficient--){
		value=x*value + coefficients[i_coefficient];
	}
	for (i_order = 0; i_order < min_order; i_order++){
		value*= x;
	}

	return value;
}


/**
 @param payments output array of dimension duration+1
 @param survival_rates input array of dimension duration
 @param default_rates input array of dimension duration 
 @param duration loan duration in months
 
 @param amount notional amount to find appropriate recovery rate
 @param rr_thresholds pay recovery_rates[i_d] if remaining notional<= rr_thresholds[i] 
 @param recovery_rates pay recovery_rates[i_d] if remaining notional<= rr_thresholds[i] 
*/ 

int __stdcall calcPayments(double * payments, double * survival_rates, double * default_rates, int ir_bp, int duration, int amount, int * rr_thresholds, double * recovery_rates, int n_recovery_rates){
	double tau = 1/12.0;
	double period_ir = ir_bp *tau/10000.0;
	double q = 1 + period_ir;
	double q_d = pow( q, duration); // growth until end of loan
	double installment = q_d * period_ir / (q_d - 1);
	double remaining_principal;
	double q_i=1;
	double recovery_rate;
	int i_d, i_rr_threshold, rr_threshold;

	for (i_d = 0 ; i_d < duration; i_d++ ){
		remaining_principal = (q_d - q_i ) / (q_d - 1);
		q_i *= q;
		
		for (i_rr_threshold =0; i_rr_threshold<n_recovery_rates; i_rr_threshold++){
			recovery_rate=recovery_rates[i_rr_threshold];
			rr_threshold = rr_thresholds[i_rr_threshold];
			if (remaining_principal*amount <= rr_threshold) break;
		}
		payments[i_d]= survival_rates[i_d] * installment + default_rates[i_d] * remaining_principal * recovery_rate;
	}
    //remaining_principal = (q ^ d - q .^ ((d-1):-1:0)) / (q ^ d - 1);
	return 0;
}

enum eResults{ e_duration = 0, e_rating = 1, e_amount = 2, e_base_rate = 3, e_service_fee = 4, e_borrower_fee = 5, e_right = 6, e_left = 7, e_last= 8, n_results_cols };

int __stdcall calcRates(double * results, double * base_rates, double * borrower_fees, double * PD_mids, int n_ratings, int * durations, int n_durations, 
	int * amounts, int n_amounts, int *rr_thresholds, double * recovery_rates, int n_recovery_rates, 
	double service_fee){
	int n_results_rows = n_ratings*n_durations*n_amounts;
	int index, i_col, i, i_duration, i_rating, i_amount;
	int duration, amount;
	int max_duration = durations[0];
	int i_left, i_right, ir;
	double base_rate, pd_year, df, df_check, borrower_fee;
	double ty_left, ty_right;
	int tmp_rr_threshold = 1;
	int use_previous;
	
	for (i = 1; i < n_durations; i++){
		if (durations[i]> max_duration) max_duration = durations[i];
	}
	double * payments = (double *)malloc((max_duration + 1)*sizeof(double));
	double * survival_rates = (double *)malloc((max_duration )*sizeof(double));
	double * default_rates = (double *)malloc((max_duration)*sizeof(double));
	
	for (index=0, i_duration = 0; i_duration < n_durations; i_duration++){
		duration = durations[i_duration];
		for (i = 0; i < max_duration; i++) {
			/* shouldn't be necessary */
			payments[i] = 0;
			survival_rates[i] = 0;
			default_rates[i] = 0;
		}
		payments[i] = 0;

		for (i_rating = 0; i_rating < n_ratings; i_rating++){
			pd_year = PD_mids[i_rating];
			calcSurvival(survival_rates, default_rates, duration, pd_year);
			base_rate = base_rates[n_ratings*i_duration + i_rating];
			borrower_fee = borrower_fees[n_ratings*i_duration + i_rating];
			df = pow(1 + base_rate, -1 / 12.0);

			/* check base rate against min nominal rate 0.01% */
			i_left = 1;      /* 0.0001;*/
			tmp_rr_threshold = 1; /* use single recovery rate, amount =1 */
			calcPayments(payments, survival_rates, default_rates, i_left, duration, 1, &tmp_rr_threshold, recovery_rates, 1);
			if ((1 - service_fee) * polyval(payments, duration, df, 1) >= 1){
				continue;
				/* WHAT TO DO !!!
					disp("base rate too low - 0.01% nominal rate would be sufficient already")
					*/
			}

			/* iterating over amounts */
			for (i_amount = 0; i_amount < n_amounts; i_amount++, index++){


				/* search the appropriate nominal rate by calculating the present value(relative to loan amount) of the expected cash flow */

				/* initalize boundaries of bisection algorithm, calculating with integers for numerical stability */
				
				i_left = 1;      /* 0.0001 */

				/* check the previous amount */
				amount = amounts[i_amount];
				use_previous = 0;
				if (i_amount > 0){
					i_right = results[(index - 1) + e_right*n_results_rows] * 10000;
					/* !!! */

					calcPayments(payments, survival_rates, default_rates, i_right, duration, amount, rr_thresholds, recovery_rates, n_recovery_rates);
					if ((1 - service_fee) * polyval(payments, duration, df, 1) >= 1){
						use_previous = 1;
					}
					else{
						i_left = i_right;
					}
				}

				if (use_previous){
					for (i_col = 0; i_col < n_results_cols; i_col++) results[index + n_results_rows*i_col] = results[index - 1 + n_results_rows*i_col];
					results[index + n_results_rows*e_amount] = amount;
				}
				else{
					
					results[index + n_results_rows*e_duration] = duration;
					results[index + n_results_rows*e_rating] = i_rating;
					results[index + n_results_rows*e_amount] = amount;
					results[index + n_results_rows*e_base_rate] = base_rate;
					results[index + n_results_rows*e_service_fee] = service_fee;
					results[index + n_results_rows*e_borrower_fee] = borrower_fee;
					/* results(index, 1:6) = [d, PD, amounts(amount), base_rate, service_fee, borrower_fee];*/

					i_right = 1700;  /* % 0.1700; */
					calcPayments(payments, survival_rates, default_rates, i_right, duration, amount, rr_thresholds, recovery_rates, n_recovery_rates);
					if ((1 - service_fee) * polyval(payments, duration, df, 1) < 1){
						break; /* % base rate, risk costs and service fee require nominal interest rate above 17 % -stop */
					}

					/* %bisection algorithm */
					while (i_left + 1 < i_right){
						ir = (int)(0.5 * (i_left + i_right));
						calcPayments(payments, survival_rates, default_rates, ir, duration, amount, rr_thresholds, recovery_rates, n_recovery_rates);
						if ((1 - service_fee) * polyval(payments, duration, df, 1) < 1){
							i_left = ir;
						}
						else{
							i_right = ir;
						}

					} /* endwhile */

					results[index + n_results_rows*e_right] = i_right / 10000.0;

					/* % search the targeted yield and expected yield at 50 % discount on service fee */

					/* % calculate expected payments at derived nominal rate */
					calcPayments(payments, survival_rates, default_rates, i_right, duration, amount, rr_thresholds, recovery_rates, n_recovery_rates);


					/* % targeted yield */
					/* % initalize boundaries of bisection algorithm */
					ty_left = base_rate;
					ty_right = i_right / 10000.0;

					/* %bisection algorithm */
					while (round(ty_left * 10000) != round(ty_right * 10000)){
						df_check = pow(1 + 0.5 * (ty_left + ty_right), -1 / 12.0);
						if (polyval(payments, duration, df_check, 1) > 1){
							ty_left = 0.5 * (ty_left + ty_right);
						}
						else{
							ty_right = 0.5 * (ty_left + ty_right);
						}
					} /* endwhile */

					results[index + n_results_rows* e_left] = round(ty_left * 10000) / 10000.0;

					/* % expected yield at 50 % discount on service fee
					% initalize boundaries of bisection algorithm */
					ty_left = base_rate;
					ty_right = i_right / 10000.0;

					/* %bisection algorithm */
					while (round(ty_left * 10000) != round(ty_right * 10000)){
						df_check = pow(1 + 0.5 * (ty_left + ty_right), -1 / 12.0);
						if ((1 - 0.5 * service_fee) * polyval(payments, duration, df_check, 1) > 1){
							ty_left = 0.5 * (ty_left + ty_right);
						}
						else{
							ty_right = 0.5 * (ty_left + ty_right);
						}//endif
					}/* endwhile */

					results[index + n_results_rows* e_last] = round(ty_left * 10000) / 10000.0;

				}/* endif % use_previous */

			}/* endfor % amounts */


		}	/*	endfor % i_rating */

	}	/* endfor % durations */

				/*disp(datestr(now, "yyyy-mm-dd HH-MM-SS"))

				% output
				dlmwrite(["pricing_" datestr(now, "yyyy-mm-dd HH-MM-SS") ".csv"], results(not(isna(results(:, 7))), :), ";", "precision", 5);
				*/
	free(payments);
	free(survival_rates);
	free(default_rates);
	return 0;

}

