require('lubridate')
require('survival')

# NEED TO SET WORKING DIRECTORY
source('../../../lib/read_postgresql.R')

con_drv=get_con()

sql_loans<-read_string('loans_capacity.sql')
lendi_loans<-dbGetQuery(con_drv[[1]],sql_loans)  


lendi_loans$duration_months<-lendi_loans$duration/30
facs<-c("category")
lendi_loans[facs]<-lapply(lendi_loans[facs],as.factor)
lendi_loans['in_arrears_since_combined_days']=NA
lendi_loans[!is.na(lendi_loans['in_arrears_since_combined']),'in_arrears_since_combined_days'] = 
  interval(lendi_loans[!is.na(lendi_loans['in_arrears_since_combined']),'in_arrears_since_combined'],now())/edays(1)


#   loans_attribute_late<-merge(x = loans_attribute, y = loans_first_lates, by.x="id_loan", by.y = "fk_loan", all=FALSE)
#   loans_first_lates<-get_first_lates(con_drv)
#   


borrower_ids<-unique(lendi_loans$fk_user)
borrowers_str<-paste(borrower_ids, collapse=',')
borrowers<-get_accounts(con_drv,borrowers_str)

intersect(names(lendi_loans), names(borrowers))
# state different and date fields 

borrower_attribute<-get_attributes(con_drv,borrowers_str)
# attributes takes long to load!!
borrower_attribute1<-clean_attributes(borrower_attribute)

#left join
intersect(names(lendi_loans), names(borrower_attribute1))

# no duplicates
loans_attribute<-merge(x = lendi_loans, y = borrower_attribute1, by = c("dwh_country_id","fk_user"), all.x=TRUE)

loans_attribute$user_income_employment_length_months<-
  interval(loans_attribute$user_income_employment_length_date,loans_attribute$loan_request_creation_date)/months(1)
intersect(names(lendi_loans), names(borrowers))
# we add account to the shared variable names - some are duplicates
loans_account_attribute<-merge(x=loans_attribute,y=borrowers,by.x=c("dwh_country_id","fk_user"),by.y=c("dwh_country_id","id_user"),
                               suffixes=c('','.account'))

first_lates<-get_first_lates(con_drv)
loans_account_attribute_lates<-merge(x=loans_account_attribute,y=first_lates,by.x="id_loan",by.y="fk_loan")

loans_account_attribute_lates$total_net_income<-total_net_income_it(loans_account_attribute_lates)

sql_loan_arrears<-read_string('loan_arrears.sql')
loan_arrears<-dbGetQuery(con_drv[[1]],sql_loan_arrears)
loan_arrears$elapsed_month=floor(loan_arrears$elapsed_days_30360/30)
loan_arrears$is_30dpd=loan_arrears$in_arrears_since_days_30360>30
loan_arrears$is_30dpd[is.na(loan_arrears$is_30dpd)]=FALSE




# user account and user_attribute both have gender ( anything else?)
"dwh_country_id" 
"country_name"
"currency_code"
"user_age"
"title"                   
"state"
"created_at"
"updated_at"
"dwh_created"
"dwh_last_modified"
"user_campaign"
"net_income_precheck"
"net_income"
"expenses_precheck"
"expenses"
"expenses_current_loans"
"pre_capacity"
"first_name"
"gender"
"last_name"
"loan_request_description"
"loan_request_title"
"marital_status"
"newsletter_subscription"
"postal_code"
"street"
"street_number"
"voucher_code"



loans_account_attribute_lates$gender_f<-as.factor(loans_account_attribute_lates$gender)

a<-loans_account_attribute_lates[!is.na(loans_account_attribute_lates['in_arrears_since_combined_days'])&loans_account_attribute_lates['in_arrears_since_combined_days']>=91,]
write.csv(a,file('clipboard-128'))



my.fit<-survfit(Surv(loans_account_attribute_lates$surv_time_90, loans_account_attribute_lates$late_90)
                       ~1)
capture.output(summary(my.fit),file=file('clipboard-128'))

my.fit.gender<-survfit(Surv(loans_account_attribute_lates$surv_time_30, loans_account_attribute_lates$surv_30)
                       ~loans_account_attribute_lates$gender_f)

plot(my.fit, main="Kaplan-Meier estimate >90days", 
     xlab="time", 
     ylab="survival function",
     ymin=.6,
     yscale=100)
lines(my.fit.gender, main="Kaplan-Meier estimate", 
      xlab="time", 
      ylab="survival function", 
      col=seq(2,3))
z1<-levels(loans_account_attribute_lates$gender_f)
z2<-c("overall",z1)
legend(100,.7,legend=z2,fill=seq(3))
# change to 400? use ymin =.6

# change scale





vars<-c("gender", "marital_status","user_age", "rating","user_expenses_home","user_income_employment_status","user_income_employment_type")
loans_account_attribute_lates$marital_status_f<-
  as.factor(loans_account_attribute_lates$marital_status.x)

loans_account_attribute_lates$user_age_f<-
  cut(loans_account_attribute_lates$user_age.x,c(18,31,46,76),right=FALSE)

loans_account_attribute_lates$rating_f<-
  as.factor(loans_account_attribute_lates$rating)


kmplot<-function(f, ndays){
    a_string<-paste0(
        "Surv(loans_account_attribute_lates$surv_time_",ndays, ", 
        loans_account_attribute_lates$surv_",ndays,")~1")
  
    my.fit<-survfit(as.formula(a_string))
    f_string<-paste0(
      "Surv(loans_account_attribute_lates$surv_time_",ndays, ", 
      loans_account_attribute_lates$surv_",ndays,")~loans_account_attribute_lates$",paste0(f,"_f"))
    print( f_string)
    z<-survfit(as.formula(f_string))
    
    a<-plot(my.fit, main=paste("Kaplan-Meier estimate >",ndays," days",f), 
          xlab="time", ylab="survival function",
          ymin=0.6,
          yscale=100)
    z1<-levels(loans_account_attribute_lates[[paste0(f,"_f")]])
    z2<-c("overall",z1)
    lines(z,  col=seq(2,length(z2)),conf.int=TRUE)
    legend(25,.8,legend=z2,fill=seq(length(z2)))
    z
}

kmplot(vars[1],30)

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

