# -*- coding: utf-8 -*-
"""
Created on Thu Jul 16 18:55:58 2015

@author: Sean Violante
"""

from __future__ import division
import pandas as pd
import numpy as np
import datetime

import pandas.io.sql as psql
import pandas as pd
import sys
import xml.etree.ElementTree as ET
from bs4 import BeautifulSoup
import json
import requests
import re
import datetime



ns={'schufa':'http://www.schufa.de/siml/2.0/final'}

def get_scoring(con):
    scoring = psql.read_sql(""" 
    select * 
    from backend.scoring_result sr
    where sr.dwh_country_id=1 and sr.created_at>'2015-07-07' """, con)
    return scoring
    

    loan_requests = psql.read_sql("""
    select 
        lr.id_loan_request, 
        lr.loan_request_nr, 
        sr.fk_user,
        sr.id,
        lr.principal_amount,
        ua.net_income,
        uh.postcheck_data
    from base.loan_request lr
    join base.user_account ua on 
        lr.dwh_country_id=ua.dwh_country_id and
        lr.fk_user=ua.id_user
    join backend.loan_request_user_history uh on 
        lr.dwh_country_id=uh.dwh_country_id and
        lr.id_loan_request=uh.fk_loan_request
    join backend.scoring_result sr on
        lr.dwh_country_id=sr.dwh_country_id and
        lr.fk_user=sr.fk_user
    
    where sr.dwh_country_id=1 and sr.created_at>'2015-07-07'
    and sr.is_latest=1
    """,con)
    return loan_requests

    
    
def php_strip(a):
    b=a[a.find('"')+1:-2]
    return b

def xml_strip(b):
    #root = ET.XML(b,xml_parser)
    #if b!='ANONYMOUS_REQUEST':
    # 'ANONYMOUS_REQUEST', u'deleted_user'
    try:
        root = ET.fromstring(b.encode('UTF-8'))
    except ET.ParseError:
        root=None
    return root


def strip_ns(name):
    if name[0]=='{':
        uri, tag = name[1:].split("}")
    else:
        uri, tag = (None, name)
    return uri, tag
        
    
def record_parse(m):
    line={}
    
    for ch in m.iter():
        uri, tag=strip_ns(ch.tag)
        text=ch.text
        
        text = re.sub('[\n\t]', '', text)
        #merkmal line has just formatting
        if len(text)>0:
            line[tag]=text
        for key,value in ch.attrib.iteritems():
            line[tag+'_'+key]=value
        
    return line


def cat_parse(root, cat):
    
    elems=root.findall('.//schufa:'+cat,ns)

    lis=[]
    for x in elems:
        lis.append(record_parse(x))
    return pd.DataFrame(lis)

def schufa_parse(root):
    #root= xml_strip(s)
    if root is None:
        return None
    df=cat_parse(root,'Merkmal')
    if df.shape[0]>0:
        df['Merkmal_id']=(df['Merkmal_typ'].isin(['hauptmerkmal', 'einzelmerkmal'])).cumsum()
    return df


def match_id(df,select):
    # find all groups satisfying select.
    # need to drop duplicates otherwise the join will duplicate too
    keys=df.Merkmal_id[select].\
        reset_index()[['dwh_country_id','id','Merkmal_id']].drop_duplicates()
    
    b=df.reset_index().\
        merge(keys,on=['dwh_country_id','id','Merkmal_id'])
    
    return b.set_index(['dwh_country_id','id','record'])


def drop_id(df,select):
    df1=match_id(df, select)
    df1['XXX']=True
    df2=df.join(df1['XXX'],how='left')
    df3=df2[df2.XXX.isnull()]
    del df3['XXX']
    return df3


def drop_paid_off(df):
    return drop_id(df, df.Merkmalcode=='ER')


def json_extract(s, class_name):
    cats=['actual','expected','operator','status']
    if s =='null':
        return pd.Series(data=[None, None, None, None],index=cats)
    js=json.loads(s)
    
    for o in js:
        if o['class'] in class_name:
            return pd.Series(map(lambda x: o[x],cats),index=cats)
    return pd.Series(data=[None, None, None, None], index=cats)



def extract_indebtedness(loan_requests):

    indebt = loan_requests.postcheck_data.apply(json_extract,
                                    class_name='SchufaIndebtedness')
    indebt.rename(columns=lambda x: 'indebt:'+x, inplace=True)
    loan_requests1 = pd.concat((loan_requests, indebt), axis=1)
    return loan_requests1

def parse_scoring(scoring):
    """ set index to scoring id and extract merkmale data from schufa"""
    scoring_ind=scoring.set_index(['dwh_country_id','id'])
    scoring_ind['response_x']=scoring_ind['response'].map(php_strip)
    scoring_ind['response_len']=scoring_ind['response_x'].str.len()
    scoring_ind['response_root']=scoring_ind['response_x'].map(xml_strip)
    scoring_ind['response_merkmale']=scoring_ind['response_root'].map(schufa_parse)
    return scoring_ind

