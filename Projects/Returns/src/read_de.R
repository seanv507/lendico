source('../../../lib/read_postgresql.R')
require("reshape2")
require("lubridate")
con_drv=get_con()

#sql='select * from base.loan_request limit 10'

sql_loans="select  l.*, gblrc.pd, gblrc.pd_original, gblrc.lgd, pp.interval_payment,
ac.net_income, ac.expenses_without_loans,  ac.expenses_pre_capacity,
from base.loan l join il.global_borrower_loan_requests_cohort gblrc 
on (l.dwh_country_id=gblrc.dwh_country_id and l.loan_nr=gblrc.loan_request_nr)
join base.loan_payment_plan pp on (l.dwh_country_id=pp.dwh_country_id and l.id_loan=pp.fk_loan) 
join base.user_account ac on (l.dwh_country_id=ac.dwh_country_id and l.fk_user=ac.id_user)
where l.dwh_country_id=1 and id_loan not in (3,4,6,8,11,14) 
and l.loan_nr not in   (94479925,182766269,312403183,345557011,379731992,421384595,509393088,546756655,727207610,11204373,142735577,765881911,803090308,895824248,650534649,382135828,556358891)
and l.state!='canceled'"
# either founder loans or lendico loans


#sql_loans_pps<-"select fk_loan,interval_payment from  base.loan_payment_plan where dwh_country_id=1"
#loan_pps<-dbGetQuery(con_drv[[1]],sql_loans_pps)
#loans_attribute_late2<-merge(loans_attribute_late2, loan_pps,by.x="id_loan",by.y="fk_loan")

sql_user_cap<-"select id_user,ac.net_income, ac.expenses_without_loans,  ac.pre_capacity from  
base.user_account ac where dwh_country_id=1"
user_cap<-dbGetQuery(con_drv[[1]],sql_user_cap)
loans_attribute_late2<-merge(loans_attribute_late2, user_cap,by.x="fk_user",by.y="id_user",all.x=T)



#sql_loan_requests="select * from  il.bid_transactions"


lendi_loans<-dbGetQuery(con_drv[[1]],sql_loans)
#resTables<-dbListTables(con)


borrower_ids<-unique(lendi_loans$fk_user)
borrowers_str<-paste(borrower_ids, collapse=',')
sql_borrowers=paste0("select * from  base.user_account  where dwh_country_id =1 and id_user in (",borrowers_str,
                     ")",collapse=' ')
borrowers<-dbGetQuery(con_drv[[1]],sql_borrowers)

