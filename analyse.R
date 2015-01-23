
setwd("~/Projects/lendico")
source('../lib/read_postgresql.R')

con_drv=get_con()

#sql='select * from base.loan_request limit 10'

sql_loan_requests="select * from  il.global_borrower_accounts_cohort"
#sql_loan_requests="select * from  il.bid_transactions"


res<-dbGetQuery(con_drv[[1]],sql_loan_requests)
#resTables<-dbListTables(con)


colnames(res)
borrower_accounts<-data.table(res)
cities<-borrower_accounts[,.N,by=city][order(-N),]
ggplot(user_age,aes(x=user_age,y=N))+geom_bar(stat="identity")

ggplot(cities[:1000],aes(x=user_age,y=N))+geom_bar(stat="identity")
