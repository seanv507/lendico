from __future__ import division
import numpy as np
import pandas as pd
import datetime
import scipy.optimize
import os

# todo actual date
#
def get_src_dir():
    return os.path.dirname(os.path.abspath(__file__))

def get_sql_strings():
    # combined payment plan has null for investor
    # initial/residual principals ( for interval 0)
    # also if no match found for actual payment then
    # combined payment fields will nbe null in actual_payments...
    # excluded_loans =
    # (3,4,6,8,11,14,526,528,558,630,557,556,555,
    #  553,552,554,578,579,580,603,596,611,642)
    src_dir = get_src_dir()
    sql_dict = dict()
    
    sqls = [
            'actual_payments_combined_date',
            'actual_payments_combined1',
            'actual_payments_combined',
            'actual_payments',
            'payment_plans_combined',
            'payment_plans',
            'loan_fundings',
            'loans']
    for sql_name in sqls:
        with open(src_dir + '\\' + sql_name + '.sql') as sqf:
            sql = sqf.read()
            sql_dict[sql_name] = sql

    return sql_dict


def annualise(x):
        return np.power(1 + x, 12) - 1


def recovery(amounts):
    return 0.1425 + (0.2613 - .1425) * (amounts <= 25000) \
        + (0.5814 - 0.2613) * (amounts <= 5000)
    # losses return 0.4186+(0.7387-.4186)*(amounts>5000)+
    #    (0.8575 - 0.7387)*(amounts>25000)


def days360_tup(diff):
    # not actually 30360 as in bond basis.
    # note february -> 30 so longer ( and 31 months get shortened)
    x = None
    try:
        x = (diff[1].year - diff[0].year) * 360 \
            + (diff[1].month - diff[0].month) * 30 \
            + min((diff[1].day-diff[0].day), 30)
    except AttributeError:
        pass
    return x


def days360(start, end):
    diffs = zip(start, end)
    return map(days360_tup, diffs)


def xnpv(rs, amount_dcf_or_list, dcfs=None):
    """ should work for scalars and vectors
    and DataFrame or list of DataFrames.
    amount_dcf: dataframe,list of dataframes
    taus: is the day count fraction as of the valuation date (tau=0)
    """
    if isinstance(amount_dcf_or_list, (list, tuple)):
        return sum(map(lambda amount_dcf: xnpv(rs, amount_dcf),
                       [x for x in amount_dcf_or_list if x is not None]))
    if isinstance(amount_dcf_or_list, pd.core.frame.DataFrame):
        if amount_dcf_or_list.shape[0] == 0:
            return 0
        else:
            dcfs = amount_dcf_or_list.dcf
            amounts = amount_dcf_or_list.payment

    else:
        amounts = amount_dcf_or_list
    qs = np.power(1 + rs, dcfs)
    return np.sum(amounts * qs)


def xirr(amounts, dcfs=None, a=-.99, b=1):

    try:
        z = scipy.optimize.brentq(lambda r: xnpv(r, amounts, dcfs), a, b)
    except ValueError:
        z = np.nan
    return z


def calc_dcf(dates):
    dt64 = np.array(dates.values, 'datetime64[D]')
    return (np.datetime64('2015-04-01', 'D') - dt64) \
        / np.timedelta64(1, 'D') / 365


