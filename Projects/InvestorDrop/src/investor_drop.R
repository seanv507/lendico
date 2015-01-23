source('../../../lib/read_postgresql.R')

con_drv=get_con()

#sql='select * from base.loan_request limit 10'

sql_loan_requests="select * from  il.global_borrower_accounts_cohort"
#sql_loan_requests="select * from  il.bid_transactions"


res<-dbGetQuery(con_drv[[1]],sql_loan_requests)
#resTables<-dbListTables(con)
