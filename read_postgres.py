# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""


import pandas.io.sql as psql
import pandas as pd
import sys
sys.path.insert(0,'C:\Users\Sean Violante\Documents\Projects\lendico\lib')
import dwh


conn, cur = get_DWH()
sql="select * from base.loan_request limit 5"
df=psql.read_sql(sql,conn)
# cur.execute(sql)
#res = cur.fetchall()
print df.head(5)
#sql="select table_name from INFORMATION_SCHEMA.views where table_schema='base';"

sql="select * from il.t_global_investor_bids_transaction"
bids_df=psql.read_sql(sql,conn)

