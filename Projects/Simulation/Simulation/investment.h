enum PeriodColumns{ k_period_id, k_month, k_new_loans, k_fresh_money, k_reinvest, n_period_columns };

class Period{
public:
	int id_;
	int month_;
	double new_loans_;
	double fresh_money_;
	bool reinvest_;

	Period():id_(-1){};

	Period(int id, int month, double new_loans, double fresh_money, bool reinvest) :id_(id), month_(month), new_loans_(new_loans), fresh_money_(fresh_money), reinvest_(reinvest){}
};