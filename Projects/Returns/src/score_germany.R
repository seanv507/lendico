require('lubridate')
require('zoo')
require('survival')
require('plyr')
require('stringr')
require('rms')
require('Hmisc')
require(data.table)

# NEED TO SET WORKING DIRECTORY
setwd("~/Projects/lendico/Projects/Capacity/src")

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

web_indebtedness=read.csv('../../Capacity/src/web_indebtedness_20150919.csv')

web_capacity<-read.csv('../../Capacity/src/web_capacity_20150919.csv')
within( web_capacity,{
        Postcheck.available_cash<-Postcheck.Income.total - Postcheck.Expenses.total
        Loan.Request.installment<-pmt(Loan.Request.interestPerYearInPercent/1200,
                                      Loan.Request.durationInMonth,
                                      Loan.Request.principalAmount)
}
)



first_lates<-dbGetQuery(con_drv[[1]],read_string('first_lates.sql'))
first_lates_EOM<-dbGetQuery(con_drv[[1]],read_string('first_lates_EOM.sql'))
first_lates_EOM_month<-dbGetQuery(con_drv[[1]],read_string('first_lates_EOM_month.sql'))
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

df<-read.csv('gblrc_web_ind_web_cap_underwriting_first_lates_EOM_dpd_20150919c.csv')

df<-read.csv('gblrc_web_ind_web_cap_underwriting_first_lates_EOM_dpd_20150919c_mrk.csv')

df$user_expenses_home_score<-as.factor(df$user_expenses_home_score)
df$user_income_employment_status_score<-as.factor(df$user_income_employment_status_score)
cv.f
late_x_eom_M<-function(df,dpd,payout_months){
    # define target variable - na if row is too young otherwise 0/1
    surv_month=paste('surv_months',dpd,'eom',sep='_')
    late=paste('late',dpd,'eom',sep='_')
    
    target<-df[late] & (df[surv_month]<payout_months)
    #TODO standardise payout months to date!!
    target[df$payout_age_months<payout_months]<-NA
    target
}



binom_conf_interval<-function (bool,prob){
    a<-(1-prob)/2
    hits=sum(bool,na.rm=T)
    misses=sum(!bool,na.rm=T)
    res<-list(
                count=sum(!is.na(bool)),
                hits=hits,
                misses=misses,
                mean=mean(bool,na.rm=T),
                lower_CI=qbeta(a,hits+.5,misses+0.5),
                upper_CI=qbeta(1-a,hits+.5,misses+0.5))
    res
}


df$late_90_eom_6m<-late_x_eom_M(df,90,6)

sql_schufa_scoring<-read_string('schufa_scoring.sql')
schufa_scoring<-dbGetQuery(con_drv[[1]],sql_schufa_scoring)
dt_schufa_scoring=data.table(schufa_scoring)

my.fit<-survfit(Surv(df$surv_time_90_eom, df$late_90_eom) ~1)

plot(my.fit)

lendico_score<-function(df, debug=F){
    # should treat as logistic function?
    beta=+0.11713
    #schufa
    schufa_adj<- 0.7*(1-df$credit_agency_score/10000)
    schufa_var<-logit(schufa_adj)
    
    s<-schufa_var
    s1<-s
    
    # age in years
    age = (df$user_age_score=='(17, 30]')*1 + (df$user_age_score=='(45, 76]')*-1 
    s <- s + beta * age
    s2<-s
    
    s <- s + beta * df$marital_status_score
    s3<-s
    
    s <- s + beta * df$user_income_employment_status_score
    s4<-s
    
    el <- (df$user_income_employment_length_months_score== "[0, 24)") - (df$user_income_employment_length_months_score== "[60, 1200)")
    s <- s + beta * el
    s5<-s
    
    s <- s + beta * df$user_expenses_home_score
    s6<-s
    
    exp_to_inc <- (df$Postcheck.Income.total - df$Postcheck.Expenses.total)/df$Postcheck.Income.total
    # note excluding instalment
    s <- s + beta * 2 * ((exp_to_inc<=.25) - (exp_to_inc>.42))
    s7<-s
    
    pd<-logistic(s)
    pd<-pmin(.124,pd)
    pd<-pmax(0.01,pd)
    pd[ df$user_income_employment_status %in% c('freelancer','self_employed') ] <- 
        pmax(0.0301,pd[ df$user_income_employment_status %in% c('freelancer','self_employed') ])
    # changed september 17 2015 to 1.23%
    if (debug){
        data.frame(s1,s2,s3,s4,s5,s6,s7,pd)
    }else pd
    
}

