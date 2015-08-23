// ConsoleTest.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
extern "C" __declspec(dllimport)  int  simulate(int n_paths, int days_to_invest, int max_investment_per_loan, int seed,
	int n_loan_categories, double * loan_category_table,
	int n_periods, double * period_table, double * payments
	);


int _tmain(int argc, _TCHAR* argv[])
{
	int n_paths = 10;
	int days_to_invest = 15;
	int max_investment_per_loan = 10;
	int seed = 10;
	int n_loan_categories = 10;
	double loan_category_table[10] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, };
	int n_periods = 5;
	double period_table[10] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, };
	double payments[10] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, };
	int a= simulate(n_paths, days_to_invest, max_investment_per_loan, seed,
		n_loan_categories, loan_category_table,
		n_periods, period_table, payments);
	return 0;
}

