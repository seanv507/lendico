# -*- coding: utf-8 -*-
"""
Created on Wed Sep 02 17:33:50 2015

@author: Sean Violante
"""

filenamespu=get_filenames(u'../users','*.xlsm')
df1 = filename_analyse(filenamespu)
underwriting_df = load_underwriting(filenamespu)

underwriting_df.to_csv('underwriting_df_20150909.csv',encoding='utf-8')

con = dwh.get_DWH()
id_loan_requests=pd.concat((
                            df1.id_loan_request.dropna(),
                            underwriting_df["Loan ID"].dropna()),
                           ignore_index=True).unique()

lr_lookup = read_loan_nr(con, df1.loan_nr.dropna(), id_loan_requests)
df2 = df1.merge(lr_lookup,how='left', 
              left_on='loan_nr',
              right_on='loan_request_nr',
              suffixes=('_orig','_loan_nr'))
df3 = df2.merge(lr_lookup,how='left', 
              left_on='id_loan_request_orig',
              right_on='id_loan_request',
              suffixes=('','_id_loan_request'))
             
mg = underwriting_df.reset_index().merge(df3,left_on='filename',right_on='fullname')


mg['loan_request_nr_comb'] = np.where(mg.loan_request_nr.notnull(),
                                      mg.loan_request_nr,
                                      mg.loan_request_nr_id_loan_request)
mg['id_loan_request_comb'] = np.where(mg.id_loan_request.notnull(),
                                      mg.id_loan_request,
                                      mg.id_loan_request_loan_nr)
mg['last_name_comb'] = np.where(mg.last_name.notnull(),
                                mg.last_name,
                                mg.last_name_id_loan_request)
mg['first_name_comb']=np.where(mg.first_name.notnull(),
                               mg.first_name,
                               mg.first_name_id_loan_request)
                               
mg.to_csv('underwriting_data_20150909.csv', encoding='utf-8')

# warning need to ensure that no text in loan_request_nr override column 
# otherwise column will be treated as text (ie including numbers)
loan_nr_overrides=pd.read_csv('loan_nr_overrides_20150909.csv', encoding='utf-8')

match_names_sql=dwh.read_sql_str('match_names.sql')

match_names=pd.read_sql(match_names_sql,con)

first_lates_sql=dwh.read_sql_str('first_lates.sql', dir_name='../../returns/src')
first_lates_EOM_sql=dwh.read_sql_str('first_lates_EOM.sql', dir_name='../../returns/src')

first_lates=pd.read_sql_query(first_lates_sql,con)

mg1 = mg.merge(loan_nr_overrides[['filename','loan_request_nr_override','checked']],
              on='filename', how='left')
mg1 = mg1.merge(match_names[['l_loan_nr',
                            'lr_loan_request_nr',
                            'l_last_name',
                            'lr_last_name',
                            'l_first_name',
                            'lr_first_name',
                            ]],
              left_on='loan_request_nr_comb',
              right_on='lr_loan_request_nr',
              how='left')
              
mg1['loan_request_nr_comb_over'] = np.where(
                                      mg1.loan_request_nr_override.notnull(),
                                      mg1.loan_request_nr_override,
                                      np.where(mg1.lr_loan_request_nr.notnull(),
                                               mg1.lr_loan_request_nr,
                                               mg1.loan_request_nr_comb))

# reorder and filter out columns
underwriting_merge = mg1[column_ordering]




underwriting_merge.shape

issued_loans=get_issued_loans(con)

web_capacity=get_web_capacity(issued_loans.fk_loan_request)
web_capacity.to_csv('web_capacity.csv',index=False)

issued_loans_capacity=issued_loans.merge(web_capacity,left_on='fk_loan_request',right_index=True)

issued_loans_capacity.to_csv('issued_loans_capacity.csv',index=False)
#issued_loans_capacity=pd.read_csv('../../Indebtedness/src/issued_loans_capacity.csv')

web_indebtedness=get_web_indebtedness(issued_loans.fk_loan_request)

web_indebtedness.to_csv('web_indebtedness.csv')
gblrc=get_issued_loans_gblrc(con)
gblrc.to_csv('gblrc.csv',encoding='utf-8')

gblrc_underwriting=gblrc.merge(underwriting_merge,
                               left_on='loan_request_nr',
                               right_on='loan_request_nr_comb_over',
                               suffixes=('_gblrc','_und'),
                               how='left')
dpd=pd.read_csv('dpd90.csv')

gblrc_underwriting_dpd=gblrc_underwriting.merge(dpd,
                                                left_on='loan_request_nr_gblrc',
                                                right_on='loan_request_nr',
                                                how='left')
                                                
web_indebtedness=pd.read_csv('web_indebtedness.csv')
gblrc_underwriting_dpd_web_ind=gblrc_underwriting_dpd.merge(web_indebtedness,
                                                            left_on='id_loan_request_gblrc',
                                                            right_on='id_loan_request',
                                                            how='left'
                                                            )

gblrc_underwriting_dpd_web_ind_web_cap = gblrc_underwriting_dpd_web_ind.\
    merge(web_capacity.reset_index(),
          left_on='id_loan_request_gblrc',
          right_on='id_loan_request',how='left')

id_columns= [u'fk_loan', u'loan_request_nr']
gblrc_underwriting_dpd_web_ind_web_cap_first_lates = \
    gblrc_underwriting_dpd_web_ind_web_cap.\
        merge(first_lates_EOM.drop(id_columns,axis=1),
          left_on='id_loan_request_gblrc',
          right_on='fk_loan_request',how='left')
