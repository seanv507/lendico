# -*- coding: utf-8 -*-
"""
Created on Thu Jun 18 12:34:09 2015

@author: Sean Violante
"""
import pandas as pd

def lose_guaranteed_offer(table, lf):
    table = drop_merge(table, lf,
                       keys=['dwh_country_id', 'fk_loan', 'fk_user_investor'],
                       fields=['state'], how='left')
    table = table[table['state'] == 'funded'].\
            drop('state', axis=1, inplace=False, errors='ignore')
    return table


#EOM_dates=pd.date_range('2014-04-01', '2015-06-30', freq='M')
#EOM_dates=pd.date_range('2015-01-01', '2015-08-30', freq='M')
EOM_dates=pd.date_range('2015-07-01', '2015-08-31', freq='M')

minimum_vintage=pd.tseries.offsets.MonthEnd(3)
pd.DataFrame({'d':EOM_dates,'e':EOM_dates -minimum_vintage})

reporting_dates=EOM_dates

excluded_loans_de = [3,4,6,8]

excluded_loans = {1: excluded_loans_de,
                  32: [],
                  128:[]}

# certain loans are excluded from de_payments.
# therefore we also need to exclude them from loan funding

# to enable comparison we also exclude them from payment plans
# ( ie in calculating planned IRR)

defaulted_but_lendico_paid_back_de = [27, 76] # we assume weren't repaid
defaulted_but_lendico_paid_back = {1:defaulted_but_lendico_paid_back_de,
                                   32:[],
                                   128:[]}

loans_base = filter_loans(loans, excluded_loans)
# exclude guaranteed offer
loan_fundings_base = filter_loans(loan_fundings[loan_fundings.state=='funded'],
                                   excluded_loans)

# [these aren't amongst repaid, but would be fine because problem is bad record of actual payments for these loans]

repaid_loans = filter_loans(
    loans_base.loc[loans_base.payback_state == 'payback_complete',
                   ['dwh_country_id', 'fk_loan']],
    defaulted_but_lendico_paid_back)

repaid_loans_gp =repaid_loans.groupby('dwh_country_id')
# groups just returns indices, whilst we want the values
repaid_loans_gp = {name: group.fk_loan for name, group in repaid_loans_gp}


actual_payments_monthly_base = actual_payments

act_pay_monthly_base = filter_loans( actual_payments_combined,
                                    repaid_loans_gp)
act_pay_monthly_base = lose_guaranteed_offer(act_pay_monthly_base,
                                             loan_fundings_base)

act_pay_date_base = filter_loans(actual_payments_combined_date,
                                 repaid_loans_gp)

act_pay_date_base = lose_guaranteed_offer(act_pay_date_base,
                                          loan_fundings_base)
plan_repaid_base = select_loans( payment_plans_combined, repaid_loans_gp)
plan_repaid_base = lose_guaranteed_offer(plan_repaid_base, loan_fundings_base)
# problem with combined payment plan so exclude all "closed" loans cut off at payback complete date

plan_pay_base_all = filter_loans( payment_plans_combined,
                                 excluded_loans)
plan_pay_base_all = lose_guaranteed_offer(plan_pay_base_all, loan_fundings_base)
plan_pay_base = filter_loans(plan_pay_base_all,
                             repaid_loans_gp)
plan_pay_base = lose_guaranteed_offer(plan_pay_base, loan_fundings_base)
cash_keys=['dwh_country_id', 'fk_loan', 'fk_user_investor', 'payout_date']

selected_reporting_dates=reporting_dates
# need it in adding key in concatenating reports

# enrich data
loan_keys = ['dwh_country_id', 'fk_loan']
# originated quarter
loan_fields = ['payout_quarter', 'rating_base',
               'gblrc_rating_mapped', 'gblrc_rating_mapped_base',
               'payback_state', 'eur_principal_amount']

splits = ['dwh_country_id',
          ('dwh_country_id','payout_quarter'),
          ('dwh_country_id','rating_base'),
          ('dwh_country_id','gblrc_rating_mapped_base'),
          ('dwh_country_id','fk_loan'),
          ('dwh_country_id','payout_quarter','rating_base')]

# although we don't need to filter out loans <month old we do so to match actual return

xirrs_overall_list = []

xirrs_all_list = {}
xirrs_all = {}

xirrs_overall_seed_list = []
xirrs_seed_all_list = {}
xirrs_seed_all = {}



for split in (splits):
    xirrs_all_list[split]=[]
    xirrs_seed_all_list[split]=[]

