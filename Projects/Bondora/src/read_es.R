source('../../../lib/read_postgresql.R')
con_drv=get_con()

#sql='select * from base.loan_request limit 10'

sql_loans="select * from  es.loan"
#sql_loan_requests="select * from  il.bid_transactions"


lendi_loans<-dbGetQuery(con_drv[[1]],sql_loans)
#resTables<-dbListTables(con)


borrower_ids<-unique(lendi_loans$fk_user)
borrowers_str<-paste(borrower_ids, collapse=',')
sql_borrowers=paste0("select * from  es.user where id_user in (",borrowers_str,
                 ")",collapse=' ')
borrowers<-dbGetQuery(con_drv[[1]],sql_borrowers)

sql_user_attribute=paste0("select * from  es.user_attribute where fk_user in (",borrowers_str,
                          ")",collapse=' ')
borrower_attribute<-dbGetQuery(con_drv[[1]],sql_user_attribute)
# turn into wide format
borrower_attribute<-dcast(borrower_attribute, fk_user~key,value.var='value')
# remove new lines to paste into excel
borrower_attribute$loan_request_description<-gsub("\r\n","  ",borrower_attribute$loan_request_description)
borrower_attribute$user_income_employment_length_date<-
  floor_date(parse_date_time(borrower_attribute$user_income_employment_length,
                             c("%m%y","Y%m%d","%d%m%Y")),"month")
# HACK
borrower_attribute$user_income_employment_length_date[c(141,183)]<-parse_date_time(
  borrower_attribute$user_income_employment_length[c(141,183)],"%m%y")
# format 01/13
# HACK

borrower_attribute$user_income_employment_length_years<-
  interval(borrower_attribute$user_income_employment_length_date,Sys.Date())/years(1)
#left join
loans_attribute<-merge(x = lendi_loans, y = borrower_attribute, by = "fk_user", all.x=TRUE)
loans_attribute$duration_months<-loans_attribute$duration/30
loans_attribute$user_income_net_income_euros<-as.numeric(loans_attribute$user_income_net_income)/100
loans_attribute$principal_amount_euros<-as.numeric(loans_attribute$principal_amount)/100

