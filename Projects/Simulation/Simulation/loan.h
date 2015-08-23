#ifndef LOAN_H
#define LOAN_H

#include <math.h>

enum LoanState {kLive, kPaidBack, kDefaulted, kUninit} ;
enum LoanColumns { k_loan_id , k_duration , k_min_amount , k_max_amount, k_lendico_class, k_pd, k_nominal_rate, k_lender_fee, k_probability, k_counts, n_LoanColumns };
// TODO 
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

	Loan(int id, double bid_amount, double amount, int duration, double pd, double nominal_rate, double lender_fee) :
		id_(id), bid_amount_(bid_amount), amount_(amount), duration_(duration), pd_(pd), nominal_rate_(nominal_rate), lender_fee_(lender_fee), start_(-1), end_(-1), state_(kUninit) {
		pd_monthly_ = 1-pow(1 - pd_, kTau);
		q_ = (1 + nominal_rate_ * kTau);
		installment_ = (q_ - 1) * pow(q_, duration_) / (pow(q_, duration) - 1);
	}
	operator <<

	void set_state(LoanState state, int time=-1){
		state_ = state;
		switch (state){
		case kLive:
			start_ = time;
			end_ = start_ + duration_;
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
		if (state_ != kLive) { return 0; 
		}
		else{
			return (pow(q_, duration_) - pow(q_, time - start_)) / (pow(q_, duration_) - 1);
		}
	}

	double recover(int time){
		double frac = frac_remaining_borrower( time);
		return (1 - lgd_.calc_loss(amount_ * frac))* bid_amount_;
	}
};


#endif