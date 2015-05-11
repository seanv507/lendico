
setwd("~/Projects/lendico/Projects/InvestorDrop/src")
source('../../../lib/read_postgresql.R')
require(data.table)
require(ggplot2)
require(zoo)
con_drv=get_con()

#sql='select * from base.loan_request limit 10'
sql_loan_requests="select * from  il.global_borrower_loan_requests_cohort"
res<-dbGetQuery(con_drv[[1]],sql_loan_requests)

loan_requests<-data.table(res)

#resTables<-dbListTables(con)
