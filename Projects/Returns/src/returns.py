from __future__ import division
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import datetime
import scipy.optimize
import pandas.io.sql as psql
import pandas as pd


def recovery(amounts):
    return 0.1425 + (0.2613 - .1425) * (amounts <= 25000) \
        + (0.5814 - 0.2613) * (amounts <= 5000)
    # losses return 0.4186+(0.7387-.4186)*(amounts>5000)+ (0.8575 - 0.7387)*(amounts>25000)


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
    """ should work for scalars and vectors and DataFrame or list of DataFrames.
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


def xirr(amounts, dcfs=None, guess=0.1):
    # RuntimeError: Failed to converge after 50 iterations, value is nan
    try:
        z = scipy.optimize.newton(lambda r: xnpv(r, amounts, dcfs), guess)
    except RuntimeError:
        z = np.nan
    return z


def calc_dcf(dates):
    dt64 = np.array(dates.values, 'datetime64[D]')
    return (np.datetime64('2015-04-01', 'D') - dt64) \
        / np.timedelta64(1, 'D') / 365


def extend_loans(loans):
    loans.rename(columns={'id_loan':'fk_loan'},inplace=True)
    loans['rating_base'] = loans.rating.str[0]
    loans['originated_since_date'] = \
        np.array(loans.payout_date, 'datetime64[D]')
    loans['originated_since_date_EOM'] = loans['originated_since_date'] \
        + np.array(30 - loans.payback_day, 'timedelta64[D]')
    loans['dcf'] = calc_dcf(loans["originated_since_date_EOM"])
    return loans


def extend_loan_fundings(loan_fundings, loans):
    # cannot merge multiple times 
    # (pandas will add suffixes to duplicated columns)
    # so better to use new variable fro extended
    loan_fundings.rename(columns={'fk_user':'fk_user_investor'}, inplace=True)
    merge_fields=[ 'originated_since_date',
                  'originated_since_date_EOM', 'dcf',
                  'payback_day', 'rating_base', 'principal_amount']
    loan_fundings.drop(merge_fields, axis=1, inplace=True,errors='ignore')
    
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

    actual_payments.drop('rating_base', axis=1, inplace=True, errors='ignore')
    actual_payments = \
        actual_payments.merge(loans[['fk_loan', 'rating_base']],
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
    payment_plans.drop('rating_base', axis=1, inplace=True, errors='ignore')
    payment_plans = \
        payment_plans.merge(loans[['fk_loan', 'rating_base']],
                            on='fk_loan', how='left')
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
    if payment plan omitted use all remaining principal
    (ie including in arrears) otherwise use next initial principal
    if default take full outstanding borrower principal
        *(1-1% service fee)  * recovery fraction
    
    """
    #TODO deal with empty payment plan
    act_fields = ['iso_date', 'rating_base', 'fk_loan', 'fk_user_investor',
                  'in_arrears_since_days_30360',
                  'residual_principal_amount_borrower',
                  'residual_principal_amount_investor']
    act_EOM = actual.loc[(actual.iso_date == EOM_date), act_fields]
    has_defaulted = (act_EOM.in_arrears_since_days_30360 > 90)
    live_loans = act_EOM.loc[~has_defaulted, 'fk_loan'].unique()
    if payment_plans is None:
        resid_fields = ['rating_base', 'fk_loan', 'fk_user_investor',
                        'residual_principal_amount_investor']
        residual = act_EOM.loc[~has_defaulted, resid_fields]\
            .rename(columns={'residual_principal_amount_investor': 'payment'})

    else:
        resid_fields = ['rating_base', 'fk_loan', 'fk_user_investor', 'interval_payback_date',
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
                loan_fundings[['fk_loan', 'fk_user_investor', 'loan_coverage1']],
                on=['fk_loan', 'fk_user_investor'],
                how='left')
        recovery_payment['payment'] = .99 * recovery_payment['recovery'] * \
            recovery_payment['residual_principal_amount_borrower'] * \
            recovery_payment['loan_coverage1'] / 100.0

        recovery_payment = \
            recovery_payment[['rating_base', 'fk_loan', 'fk_user_investor',
                              'payment']]
        recovery_payment['date'] = np.datetime64(EOM_date, 'D')
        recovery_payment['dcf'] = calc_dcf(recovery_payment['date'])
    else:
        recovery_payment = None

    return residual, recovery_payment


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
        pp[['fk_loan','interval']].groupby(['fk_loan']).transform(rebase)

    pp['surv_month'] = (1 - pp.pd).pow(1 / 12.0)
    pp['survive'] = pp.surv_month.pow(pp.interval_rebased)
    pp['default'] = (pp.interval_rebased > 0) * \
        pp.surv_month.pow(pp.interval_rebased - 1) * (1 - pp.surv_month)
    pp['e_payment_amount_investor'] = pp.survive * pp.payment_amount_investor
    pp['e_recovery'] = pp.default * pp.recovery * \
        pp.initial_principal_amount_investor * .99  # service fee
    pp['e_tot'] = pp.e_payment_amount_investor + pp.e_recovery
    return pp