def extract_merkmale(scoring_ind):
    """ join up all parsed merkmale dataframes and clean up (dates/values) """
    merkmale = pd.concat(scoring_ind['response_merkmale'].values, keys=scoring_ind.index, 
                       names=['dwh_country_id', 'id', 'record'])
    merkmale['Betrag']=merkmale['Betrag'].astype(np.float64) #is string, float to allow NAN
    merkmale['Ratenzahl']=merkmale['Ratenzahl'].astype(np.float64)
    merkmale['Date'] = \
        pd.to_datetime(merkmale.Datum, 
                       coerce=True, 
                       format='%d.%m.%Y') 
    #pandas has problems with mixed data..need to select only real dates 
    # (or use coerce)

    return merkmale
    
def calc_creditworthy(merkmale):
    merkmale['not_creditworthy']=merkmale.Merkmalcode.isin(['KW', 'RB', 'RV', 'S1', 'S2', 'S3', 'IE', 'EV', 'IA', 'HB', 'RA'])
    KRML_US=match_id(merkmale, merkmale.Merkmalcode.isin(['KR','ML']))
    KRML_US['not_creditworthy_US']=(KRML_US.Merkmalcode=='US')
    merkmale['not_creditworthy_US']=KRML_US['not_creditworthy_US']
    KRMLKWKX_US=match_id(merkmale, merkmale.Merkmalcode.isin(['KR','ML','KW','KX']))
    KRMLKWKX_US['not_creditworthy_US']=(KRMLKWKX_US.Merkmalcode=='US')
    merkmale['not_creditworthy_KRMLKWKX_US']=KRMLKWKX_US['not_creditworthy_US']
    return merkmale
    
def calc_additional_limit(merkmale):    
    additional_limit=match_id(merkmale, merkmale.Merkmalcode.isin(['XX','RK','CR']))
    # add KG

    additional_limit_paid_off=match_id(additional_limit, additional_limit.Merkmalcode=='ER')
    additional_limit_outstanding=drop_paid_off(additional_limit)
    additional_limit_outstanding_user = \
        additional_limit_outstanding.groupby(level=['dwh_country_id','id']).\
            Betrag.sum()
    additional_limit_outstanding_user.name = 'add_Betrag'
    return additional_limit_outstanding_user
    
def calc_LOC(merkmale):    
    LOC=match_id(merkmale, merkmale.Merkmalcode.isin(['GI']))
    LOC=match_id(LOC, LOC.Merkmalcode=='KG')
    LOC_paid_off=match_id(LOC, LOC.Merkmalcode=='ER')
    LOC_outstanding=drop_paid_off(LOC)
    LOC_outstanding_user=LOC_outstanding.groupby(level=['dwh_country_id','id']).Betrag.sum()
    LOC_outstanding_user.name='LOC_Betrag'
    return LOC_outstanding_user


def calc_installments(issued,now):
    return (now.year - issued.year)*12 + \
        (now.month - issued.month) + 1 - 1 * (issued.day > now.day)


def today_str():
    return datetime.date.today().strftime('%Y%m%d')