gini(df$lendico_s[!is.na(df$late_60_eom_6m)],df$late_60_eom_6m[!is.na(df$late_60_eom_6m)])


base_formula<-formula(~ credit_agency_pd_logit + 
                          user_age + user_age_score +
                          marital_status + 
                          user_income_employment_status_score + 
                          user_income_employment_length_months_score + 
                          user_expenses_home_score+
                          gender + 
                          Postcheck.Income.total +
                          Postcheck.Expenses.total -1
                          )

schufa_spline_formula<-formula(~  rcs(credit_agency_pd_logit, c(-3.4389536, -2.7235144 ,-2.0243010)))

base_formula_y<-formula(late_60_eom_9m ~ credit_agency_pd_logit + 
                          user_age + user_age_score +
                          marital_status + 
                          user_income_employment_status_score + 
                          user_income_employment_length_months_score + 
                          user_expenses_home_score+
                          gender + Postcheck.Income.total
                      + Postcheck.Expenses.total
)


x<-model.matrix(base_formula,data=df[!is.na(df$late_60_eom_9m),])

x_schufa<-model.matrix(schufa_spline_formula,data=df[!is.na(df$late_60_eom_9m),])
y<-df$late_60_eom_9m[!is.na(df$late_60_eom_9m)]==1
x_30_6m<-model.matrix(base_formula,data=df[!is.na(df$late_30_eom_6m),])
y_30_6m<-df$late_30_eom_6m[!is.na(df$late_30_eom_6m)]==1
cv.fit<-cv.glmnet(x,y,family="binomial")
cv.fit<-cv.glmnet(x_30_6m,y_30_6m,family="binomial")

rp<-rpart(base_formula_y,data=df[!is.na(df$late_60_eom_9m),])

logloss(1-df$credit_agency_score[!is.na(df$late_60_eom_6m) &is.finite(df$credit_agency_pd_logit)]/10000,
        df$late_60_eom_6m[!is.na(df$late_60_eom_6m)&is.finite(df$credit_agency_pd_logit)]==1)

capture.output(summary(my.fit),file=file('clipboard-128'))

user_age_score
credit_agency_pd_logit
marital_status_score
user_income_employment_status_score
user_expenses_home_score
user_income_employment_length_months_score