def add_pd(pp, loans, use_in_arrears):
    """ add pd from loans, divide by 100, and create dupl pd_noarr """
    pp_pd = pp.merge(
        loans[['id_loan', 'pd', 'bucket_pd']],
        left_on='fk_loan', right_on='id_loan')
    pp_pd['pd']=pp_pd['pd'] / 100.0
    pp_pd['pd_noarr'] = pp_pd['pd']
    if use_in_arrears:
        pp_pd.loc[pp_pd.bucket_pd.notnull(),'pd']=pp_pd.loc[pp_pd.bucket_pd.notnull(),'bucket_pd']
    return pp_pd


def make_future_pd(payment_plans,loans, arrears_dict, use_in_arrears, EOM_date_str=None, latest_paid_interval=None):
    """
        select future payments after EOM_date_str or after last paid_interval
        if last_paid_interval provided then use those too and set andy dates before EOM to EOM
        if cut_off is None use all data

    """

    if EOM_date_str is not None:
        EOM_date=datetime.datetime.strptime(EOM_date_str,'%Y-%m-%d').date()
        if latest_paid_interval is None:
            fut=payment_plans[payment_plans.interval_payback_date > EOM_date ]
        else:
            fut=payment_plans.merge( pd.DataFrame(latest_paid_interval),left_on=['fk_loan','fk_user_investor'],right_index=True,how='left')
            fut=fut[(fut.latest_paid_interval.isnull() )|(fut.interval>fut.latest_paid_interval)]
            fut.loc[fut.interval_payback_date<EOM_date,"interval_payback_date"]=EOM_date
    else:
        fut=payment_plans.copy()
    # drop intervals already in actual???
    fut_pd=add_pd(fut, loans, use_in_arrears)
    fut_pd=calc_survival_investor(fut_pd)
    return fut_pd



def generate_cashflows_pp(pp,loan_fundings,loans, EOM_date_str=None):
    if EOM_date_str is None:
        EOM_date_str='2300-01-01'
    EOM_date=datetime.datetime.strptime(EOM_date_str,'%Y-%m-%d').date()
    # generate cashflows from plan for xirr ( by taking payment amount, loan funding and residual principal
    # exclude loans for which no plan yet or interval zero where
    cashflows=pp.loc[pp.interval_payback_date<=EOM_date,['fk_loan','fk_user_investor','interval_payback_date','payment_amount_investor']].copy()


    cashflows=cashflows[cashflows.payment_amount_investor.notnull()]
    cashflows['interval_payback_date']=np.array(cashflows['interval_payback_date'],'datetime64[D]')
    investor_loan_ids=cashflows[['fk_loan','fk_user_investor']].drop_duplicates()

    # filter out cases with no plan yet ( depends on investor because first payment could be <1 cent)
    cashflows.rename(columns={'fk_loan':'id_loan','interval_payback_date':'date','payment_amount_investor':'payment'},inplace=True)
    loan_fundings=loan_fundings[['fk_loan','fk_user','originated_since_date','amount']].merge(investor_loan_ids,left_on=['fk_loan','fk_user'],right_on=['fk_loan','fk_user_investor'])
    del loan_fundings['fk_user_investor']
    #loan_fundings['date']=np.array(loan_fundings['date'],'datetime64[D]')
    loan_fundings.amount=-loan_fundings.amount
    loan_fundings.rename(columns={'fk_loan':'id_loan', 'fk_user':'fk_user_investor','originated_since_date':'date' ,'amount':'payment'},inplace=True)

    residuals=pp.loc[pp.interval_payback_date<=EOM_date,['fk_loan','fk_user_investor','interval_payback_date','residual_principal_amount_investor']]        .groupby(['fk_loan','fk_user_investor']).agg({                                'interval_payback_date':np.max,                                'residual_principal_amount_investor':np.min}).reset_index()

    # should be same as finding principal at max date!
    residuals=residuals[residuals.residual_principal_amount_investor.notnull()]
    residuals['interval_payback_date']=np.array(residuals['interval_payback_date'],'datetime64[D]')
    residuals.rename(columns={'fk_loan':'id_loan','interval_payback_date':'date' ,                              'residual_principal_amount_investor':'payment'},inplace=True)

    cashflows=pd.concat([loan_fundings,cashflows, residuals],ignore_index=True)
    # warning a mix of datetimes and dates causes problems - datetimes -> 1970-...
    cashflows['date']=np.array(cashflows['date'],'datetime64[D]')

    cashflows['dcf']=(datetime.date(2015,4,1)  -cashflows['date'])/np.timedelta64(1,'D')/365

    return cashflows


