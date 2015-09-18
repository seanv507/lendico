require('lubridate')
require('survival')
require('plyr')
require('stringr')


# NEED TO SET WORKING DIRECTORY
setwd("~/Projects/lendico/Projects/Returns/src")

source('../../../lib/read_postgresql.R')

con_drv=get_con()

sql_loans<-read_string('loans_capacity.sql')
lendi_loans<-dbGetQuery(con_drv[[1]],sql_loans)  
lendi_loans$credit_agency_score <- as.numeric(lendi_loans$credit_agency_score)
lendi_loans$duration_months <- lendi_loans$duration/30
lendi_loans$duration_months_f <- as.factor(lendi_loans$duration_months)

fac1<-c('category', 'gblrc_rating', 'gblrc_rating_mapped', 'gblrc_rating_mapped_base')
lendi_loans[fac1] <- lapply(lendi_loans[fac1],as.factor)
lendi_loans['in_arrears_since_combined_days']=NA
lendi_loans[!is.na(lendi_loans['in_arrears_since_combined']),'in_arrears_since_combined_days'] = 
    interval(lendi_loans[!is.na(lendi_loans['in_arrears_since_combined']),'in_arrears_since_combined'],now())/edays(1)









#   loans_attribute_late<-merge(x = loans_attribute, y = loans_first_lates, by.x="id_loan", by.y = "fk_loan", all=FALSE)
#   loans_first_lates<-get_first_lates(con_drv)
#   


borrower_ids<-unique(lendi_loans$fk_user)
borrowers_str<-paste(borrower_ids, collapse=',')
borrowers<-get_accounts(con_drv,borrowers_str)
borrowers$user_age_f<-
    cut(borrowers$user_age,c(18,31,46,76),right=FALSE)
borrowers$user_age_quartile<-
    cut(borrowers$user_age,c(18,36,46,53,76),right=FALSE)

borrower_attribute<-get_attributes(con_drv,borrowers_str)
# attributes takes long to load!!
borrower_attribute1<-clean_attributes(borrower_attribute)

web_indebtedness=read.csv('../../Capacity/src/web_indebtedness.csv')

web_capacity<-read.csv('../../Capacity/src/web_capacity_20150917.csv')
within( web_capacity,
        Postcheck.available_cash<-Postcheck.Income.total - Postcheck.Expenses.total
        Loan.Request.installment<-pmt(Loan.Request.interestPerYearInPercent/1200,
                                      Loan.Request.durationInMonth,
                                      Loan.Request.principalAmount)
)



first_lates<-dbGetQuery(con_drv[[1]],read_string('first_lates.sql'))
first_lates_EOM<-dbGetQuery(con_drv[[1]],read_string('first_lates_EOM.sql'))

#merge data

intersect(names(lendi_loans), names(borrowers))
#TODO drop fields
# state different and date fields 
#"dwh_country_id"    "country_name"      "currency_code"     "user_age"          "state"             "created_at"       
# [7] "updated_at"        "dwh_created"       "dwh_last_modified" "user_campaign"   


#left join
intersect(names(lendi_loans), names(borrower_attribute1))
# no duplicates
#"dwh_country_id" "fk_user"   
loans_attribute<-merge(x = lendi_loans, y = borrower_attribute1, by = c("dwh_country_id","fk_user"), all.x=TRUE)

loans_attribute <- within(loans_attribute, 
                          user_income_employment_length_months<-
                            interval(loans_attribute$user_income_employment_length_date,loans_attribute$loan_request_creation_date)/months(1))


# we add account to the shared variable names - some are duplicates
loans_account_attribute<-merge(x=loans_attribute,y=borrowers,by.x=c("dwh_country_id","fk_user"),by.y=c("dwh_country_id","id_user"),
                               suffixes=c('','.account'))


loans_account_attribute$total_net_income<-total_net_income_it(loans_account_attribute)

drop_id_columns=c('loan_request_nr','fk_loan_request')
loans_account_attribute_lates<-merge(
    x=loans_account_attribute,
    y=first_lates[,!(names(first_lates) %in% drop_id_columns)],
    by.x="id_loan",
    by.y="fk_loan")
