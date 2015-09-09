# -*- coding: utf-8 -*-
"""
Created on Fri Aug 28 19:08:10 2015

@author: Sean Violante
"""
import numpy as np
import pandas as pd
import xlrd
import zipfile
import os
import re
import fnmatch




import string

import functools

#@functools.lru_cache(maxsize=4095)
def edit_distance(s, t):
    # http://rosettacode.org/wiki/Levenshtein_distance#Python
	if not s: return len(t)
	if not t: return len(s)
	if s[0] == t[0]: return ld(s[1:], t[1:])
	l1 = ld(s, t[1:])
	l2 = ld(s[1:], t)
	l3 = ld(s[1:], t[1:])
	return 1 + min(l1, l2, l3)


def load_underwriting(filenames):
    capacity_table=pd.read_csv('capacity_cells01.csv')
    records=[]
    for i_filename, filename in enumerate(filenames):
        strip_name=filename.split('\\')[-1].split('.')[0]
        print i_filename, strip_name
        # openpyxl crashes on underwriting sheets (first complained of missing ref. then updated open pyxl
     #  __init__() got an unexpected keyword argument 'hashValue')
        try:
            wb = xlrd.open_workbook(filename = filename)
            lis = read_capacity(wb, capacity_table)
        except (IOError,xlrd.XLRDError, zipfile.BadZipfile), e:
            lis={}
            lis['IOError']=str(e.args)
        records.append(lis)
        
    df=pd.DataFrame.from_records(records, 
                                 index=pd.Series(filenames,name='filename'))
    return df
    
def row_col(address):
    address= address.lower()
    letters = re.findall('[a-z]',address)
    
    row = int(re.findall('[0-9]+',address)[0])-1
    col =0
    for i,l in enumerate(letters):
        
        pw = 26**(len(letters)-i-1)
        
        ps = string.lowercase.index(l)
        if pw >1:
            # have b -> index 1
            #ab -> 26+1 (ie higher indices have '0' element)
            ps+=1
        col += ps*pw
    return row,col

def get_filenames(startdir,pattern):
    # need to find a way of excluding xl backup files ~xxx ?
# glob is not recursive
    matches = []
    for root, dirnames, filenames in os.walk(startdir):
        for filename in fnmatch.filter(filenames, pattern):
            matches.append(os.path.join(root, filename))    
    return matches
    
def read_capacity(wb, capacity_table):
    n_values = capacity_table.shape[0]
    #values=np.empty((n_values, 1))
    #values.fill(np.nan)
    values={}
    for i_value in range( n_values):
        sheet_name = capacity_table['sheet'].loc[i_value]
        key_cell = capacity_table['key_cell'].loc[i_value]
        value_cell = capacity_table['value_cell'].loc[i_value]
        try:
            sheet = wb.sheet_by_name(sheet_name)
            key_text_value = sheet.cell_value(*row_col(key_cell))
            if key_text_value!="":
                value_cell_value = sheet.cell_value(*row_col(value_cell))
                values[key_text_value] = value_cell_value
        except (xlrd.XLRDError, IndexError), e:
            pass
        #if key_text_value==key_text:
            #values[i_value] = wb.sheet_by_name(sheet).cell_value(*row_col(value_cell))
    return values
    
def filename_analyse(filenames):
    df=pd.DataFrame(filenames)
    df.columns=['fullname']
    splits=df['fullname'].str.split('\\',return_type='frame')
    n_cols=splits.shape[1]
    df[['path_'+str(i) for i in range(n_cols)]]=splits
    df['loan_nr']=np.nan
    for i in range(n_cols):
        df['path_sheet_'+str(i)]=df['path_'+str(i)].str.contains('.xlsm')
        df['path_number_'+str(i)]=strip_number(df['path_'+str(i)])
        df['path_number_len_'+str(i)]=df['path_number_'+str(i)].str.len()
    
        ind = (df['path_number_len_' + str(i)] > 6 )
        df.loc[ ind, 'loan_nr'] = \
            df.loc[ind,'path_number_'+str(i)].astype(np.int)
        ind = (df['path_sheet_' + str(i)] ) & \
            (df['path_number_len_' + str(i)] <= 6 )
        df.loc[ind,'id_loan_request'] = \
            df.loc[ind, 'path_number_' + str(i)].astype(np.int)
    ind = (df['path_sheet_4' ]  ) & (df['path_number_4' ].notnull()  ) 
    df.loc[ind,'id_loan_request']=df.loc[ind, 'path_number_4'].astype(np.int)
    return df

def strip_number(ser):
    return ser.str.extract('([0-9]+)')
    # remove . onward
    # find 7-10 digit number

# given loan request or loan number get 


#def loan_nr_    
def read_loan_nr(con, loan_nrs,id_loan_requests):
    loan_nrss=[str(s) for s in loan_nrs]
    id_loan_requestss=[str(s) for s in id_loan_requests]
    l_n_s='(' + ', '.join(loan_nrss) +')'
    i_l_s='(' + ', '.join(id_loan_requestss) +')'
    sql='''select 
            id_loan_request, 
            loan_request_nr, 
            id_user, 
            last_name,
            first_name
            from 
            base.loan_request lr join 
            base.user_account ua
            on lr.dwh_country_id=ua.dwh_country_id and
            lr.fk_user=ua.id_user
            where
            lr.dwh_country_id=1 and 
            (lr.loan_request_nr in {0} or
            lr.id_loan_request in {1})'''.format(l_n_s,i_l_s)
    df=pd.read_sql_query(sql,con)
    return df
    
