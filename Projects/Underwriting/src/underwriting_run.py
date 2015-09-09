# -*- coding: utf-8 -*-
"""
Created on Wed Sep 02 17:33:50 2015

@author: Sean Violante
"""

filenamespu=get_filenames(u'../users','*.xlsm')
df1 = filename_analyse(filenamespu)
underwriting_df = load_underwriting(filenamespu)
con = dwh.get_DWH()
lr_lookup = read_loan_nr(con, df1.loan_nr.dropna(), df1.id_loan_request.dropna())
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
                               
mg.to_csv('underwriting_data.csv', encoding='utf-8')
loan_nr_overrides=pd.read_csv('loan_nr_overrides.csv', encoding='utf-8')
mg = mg.merge(loan_nr_overrides[['filename','loan_request_nr_override','checked']],
              on='filename', how='left')
mg['loan_request_nr_comb_over'] = np.where(
                                      mg.loan_request_nr_override.notnull(),
                                      mg.loan_request_nr_override,
                                      mg.loan_request_nr_comb)

# reorder and filter out columns
underwriting_merge = mg[column_ordering]




underwriting_merge.shape
con=dwh.get_DWH()
issued_loans=get_issued_loans(con)

loans_capacity=get_web_capacity(issued_loans.fk_loan_request)

issued_loans_capacity=issued_loans.merge(loans_capacity,left_on='fk_loan_request',right_index=True)

issued_loans_capacity.to_csv('issued_loans_capacity.csv',index=False)
#issued_loans_capacity=pd.read_csv('../../Indebtedness/src/issued_loans_capacity.csv')

web_indebtedness=get_web_indebtedness(issued_loans.fk_loan_request)

web_indebtedness.to_csv('web_indebtedness.csv')
gblrc=get_issued_loans_gblrc(con)
gblrc.to_csv('gblrc.csv',encoding='utf-8')