score_card_vars=c('credit_agency_pd_logit', 'user_age_score', 'marital_status', 'user_income_employment_status_score',
'user_income_employment_length_months_score', 
'gender'


km_vars<-c('duration_in_months','payout_quarter','marital_status', 'user_income_employment_status','user_expenses_home')
km_vars_fits<-list()
km_vars_default_rate<-list()
for (f in km_vars){
    km_vars_fits[[f]]<-npsurv(Surv(df$surv_time_90_eom, df$late_90_eom)~df[[f]])
    f_name=paste0('sp_surv90_',f, '.emf')
    win.metafile(f_name)
    survplot(km_vars_fits[[f]],ylim=c(0,.3),col=seq(km_vars_fits[[f]]$strata), n.risk=T,y.n.risk=.15,levels.only=T, xlab='Observation time', ylab='Default probability', fun=function(x) 1-x)
    dev.off()
}

f<-'overall'
km_vars_fits[[f]]<-npsurv(Surv(df$surv_time_90_eom, df$late_90_eom)~1)

default_rate_name<-paste(f,90,'6M',sep='_')
km_vars_default_rate[[default_rate_name]]<-binom_conf_interval(df$late_90_eom_6m,.95)

default_rate_name<-paste(f,90,'9M',sep='_')
km_vars_default_rate[[default_rate_name]]<-binom_conf_interval(df$late_90_eom_9m,.95)
default_rate_name<-paste(f,90,'12M',sep='_')
km_vars_default_rate[[default_rate_name]]<-binom_conf_interval(df$late_90_eom_12m,.95)
              

f_name=paste0('sp_surv90_',f, '.emf')
#win.metafile(f_name)
survplot(km_vars_fits[[f]],ylim=c(.85,1), n.risk=T, 
         main='Portfolio 90+ survival curve', xlab='Observation time', ylab='Default probability')
default_rate_name<-paste(f,90,'6M',sep='_')

mnths <- seq(6,12,3)
x <-30 * mnths
y <- sapply(mnths,function (x) km_vars_default_rate[[paste0('overall_90_',x,'M')]]$mean)
y_m <- sapply(mnths,function (x) km_vars_default_rate[[paste0('overall_90_',x,'M')]]$lower_CI)
y_p <- sapply(mnths,function (x) km_vars_default_rate[[paste0('overall_90_',x,'M')]]$upper_CI)
# showing survival not default so lower bound -> upper
errbar(x,1-y,1-y_m, 1-y_p, add=T)
points(6*30, 1 - km_vars_default_rate[[default_rate_name]]$mean, pch=19)
default_rate_name<-paste(f,90,'9M',sep='_')
points(9*30, 1 - km_vars_default_rate[[default_rate_name]]$mean, pch=19)
default_rate_name<-paste(f,90,'12M',sep='_')
points(12*30, 1 - km_vars_default_rate[[default_rate_name]]$mean, pch=19)
title(main='Kaplan-Meier estimate: Portfolio 90+')
# we are using EOM so observation date is 90+30
x1<-seq(90+30,700,90)
lam<- -log(1-0.05)
lam1<- -log(1-0.08)
y1<-exp(-lam * (x1-(90+30))/365)
y2<-exp(-lam1 * (x1-(90+30))/365)
lines(x1,y1,col=2)
lines(x1,y2,col=3)
# dashed line
abline(h=.95, col=2, lty=3)
abline(v=365+90+30, col=2, lty=3)
legend(50,.95,legend=c('overall','5% annual pd', '8% annual pd'),fill=seq(3))

#dev.off()

# todo add error bars other estimates

my.fit.duration<-survfit(Surv(df$surv_time_90_eom, df$late_90_eom) ~df$duration_in_months)
plot(my.fit.duration, main="Kaplan-Meier estimate Loan Duration", 
     xlab="time", 
     ylab="survival function", 
     col=seq(6),ymin=.85,
     
     yscale=100)
z1<-sort(unique(df$duration_in_months))
#z2<-c("overall",z1)
legend(50,.95,legend=z1,fill=seq(6))

my.fit.duration_fraction<-survfit(Surv(df$surv_time_90_eom/df$duration_in_months/30, df$late_90_eom) ~df$duration_in_months)
plot(my.fit.duration_fraction, main="Kaplan-Meier estimate Loan Duration", 
      xlab="time", 
      ylab="survival function", 
      col=seq(6),ymin=.85,
     yscale=100)
z1<-sort(unique(df$duration_in_months))
#z2<-c("overall",z1)
legend(.05,.93,legend=z1,fill=seq(6))


my.fit<-survfit(Surv(df$surv_time_90_eom, df$late_90_eom) ~1)
plot(my.fit, main="Kaplan-Meier estimate: Portfolio 90+", 
     xlab="observation time", 
     ylab="survival function", 
     ymin=.85,
     yscale=100)
x1<-seq(0,700,90)
lam<- -log(1-0.05)
y1<-exp(-lam * (x1-90)/365)
lines(x1,y1,col=2)
# dashed line
abline(h=.95, col=2, lty=3)
legend(50,.95,legend=c('overall','5% annual pd'),fill=seq(2))


my.fit.payout_quarter<-survfit(Surv(df$surv_time_90_eom, df$late_90_eom) ~df$payout_quarter)
plot(my.fit, main="Kaplan-Meier estimate Payout quarter 90+", 
     xlab="time", 
     ylab="survival function", 
     ymin=.85,
     yscale=100)
lines(my.fit.payout_quarter, main="Kaplan-Meier estimate Payout quarter", 
     xlab="time", 
     ylab="survival function", 
     col=seq(2,9),ymin=.85,
     yscale=100)
z1<-sort(unique(payout_quarter))
z2<-c("overall",as.character(z1))
legend(50,.95,legend=z2,fill=seq(9))
capture.output(summary(my.fit.payout_quarter),file=file('clipboard-128'))

# schufa rating

plot_km<-function(df, factor, selection){
    fit_it<-survfit(Surv(df$surv_time_90_eom[selection], df$late_90_eom[selection]) ~df[selection, factor])
    z1<-sort(unique(df[selection,factor]))
    cols<-seq(length(z1))
    plot(fit_it, main=paste0("Kaplan-Meier estimate 90+ ", factor), 
         xlab="observation time", 
         ylab="survival function", 
         col=cols,ymin=.85,
         yscale=100)
    z2<-as.character(z1)
    return (list(fit_it, z2))
}


fit_leg<-plot_km(df, 'credit_agency_rating', df$credit_agency_rating %in% c('A','B','C','D','E','F','G'))
my.fit.credit_agency_rating<-fit_leg[[1]]
legend(50,.95,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))