def script():
    # pasting from history
    filenamespu=get_filenames(u'../users','*.xlsm')
    df1=filename_analyse(filenamespu)
    underwriting_df=load_underwriting(filenamespu)
    con=dwh.get_DWH()
    lr_lookup=read_loan_nr(con, df1.loan_nr.dropna(), df1.id_loan_request.dropna())
    df2=df1.merge(lr_lookup,how='left', 
                  left_on='loan_nr',
                  right_on='loan_request_nr',
                  suffixes=('_orig','_loan_nr'))
    df3=df2.merge(lr_lookup,how='left', 
                  left_on='id_loan_request_orig',
                  right_on='id_loan_request',
                  suffixes=('','_id_loan_request'))
                 
    mg=underwriting_df.reset_index().merge(df3,left_on='filename',right_on='fullname')
    underwriting_merge=mg[column_ordering]
    underwriting_merge.shape
    underwriting_merge.to_csv('underwriting_data.csv', encoding='utf-8')

column_ordering=[
'filename',
'IOError',


'loan_nr',
u'loan_request_nr',
u'loan_request_nr_id_loan_request',
u'loan_request_nr_comb',
u'loan_request_nr_override',
u'loan_request_nr_comb_over',
u'Loan ID',
u'id_loan_request',
'id_loan_request_orig',
u'id_loan_request_loan_nr',
u'Id user',
u'id_user',
u'id_user_id_loan_request',
u'Last Name',
u'last_name',
u'last_name_id_loan_request',
u'First Name',
u'first_name',
u'first_name_id_loan_request',
u'Gender',
u'Gehalt / Rente s. Abrechnung',
u'Gehalt s. Abrechnung',
u'Gehalt/Rente s. Abrechnung',
u'Einkommen aus selbstst\xe4ndiger T\xe4tigkeit',
u'evtl. Kindergeld (wenn Kind im Haushalt - automatisch berrechnet)',
u'evtl. Kindergeld (wenn Kind im Haushalt)',
u'Rente',
u'evtl. Unterhaltseink\xfcnfte lt. Nachweis',
u'evtl. Mieteinnahmen lt. Nachweis',
u'evtl. sonstige Einnahmen lt. Nachweis',
u'evtl. Nebenjob lt. Nachweis',
u'evtl. Zinseinnahmen lt. Nachweis',
u'evtl. Krankenversicherung',
u'a. Summe Einnahmen',
u'Lebenshaltungskosten',
u'Miete o. Baufirate  ',
u'Kosten der Unterkunft (Warmmiete od. BauFi+Nebenkosten)',
u'evtl. Fremdkreditraten (kein BauFi)',
u'd. evtl. Fremdkreditraten (alle)',
u'evtl. Unterhaltszahlung (Kosten)',
u'Leasingraten',
u'Sonstige Kosten',
u'andere Kosten, die wir ansetzen:',
u'andere mon. Kosten s. Kontoauszug',
u'b. Summe Kosten',
u'e. evtl. abzul\xf6sende Fremdkreditrate',
u'evtl. abzul\xf6sende Fremdkreditraten',
u'f. frei f\xfcr neuen Kredit eigen',
u'c. Deckungsbetrag',
u'g. neue Kreditrate lt. Antrag',
u'g. neue Kreditrate lt. Antrag ',
u'h. Ergebnis Kalkulation',
u'Inkassoraten',
u'SUMME (aller Nettobetr\xe4ge fremd)',
u'NeuKredit_netto (Lendico)',
u'Dispo-Limit laut Kontoauszug',
u'sonstige Limite (laut Schufaauskunft)',
u'Netto-Verbindlichkeit (Gesamt)',
u'Verschuldungsgrad ',
u'Nettogehalt', 
u'Nettoverbindlichkeiten',
'path_0', 'path_1', 'path_2', 'path_3', 'path_4', 'path_5', 'path_6',
'path_sheet_0', 'path_number_0', 'path_number_len_0',
 'path_sheet_1', 'path_number_1', 'path_number_len_1', 
 'path_sheet_2', 'path_number_2', 'path_number_len_2', 
 'path_sheet_3', 'path_number_3', 'path_number_len_3', 
 'path_sheet_4', 'path_number_4', 'path_number_len_4', 
 'path_sheet_5', 'path_number_5', 'path_number_len_5', 
 'path_sheet_6', 'path_number_6', 'path_number_len_6', 
 'fullname'
 ]

    
os.chdir(r'C:\Users\Sean Violante\Documents\Projects\lendico\Projects\Underwriting\src')     
#filenames=pd.read_csv('dirlist.txt')
# problem with reading unicode from cmd into python (better to directly do in python)
#with open('dirlistu.txt') as f:
#    filenamesu=f.readlines()
#filenamesu=[ f.strip() for f in filenamesu
#wb=openpyxl.load_workbook(filenames[2],keep_vba=False)
#wb=xlrd.open_workbook(filenamesu[2])


dpd90_loan_nr=[711135326,
891217189,
795500338,
617638520,
132774479,
228740690,
993890022,
77995857,
222659078,
144453794,
563484430,
68722247,
466839637,
383601591,
614781009,
133848560,
191351526,
783844396,
852438379,
435591349,
152625287,
867916904,
686052166,
336002356,
251659337,
973546972,
314881037,
66865355,
612195333,
357432900,
250768438,
621914299,
497521512,
971733773,
140232261,
67052570,
958674197,
703309030,
233678116,
849498645,
407516696,
490904055,
801857330,
1410001,
826662185,
369383523,
142502050,
29559170,
679251816,
881022127,
326074574,
348819947,
756781058,
761039062,
517264955,
671851891,
879113405,
753457790,
515323631,
165762634,
289439086,
488438265,
267515550,
717366316,
198217436
]