sql_user_attribute1=paste0("select dwh_country_id,max(id_attribute) id_attribute from  backend.user_attribute 

                          where dwh_country_id=1 and fk_user in (",borrowers_str,
                          ")  group by dwh_country_id, fk_user,key",collapse=' ')
sql_user_attribute=paste0("select ua.* from backend.user_attribute ua join (",sql_user_attribute1,") unis 
                          on ua.id_attribute=unis.id_attribute and ua.dwh_country_id=unis.dwh_country_id",collapse=' ')
borrower_attribute_narrow<-dbGetQuery(con_drv[[1]],sql_user_attribute)
# turn into wide format
borrower_attribute<-dcast(borrower_attribute_narrow, fk_user~key,value.var='value')
# remove new lines to paste into excel
borrower_attribute$loan_request_description<-gsub("\r\n","  ",borrower_attribute$loan_request_description)
borrower_attribute$user_income_employment_length_date<-
  floor_date(parse_date_time(borrower_attribute$user_income_employment_length,
                             c("%m%y","Y%m%d","%d%m%Y")),"month")
#which(is.na(borrower_attribute$user_income_employment_length_date) & !is.na(borrower_attribute$user_income_employment_length))
borrower_attribute$user_income_employment_length_date[borrower_attribute$user_income_employment_length=="01.12.21985"]=ymd("19851201")
borrower_attribute$user_income_employment_length_date[borrower_attribute$user_income_employment_length=="2012-01-01.2012"]=ymd("20120101")



# HACK
# format 01/13
# HACK

borrower_attribute$user_income_employment_length_years<-
  interval(borrower_attribute$user_income_employment_length_date,Sys.Date())/years(1)

#left join
loans_attribute<-merge(x = lendi_loans, y = borrower_attribute, by = "fk_user", all.x=TRUE)
loans_attribute$duration_months<-loans_attribute$duration/30

loans_attribute$user_income_employment_length_months<-
  interval(loans_attribute$user_income_employment_length_date,loans_attribute$loan_request_creation_date)/months(1)

loans_attribute$user_income_net_income_euros<-as.numeric(loans_attribute$user_income_net_income)/100
loans_attribute$principal_amount_euros<-as.numeric(loans_attribute$principal_amount)/100

lifetime_lates<-"
  select  fk_loan
,count(fk_loan) as count_days_live
,coalesce(sum(CAST((in_arrears_since_days>7) as int)),0) as count_in_arrears_since_days_7
,coalesce(sum(CAST((in_arrears_since_days>14) as int)),0) as count_in_arrears_since_days_14
,coalesce(sum(CAST((in_arrears_since_days>30) as int)),0) as count_in_arrears_since_days_30
,coalesce(sum(CAST((in_arrears_since_days>60) as int)),0) as count_in_arrears_since_days_60
from de_payments group by fk_loan 
having  
sum(CAST((in_arrears_since_days>7) as int)) is not null and 
sum(CAST((in_arrears_since_days>7) as int)) >0
order by fk_loan
"

sql_first_lates<-"
select latest.fk_loan
,earliest_date,latest_date
,in_arrears_since_days_7_plus_first
,in_arrears_since_days_14_plus_first 
,in_arrears_since_days_30_plus_first 
,in_arrears_since_days_60_plus_first 
,coalesce(in_arrears_since_days_7_plus_first,latest_date)-earliest_date as surv_time_7
,coalesce(in_arrears_since_days_14_plus_first,latest_date)-earliest_date as surv_time_14
,coalesce(in_arrears_since_days_30_plus_first,latest_date)-earliest_date as surv_time_30
,coalesce(in_arrears_since_days_60_plus_first,latest_date)-earliest_date as surv_time_60
,in_arrears_since_days_7_plus_first is not null as surv_7
,in_arrears_since_days_14_plus_first is not null as surv_14
,in_arrears_since_days_30_plus_first is not null as surv_30
,in_arrears_since_days_60_plus_first is not null as surv_60
FROM 
          (select  fk_loan, min(iso_date) earliest_date, max(iso_date) latest_date from base.de_payments  group by fk_loan) latest
left join (select  fk_loan, min(iso_date) in_arrears_since_days_7_plus_first from base.de_payments where in_arrears_since_days>7 group by fk_loan ) f7  on (latest.fk_loan=f7.fk_loan)
left join (select  fk_loan, min(iso_date) in_arrears_since_days_14_plus_first from base.de_payments where in_arrears_since_days>14 group by fk_loan ) f14 on (latest.fk_loan=f14.fk_loan)
left join (select  fk_loan, min(iso_date) in_arrears_since_days_30_plus_first from base.de_payments where in_arrears_since_days>30 group by fk_loan ) f30 on (latest.fk_loan=f30.fk_loan)
left join (select  fk_loan, min(iso_date) in_arrears_since_days_60_plus_first from base.de_payments where in_arrears_since_days>60 group by fk_loan ) f60 on (latest.fk_loan=f60.fk_loan)
order by fk_loan
"
loans_first_lates<-dbGetQuery(con_drv[[1]],sql_first_lates)

# missing either because excluded fake loans or because not funded or not yet paid out
loans_attribute_late<-merge(x = loans_attribute, y = loans_first_lates, by.x="id_loan", by.y = "fk_loan", all=FALSE)

loans_attribute_late$user_income_employment_length_months<-
  interval(loans_attribute_late$user_income_employment_length_date,loans_attribute_late$loan_request_creation_date)/months(1)
loans_attribute_late$gender_f<-as.factor(loans_attribute_late$gender)


my.fit<-survfit(Surv(loans_attribute_late$surv_time_14,loans_attribute_late$surv_14)~1)
my.fit.gender<-survfit(Surv(loans_attribute_late$surv_time_14,loans_attribute_late$surv_14)~loans_attribute_late$gender_f)

plot(my.fit, main="Kaplan-Meier estimate >14days", xlab="time", ylab="survival function")
lines(my.fit1, main="Kaplan-Meier estimate", xlab="time", ylab="survival function", col=seq(2,3))
z1<-levels(factor(loans_attribute_late$gender))
z2<-c("overall",z1)
legend(300,.2,legend=z2,fill=seq(3))
# change to 400? use ymin =.6







vars<-["marital_status","user_age", "rating","user_expenses_home","user_income_employment_status","user_income_employment_type"]
facs<-c("marital_status","rating","user_expenses_home","user_income_employment_status","user_income_employment_type")
facs_f<-paste0(facs,"_f")
loans_attribute_late[facs_f]<-lapply(loans_attribute_late[facs],as.factor)

kmplot<-function(f){
  f_string<-paste0("Surv(loans_attribute_late$surv_time_14,loans_attribute_late$surv_14)~loans_attribute_late$",paste0(f,"_f"))
  z<-survfit(as.formula(f_string))
                                     
  a<-plot(my.fit, main=paste("Kaplan-Meier estimate >14 days",f), xlab="time", ylab="survival function",ymin=0.6)
  z1<-levels(loans_attribute_late[[paste0(f,"_f")]])
  z2<-c("overall",z1)
  lines(z,  col=seq(2,length(z2)))
  legend(300,1,legend=z2,fill=seq(length(z2)))
  z
}

my.fit.user_expenses_home<-survfit(Surv(loans_attribute_late$surv_time_14,loans_attribute_late$surv_14)
                                   ~loans_attribute_late$user_expenses_home_f)

plot(my.fit, main=paste("Kaplan-Meier estimate >14 days","user_expenses_home"), xlab="time", ylab="survival function",ymin=0.6)
z1<-levels(loans_attribute_late$user_expenses_home_f)
z2<-c("overall",z1)

lines(my.fit.user_expenses_home,  col=seq(2,length(z2)))
legend(300,1,legend=z2,fill=seq(length(z2)))

loans_attribute_late$user_income_alimony<-as.numeric(loans_attribute_late$user_income_alimony)
loans_attribute_late$user_income_business<-as.numeric(loans_attribute_late$user_income_business)
loans_attribute_late$user_income_child_benefit<-as.numeric(loans_attribute_late$user_income_child_benefit)
loans_attribute_late$user_income_pension<-as.numeric(loans_attribute_late$user_income_pension)

loans_attribute_late$user_income_net_income<-as.numeric(loans_attribute_late$user_income_net_income)
loans_attribute_late$user_income_net_income_from_business<-as.numeric(loans_attribute_late$user_income_net_income_from_business)
loans_attribute_late$user_income_net_income_if_any<-as.numeric(loans_attribute_late$user_income_net_income_if_any)
loans_attribute_late$user_income_net_income_other<-as.numeric(loans_attribute_late$user_income_net_income_other)
loans_attribute_late$user_income_net_income_pension<-as.numeric(loans_attribute_late$user_income_net_income_pension)
loans_attribute_late$user_income_net_income2<-as.numeric(loans_attribute_late$user_income_net_income2)
loans_attribute_late$user_income_net_income_pension<-as.numeric(loans_attribute_late$user_income_net_income_pension)
loans_attribute_late$user_income_rent<-as.numeric(loans_attribute_late$user_income_rent)
loans_attribute_late$user_expenses_health_insurance<-as.numeric(loans_attribute_late$user_expenses_health_insurance)
loans_attribute_late$user_expenses_children<-as.numeric(loans_attribute_late$user_expenses_children)
loans_attribute_late$user_expenses_leasing<-as.numeric(loans_attribute_late2$user_expenses_leasing)
loans_attribute_late$user_expenses_monthly_mortgage<-as.numeric(loans_attribute_late$user_expenses_monthly_mortgage)
loans_attribute_late$user_expenses_monthly_rent<-as.numeric(loans_attribute_late$user_expenses_monthly_rent)
num_strs<-c("user_expenses_alimony","user_expenses_current_loans", "user_expenses_leasing")
loans_attribute_late[,num_strs]<-lapply(loans_attribute_late[,num_strs],as.numeric)



sql_loans_rating<- "select l.id_loan,l.loan_nr,l.fk_loan_request,gblrc.credit_agency_score, gblrc.pd, gblrc.pd_original, gblrc.lgd from base.loan l join il.global_borrower_loan_requests_cohort gblrc 
on (l.dwh_country_id=gblrc.dwh_country_id and l.loan_nr=gblrc.loan_request_nr)
where l.dwh_country_id=1 and id_loan not in (3,4,6,8,11,14) 
and l.loan_nr not in   (94479925,182766269,312403183,345557011,379731992,421384595,509393088,546756655,727207610,11204373,142735577,765881911,803090308,895824248,650534649,382135828,556358891)
and l.state!='canceled'"
loans_rating<-dbGetQuery(con_drv[[1]],sql_loans_rating)
loans_attribute_late2<-merge(loans_attribute_late,loans_rating[c("id_loan","credit_agency_score")], on="id_loan")
loans_attribute_late2$credit_agency_score<-as.numeric(loans_attribute_late2$credit_agency_score)

loans_attribute_late1<-