loans_account_attribute_lates_lates_EOM<-merge(
    x=loans_account_attribute_lates,
    y=first_lates_EOM[,!(names(first_lates_EOM) %in% drop_id_columns)],
    by.x="id_loan",
    by.y="fk_loan")

loans_account_attribute_lates_lates_EOM_indebt<-merge(x=loans_account_attribute_lates_lates_EOM,
                                            y=web_indebtedness,
                                            by.x="fk_loan_request",
                                            by.y="id_loan_request",
                                            all.x=TRUE)

loans_account_attribute_lates_lates_EOM_indebt_cap<-merge(x=loans_account_attribute_lates_lates_EOM_indebt,
                                                      y=web_capacity,
                                                      by.x="fk_loan_request",
                                                      by.y="id_loan_request",
                                                      all.x=TRUE)

write.csv(first_lates,file('clipboard-256'))




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





a<-loans_account_attribute_lates[!is.na(loans_account_attribute_lates['in_arrears_since_combined_days'])&loans_account_attribute_lates['in_arrears_since_combined_days']>=91,]
write.csv(a,file('clipboard-128'))




my.fit<-survfit(Surv(surv_time_90, late_90) ~1)
capture.output(summary(my.fit),file=file('clipboard-128'))


my.fit.duration<-survfit(Surv(surv_time_90, late_90) ~duration_months)


my.fit.EOM<-survfit(Surv(surv_time_90_eom, late_90_eom) ~1)
capture.output(summary(my.fit.EOM),file=file('clipboard-128'))

surv_report<-function(df, late, reporting_date ){
    df1<-first_lates_reporting_date(df,late,reporting_date)
    survfit(Surv(
        as.numeric(df1[[surv_name(late)]]), 
        df1[[late_name(late)]]) ~1)
}

z1<-surv_report(first_lates, 90, as.Date('2015-08-01') )


reporting_dates<-as.Date(c('2015-04-30','2015-05-30', '2015-06-30','2015-07-31','2015-08-31'))

surv_90.fits<-lapply( reporting_dates, function(date) surv_report(first_lates, 90, date ))
names(surv_90.fits)<-reporting_dates

plot(surv_90.fits[[1]], main=paste("Kaplan-Meier estimate >90days",reporting_dates[[1]]), 
     xlab="time", 
     ylab="survival function",
     ymin=.6,
     yscale=100)

lines(surv_90.fits[[3]], main=paste("Kaplan-Meier estimate >90days",reporting_dates[[3]]), 
      xlab="time", 
      ylab="survival function", 
      col=2)

capture.output(lapply(reporting_dates,function(x) summary(surv_90.fits[[as.character(x)]])),file=file('clipboard-128'))
 


surv_before<-function(payout_before) {
    survfit(Surv(
                    surv_time_90_eom[payout_date<payout_before], 
                    late_90_eom[payout_date<payout_before]) ~1)}
surv.fit_EOMS<-lapply(payout_date_m, surv_before)
names(surv.fit_EOMS)<-payout_date_m