def calc_quarter(z):
    # pandas problem? copy turned datetime objects to long
    return z.map(lambda x: '{}_Q{}'.format(x.year, ((x.month - 1) // 3) + 1))


def extend_loans(loans):
    loans.rename(columns={'id_loan': 'fk_loan'}, inplace=True)

    loans['rating_base'] = loans.rating.str[0]
    loans['payout_date'] = \
        np.array(loans.payout_date, 'datetime64[D]')
    
    loans['payout_quarter'] = calc_quarter(loans['payout_date'])
    loans.loc[loans['payout_date'] < np.datetime64('2014-01-01', 'D'),
              'payout_quarter'] = '2014_Q1'
    # one loan before

    loans['rating_switch'] = np.nan
    loans.loc[loans.payout_date < np.datetime64('2014-07-01', 'D'),
              'rating_switch'] = 1
    loans.loc[
        (loans.payout_date >= np.datetime64('2014-07-01', 'D')) &
        (loans.payout_date < np.datetime64('2014-10-15', 'D')),
        'rating_switch'] = 2
    loans.loc[loans.payout_date >= np.datetime64('2014-10-15', 'D'),
              'rating_switch'] = 3

    loans['payout_date_EOM'] = loans['payout_date'] \
        + np.array(30 - loans.payback_day, 'timedelta64[D]')
    loans['dcf'] = calc_dcf(loans["payout_date_EOM"])
    return loans


def extend_loan_fundings(loan_fundings, loans):
    # cannot merge multiple times
    # (pandas will add suffixes to duplicated columns)
    # so better to use new variable fro extended
    loan_fundings.rename(columns={'fk_user': 'fk_user_investor'}, inplace=True)
    merge_fields = ['payout_date',
                    'payout_date_EOM', 'dcf',
                    'payback_day', 'principal_amount']
    loan_fundings.drop(merge_fields, axis=1, inplace=True, errors='ignore')

    loan_fundings = \
        loan_fundings.merge(loans[['fk_loan'] + merge_fields], on='fk_loan')
    loan_fundings['payment'] = -loan_fundings.amount
    loan_fundings['loan_coverage1'] = \
        loan_fundings.amount / loan_fundings.principal_amount * 100
    # because combined payment plan has loan coverage
    #    but is blank if no payment was made ( eg vorlauf zinsen)
    return loan_fundings


def extend_actual_payments(actual_payments, loans, arrears_dict):
    actual_payments['dcf'] = calc_dcf(actual_payments.iso_date)

    actual_payments.drop(['payout_date'], axis=1,
                         inplace=True, errors='ignore')
    actual_payments = \
        actual_payments.merge(loans[['fk_loan', 'payout_date']],
                              on='fk_loan',
                              how='left')

    actual_payments['in_arrears_since_days_30360'] = \
        days360(actual_payments.in_arrears_since.values,
                actual_payments.iso_date.values)

    actual_payments['bucket'] = \
        np.ceil(actual_payments.in_arrears_since_days_30360/30)*30
    actual_payments['bucket_pd'] = actual_payments.bucket.map(arrears_dict)
    actual_payments['cum_diff'] = actual_payments.expected_amount_cum -\
        actual_payments.actual_amount_cum
    return actual_payments


def extend_payment_plans(payment_plans, loans):
    payment_plans['dcf'] = calc_dcf(payment_plans.interval_payback_date)
    if 'initial_principal_amount_borrower' in payment_plans.columns:
        principal_str = 'initial_principal_amount_borrower'
    else:
        principal_str = 'initial_principal_amount'
    payment_plans['recovery'] = recovery(payment_plans[principal_str])
    return payment_plans


def isostr_date(date_str):
    return datetime.datetime.strptime(date_str, '%Y-%m-%d').date()


def generate_residual_act_investor(actual, loan_fundings,
                                   EOM_date, payment_plans=None):
    """  generate residual principals for IRR calc.
    We have two main options if in arrears
        if in 
    if payment plan omitted use all remaining principal
    (ie including in arrears) otherwise use next initial principal
    if default take full outstanding borrower principal
        *(1-1% service fee)  * recovery fraction
    NB need residual/initial principals to be not NULL
    """
    # TODO deal with empty payment plan
    # TODO what if default and paid back! loans 27 & 76
    act_fields = ['iso_date', 'fk_loan', 'fk_user_investor',
                  'in_arrears_since_days_30360',
                  'residual_principal_amount_borrower',
                  'residual_principal_amount_investor']
    act_EOM = actual.loc[(actual.iso_date == EOM_date), act_fields]
    has_defaulted = (act_EOM.in_arrears_since_days_30360 > 90)
    live_loans = act_EOM.loc[~has_defaulted, 'fk_loan'].unique()
    if payment_plans is None:
        # take residual principal at reporting date 
        resid_fields = ['fk_loan', 'fk_user_investor',
                        'residual_principal_amount_investor']
        residual = act_EOM.loc[~has_defaulted, resid_fields]\
            .rename(columns={'residual_principal_amount_investor': 'payment'})

    else:
        # otherwise take first initial principal after reporting date
        resid_fields = ['fk_loan', 'fk_user_investor',
                        'interval_payback_date',
                        'initial_principal_amount_investor']
        residual = payment_plans.loc[
            (payment_plans.interval_payback_date > EOM_date) &
            (payment_plans.fk_loan.isin(live_loans)), resid_fields]\
            .sort('interval_payback_date', inplace=False)\
            .groupby(['fk_loan', 'fk_user_investor'])\
            .first().reset_index().rename(columns={
                    'initial_principal_amount_investor': 'payment'})
        del residual['interval_payback_date']
    residual['date'] = np.datetime64(EOM_date, 'D')
    residual['dcf'] = calc_dcf(residual['date'])
    # for defaulted loans always use full outstanding in arrears

    if (has_defaulted.sum() > 0):
        recovery_payment = act_EOM[has_defaulted].copy()

        recovery_payment['recovery'] = \
            recovery(recovery_payment['residual_principal_amount_borrower'])
        recovery_payment = \
            recovery_payment.merge(
                loan_fundings[
                    ['fk_loan', 'fk_user_investor', 'loan_coverage1']],
                on=['fk_loan', 'fk_user_investor'], how='left')
        recovery_payment['payment'] = .99 * recovery_payment['recovery'] * \
            recovery_payment['residual_principal_amount_borrower'] * \
            recovery_payment['loan_coverage1'] / 100.0

        recovery_payment = \
            recovery_payment[['fk_loan', 'fk_user_investor',
                              'payment']]
        recovery_payment['date'] = np.datetime64(EOM_date, 'D')
        recovery_payment['dcf'] = calc_dcf(recovery_payment['date'])
    else:
        recovery_payment = None

    return residual, recovery_payment


def calc_act_irr(reporting_dates, act_pay, plan_pay, plan_repaid,
                 loan_fundings, minimum_vintage, filtered_de_payments):
                     
    cash_key=['fk_loan', 'fk_user_investor', 'payout_date']
    irr_df = pd.DataFrame({ 'irr': np.nan}, index=reporting_dates)
    # paidback loans are filtered out (including defaults!!!)
    dfs = []
    for EOM_date in reporting_dates:
        loan_principals = \
            loan_fundings.loc[
                (loan_fundings.payout_date <=
                    (EOM_date - minimum_vintage)) &
                ~(loan_fundings.fk_loan.isin(filtered_de_payments)),
                cash_key + ['payout_date_EOM', 'dcf', 'payment']]
        # loan payments may have payments for loans that have been filterd out

        act_filter = (act_pay.iso_date <= EOM_date.date()) & \
                     (act_pay.payout_date <=
                         (EOM_date-minimum_vintage).date())
        plan_filter = (plan_pay.payout_date <=
                        (EOM_date - minimum_vintage).date())
        loan_payments=act_pay.loc[act_filter,
                        cash_key+['dcf', 'payment_amount_investor_month']]\
                .rename(columns={'payment_amount_investor_month': 'payment'})
        residuals, recoveries = generate_residual_act_investor(
                                    act_pay[act_filter], loan_fundings,
                                    EOM_date.date(),
                                    payment_plans=plan_pay[plan_filter])
        repaid_loans_cash = \
            plan_repaid.loc[plan_repaid.payout_date <=
                            (EOM_date - minimum_vintage).date(),
                            cash_key + ['interval_payback_date', 'dcf',
                                        'payment_amount_investor']]\
                       .rename(columns={'payment_amount_investor': 'payment'})
        gps = [ zx.groupby(['rating_base', 'dcf']).payment.sum()
                .reset_index('dcf').groupby(level=0)
                    for zx in [loan_principals,loan_payments, residuals,
                            recoveries, repaid_loans_cash] if zx is not None ]
        df = gps[0].apply(
                lambda x: xirr([x] +
                               [z.get_group(x.index[0]) for z in gps[1:]
                                   if x.index[0] in z.groups.keys()]))
        dfs.append(df)
        gps_overall=[zx.groupby(['dcf']).payment.sum().reset_index('dcf') \
                     for zx in [loan_principals, loan_payments,
                                residuals, recoveries, repaid_loans_cash]
                    if zx is not None]
        irr_df.loc[EOM_date, 'irr'] = xirr(gps_overall)
    df_all = pd.concat(dfs, keys=reporting_dates)
    df_all.columns = ['irr']
    return df_all

        #loan_payments=payments paid before EOM_date
        #loan_final_principal=remaining principal
    # what about repayment
    # what about end of loan
        #group by rating/date (to sum over investors)
        #generate IRR


def rebase(x):
    # we treat interval 0 as special ( can't default then)
    # might consider doing fractional amount
    # if first interval is zero, return x otherwise x-x[0]+1
    # different investors may or may not have zero interval
    # ( if investment too low <1 cent interest)
    min_interval = x.min()
    if min_interval != 0:
        min_interval -= 1
    return x - min_interval


def calc_survival_investor(pp):
    """ adds expected cashflows to copy of payment plan
    survive: probabability of surviving up to (and including) interval
    """

    pp = pp.copy()
    pp['interval_rebased'] = \
        pp[['fk_loan', 'interval']].groupby(['fk_loan']).transform(rebase)

    pp['surv_month'] = (1 - pp.pd).pow(1 / 12.0)
    pp['survive'] = pp.surv_month.pow(pp.interval_rebased)
    pp['default'] = (pp.interval_rebased > 0) * \
        pp.surv_month.pow(pp.interval_rebased - 1) * (1 - pp.surv_month)
    pp['e_payment_amount_investor'] = pp.survive * pp.payment_amount_investor
    pp['e_recovery'] = pp.default * pp.recovery * \
        pp.initial_principal_amount_investor * .99  # service fee
    pp['e_tot'] = pp.e_payment_amount_investor + pp.e_recovery
    return pp


def add_pd(pp, act_EOM, loans, use_in_arrears):
    """ add pd from loans, divide by 100, and create dupl pd_noarr """
    pp_pd = pp.merge(act_EOM[['fk_loan', 'fk_user_investor', 'bucket_pd']],
                     on=['fk_loan', 'fk_user_investor'], how='left')

    pp_pd = pp_pd.merge(loans[['fk_loan', 'pd']], on='fk_loan')
    pp_pd['pd'] = pp_pd['pd'] / 100.0
    pp_pd['pd_noarr'] = pp_pd['pd']
    if use_in_arrears:
        pp_pd.loc[pp_pd.bucket_pd.notnull(), 'pd'] = \
            pp_pd.loc[pp_pd.bucket_pd.notnull(), 'bucket_pd']
    return pp_pd


def make_future_pd(payment_plans, act_EOM, loans, arrears_dict, use_in_arrears,
                   EOM_date=None, latest_paid_interval=None):
    """ select future payments after EOM_date_str or after last paid_interval
        if last_paid_interval provided then use those too and
        set any dates before EOM to EOM
        if EOM_date_str is None use all data
    """

    if EOM_date is not None:
        
        if latest_paid_interval is None:
            fut = payment_plans[payment_plans.interval_payback_date > EOM_date]
        else:
            fut = payment_plans.merge(pd.DataFrame(latest_paid_interval),
                                      left_on=['fk_loan', 'fk_user_investor'],
                                      right_index=True, how='left')
            # TODO 
            # a) no record: select all future payments
            # b) vorlaufzinsen? - works[ paid vorlauf zinsen->interval 0]
            
            fut = fut[(fut.latest_paid_interval.isnull()) |
                      (fut.interval > fut.latest_paid_interval)]
            fut.loc[fut.interval_payback_date < EOM_date,
                    'interval_payback_date'] = EOM_date
            fut['dcf']=calc_dcf(fut['interval_payback_date'])
    else:
        fut = payment_plans.copy()
    # drop intervals already in actual???
    fut_pd = add_pd(fut, act_EOM, loans, use_in_arrears)
    fut_pd = calc_survival_investor(fut_pd)
    return fut_pd


def generate_cashflows_pp(pp, loan_fundings, loans, EOM_date_str=None):
    print " needs to be adjustede but doesnt make sense for time history"
    if EOM_date_str is None:
        EOM_date_str = '2300-01-01'
    EOM_date = datetime.datetime.strptime(EOM_date_str, '%Y-%m-%d').date()
    # generate cashflows from plan for xirr
    # ( by taking payment amount, loan funding and residual principal
    # exclude loans for which no plan yet or interval zero where
    pp_fields = ['fk_loan', 'fk_user_investor',
                 'interval_payback_date', 'payment_amount_investor']
    cashflows = pp.loc[pp.interval_payback_date <= EOM_date, pp_fields].copy()

    cashflows = cashflows[cashflows.payment_amount_investor.notnull()]
    cashflows['interval_payback_date'] = \
        np.array(cashflows['interval_payback_date'], 'datetime64[D]')
    investor_loan_ids = cashflows[['fk_loan', 'fk_user_investor']]\
        .drop_duplicates()

    # filter out cases with no plan yet
    # ( depends on investor because first payment could be <1 cent)
    cashflows.rename(columns={'interval_payback_date': 'date',
                              'payment_amount_investor': 'payment'},
                     inplace=True)
    loan_fundings = loan_fundings[
        ['fk_loan', 'fk_user', 'payout_date', 'amount']]\
        .merge(investor_loan_ids, on=['fk_loan', 'fk_user_investor'])
    del loan_fundings['fk_user_investor']
    # loan_fundings['date']=np.array(loan_fundings['date'],'datetime64[D]')
    resid_fields = ['fk_loan', 'fk_user_investor',
                    'interval_payback_date',
                    'residual_principal_amount_investor']
    residuals = pp.loc[pp.interval_payback_date <= EOM_date, resid_fields]\
        .groupby(['fk_loan', 'fk_user_investor']).agg(
            {'interval_payback_date': np.max,
             'residual_principal_amount_investor': np.min}).reset_index()

    # should be same as finding principal at max date!
    residuals = residuals[ residuals.residual_principal_amount_investor.notnull()]
    residuals['interval_payback_date'] = \
        np.array(residuals['interval_payback_date'], 'datetime64[D]')
    residuals.rename(columns={'interval_payback_date': 'date',
                              'residual_principal_amount_investor': 'payment'},
                     inplace=True)

    cashflows = pd.concat([loan_fundings, cashflows, residuals],
                          ignore_index=True)
    # warning a mix of datetimes and dates causes problems - datetimes -> 1970-
    cashflows['date'] = np.array(cashflows['date'], 'datetime64[D]')
    cashflows['dcf'] = calc_dcf(cashflows['date'])
    return cashflows


def generate_cashflows(pred_pp, loan_funding, useEOM_shift, actual=None):
    """ prepare data for IRR calculation.
        take predicted future cashflows together with inital principal
        and any actual payments and return merged cashflows for IRR calculation
        useEOM_shift: since shifts
    """
    if useEOM_shift:
        date_str = 'payout_date_EOM'
    else:
        date_str = 'payout_date'

    # take payments and add initial principal
    cashflows = pred_pp[['fk_loan', 'fk_user_investor', 'e_tot']].copy()
    cashflows['interval_payback_date'] = \
        np.array(pred_pp.interval_payback_date, 'datetime64[D]')
    cashflows.rename(columns={'interval_payback_date': 'date',
                              'e_tot': 'payment'}, inplace=True)

    if actual is not None:
        act_fields = ['fk_loan', 'fk_user_investor', 'iso_date',
                      'payment_amount_investor_month']
        act = actual[act_fields].rename(columns=\
            {'iso_date': 'date', 'payment_amount_investor_month': 'payment'})

        act.date = np.array(act.date, 'datetime64[D]')
    else:
        act = None
    cashflows = pd.concat([loans_orig, act, cashflows], ignore_index=True)
    return cashflows


def add_loan_rating(cashflows, loans):
    return cashflows.merge(loans[
        ['fk_loan', 'payout_date', 'rating_base', 'base_date',
         'base_return', 'payback_state']], on='fk_loan', how='left')


def gen_rating(cashflows, orig_date_str, exc_loans):
    orig_date = isostr_date(orig_date_str)
    return cashflows[(cashflows.payback_state != 'payback_complete') &
                     (cashflows.payout_date < orig_date) &
                     ~(cashflows.fk_loan.isin(exc_loans))]\
        .groupby(['base_date', 'rating_base'])\
        .apply(lambda x: xirr(x.payment, x.dcf))

def abs_diff(df, pairs):
    for x, y in pairs:
        df[x + '_m_' + y] = np.abs(df[x] - df[y])
    return df