def generate_cashflows(pred_pp, loan_funding, useEOM_shift, EOM_date_str=None, actual=None):
    """ prepare data for IRR calculation.
        take predicted future cashflows together with inital principal
        and any actual payments and return merged cashflows for IRR calculation
        useEOM_shift: if
        EOM_date_str: only used to filter loans that were originated before EOM_str
    """
    if useEOM_shift:
        date_str='originated_since_date_EOM'
    else:
        date_str='originated_since_date'

    if EOM_date_str is not None:
        EOM_date=datetime.datetime.strptime(EOM_date_str,'%Y-%m-%d').date()

    # take payments and add initial principal
    cashflows=pred_pp[['fk_loan','fk_user_investor','e_tot']].copy()
    cashflows['interval_payback_date']=np.array(pred_pp.interval_payback_date,'datetime64[D]')
    cashflows.rename(columns={'fk_loan':'id_loan','interval_payback_date':'date','e_tot':'payment'},inplace=True)
    # ids=cashflows.id_loan.unique()


    if EOM_date_str is not None:
        loans_orig=loan_funding.loc[loan_funding.originated_since_date<EOM_date,['fk_loan','fk_user',date_str,'amount']].copy()
    else:
        loans_orig=loan_funding[['fk_loan','fk_user',date_str,'amount']].copy()
    loans_orig.amount=-loans_orig.amount
    loans_orig.rename(columns={'fk_loan':'id_loan', 'fk_user':'fk_user_investor',date_str:'date' ,'amount':'payment'},inplace=True)

    if actual is not None:
        act=actual[['fk_loan','fk_user_investor','iso_date','payment_amount_investor_month']].rename(columns={'fk_loan':'id_loan','iso_date':'date','payment_amount_investor_month':'payment'})

        act.date=np.array(act.date,'datetime64[D]')
    else:
        act=None
    cashflows=pd.concat([loans_orig,act,cashflows],ignore_index=True)

    return cashflows


def add_loan_rating(cashflows,loans):
    return cashflows.merge(loans[['id_loan','originated_since_date',\
    'rating_base','base_date','base_return','payback_state']],on='id_loan',how='left')


# merge in investor field and loan coverage, change borrower payment to investor cashflow ( ie according to their allocation of loan)
def add_investor_coverage(cashflows,loan_fundings):
    cashflows1=cashflows.merge(loan_fundings[['fk_loan','fk_user','loan_coverage1']],\
                               left_on='id_loan',right_on='fk_loan')
    cashflows1['orig_payment']=cashflows1['payment']
    cashflows1['payment']=cashflows1['orig_payment']*cashflows1['loan_coverage1']/100.0
    return cashflows1


def gen_rating(cashflows, orig_date_str, exc_loans):
    orig_date=datetime.datetime.strptime(orig_date_str,'%Y-%m-%d').date()
    return cashflows[(cashflows.payback_state!='payback_complete') & \
                     (cashflows.originated_since_date<orig_date) &
                    ~(cashflows.id_loan.isin(exc_loans))
                    ]\
        .groupby(['base_date','rating_base']).apply(lambda x: xirr(x.payment,x.dcf))

def abs_diff(df,pairs):
    for x,y in pairs:
        df[x+'_m_'+y]=np.abs(df[x]-df[y])
    return df



