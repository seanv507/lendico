enum PeriodColumns{ k_period_id, k_month, k_fresh_money, k_reinvest, n_period_columns };

class Period{
public:
	int id_;
	int month_;
	double fresh_money_;
	bool reinvest_;

	Period():id_(-1){};

	Period(int id, int month, double fresh_money, bool reinvest) :id_(id), month_(month), fresh_money_(fresh_money), reinvest_(reinvest){}
};