for EOM_date in selected_reporting_dates:
    max_payout_date = (EOM_date - minimum_vintage).date()

    act_pay_monthly_filter = (act_pay_monthly_base.iso_date <= EOM_date.date()) & \
                 (act_pay_monthly_base.payout_date <= max_payout_date)
    act_pay_date_filter = (act_pay_date_base.iso_date <= EOM_date.date()) & \
                 (act_pay_date_base.payout_date <= max_payout_date)

    act_pay_monthly_EOM_filter = \
        act_pay_monthly_filter & \
        (act_pay_monthly_base.iso_date == EOM_date.date())

    plan_filter = (plan_pay_base.payout_date <= max_payout_date)
    plan_repaid_filtered = \
        plan_repaid_base[plan_repaid_base.payout_date<= max_payout_date]
    loans_filtered = \
        loans_base[loans_base.payout_date <= max_payout_date]
    loan_fundings_filtered = \
        loan_fundings_base[loan_fundings_base.payout_date <= max_payout_date]
    nars=calc_NAR(act_pay_monthly_base, plan_repaid_filtered, act_pay_monthly_filter,
                  act_pay_monthly_EOM_filter, EOM_date,
             actual_payments_monthly_base, cash_keys)


    nars = drop_merge(nars.reset_index(), loans_base, loan_keys, loan_fields)
    nars.set_index(loan_keys, inplace=True)

    cash_lists=calc_IRR(loans_base,
         loan_fundings_filtered,
         act_pay_monthly_base, act_pay_date_base,
         plan_repaid_filtered,
         plan_pay_base,
         act_pay_monthly_filter, act_pay_monthly_EOM_filter,
         act_pay_date_filter,
         plan_filter,
         EOM_date, cash_keys)

    cash_lists = {key:
                  [drop_merge(cash, loans_base, loan_keys, loan_fields) for
                        cash in cash_list]
                  for (key, cash_list) in cash_lists.iteritems()}

    xirrs_overall, xirrs =  \
        calc_IRR_groups(EOM_date, splits, cash_lists, actual_payments_monthly_base)

    xirrs_overall_list.append(xirrs_overall)
# TODO consider enriching as subsequent step
    cols=[c for c in nars.columns if c not in \
          ['in_arrears_since','in_arrears_since_days',
           'in_arrears_since_days_30360',
           'bucket', u'bucket_pd']]

    xirrs[('dwh_country_id', 'fk_loan')] = \
        xirrs[('dwh_country_id', 'fk_loan')].join(nars[cols],how='outer')

    for split in splits :
        loan_data=loans_filtered.groupby(split)['eur_principal_amount'].\
            agg({'n_loans':'count', 'volume':'sum'})
        xirrs[split]['n_loans'] = loan_data['n_loans']
        xirrs[split]['volume_10K'] = loan_data['volume']/10000.0

        xirrs_all_list[split].append(xirrs[split])

#    seed=42
#    #np.random.seed(seed)
#    n_runs=50
#    for run in range(n_runs):
#        cash_lists=calc_IRR_stdev(loans_base,
#                                  loan_fundings_filtered,
#                                  act_pay_monthly_base, act_pay_date_base,
#                                  plan_repaid_filtered,
#                                  plan_pay_base,
#                                  act_pay_monthly_filter, 
#                                  act_pay_monthly_EOM_filter,
#                                  act_pay_date_filter,
#                                  plan_filter,
#                                  EOM_date, cash_keys)
#
#        cash_lists = {key:
#                  [drop_merge(cash, loans_base, loan_keys, loan_fields) for
#                        cash in cash_list]
#                  for (key, cash_list) in cash_lists.iteritems()}
#
#        xirrs_overall_seed, xirrs_seed =  \
#            calc_IRR_groups(EOM_date, splits, cash_lists, 
#                            actual_payments_monthly_base)
#        xirrs_overall_seed['run']=run
#        xirrs_overall_seed_list.append(xirrs_overall_seed)
#
#        for split in splits :
#            xirrs_seed[split]['run']=run
#            xirrs_seed[split].set_index('run', append=True)
#            xirrs_seed_all_list[split].append(xirrs_seed[split])
#dup_selected_reporting_dates = [d for d in selected_reporting_dates for i in range(n_runs)]
#xirrs_overall_seed=pd.DataFrame.from_records(data=xirrs_overall_seed_list, \
#                                        index=dup_selected_reporting_dates)
#for split in splits :    
#    xirrs_seed_all[split] = pd.concat( xirrs_seed_all_list[split], 
#                                      keys=zip(dup_selected_reporting_dates, 
#                                               range(n_runs)*
#                                               len(selected_reporting_dates)),
#                                     names=['reporting_date','run'])


xirrs_overall=pd.DataFrame.from_records(data=xirrs_overall_list, \
                                        index=selected_reporting_dates)


for split in splits :
    xirrs_all[split] = pd.concat( xirrs_all_list[split], keys=selected_reporting_dates)