def calc_net_loans(merkmale, today_string):
    # note that yearly payments are treated as 12 monthly payments
    # so we actually assume that within the year debt has gone down
    net_loans=match_id(merkmale, merkmale.Merkmalcode.isin(['KR','ML']))
    net_loans_exclude_US=drop_id(net_loans,net_loans.Merkmalcode=='US')
    net_loans_exclude_US_outstanding=drop_paid_off(net_loans_exclude_US)

    now_date=pd.Timestamp(today_string)
    KR_select=net_loans_exclude_US_outstanding.Merkmalcode.isin(['KR','ML'])
    net_loans_exclude_US_outstanding.loc[KR_select,'paid_installments'] = \
        calc_installments(net_loans_exclude_US_outstanding.loc[KR_select,'Date'].dt,
                          now_date)
    
    net_loans_exclude_US_outstanding.loc[KR_select,'Ratenzahl_Month'] = \
        net_loans_exclude_US_outstanding.loc[KR_select,'Ratenzahl']
    net_loans_exclude_US_outstanding.loc[KR_select & 
        (net_loans_exclude_US_outstanding.Ratenart=='J'),'Ratenzahl_Month'] = \
        12 *net_loans_exclude_US_outstanding.loc[KR_select,'Ratenzahl']

    net_loans_exclude_US_outstanding.loc[KR_select,'paid_installments'] = \
        net_loans_exclude_US_outstanding.loc[KR_select,['Ratenzahl_Month',
                                            'paid_installments']].min(axis=1)
           
    net_loans_exclude_US_outstanding.loc[KR_select,'installment'] = \
        (1.3 * net_loans_exclude_US_outstanding.loc[KR_select, 'Betrag']).\
        floordiv(net_loans_exclude_US_outstanding.loc[KR_select,
                                                      'Ratenzahl_Month'])
    
    net_loans_exclude_US_outstanding.loc[KR_select,'loan_gross_amount'] = \
        net_loans_exclude_US_outstanding.loc[KR_select,'installment'] * \
        net_loans_exclude_US_outstanding.loc[KR_select,'Ratenzahl_Month']

    net_loans_exclude_US_outstanding.loc[KR_select,'loan_gross_outstanding_amount'] = \
        net_loans_exclude_US_outstanding.loc[KR_select,'loan_gross_amount'] - \
        net_loans_exclude_US_outstanding.loc[KR_select,'installment'] * \
        net_loans_exclude_US_outstanding.loc[KR_select,'paid_installments']

    net_loans_exclude_US_outstanding.loc[KR_select,'outstanding_installments'] = \
        net_loans_exclude_US_outstanding.loc[KR_select,'Ratenzahl_Month'] - \
        net_loans_exclude_US_outstanding.loc[KR_select,'paid_installments']

    net_loans_exclude_US_outstanding.loc[KR_select,'interest'] = \
        net_loans_exclude_US_outstanding.loc[KR_select,'loan_gross_amount'] - \
        net_loans_exclude_US_outstanding.loc[KR_select,'Betrag']
    
    net_loans_exclude_US_outstanding.loc[KR_select,'interest_allowance'] = \
        (net_loans_exclude_US_outstanding.loc[KR_select,'interest'].mul(
        net_loans_exclude_US_outstanding.loc[KR_select,'outstanding_installments']-4).mul(
        net_loans_exclude_US_outstanding.loc[KR_select,'outstanding_installments']-3)/ 
        (net_loans_exclude_US_outstanding.loc[KR_select,'Ratenzahl_Month'].mul(
            net_loans_exclude_US_outstanding.loc[KR_select,'Ratenzahl_Month']+1))).round(2)
    net_loans_exclude_US_outstanding.loc[KR_select,'net_value'] = np.maximum( 0,
        net_loans_exclude_US_outstanding.loc[KR_select,'loan_gross_outstanding_amount'] - \
        net_loans_exclude_US_outstanding.loc[KR_select,'interest_allowance'])
    
    net_loans_exclude_US_outstanding_user = net_loans_exclude_US_outstanding.\
        groupby(level=['dwh_country_id','id'])\
        ['Betrag','loan_gross_amount', 'loan_gross_outstanding_amount', 
         'interest','interest_allowance', 'net_value'].sum()
    net_loans_exclude_US_outstanding_user.rename(columns={'Betrag':'net_loan_Betrag'},inplace=True)
    return net_loans_exclude_US_outstanding_user
    
    
def calc_indebtedness(loan_requests, not_creditworthy_user, 
                      additional_limit_outstanding_user,  
                      LOC_outstanding_user, 
                      net_loans_exclude_US_outstanding_user):
    all_user=pd.concat((not_creditworthy_user, 
                        additional_limit_outstanding_user,  
                        LOC_outstanding_user, 
                        net_loans_exclude_US_outstanding_user),axis=1)
                   
                   
    lr_all_user = loan_requests.merge(all_user.reset_index(),on='id')
    lr_all_user['net_debt'] = lr_all_user[
        ['net_value','principal_amount','LOC_Betrag','add_Betrag']
        ].sum(axis=1) # sum removes NAN
    lr_all_user['debt_ratio'] = lr_all_user['net_debt'] / \
        lr_all_user['net_income']
    return lr_all_user

def parse_indebt_table(html):
    soup = BeautifulSoup(html, "html")
    table = soup.find('table', {'class': 'table table-striped'})
    tdList = table.findAll('td')
    td_key=map(lambda x: x.text,tdList[0::2])
    td_value=map(lambda x: x.text,tdList[1::2])
    # get rid of EUR    
    td_value=[re.sub(u' \u20ac','',td) for td in td_value]
    
    # convert from german decimal
    td_value=[re.sub(u'[.%]','',td) for td in td_value]
    td_value=[re.sub(',','.',td) for td in td_value]
    data=dict(zip(td_key,td_value))
    del data['']
    
    return data

def get_web_indebtedness(id_loan_requests):
    indebt_addr = 'https://admin.lendico.de/admin/loan-request/display-indebtedness-details/'   
    data=[]
    
    payload={'_username':'sean.violante@lendico.de',
         '_password': '7642lottA!!',
        'login':'Login'}

    headers = {'User-Agent': 'Mozilla/5.0'}
    with requests.Session() as s:
        s.auth=('lendico_beta', 'p2pLend4every1')
        r1 = s.get('https://admin.lendico.de/admin')
        p = s.post('https://admin.lendico.de/admin/login_check', headers=headers, data=payload)
        
        for  id_loan_request in id_loan_requests:            
            r = s.get(indebt_addr + str(id_loan_request))
            data_row = parse_indebt_table(r.text)
            data_row['id_loan_request'] = id_loan_request
            data.append(data_row)
    df =pd.DataFrame.from_records(data,index='id_loan_request')
    del df['Debt Calculation']
    df['Creditworthy?']=(df['Creditworthy?']=='Yes')
    for c in df.columns:
        if c != 'CreditWorthy?':
            df[c]=df[c].astype(np.float)
    return df            
    