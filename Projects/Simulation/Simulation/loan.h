#ifndef LOAN_H
#define LOAN_H

#include <math.h>
#include <iostream>
#include <algorithm>

enum LoanState {kLive, kPaidBack, kDefaulted, kUninit} ;
enum LoanColumns { k_loan_id ,k_sme, k_lendico_class, k_duration , k_amount,  k_lendico_class_base, k_pd,
	k_lgd_amount1, k_lgd_amount2, k_lgd_amount3, k_lgd_value1, k_lgd_value2, k_lgd_value3,
	k_nominal_rate, k_lender_fee, k_probability, k_counts, n_LoanColumns };
// TODO sme /base class/ LGD/ output portfolio
const int kPeriod = 30;
const int kDaysInYear = 360;
const double kTau = kPeriod / float(kDaysInYear);
const int kNAmounts = 3;

class LGD{
	
	double amounts_[kNAmounts];
	double losses_[kNAmounts];
public:
	LGD(){
		amounts_[0] = 5000;
		amounts_[1] = 100000;
		amounts_[2] = 200000;
		losses_[0] = 0.62;
		losses_[1] = 0.83;
		losses_[2] = 1;
	};
	LGD(double * amounts_losses){
		for (int i = 0; i < kNAmounts; i++){
			amounts_[i]=amounts_losses[i];
			losses_[i] = amounts_losses[i + kNAmounts];
		}
	}
	LGD(double amount1, double amount2, double amount3, double value1, double value2, double value3) {
		
		amounts_[0] = amount1;
		amounts_[1] = amount2;
		amounts_[2] = amount3;
		losses_[0] = value1;
		losses_[1] = value2;
		losses_[2] = value3;
	}

	double calc_loss(double amount){
		/* <=5000 X, <=10000 Y ...*/
		for (int i = 0; i < kNAmounts; i++){
			if (amounts_[i] > amount) return losses_[i];
		}
		return -1; // error!
	}

};

class Loan{
public:
	int id_;
	bool is_sme_;
	double bid_amount_;
	double amount_;
	int duration_;
	double pd_;
	double pd_monthly_;
	LGD  lgd_;
	double nominal_rate_; 
	double q_;
	double installment_; //!< for unit amount (ie ignores amount and bid_amount)
	double lender_fee_;
	int start_;
	int end_;
	LoanState state_;
	Loan() :state_(kUninit){};

	Loan(int id, int is_sme, double bid_amount, double amount, int duration, double pd, const LGD& lgd, double nominal_rate, double lender_fee) :
		id_(id), is_sme_(is_sme), bid_amount_(bid_amount), amount_(amount), duration_(duration), pd_(pd), lgd_(lgd), nominal_rate_(nominal_rate), lender_fee_(lender_fee), start_(-1), end_(-1), state_(kUninit) {
		pd_monthly_ = 1-pow(1 - pd_, kTau);
		q_ = (1 + nominal_rate_ * kTau);
		installment_ = (q_ - 1) * pow(q_, duration_) / (pow(q_, duration) - 1);
	}

	void set_state(LoanState state, int time=-1){
		state_ = state;
		switch (state){
		case kLive:
			start_ = time;
			end_ = start_ + 1 + duration_;
			break;

		case kDefaulted:
			end_ = time;
			break;
		case kPaidBack:
			end_ = time;
			break;
		}

	}
	
	double frac_remaining_borrower(int time){
		// frac remaining to be paid at beginning of period 2
		if (state_ != kLive) { return 0; 
		}
		else{
			// start=0, vorlaufzins =1, and full inst =2
			int full_installments_paid = std::max(time - 2 - start_ ,0);
			return (pow(q_, duration_) - pow(q_, full_installments_paid)) / (pow(q_, duration_) - 1);
		}
	}

	double recover(int time){
		double frac = frac_remaining_borrower( time);
		return (1 - lgd_.calc_loss(amount_ * frac))* frac * bid_amount_;
	}

	static void print_header(std::ostream&);
};

std::ostream& operator<<(std::ostream& os, const Loan& loan);
#endif