df, 'credit_agency_rating', df$credit_agency_rating %in% c('A','B','C','D','E','F','G'))


fit_leg<-plot_km(df, 'user_campaign', df$user_campaign %in% c('other','creditolo','credit12'))
my.fit.user_campaign<-fit_leg[[1]]
legend(50,.95,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))

fit_leg<-plot_km(df, 'marital_status', T)
my.fit.marital_status<-fit_leg[[1]]
legend(50,.85,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))

# marital_status_score=pd.read_csv(StringIO.StringIO(\
#        """status                  counts  score      
#        married                 1755    1
#        single                  1378    0
#        divorced                 449    1
#        separated                103    1
#        widowed                   95    0
#        domestic_partnership      57    -1
#        partnership               19    -1
#        married_b                 1     -1"""),sep="\s+", index_col=0)
# user_income_employment_status_score=pd.read_csv(StringIO.StringIO(\
#   """status             counts        score
#   salaried              1922          -1
#   self_employed         1118           2
#   public_official        299          -2 
#   retired                258          -1
#   manual_worker          136           0
#   freelancer              95           2
#   student                 10           2 
#   soldier                  7           0
#   welfare                  5           2
#   house_wife_husband       1           2"""),sep="\s+", index_col=0)


#      """status             counts        score    
#      rent                   2008          0
#      own                    1370         -1 
#      living_with_parents     445          0
#      family                   18          0
#      other                    1           0"""),sep="\s+", index_col=0)
# df['user_income_employment_status_score'] = \
# df['user_income_employment_status'].map(user_income_employment_status_score.score)
# df['user_expenses_home_score'] = \
# df['user_expenses_home'].map(user_expenses_home.score)
#df.user_income_employment_length_months.describe(
#    count    2781.000000
#    mean      114.051420
#    std       108.243357
#    min         0.000000
#    25%        32.000000
#    50%        78.000000
#    75%       171.000000
#    max      1004.00000



# 'marital_status', 'user_income_employment_status',
# 'user_income_employment_length_months_score', 
# 'gender']

fit_leg<-plot_km(df, 'user_income_employment_status', df$user_income_employment_status %in% 
                     c('salaried','self_employed','public_official','retired','manual_worker','freelancer') )
my.fit.user_income_employment_status<-fit_leg[[1]]
legend(50,.95,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))

user_income_employment_length_months_score
fit_leg<-plot_km(df, 'user_income_employment_length_months_score', T )
my.fit.user_income_employment_length_months_score<-fit_leg[[1]]
legend(50,.95,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))



fit_leg<-plot_km(df, 'gender', T )
my.fit.gender<-fit_leg[[1]]
legend(50,.95,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))


fit_leg<-plot_km(df, 'user_expenses_home', T )
my.fit.user_expenses_home<-fit_leg[[1]]
legend(50,.95,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))



fit_leg<-plot_km(df, 'user_age_score', T )
my.fit.user_age_score<-fit_leg[[1]]
legend(50,.90,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))

fit_leg<-plot_km(df, 'h..Ergebnis.Kalkulation_quartile', T )
my.fit.capacity_quartile<-fit_leg[[1]]
legend(50,.90,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))

