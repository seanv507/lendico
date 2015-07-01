require('lubridate')
source('../../../lib/read_postgresql.R')

con_drv=get_con()
lendi_loans<-get_loans(con_drv)

lendi_loans$duration_months<-lendi_loans$duration/30
facs<-c("category")
lendi_loans[facs]<-lapply(lendi_loans[facs],as.factor)
lendi_loans['in_arrears_since_combined_days']=NA
lendi_loans[!is.na(lendi_loans['in_arrears_since_combined']),'in_arrears_since_combined_days'] = 
  interval(lendi_loans[!is.na(lendi_loans['in_arrears_since_combined']),'in_arrears_since_combined'],now())/edays(1)
lendi_loans['in_arrears_since_combined_days']=interval(lendi_loans['in_arrears_since_combined'],now())/edays(1)
#   loans_attribute_late<-merge(x = loans_attribute, y = loans_first_lates, by.x="id_loan", by.y = "fk_loan", all=FALSE)
#   loans_first_lates<-get_first_lates(con_drv)
#   


borrower_ids<-unique(lendi_loans$fk_user)
borrowers_str<-paste(borrower_ids, collapse=',')
borrowers<-get_accounts(con_drv,borrowers_str)

borrower_attribute<-get_attributes(con_drv,borrowers_str)
# attributes takes long to load!!
borrower_attribute1<-clean_attributes(borrower_attribute)

#left join
loans_attribute<-merge(x = lendi_loans, y = borrower_attribute1, by = "fk_user", all.x=TRUE)



loans_attribute$user_income_employment_length_months<-
  interval(loans_attribute$user_income_employment_length_date,loans_attribute$loan_request_creation_date)/months(1)

# sql_lifetime_lates<-"
#   select  fk_loan
# ,count(fk_loan) as count_days_live
# ,coalesce(sum(CAST((in_arrears_since_days>7) as int)),0) as count_in_arrears_since_days_7
# ,coalesce(sum(CAST((in_arrears_since_days>14) as int)),0) as count_in_arrears_since_days_14
# ,coalesce(sum(CAST((in_arrears_since_days>30) as int)),0) as count_in_arrears_since_days_30
# ,coalesce(sum(CAST((in_arrears_since_days>60) as int)),0) as count_in_arrears_since_days_60
# from de_payments group by fk_loan 
# having  
# sum(CAST((in_arrears_since_days>7) as int)) is not null and 
# sum(CAST((in_arrears_since_days>7) as int)) >0
# order by fk_loan
# "


loans_account_attribute<-merge(x=loans_attribute,y=borrowers,by.x="fk_user",by.y="id_user")

first_lates<-get_first_lates(con_drv)
loans_account_attribute_lates<-merge(x=loans_attribute,y=first_lates,by.x="id_loan",by.y="fk_loan")
loans_account_attribute_lates$total_net_income<-total_net_income_it(loans_account_attribute_lates)

loans_account_attribute_lates$gender_f<-as.factor(loans_account_attribute_lates$gender)

a<-loans_account_attribute_lates[!is.na(loans_account_attribute_lates['in_arrears_since_combined_days'])&loans_account_attribute_lates['in_arrears_since_combined_days']>=91,]
write.csv(a,file('clipboard-128'))




my.fit<-survfit(Surv(loans_account_attribute_lates$surv_time_14,loans_account_attribute_lates$surv_14)~1)
my.fit.gender<-survfit(Surv(loans_account_attribute_lates$surv_time_14, loans_account_attribute_lates$surv_14)
                       ~loans_account_attribute_lates$gender_f)

plot(my.fit, main="Kaplan-Meier estimate >14days", xlab="time", ylab="survival function")
lines(my.fit.gender, main="Kaplan-Meier estimate", xlab="time", ylab="survival function", col=seq(2,3))
z1<-levels(factor(loans_account_attribute_lates$gender))
z2<-c("overall",z1)
legend(300,.2,legend=z2,fill=seq(3))
# change to 400? use ymin =.6







vars<-c("marital_status","user_age", "rating","user_expenses_home","user_income_employment_status","user_income_employment_type")

kmplot<-function(f){
  f_string<-paste0("Surv(loans_account_attribute_lates$surv_time_14,loans_account_attribute_lates$surv_14)~loans_account_attribute_lates$",paste0(f,"_f"))
  z<-survfit(as.formula(f_string))
  
  a<-plot(my.fit, main=paste("Kaplan-Meier estimate >14 days",f), xlab="time", ylab="survival function",ymin=0.6)
  z1<-levels(loans_account_attribute_lates[[paste0(f,"_f")]])
  z2<-c("overall",z1)
  lines(z,  col=seq(2,length(z2)))
  legend(300,1,legend=z2,fill=seq(length(z2)))
  z
}

kmplot(vars[1])

f1 =vars[1]
my.fit.user_expenses_home<-survfit(Surv(loans_account_attribute_lates$surv_time_14,loans_account_attribute_lates$surv_14)
                                   ~loans_account_attribute_lates$user_expenses_home_f)

plot(my.fit, main=paste("Kaplan-Meier estimate >14 days","user_expenses_home"), xlab="time", ylab="survival function",ymin=0.6)
z1<-levels(loans_account_attribute_lates$user_expenses_home_f)
z2<-c("overall",z1)

lines(my.fit.user_expenses_home,  col=seq(2,length(z2)))
legend(300,1,legend=z2,fill=seq(length(z2)))





loans_attribute_late3$total_net_income_nib_p<-total_net_income_it(loans_attribute_late3)


loans_attribute_late3[c(1416,1451),grep("user_income",names(loans_attribute_late3))]