my.fit.gender<-survfit(Surv(loans_account_attribute_lates$surv_time_90, loans_account_attribute_lates$late_90)
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



kmplot<-function(f, ndays){
    a_string<-paste0(
        "Surv(loans_account_attribute_lates$surv_time_",ndays, ", 
        loans_account_attribute_lates$late_",ndays,")~1")
  
    my.fit<-survfit(as.formula(a_string))
    f_string<-paste0(
      "Surv(loans_account_attribute_lates$surv_time_",ndays, ", 
      loans_account_attribute_lates$late_",ndays,")~loans_account_attribute_lates$",paste0(f,"_f"))
    print( f_string)
    z<-survfit(as.formula(f_string))
    # Add extra space to right of plot area; change clipping to figure
    
    a<-plot(my.fit, main=paste("Kaplan-Meier estimate >",ndays," days",f), 
          xlab="time", ylab="survival function",
          ymin=0.6,
          yscale=100)
    legen<-levels(loans_account_attribute_lates[[paste0(f,"_f")]])
    legend_a<-c("overall",legen)
    lines(z,  col=seq(2,length(legend_a)),conf.int=TRUE)
    legend("topright", inset=c(-1,0),legend=legend_a,fill=seq(length(legend_a)))
    
}

days<-c(14,30,60,90)

surv_file<-'../KM Survival CurvesD.pdf'
pdf(surv_file, paper='a4r')
par( mfrow = c( 2, 2 ) )

for (var in vars){
    for (d in days){
        par(mar=c(5.1, 4.1, 4.1, 8.1), xpd=TRUE)
        kmplot(var,d)
    }
}

dev.off()

f1 =vars[1]
my.fit.user_expenses_home<-survfit(Surv(loans_account_attribute_lates$surv_time_14,loans_account_attribute_lates$surv_14)
                                   ~loans_account_attribute_lates$user_expenses_home_f)

# variables


plot(my.fit, main=paste("Kaplan-Meier estimate >14 days","user_expenses_home"), xlab="time", ylab="survival function",ymin=0.6)
z1<-levels(loans_account_attribute_lates$user_expenses_home_f)
z2<-c("overall",z1)

lines(my.fit.user_expenses_home,  col=seq(2,length(z2)))
legend(300,1,legend=z2,fill=seq(length(z2)))

detach(loans_account_attribute_lates_lates_EOM_indebt)
attach(loans_account_attribute_lates_lates_EOM_indebt)

more_than_nine_months_ago<-payout_date<=as.Date('2015-01-01')

defaulted_within_nine_months<-(more_than_nine_months_ago & (surv_time_90_eom<9*31) & late_90_eom)

loans_account_attribute_lates_lates_EOM_indebt[defaulted_within_nine_months, c('id_loan','payout_date','duration_months','surv_time_90')]






loans_attribute_late3$total_net_income_nib_p<-total_net_income_it(loans_attribute_late3)
loans_attribute_late3[c(1416,1451),grep("user_income",names(loans_attribute_late3))]


employment_status_lookup<-read.table(header=T,stringsAsFactors = T,
text='Status Adjustment Adjustment_SV
house_wife_husband  "+2" "other"
unemployed          "+2" "other"
self_employed       "+2"  "self_employed"
freelancer          "+2"  "self_employed"   
student             "+2"  "other"
soldier             "0"   "manual_worker"
manual_worker       "0"   "manual_worker"
retired             "-1"  "retired"
salaried            "-1"  "salaried"
public_official     "-2" "public_official" ')


# x freq
# 1          freelancer   72
# 2  house_wife_husband    1
# 3       manual_worker   81
# 4     public_official  189
# 5             retired  162
# 6            salaried 1075
# 7       self_employed  858
# 8             soldier    6
# 9             student    8
# 10               <NA>   10


# count(user_income_employment_type)
# x freq
# 1 full_time 1259
# 2 part_time   14
# 3      <NA> 1189

vars<-c("credit_agency_score_logist","gender", "user_age_f", "marital_status", 
        "user_income_employment_status_f","user_income_employment_type_f" ,
        "user_income_employment_length_months_f","user_expenses_home_f")


replace_NA<-function (fac){
    fac<-factor(fac, levels=c(levels(fac),'NAF'))
    fac[is.na(fac)]<-'NAF'
    fac
}

loans_account_attribute_lates_lates_EOM_indebt<-loans_account_attribute_lates_lates_EOM_indebt[-as.logical(sme_flag),]

within(loans_account_attribute_lates_lates_EOM_indebt,{
    credit_agency_score_quartile<-cut(credit_agency_score,quantile(credit_agency_score,seq(0,1,0.25)))
    user_income_employment_length_months_f<-cut(user_income_employment_length_months,c(0,24,60),right=F)
    user_income_employment_length_months_f<-replace_NA(user_income_employment_length_months_f)
    user_income_employment_type<-replace_NA(user_income_employment_type)
    
    user_age_f<-cut(user_age,c(18,31,46,76),right=FALSE)

    
    # home leave as is ( but deal with NA)
    user_expenses_home_f<-replace_NA(user_expenses_home)
})
loans_account_attribute_lates_lates_EOM_indebt<-merge(loans_account_attribute_lates_lates_EOM_indebt,
                                                      employment_status_lookup)

tapply(loans_account_attribute_lates_lates_EOM_indebt$defaulted_within_nine_months[more_than_nine_months_ago],
       credit_agency_score_decile[more_than_nine_months_ago],mean)

user_income_employment_length_months

