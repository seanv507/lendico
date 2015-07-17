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
import json
import requests
import re




ns={'schufa':'http://www.schufa.de/siml/2.0/final'}

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
    