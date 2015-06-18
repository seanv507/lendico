from __future__ import division # float not integer division
import numpy as np
import pandas as pd
import datetime
import scipy.optimize
import os

# todo actual date
# loan_funding dcf_EOM vs dcf normal
# filtering out loans... do one country at time...
# why can't use just actual amounts with  service fee? for IRR
# no need to match investor payments? and use borrower principal???


def get_src_dir():
    return os.path.dirname(os.path.abspath(__file__))


def drop_merge(left_df, right_df, keys, fields, how='inner'):
    """ merge columns from right dataframe.
    If they already exist in left df, they are first dropped
    keys and fields should be lists
    """
    # given time to load data, always create new dataframe to avoid requery
    new_df = left_df.drop(fields, axis=1, inplace=False, errors='ignore')
    new_df = new_df.merge(right_df[keys + fields],
                          on=keys, how=how)
    return new_df


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


def isostr_date(date_str):
    return datetime.datetime.strptime(date_str, '%Y-%m-%d').date()


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


def calc_dcf(dates):
    dt64 = np.array(dates.values, 'datetime64[D]')
    return (np.datetime64('2015-04-01', 'D') - dt64) \
        / np.timedelta64(1, 'D') / 365


def calc_quarter(z):
    # pandas problem? copy turned datetime objects to long
    return z.map(lambda x: '{}_Q{}'.format(x.year, ((x.month - 1) // 3) + 1))


def drop_none(li):
        return [zx for zx in li if zx is not None]


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


def group_payment_sum(grps,grouping):
    # what if empty list
    # convert scalar to list if necc
    if isinstance(grouping,str):
        levels = 0
        grouping_list = [grouping]+['dcf']
    else:
        levels = range(len(grouping))
        grouping_list = list(grouping) + ['dcf']  # co
    # pandas throws error if send [0] when no multiindex
    ans = [zx.groupby(grouping_list).payment.
           sum().
           reset_index('dcf').
           groupby(level=levels) for zx in grps]
    return ans


def xirr_group(grps):
    # calc irr for group
    # grps[0] must be loan_funding - initial principal
    # we only take other cashflows if initial principal in list
    return grps[0].apply( lambda x: xirr([x] +
            [z.get_group(x.index[0]) for z in grps[1:] if x.index[0] in z.groups.keys()]))


def extend_loans(loans):
    loans.rename(columns={'id_loan': 'fk_loan'}, inplace=True)

    loans['rating_base'] = loans.rating.str[0]
    loans['payout_date'] = \
        np.array(loans.payout_date, 'datetime64[D]')

    loans['payout_quarter'] = calc_quarter(loans['payout_date'])
    loans.loc[loans['payout_date'] < np.datetime64('2014-01-01', 'D'),
              'payout_quarter'] = '2014_Q1'
    # one loan before

    loans['payout_date_EOM'] = loans['payout_date'] \
        + np.array(30 - loans.payback_day, 'timedelta64[D]')
    loans['dcf'] = calc_dcf(loans["payout_date"])
    loans['dcf_EOM'] = calc_dcf(loans["payout_date_EOM"])
    print 'using shifted payout date'
    return loans


def extend_loan_fundings(loan_fundings, loans):
    # cannot merge multiple times
    # (pandas will add suffixes to duplicated columns)
    # so better to use new variable fro extended
    loan_fundings.rename(columns={'fk_user': 'fk_user_investor'}, inplace=True)
    merge_keys = ['dwh_country_id', 'fk_loan']
    merge_fields = ['payout_date',
                    'payout_date_EOM', 'dcf','dcf_EOM',
                    'payback_day', 'eur_principal_amount']

    loan_fundings = drop_merge(loan_fundings, loans,
                               merge_keys, merge_fields, 'left')

    loan_fundings['payment'] = -loan_fundings.eur_amount
    loan_fundings['loan_coverage1'] = \
        loan_fundings.eur_amount / loan_fundings.eur_principal_amount * 100
    # because combined payment plan has loan coverage
    #    but is blank if no payment was made ( eg vorlauf zinsen)
    return loan_fundings


# by EOM we actually mean reporting date
def extend_actual_payments_EOM(actual_payments, loans, arrears_dict,
                               loan_fundings=None):
    actual_payments['dcf'] = calc_dcf(actual_payments.iso_date)
    merge_keys = ['dwh_country_id', 'fk_loan']
    merge_fields = ['payout_date']
    actual_payments = drop_merge(actual_payments, loans,
                                 merge_keys, merge_fields, 'left')

    merge_keys = ['dwh_country_id', 'fk_loan', 'fk_user_investor']
    merge_fields = ['loan_coverage1', 'investment_fee_def']
    if loan_fundings is not None:
        # missing when  only borrower side
        actual_payments = drop_merge(actual_payments, loan_fundings,
                                     merge_keys, merge_fields, 'left')

    actual_payments['in_arrears_since_days_30360'] = \
        days360(actual_payments.in_arrears_since.values,
                actual_payments.iso_date.values)

    actual_payments['bucket'] = \
        np.ceil(actual_payments.in_arrears_since_days_30360/30)*30
    actual_payments['bucket_pd'] = actual_payments.bucket.map(arrears_dict)
    actual_payments['cum_diff'] = actual_payments.expected_amount_cum -\
        actual_payments.actual_amount_cum
    return actual_payments

def extend_actual_payments(actual_payments, loans):
    actual_payments['dcf'] = calc_dcf(actual_payments.iso_date)
    merge_keys = ['dwh_country_id', 'fk_loan']
    merge_fields = ['payout_date']
    actual_payments = drop_merge(actual_payments, loans,
                                 merge_keys, merge_fields, 'left')
    return actual_payments


def extend_payment_plans(payment_plans, loan_fundings=None):
    payment_plans['dcf'] = calc_dcf(payment_plans.interval_payback_date)

    if 'eur_initial_principal_amount_borrower' in payment_plans.columns:
        if loan_fundings is None:
            raise ValueError('need to pass loan fundings for combined payment_plans')
        principal_str = 'eur_initial_principal_amount_borrower'
        merge_keys = ['dwh_country_id', 'fk_loan', 'fk_user_investor']
        merge_fields = ['investment_fee_def']
        payment_plans = drop_merge( payment_plans, loan_fundings,
                               merge_keys, merge_fields, 'left')
    else:
        principal_str = 'eur_initial_principal_amount'
    payment_plans['recovery'] = recovery(payment_plans[principal_str])


    return payment_plans


def generate_residual_act_investor_date(actual, payment_plans, act_EOM,
                                        loan_fundings ):
    """  generate residual principals for IRR calc.

    We have two main options if in arrears
    a) could use all remaining principal
    (ie including in arrears)
    b) otherwise use next initial principal

    when do we assume "arrears payment" is made?
        currently at end of reporting month
    when do we assume default payment is made?
        at end of reporting month

    if default take full outstanding borrower principal
        *(1-1% service fee)  * recovery fraction
    NB need residual/initial principals to be not NULL
    act_EOM: monthly actual_payments for particular reporting date
    """
    # TODO deal with empty payment plan
    # TODO what if default and paid back! loans 27 & 76
    # TODO put residual at last actual payment date? if using outstanding principal
    EOM_date=act_EOM.iso_date[0]
    fund_keys = ['dwh_country_id', 'fk_loan', 'fk_user_investor']
    act_fields = ['iso_date', 'dwh_country_id', 'fk_loan', 'fk_user_investor',
                  'in_arrears_since_days_30360',
                  'eur_residual_principal_amount_borrower',
                  'eur_residual_principal_amount_investor']


    has_defaulted = (act_EOM.in_arrears_since_days_30360 > 90)
    in_arrears = (act_EOM.in_arrears_since_days_30360 > 0) & ~has_defaulted

    live_loans = act_EOM.loc[~has_defaulted, fund_keys]
    arrears_loans = act_EOM.loc[in_arrears, fund_keys]
    current_loans = act_EOM.loc[act_EOM.in_arrears_since_days_30360 == 0,
                                fund_keys]

# if current, then use latest residual and latest payment date
# if in arrears use EOM

#    if False:
#        # take outstanding principal but need to change date to
#        # latest plan patyment
#        resid_fields = ['iso_date',
#                        'dwh_country_id', 'fk_loan', 'fk_user_investor',
#                        'residual_principal_amount_investor']
#        residual = actual[resid_fields].merge(live_loans, on= loan_keys)
#
#        residual = residual.sort('iso_date', inplace=False)\
#                   .groupby(loan_keys + ['fk_user_investor'])\
#                   .last()\
#                   .reset_index()\
#                   .rename(columns={'residual_principal_amount_investor':
#                                    'payment'})
#        residual['dcf'] = calc_dcf(residual['iso_date'])
#
#    else:
        # otherwise take last residual principal before reporting date


    resid_fields = fund_keys + ['iso_date',
                                'eur_residual_principal_amount_investor']
    residual_current = actual.loc[actual.iso_date <= EOM_date,
                                  resid_fields]\
                       .merge(current_loans, on= fund_keys)\
                       .sort('iso_date', inplace=False)\
                       .groupby(fund_keys)\
                       .last()\
                       .reset_index()\
                       .rename(columns={
                       'iso_date':'date',
                       'eur_residual_principal_amount_investor': 'payment'})
    residual_current['dcf'] = calc_dcf(residual['date'])
    # how to treat in arrears? almost defaulted/almost current?
    if (in_arrears.sum() > 0):
        arrears_payment = act_EOM[in_arrears].copy()

        arrears_payment['recovery'] = \
            recovery(arrears_payment['eur_residual_principal_amount_borrower'])


        arrears_payment['payment'] = \
            arrears_payment['eur_residual_principal_amount_investor']

        arrears_payment = \
            arrears_payment[fund_keys + ['payment']]
        arrears_payment['date'] = np.datetime64(EOM_date, 'D')
        arrears_payment['dcf'] = calc_dcf(arrears_payment['date'])
    else:
        arrears_payment = None

    # for defaulted loans always use full outstanding in arrears

    if (has_defaulted.sum() > 0):
        recovery_payment = act_EOM[has_defaulted].copy()

        recovery_payment['recovery'] = \
            recovery(recovery_payment['eur_residual_principal_amount_borrower'])

        recovery_payment['payment'] = \
            (1-recovery_payment.investment_fee_def/100.0) * \
            recovery_payment['recovery'] * \
            recovery_payment['eur_residual_principal_amount_borrower'] * \
            recovery_payment['loan_coverage1'] / 100.0

        recovery_payment = \
            recovery_payment[fund_keys + ['payment']]
        recovery_payment['date'] = np.datetime64(EOM_date, 'D')
        recovery_payment['dcf'] = calc_dcf(recovery_payment['date'])
    else:
        recovery_payment = None

    return residual_current, arrears_payment, recovery_payment


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
    act_fields = ['iso_date', 'dwh_country_id', 'fk_loan', 'fk_user_investor',
                  'in_arrears_since_days_30360',
                  'eur_residual_principal_amount_borrower',
                  'eur_residual_principal_amount_investor']
    act_EOM = actual.loc[(actual.iso_date == EOM_date), act_fields]
    has_defaulted = (act_EOM.in_arrears_since_days_30360 > 90)
    live_loans = act_EOM.loc[~has_defaulted, 'dwh_country_id', 'fk_loan'].unique()
    if payment_plans is None:
        # take residual principal at reporting date
        resid_fields = ['dwh_country_id', 'fk_loan', 'fk_user_investor',
                        'eur_residual_principal_amount_investor']
        residual = act_EOM.loc[~has_defaulted, resid_fields]\
            .rename(columns={'eur_residual_principal_amount_investor': 'payment'})

    else:
        # otherwise take first initial principal after reporting date
        resid_fields = ['dwh_country_id', 'fk_loan', 'fk_user_investor',
                        'interval_payback_date',
                        'eur_initial_principal_amount_investor']
        residual = payment_plans.loc[
            (payment_plans.interval_payback_date > EOM_date) &
            (payment_plans.fk_loan.isin(live_loans)), resid_fields]\
            .sort('interval_payback_date', inplace=False)\
            .groupby(['dwh_country_id', 'fk_loan', 'fk_user_investor'])\
            .first().reset_index().rename(columns={
                    'eur_initial_principal_amount_investor': 'payment'})
        del residual['interval_payback_date']
    residual['date'] = np.datetime64(EOM_date, 'D')
    residual['dcf'] = calc_dcf(residual['date'])
    # for defaulted loans always use full outstanding in arrears

    if (has_defaulted.sum() > 0):
        recovery_payment = act_EOM[has_defaulted].copy()

        recovery_payment['recovery'] = \
            recovery(recovery_payment['eur_residual_principal_amount_borrower'])
        recovery_payment = \
            recovery_payment.merge(
                loan_fundings[
                    ['dwh_country_id', 'fk_loan', 'fk_user_investor', 'loan_coverage1']],
                on=['dwh_country_id', 'fk_loan', 'fk_user_investor'], how='left')
        recovery_payment['payment'] = \
            (1 - recovery_payment.investment_fee_def/100.0) * \
            recovery_payment['recovery'] * \
            recovery_payment['eur_residual_principal_amount_borrower'] * \
            recovery_payment['loan_coverage1'] / 100.0

        recovery_payment = \
            recovery_payment[['dwh_country_id', 'fk_loan', 'fk_user_investor',
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
        pp[['dwh_country_id', 'fk_loan', 'interval']].\
        groupby(['dwh_country_id', 'fk_loan']).transform(rebase)

    pp['surv_month'] = (1 - pp.pd).pow(1 / 12.0)
    pp['survive'] = pp.surv_month.pow(pp.interval_rebased)
    pp['default'] = \
        (pp.interval_rebased > 0) * \
        pp.surv_month.pow(pp.interval_rebased - 1) * \
        (1 - pp.surv_month)

    pp['e_eur_payment_amount_investor'] = \
        pp.survive *\
        pp.eur_payment_amount_investor

    pp['e_eur_recovery_amount'] = \
        pp.default * \
        pp.recovery * \
        pp.loan_coverage1 * \
        pp.eur_initial_principal_amount_borrower * \
        (1 - pp.investment_fee_def/100.0)  # service fee
    pp['e_tot'] = pp.e_eur_payment_amount_investor + pp.e_eur_recovery_amount
    return pp


def add_pd(pp, act_EOM, loans, use_in_arrears):
    """ add pd from loans, divide by 100, and create dupl pd_noarr """
    pp_pd = pp.merge(act_EOM[['dwh_country_id', 'fk_loan', 'fk_user_investor', 'bucket_pd']],
                     on=['dwh_country_id', 'fk_loan', 'fk_user_investor'], how='left')

    pp_pd = pp_pd.merge(loans[['dwh_country_id', 'fk_loan', 'pd']],
                        on=['dwh_country_id', 'fk_loan'])
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
                                      left_on=['dwh_country_id', 'fk_loan', 'fk_user_investor'],
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
    pp_fields = ['dwh_country_id', 'fk_loan', 'fk_user_investor',
                 'interval_payback_date', 'eur_payment_amount_investor']
    cashflows = pp.loc[pp.interval_payback_date <= EOM_date, pp_fields].copy()

    cashflows = cashflows[cashflows.eur_payment_amount_investor.notnull()]
    cashflows['interval_payback_date'] = \
        np.array(cashflows['interval_payback_date'], 'datetime64[D]')
    investor_loan_ids = cashflows[['dwh_country_id', 'fk_loan', 'fk_user_investor']]\
        .drop_duplicates()

    # filter out cases with no plan yet
    # ( depends on investor because first payment could be <1 cent)
    cashflows.rename(columns={'interval_payback_date': 'date',
                              'eur_payment_amount_investor': 'payment'},
                     inplace=True)
    loan_fundings = loan_fundings[
        ['dwh_country_id', 'fk_loan', 'fk_user', 'payout_date', 'amount']]\
        .merge(investor_loan_ids, on=['dwh_country_id', 'fk_loan', 'fk_user_investor'])
    del loan_fundings['fk_user_investor']
    # loan_fundings['date']=np.array(loan_fundings['date'],'datetime64[D]')
    resid_fields = ['dwh_country_id', 'fk_loan', 'fk_user_investor',
                    'interval_payback_date',
                    'eur_residual_principal_amount_investor']
    residuals = pp.loc[pp.interval_payback_date <= EOM_date, resid_fields]\
        .groupby(['dwh_country_id', 'fk_loan', 'fk_user_investor']).agg(
            {'interval_payback_date': np.max,
             'eur_residual_principal_amount_investor': np.min}).reset_index()

    # should be same as finding principal at max date!
    residuals = residuals[ residuals.eur_residual_principal_amount_investor.notnull()]
    residuals['interval_payback_date'] = \
        np.array(residuals['interval_payback_date'], 'datetime64[D]')
    residuals.rename(columns={'interval_payback_date': 'date',
                              'eur_residual_principal_amount_investor': 'payment'},
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
    cashflows = pred_pp[['dwh_country_id', 'fk_loan', 'fk_user_investor', 'e_tot']].copy()
    cashflows['interval_payback_date'] = \
        np.array(pred_pp.interval_payback_date, 'datetime64[D]')
    cashflows.rename(columns={'interval_payback_date': 'date',
                              'e_tot': 'payment'}, inplace=True)

    if actual is not None:
        act_fields = ['dwh_country_id', 'fk_loan', 'fk_user_investor', 'iso_date',
                      'eur_payment_amount_investor_month']
        act = actual[act_fields].rename(columns=\
            {'iso_date': 'date', 'payment_amount_investor_month': 'payment'})

        act.date = np.array(act.date, 'datetime64[D]')
    else:
        act = None
    cashflows = pd.concat([loans_orig, act, cashflows], ignore_index=True)
    return cashflows


def calc_NAR( act_pay_monthly, plan_repaid,
             act_filter, act_EOM_filter,
             max_payout_date, EOM_date,
             actual_payments_monthly,
             cash_keys):
    # NAR
    # convert to EUR

    interest_payments = \
        act_pay_monthly.loc[act_EOM_filter,
                            cash_keys + ['eur_interest_amount_investor_cum']]
    interest_payments_exc0 = \
        act_pay_monthly.loc[act_EOM_filter,
                            cash_keys +
                            ['eur_interest_amount_investor_cum_exc0']]
    interest_payments_int0 = \
        act_pay_monthly.loc[act_filter & (act_pay_monthly.interval == 0),
                            cash_keys + ['eur_interest_amount_investor']]
    initial_principal = \
        act_pay_monthly.loc[act_filter,
                            cash_keys +
                            ['interval',
                            'eur_initial_principal_amount_investor']]
    # remove 1st eur_initial_principal matching interval 0
    # ( ie to ignore vorlaufzinsen component)
    initial_principal_int0 = initial_principal[
                                initial_principal.interval == 0].\
                                groupby(cash_keys)\
                                ['eur_initial_principal_amount_investor'].\
                                first().\
                                reset_index()

    payments_repaid = \
        plan_repaid.loc[(plan_repaid.payout_date <= max_payout_date) &
                        (plan_repaid.interval > 0) &
                        (plan_repaid.interval_payback_date <= EOM_date.date()),
                        cash_keys +
                        ['eur_interest_amount_investor',
                         'eur_initial_principal_amount_investor']]
    in_arrears_fields = ['eur_interest_amount_investor',
                         'eur_residual_principal_amount_borrower',
                         'eur_residual_principal_amount_investor']
    in_arrears = act_pay_monthly.loc[act_EOM_filter,
                                     cash_keys + in_arrears_fields]

    in_arrears['recovery'] = \
        recovery(in_arrears['eur_residual_principal_amount_borrower'])
    in_arrears['recovery_principal'] = \
        in_arrears['recovery'] * \
        in_arrears['eur_residual_principal_amount_investor']
    in_arrears['lost_principal'] = \
        -(1-in_arrears['recovery']) * \
        in_arrears['eur_residual_principal_amount_investor']
    # irregular payments won't be handled correctly
    # ( mupltiple init princ in 1 month)

    nar_dict = {'interest_payments':
                    ('eur_interest_amount_investor_cum',interest_payments),
                'interest_payments_int0':
                    ('eur_interest_amount_investor', interest_payments_int0),
                'interest_payments_exc0':
                    ('eur_interest_amount_investor_cum_exc0', interest_payments_exc0),
                'initial_principal':
                    ('eur_initial_principal_amount_investor',
                     initial_principal),
                'initial_principal_int0':
                    ('eur_initial_principal_amount_investor',
                     initial_principal_int0),
                'payments_repaid':
                    (['eur_interest_amount_investor',
                    'eur_initial_principal_amount_investor'], payments_repaid),
                'in_arrears':
                    (['recovery_principal',
                      'lost_principal',
                      'eur_interest_amount_investor'], in_arrears)}
    gps_nar = {k: pd.DataFrame(cols_df[1].groupby('dwh_country_id',  'fk_loan')[cols_df[0]].sum())
               for k, cols_df in nar_dict.iteritems()
               if cols_df[1] is not None}
    # add in dataframe name to disambiguate

    nar_df = pd.concat(gps_nar, axis=1)
    arrears_fields = ['in_arrears_since', 'in_arrears_since_days',
                      'in_arrears_since_days_30360',
                      'bucket', 'bucket_pd']
    nar1 = nar_df.merge(actual_payments_monthly.
                        loc[actual_payments_monthly.iso_date ==
                            EOM_date.date(),
                            ['dwh_country_id', 'fk_loan'] + arrears_fields],
                        left_index= True,
                        right_on= ['dwh_country_id', 'fk_loan'])
    nar2 = nar1.merge(loans[['dwh_country_id', 'fk_loan',
                             'payout_quarter',
                             'payback_state',
                             'principal_amount']],
                             on=['dwh_country_id', 'fk_loan'])

    nar2['interest'] = nar2[[('interest_payments',
                              'eur_interest_amount_investor_cum'),
                              ('payments_repaid',
                               'eur_interest_amount_investor')]].sum(axis=1)
    nar2['interest'] -= nar2[('interest_payments_int0',
                              'eur_interest_amount_investor')].fillna(0)

    nar2['default_loss'] = (nar2['bucket'] >= 120) * \
                           nar2[('in_arrears', 'lost_principal')]
    nar2['note_status_adjustment'] = (nar2['bucket'] < 120) * \
                                     nar2['bucket_pd'] * \
                                     nar2[('in_arrears', 'lost_principal')]

    nar2['bucket0_lost'] = (nar2['bucket'] == 0) * \
                           nar2[('in_arrears', 'lost_principal')]
    nar2['bucket30_lost'] = (nar2['bucket'] == 30) *\
                            nar2[('in_arrears', 'lost_principal')]
    nar2['bucket60_lost'] = (nar2['bucket'] == 60) *\
                            nar2[('in_arrears', 'lost_principal')]
    nar2['bucket90_lost'] = (nar2['bucket'] == 90) *\
                            nar2[('in_arrears','lost_principal')]
    # sum ignores nans
    nar2['monthly_principals'] = \
        nar2[[('initial_principal','eur_initial_principal_amount_investor'),
              ('payments_repaid', 'eur_initial_principal_amount_investor')]].\
              sum(axis=1)
    nar2['monthly_principals'] = nar2['monthly_principals'] - \
        nar2[[('initial_principal_int0',
               'eur_initial_principal_amount_investor')]].\
        fillna(0).values.squeeze()
    nar2['top'] = nar2[['interest', 'default_loss']].sum(axis=1)
    nar2['nar'] = annualise(nar2['top']/nar2['monthly_principals'])
    nar2['adj nar'] = annualise(nar2['top', 'note_status_adjustment'].
                                sum(axis=1) /
                                nar2['monthly_principals'])
    nar2.set_index(['dwh_country_id', 'fk_loan'], inplace=True)
    return nar2


def calc_IRR(loans, loan_fundings,
             act_pay_monthly, act_pay_date,
             plan_repaid, plan_pay,
             act_pay_monthly_filter, act_pay_monthly_EOM_filter,
             act_pay_date_filter,
             plan_filter,
             max_payout_date, EOM_date, cash_keys, filtered_de_payments,
             arrears_dict):
    # IRR
    loan_principals_monthly = \
        loan_fundings.loc[
            (loan_fundings.payout_date <=
                max_payout_date) &
            ~((loan_fundings.dwh_country_id==1) &
              loan_fundings.fk_loan.isin(filtered_de_payments)),
            cash_keys + ['payout_date_EOM', 'dcf_EOM', 'payment']].\
            rename(columns={'dcf_EOM': 'dcf'})
    loan_principals_date = \
        loan_fundings.loc[
            (loan_fundings.payout_date <=
                max_payout_date) &
            ~((loan_fundings.dwh_country_id==1) &
              loan_fundings.fk_loan.isin(filtered_de_payments)),
            cash_keys + ['payout_date', 'dcf', 'payment']]

    # loan payments may have payments for loans that have been filterd out
    loan_payments_monthly=act_pay_monthly.loc[act_pay_monthly_filter,
                    cash_keys + [ 'dcf', 'payment_amount_investor_month']]\
                .rename(columns={'eur_payment_amount_investor_month': 'payment'})

    loan_payments_date=act_pay_date.loc[act_pay_date_filter,
                    cash_keys + [ 'dcf', 'payment_amount_investor']]\
                .rename(columns={'eur_payment_amount_investor_change': 'payment'})



    # what to do if no matching interval ( borrower never paid?)
    residuals_monthly, recoveries_monthly = generate_residual_act_investor(
                                act_pay_monthly[act_pay_monthly_filter],
                                loan_fundings,
                                EOM_date.date(),
                                payment_plans=plan_pay[plan_filter])
    # do we need separate function?
    residuals_date, recoveries_date = generate_residual_act_investor_date(
                                act_pay_date[act_pay_date_filter],
                                plan_pay[plan_filter],
                                act_pay_monthly[act_pay_monthly_EOM_filter],
                                loan_fundings,
                                )

    # Expected IRR
    lpi_fields = ['iso_date', 'dwh_country_id', 'fk_loan',
                  'fk_user_investor','interval']
    latest_paid_interval_investor = \
        act_pay_monthly.loc[act_pay_monthly_filter, lpi_fields]\
        .sort('iso_date', inplace=False)\
        .groupby(['dwh_country_id', 'fk_loan', 'fk_user_investor']).interval.last()
    latest_paid_interval_investor.name='latest_paid_interval'
    if plan_pay[plan_filter].shape[0]>0:
        future_cashflows = make_future_pd(plan_pay[plan_filter], act_pay_monthly[act_pay_monthly_EOM_filter],loans,
                        arrears_dict, True,EOM_date.date(),latest_paid_interval_investor)
        expected_cashflows = future_cashflows[cash_keys + ['dcf', 'e_tot']].copy()
        expected_cashflows = expected_cashflows.rename(columns={'e_tot': 'payment'})
    else:
        expected_cashflows=None

    repaid_loans_cash = plan_repaid.loc[plan_repaid.payout_date <= max_payout_date,
                                        cash_keys + ['interval_payback_date', 'dcf', 'eur_payment_amount_investor']]\
                                   .rename(columns={'eur_payment_amount_investor':'payment'})

    cash_list_actual_monthly = drop_none([loan_principals_monthly,
                                  loan_payments_monthly,
                                  residuals_monthly,
                                  recoveries_monthly,
                                  repaid_loans_cash])

    cash_list_actual_date = drop_none([loan_principals_date,
                                  loan_payments_date,
                                  residuals_date,
                                  recoveries_date,
                                  repaid_loans_cash])



    cash_list_expected_monthly =  drop_none([loan_principals_monthly,
                                     loan_payments_monthly,
                                     expected_cashflows,
                                     repaid_loans_cash])

    cash_list_expected_date =  drop_none([loan_principals_date,
                                     loan_payments_date,
                                     expected_cashflows,
                                     repaid_loans_cash])

    return {'cash_list_actual_monthly'  : cash_list_actual_monthly,
             'cash_list_actual_date':  cash_list_actual_date,
            'cash_list_expected_monthly': cash_list_expected_monthly,
            'cash_list_expected_date': cash_list_expected_date
            }


def calc_IRR_groups(EOM_date, splits, cash_lists, actual_payments_monthly):
    gps_actual={}
    gps_expected={}
    xirrs={}

    split='overall'
    gps_actual[split]=[zx.groupby(['dcf']).payment.sum().reset_index('dcf') \
                     for zx in cash_lists['cash_list_actual']]

    gps_expected[split]=[zx.groupby(['dcf']).payment.sum().reset_index('dcf') \
                     for zx in cash_lists['cash_list_expected']]

    actual_monthly_overall = xirr(gps_actual[split])
    expected_monthly_overall = xirr(gps_expected[split])
    
    for split in splits:
        gps_actual[split] = group_payment_sum(cash_list_actual, split)
        gps_expected[split] = group_payment_sum(cash_list_expected, split)

    for split in (splits ):
        act_irr=xirr_group(gps_actual[split])
        exp_irr=xirr_group(gps_expected[split])
        xirrs[split] = \
            pd.DataFrame({'actual': act_irr if act_irr.shape[0]>0 else [],
                          'expected': exp_irr if exp_irr.shape[0]>0 else []})

    xirrs[('dwh_country_id', 'fk_loan')] = \
        xirrs[('dwh_country_id', 'fk_loan')].merge(\
            actual_payments_monthly.loc[actual_payments_monthly.iso_date ==
                               EOM_date.date(),
                               ['dwh_country_id', 'fk_loan',
                               'in_arrears_since', 'in_arrears_since_days',
                               'in_arrears_since_days_30360','bucket','bucket_pd']],
        left_index=True, \
        right_on=['dwh_country_id', 'fk_loan'])

    # index dropped when merge?

    xirrs[('dwh_country_id', 'fk_loan')] = xirrs[('dwh_country_id', 'fk_loan')].merge(loans[['dwh_country_id', 'fk_loan','rating_base','rating_switch','payback_state']],
                                          on=['dwh_country_id', 'fk_loan'])
    xirrs[('dwh_country_id', 'fk_loan')].set_index('dwh_country_id', 'fk_loan',inplace=True)

    return actual_monthly_overall, expected_monthly_overall, xirrs



def add_loan_rating(cashflows, loans):
    return cashflows.merge(loans[
        ['dwh_country_id', 'fk_loan', 'payout_date', 'rating_base', 'base_date',
         'base_return', 'payback_state']],
         on=['dwh_country_id', 'fk_loan'], how='left')


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
