# -*- coding: utf-8 -*-
"""
Created on Thu Jun 18 12:34:09 2015

@author: Sean Violante
"""
import pandas as pd

EOM_dates=pd.date_range('2015-05-01', '2015-05-31', freq='M')
minimum_vintage=pd.tseries.offsets.MonthEnd(3)
pd.DataFrame({'d':EOM_dates,'e':EOM_dates -minimum_vintage})

reporting_dates=EOM_dates
dwh_country_id = 1
filtered_de_payments=[3,4,6,8] # they are filtered out of de_payments query. 
defaulted_but_lendico_paid_back=[27,76] # we assume weren't repaid

loans_cnt = loans[(loans.dwh_country_id == dwh_country_id)]
loan_fundings_cnt = loan_fundings[
                        (loan_fundings.dwh_country_id == dwh_country_id)]
# [these aren't amongst repaid, but would be fine because problem is bad record of actual payments for these loans]

repaid_loans_cnt = loans_cnt.fk_loan[ 
                             (loans_cnt.payback_state == 'payback_complete') & 
                             ~(loans_cnt.fk_loan.isin(defaulted_but_lendico_paid_back))]

actual_payments_monthly_cnt = \
    actual_payments[ actual_payments.dwh_country_id==dwh_country_id]
                             
act_pay_monthly_cnt = \
    actual_payments_combined[(actual_payments_combined.dwh_country_id == \
                              dwh_country_id) & 
                              ~actual_payments_combined.fk_loan.isin(repaid_loans_cnt)]

act_pay_date_cnt = \
    actual_payments_combined_date[
        (actual_payments_combined_date.dwh_country_id == dwh_country_id) & 
        ~actual_payments_combined_date.fk_loan.isin(repaid_loans_cnt)]


plan_repaid_cnt = \
    payment_plans_combined[(payment_plans_combined.dwh_country_id == \
                              dwh_country_id) &
                           payment_plans_combined.fk_loan.isin(repaid_loans_cnt)]
# problem with combined payment plan so exclude all "closed" loans cut off at payback complete date
                              
plan_pay_cnt = \
    payment_plans_combined[(payment_plans_combined.dwh_country_id==dwh_country_id) & 
        ~(payment_plans_combined.fk_loan.isin(filtered_de_payments + 
                                        repaid_loans_cnt.values.tolist()))]                                                             

cash_keys=['dwh_country_id', 'fk_loan', 'fk_user_investor', 'payout_date']

selected_reporting_dates=reporting_dates
# need it in adding key in concatenating reports

splits = [('payout_quarter'), ('rating_base'), 
              ('dwh_country_id','fk_loan'), ('payout_quarter','rating_base')]

# although we don't need to filter out loans <month old we do so to match actual return

xirrs_overall_list = []
xirrs_all_list = {}
xirrs_all = {}


for split in (splits):
    xirrs_all_list[split]=[]
        
for EOM_date in selected_reporting_dates:
    max_payout_date = (EOM_date - minimum_vintage).date()
    
    act_pay_monthly_filter = (act_pay_monthly_cnt.iso_date <= EOM_date.date()) & \
                 (act_pay_monthly_cnt.payout_date <= max_payout_date)
    act_pay_date_filter = (act_pay_date_cnt.iso_date <= EOM_date.date()) & \
                 (act_pay_date_cnt.payout_date <= max_payout_date)
                 
    act_pay_monthly_EOM_filter = \
        act_pay_monthly_filter & \
        (act_pay_monthly_cnt.iso_date == EOM_date.date())
        
    plan_filter = (plan_pay_cnt.payout_date <= max_payout_date)
    
    nars=calc_NAR(act_pay_monthly_cnt, plan_repaid_cnt, act_pay_monthly_filter,
                  act_pay_monthly_EOM_filter, 
             max_payout_date, EOM_date,
             actual_payments_monthly_cnt, cash_keys)
    # enrich data    
    loan_keys = ['dwh_country_id', 'fk_loan']
    # originated quarter
    loan_fields = ['payout_quarter', 'rating_base', 
                   'payback_state', 'eur_principal_amount']
             
    nars = drop_merge(nars.reset_index(), loans_cnt, loan_keys, loan_fields)
    nars.set_index(loan_keys, inplace=True)

    cash_lists=calc_IRR(loans_cnt, loan_fundings_cnt,
             act_pay_monthly_cnt, act_pay_date_cnt,
             plan_repaid_cnt, plan_pay_cnt,
             act_pay_monthly_filter, act_pay_monthly_EOM_filter,
             act_pay_date_filter,
             plan_filter,
             max_payout_date, EOM_date, cash_keys, filtered_de_payments,
             arrears_dict)

    cash_lists = {key: 
                  [drop_merge(cash, loans_cnt, loan_keys, loan_fields) for
                        cash in cash_list] 
                  for (key, cash_list) in cash_lists.iteritems()}         

    xirrs_overall, xirrs =  \
        calc_IRR_groups(EOM_date, splits, cash_lists, actual_payments_monthly_cnt)
        
    xirrs_overall_list.append(xirrs_overall)

    cols=[c for c in nars.columns if c not in \
          ['in_arrears_since','in_arrears_since_days', 
           'in_arrears_since_days_30360',  
           'bucket', u'bucket_pd',  u'payback_state']]
    
    xirrs[('dwh_country_id', 'fk_loan')] = \
        xirrs[('dwh_country_id', 'fk_loan')].join(nars[cols],how='outer')
    
    for split in splits :
        xirrs_all_list[split].append(xirrs[split])

xirrs_overall=pd.DataFrame.from_records(data=xirrs_overall_list, \
                                        index=selected_reporting_dates)    
for split in splits :
    xirrs_all[split] = pd.concat( xirrs_all_list[split], keys=selected_reporting_dates)

