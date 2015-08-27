#include "loan.h"

void Loan::print_header(std::ostream& os) {
	os << "loan.id" << "\t";
	os << "loan.state" << "\t";
	os << "loan.bid_amount" << "\t";
	os << "loan.amount" << "\t";
	os << "loan.duration" << "\t";
	os << "loan.start" << "\t";
	os << "loan.end" << "\t";
	os << "loan.nominal_rate" << "\t";
	os << "loan.pd" << "\n";
}

std::ostream& operator<<(std::ostream& os, const Loan& loan){
	os << loan.id_ << "\t";
	os << loan.state_ << "\t";
	os << loan.bid_amount_ << "\t";
	os << loan.amount_ << "\t";
	os << loan.duration_ << "\t";
	os << loan.start_ << "\t";
	os << loan.end_ << "\t";
	os << loan.nominal_rate_ << "\t"; 
	os << loan.pd_ << "\n";

	return os;
}