fit_leg<-plot_km(df, 'a..Summe.Einnahmen_quartile', T )
my.fit.income_quartile<-fit_leg[[1]]
legend(50,.90,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))


df$Postcheck.Income.total_quartile=(cut(df$Postcheck.Income.total,quantile(df$Postcheck.Income.total,seq(0,1,0.25),na.rm=T)))




fit_leg<-plot_km(df, 'Postcheck.Income.total_quartile', T )
my.fit.income_web_quartile<-fit_leg[[1]]
legend(50,.90,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))


df$free_capacity_to_income<-df[['h..Ergebnis.Kalkulation']]/df[['a..Summe.Einnahmen']]
df$free_capacity_to_income_score<-cut( df$free_capacity_to_income,breaks=c(-1000,.25,.42,200))



fit_leg<-plot_km(df, 'free_capacity_to_income_score', T )
my.fit.free_capacity_to_income<-fit_leg[[1]]
legend(50,.90,legend=fit_leg[[2]],fill=seq(length(fit_leg[[2]])))



plot(my.fit.credit_agency_rating, main="Kaplan-Meier estimate Credit Agency Rating 90+", 
      xlab="observation time", 
      ylab="survival function", 
      col=seq(1,12),ymin=.85,
      yscale=100)
z1<-sort(unique(credit_agency_rating))
z2<-as.character(z1)
legend(50,.95,legend=z2,fill=seq(12))




my.fit.<-survfit(Surv(surv_time_90, late_90) ~duration_months)

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


loans_account_attribute_lates_lates_EOM_indebt[defaulted_within_nine_months, c('id_loan','payout_date','duration_months','surv_time_90')]


underwriting_merge_red=read.csv('../../Capacity/src/underwriting_merge_red_20150919.csv')

loans_account_attribute_lates_lates_EOM_indebt_cap_underwriting<-merge(
        x=loans_account_attribute_lates_lates_EOM_indebt_cap,
        y= underwriting_merge_red,
        by.x="loan_nr",
        by.y="loan_request_nr_comb_over",
        all.x=TRUE)

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

vars<-c("credit_agency_score_logit","gender", "user_age_f", "marital_status", 
        "user_income_employment_status_f","user_income_employment_type_f" ,
        "user_income_employment_length_months_f","user_expenses_home_f")

within(loans_account_attribute_lates_lates_EOM_indebt_cap_underwriting,
       credit_agency_score_logit<-logit(1-credit_agency_score/10000)
)

replace_NA<-function (fac){
    fac<-factor(fac, levels=c(levels(fac),'NAF'))
    fac[is.na(fac)]<-'NAF'
    fac
}

loans_account_attribute_lates_lates_EOM_indebt_cap_underwriting<-
    loans_account_attribute_lates_lates_EOM_indebt_cap_underwriting[
            -as.logical(loans_account_attribute_lates_lates_EOM_indebt_cap_underwriting$sme_flag),]

within(loans_account_attribute_lates_lates_EOM_indebt_cap_underwriting,{
    credit_agency_score_quartile<-cut(credit_agency_score,quantile(credit_agency_score,seq(0,1,0.25)))
    user_income_employment_length_months_f<-cut(user_income_employment_length_months,c(0,24,60),right=F)
    user_income_employment_length_months_f<-replace_NA(user_income_employment_length_months_f)
    user_income_employment_type<-replace_NA(user_income_employment_type)
    
    user_age_f<-cut(user_age,c(18,31,46,76),right=FALSE)

    
    # home leave as is ( but deal with NA)
    user_expenses_home_f<-replace_NA(user_expenses_home)
    more_than_nine_months_ago<-payout_date<=as.Date('2015-01-01')
    
    defaulted_within_nine_months<-(more_than_nine_months_ago & (surv_time_90_eom<9*31) & late_90_eom)
    
})

loans_account_attribute_lates_lates_EOM_indebt_cap_underwriting<-merge(loans_account_attribute_lates_lates_EOM_indebt_cap_underwriting,
                                                      employment_status_lookup)

tapply(loans_account_attribute_lates_lates_EOM_indebt$defaulted_within_nine_months[more_than_nine_months_ago],
       credit_agency_score_decile[more_than_nine_months_ago],mean)

user_income_employment_length_months

