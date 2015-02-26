require(xlsx)
require(plyr)
require(ggplot2)
require(GGally)
require(gridExtra)
require(data.table)
require(lubridate)
require(glmnet)
require(ROCR)
require(reshape2)

# load & format
# select
# train test
# model list
# train ->test score
# plot results
# store models and results 
# store models with training data
# split out model from generic code...


summary_reals<-function(dt, target,real_vars){
  list_sum<-lapply(real_vars,function (f) dt[,c(variable=f,N=.N, as.list(summary(get(f)))),keyby=get(target)])
  df_sum<-do.call(rbind,list_sum)
  setnames(df_sum,'get',target)
}

summary_factors<-function(dt, target,factor_vars){
  # calc N, mean, std err
  
  list_sum<-lapply(factor_vars,function (f) dt[,.(fact=f, N=.N, rate=sum(get(target)==1)/.N, std_err=sum(get(target)==1)*(.N-sum(get(target)==1))/.N^3),keyby=f])
  
  # create combined dataframe by adding column with variable name
  for (i in 1:length(factor_vars))   setnames(list_sum[[i]], factor_vars[i], 'value')
  df_sum<-do.call(rbind,list_sum)
}

glmdf<-function(cv.fit){
  # create data frame of of metric and coefficients
  metric_df<-data.frame(lambda=cv.fit$lambda, type=cv.fit$name, cvm=cv.fit$cvm, cvup=cv.fit$cvup,cvlo=cv.fit$cvlo,cvsd=cv.fit$cvsd,nzero=cv.fit$nzero)
  coef_df<-as.data.frame(as.matrix(coef(cv.fit$glmnet.fit)))
  coef_df$coef=rownames(coef_df)
  colnames(coef_df)<-cv.fit$lambda
  coef_df<-melt(coef_df,variable.name='lambda')
  list(metrics=metric_df,coefs=coef_df, lambda_crit=list(name=cv.fit$name,min=cv.fit$lambda.min, se1=cv.fit$lambda.1se))
}

glm_boot_gen<-function(family, measure, lambda, pred_type){

  function(data,frequencies){
    y<-data[,1]
    x<-data[,2:ncol(data)]
    weights<-frequencies
    cv.fit<-cv.glmnet(x, y, weights,family=family, type.measure=measure)
    c<-coef(cv.fit,lambda)
    v<-predict(cv.fit,x,s=lambda,type=pred_type)
    v
  }
  
}

gini<-function(predictions,labels){
  pred<-prediction(predictions,labels)
  perf<-performance(pred, measure = "auc")
  perf@'y.values'[[1]]*2-1
  
}

logloss<-function(actual,target){
  err=-((target==1)*log(actual)+(target==0)*log(1-actual))
  mean(err)
}

dict<-read.xlsx('C:\\Users\\Sean Violante\\Documents\\Projects\\lendico\\Projects\\Bondora\\data\\BondoraAll03.xlsm',
                sheetName='BondoraLoanDictionaryClean', stringsAsFactors=FALSE)

load_data<-function(dict){
  dates_names<-unique(dict$column[dict$type=='date'])
  loandata<-read.csv('C:\\Users\\Sean Violante\\Documents\\Projects\\lendico\\Projects\\Bondora\\data\\LoanData_20150204_es.csv', 
                     stringsAsFactors=FALSE,fileEncoding="UTF-8")
  
  loandata[dates_names]<-lapply(loandata[dates_names], function (x) as.Date(x,format='%Y-%m-%d'))
  
  
  # factors naturally handle NAs - problem of what to do for reals and ints - 
  loandata$nr_of_dependants[is.na(loandata$nr_of_dependants)]='Blank'
  loandata$nr_of_dependants<-as.factor(loandata$nr_of_dependants)
  loandata$nr_of_dependants_1<-!loandata$nr_of_dependants %in% c('Blank','0')
  
# for each factor (that isn't boolean)
#replace code by value
# first turn code variables  into factors
  factor_fields_orig<-unique(dict[dict$type=='categ','column'])
# read.csv calls make.names bydefault.
  factor_fields<-make.names(factor_fields_orig)

  loandata$work_experience[loandata$work_experience=='']<-'Blank'
  loandata$work_experience<-factor(loandata$work_experience,levels=c("Blank","LessThan2Years","2To5Years","5To10Years",
                                                                     "10To15Years","15To25Years","MoreThan25Years"))
  loandata$work_experience_10=loandata$work_experience %in% c("10To15Years", "15To25Years", "MoreThan25Years")

  loandata$Employment_Duration_Current_Employer[loandata$Employment_Duration_Current_Employer=='']<-'Blank'
  loandata$Employment_Duration_Current_Employer<-factor(loandata$Employment_Duration_Current_Employer,
                                                        levels=c("Blank","TrialPeriod", "UpTo1Year","UpTo2Years", "UpTo3Years", "UpTo4Years" ,"UpTo5Years", "MoreThan5Years" ))
          
  releveled<-  c('work_experience', 'Employment_Duration_Current_Employer')
  loandata[factor_fields[!factor_fields %in% releveled] ]<-lapply(loandata[factor_fields[!factor_fields %in% releveled] ], as.factor)
# TODO rearrange work experience, higher education, 

# remove factors for which either already named factor or description too long
  dont_relevel<-c('CreditGroup', 'Country','ApplicationSignedWeekday', 'ApplicationSignedHour', 'ApplicationType', 
                  'Employment_Duration_Current_Employer', 'BondoraCreditHistory', 'MonthlyPaymentDay', 
                  'nr_of_dependants', 'work_experience','Rating_V0', 'Rating_V1')
  factor_fields_rename<-factor_fields_orig[!factor_fields_orig  %in% dont_relevel]

  # now put description in
  for (f in factor_fields_rename){
    f_clean=make.names(f)
    # needs to be list for levels change to work
    code<-as.list(dict[dict$column==f,'value'])
    meaning<-as.list(dict[dict$column==f,'value.meaning'])
    levels(loandata[[f_clean]])<-setNames(code,meaning)
  }

  list(data=loandata, factors=factor_fields)
}

z<-load_data(dict)

loandata<-z$data
factor_fields<-z$factors



# glmnet needs NA removed
z1<-as.character(loandata$occupation_area)
z1[is.na(z1)]='blank'
loandata$occupation_area=as.factor(z1)


# process ints

int_fields<-unique(dict[dict$type=='integer','column'])

summary(loandata[int_fields])

# empty/0 for spain

drop_ints<-c('TotalNumDebts','TotalMaxDebtMonths','NumDebtsFinance','MaxDebtMonthsFinance',
             'NumDebtsTelco','MaxDebtMonthsTelco','NumDebtsOther','MaxDebtMonthsOther', 'NoOfInvestments')
int_fields<-int_fields[!int_fields %in% drop_ints]

real_fields<-unique(dict[dict$type=='real','column'])

request_fields<-unique(dict[dict$category=='request','column'])
request_reals<-intersect(real_fields,request_fields)
request_factors<-intersect(factor_fields,request_fields)
request_ints<-intersect(int_fields,request_fields)


drop_request_ints<-c('BidsInvestmentPlan','BidsManual','NoOfBids') 
request_ints<-request_ints[!request_ints %in% drop_request_ints]

drop_factors<-c('ApplicationType', 'Country','language_code')
paste('dropping', drop_factors)
request_factors<-request_factors [!request_factors  %in% drop_factors]
paste(request_factors)

drop_reals<-c('AmountOfInvestments',  'AmountOfBids')
request_reals<-request_reals [!request_reals  %in% drop_reals]
drop_more_reals<-c('income_from_principal_employer','IncomeFromPension','IncomeFromFamilyAllowance', 'IncomeFromSocialWelfare',
'IncomeFromLeavePay','IncomeFromChildSupport','income_other',
'AmountOfPreviousApplications','AmountOfPreviousLoans','PreviousRepayments', 'PreviousLateFeesPaid', 'PreviousEarlyRepayments')
request_reals<-request_reals [!request_reals  %in% drop_more_reals]
# determine where to label selection flags (& whether to include all other filters) ..
# better to label everything if write to main df (or likely to have old data in other rows via bugs)

# select data
# filter out loans that have been issued and NOT been extended
loan_issued<-(!is.na(loandata$LoanDate) )
loan_unchanged<-loan_issued & (loandata$CurrentLoanHasBeenExtended==0) & (loandata$MaturityDate_Last==loandata$MaturityDate_Original)
loan_verified<-loan_issued &  loandata$VerificationType=='Income and expenses verified'
  
loandata$selected_loans_6m<-( !is.na(loandata$LoanDate) & (interval(loandata$LoanDate,loandata$ReportAsOfEOD)/edays(1)>180))


loandata$selected_loans_6m<-loandata$selected_loans_6m & loan_unchanged
tr_te=rbinom(sum(loandata$selected_loans_6m),1,.7)
loandata$selected_loans_6m_train<- -1 # our label for missing,  0 =test, 1 =train
loandata$selected_loans_6m_train[loandata$selected_loans_6m]<-tr_te



# define default
loandata$defaulted_before_6m[loandata$selected_loans_6m]<-!is.na(loandata$DefaultedOnDay[loandata$selected_loans_6m]) & loandata$DefaultedOnDay[loandata$selected_loans_6m]<=180

# datatable does fast grouping etc
loandata_dt<-data.table(loandata)


loans<-loandata[loandata$selected_loans_6m_train==1,]
loans_dt<-loandata_dt[loandata_dt$selected_loans_6m_train==1,]


target_variable<-'defaulted_before_6m'


rate_overall<-loans_dt[,c(N=.N,rate=mean(get(target_variable)))]

loans_dt_ints_all<-summary_factors(loans_dt, target_variable,request_ints)
loans_dt_facs_all<-summary_factors(loans_dt, target_variable,request_factors)
loans_dt_reals_all<-summary_reals(loans_dt, target_variable,request_reals)

report_name<-paste0('univariate_factors_no_resched_',target_variable,'.pdf')

p<-ggplot(data=loans_dt_facs_all, aes(x=value, y=rate*100,size=N, ymin=rate*100-100*std_err,ymax=rate*100+100*std_err) ) +  
  geom_point()+scale_size_area()+geom_hline(yintercept=rate_overall[['rate']]*100) + coord_flip()
plots<-dlply(loans_dt_facs_all,"fact",  function(x) `%+%`(p,x)+xlab(x$fact[[1]])  )
ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))

ggsave(report_name, ml, width=21,height=27)

report_name<-paste0('univariate_ints_no_resched_',target_variable,'.pdf')
p<-ggplot(data=loans_dt_ints_all, aes(x=value, y=rate*100,size=N, ymin=rate*100-100*std_err,ymax=rate*100+100*std_err) ) +  
  geom_point()+scale_size_area()+geom_hline(yintercept=rate_overall[['rate']]*100) + coord_flip()
# replace current dataframe `%+%`, and provide labels
plots<-dlply(loans_dt_ints_all,"fact",  function(x) `%+%`(p,x)+xlab(x$fact[[1]])  )
ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
ggsave(report_name, ml, width=21,height=27)


report_name<-paste0('univariate_reals_no_resched_',target_variable,'.pdf')
loans_dt_reals_all$default<-loans_dt_reals_all$defaulted_before_6m==TRUE
# need dataframe just because of invalid column names
ml<-ggplot(data=data.frame(loans_dt_reals_all),
           aes_string(x=target_variable,ymin='Min.',lower='X1st.Qu.', middle='Median', upper='X3rd.Qu.', ymax='Max.')) + 
            geom_boxplot(stat='identity') +facet_wrap(~variable,scales='free')
ggsave(report_name, ml, width=21,height=27)



# histogram & density

#ggplot(data=loans,aes(x=LiabilitiesToIncome,y=..density..,fill=defaulted_before_6m))+geom_histogram(alpha=0.4,position='identity')
#ggplot(data=loans,aes(x=LiabilitiesToIncome,colour=defaulted_before_6m))+geom_line(stat='density')

report_name<-paste0('hist_reals_no_resched_',target_variable,'.pdf')
p<-ggplot(data=loans,aes(y=..density..,fill=defaulted_before_6m))+geom_histogram(alpha=0.4,position='identity')

plots<-llply(request_reals,  function(x) p+aes_string(x)  )
ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
ggsave(report_name, ml, width=21,height=27)


p<-ggplot(data=loans_dt_facs_all, aes(x=value, y=rate*100,size=N, ymin=rate*100-100*std_err,ymax=rate*100+100*std_err) ) +  
  geom_point()+scale_size_area()+geom_hline(yintercept=rate_overall[['rate']]*100) + coord_flip()
plots<-dlply(loans_dt_facs_all,"fact",  function(x) `%+%`(p,x)+xlab(x$fact[[1]])  )
ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
ggsave(report_name, ml, width=21,height=27)



predict_cols<-c('AppliedAmount','AppliedAmountToIncome','DebtToIncome','FreeCash','LiabilitiesToIncome','NewLoanMonthlyPayment', 'NewPaymentToIncome','SumOfBankCredits', 'SumOfOtherCredits')
#predict_cols<-request_reals
predict_cols<-c('NewPaymentToIncome','LiabilitiesToIncome',
                'VerificationType','Gender','UseOfLoan',
                'education_id','marital_status_id','employment_status_id','Employment_Duration_Current_Employer','occupation_area',
                'home_ownership_type_id')


predict_cols<-c('NewPaymentToIncome','LiabilitiesToIncome','UseOfLoan',
                'VerificationType','Gender',
                'education_id','marital_status_id','employment_status_id','Employment_Duration_Current_Employer','occupation_area',
                'home_ownership_type_id')



loans_selected<-loandata[loandata$selected_loans_6m,]

pai=c('NewPaymentToIncome','LiabilitiesToIncome','UseOfLoan',
'VerificationType','credit_score','CreditGroup')
ggpairs(data=loans[,pai])

y1<-as.matrix(loans_selected$defaulted_before_6m==TRUE)

#x1<-model.matrix(AD~(NewPaymentToIncome+LiabilitiesToIncome)*(VerificationType + Gender+ UseOfLoan+education_id+marital_status_id+employment_status_id+Employment_Duration_Current_Employer+occupation_area+home_ownership_type_id)-1,data=loandata[selected_loans,])
#y<-loandata[selected_loans,'AD']==1

reals_formula<-formula(defaulted_before_6m~AppliedAmount+AppliedAmountToIncome+DebtToIncome+FreeCash+LiabilitiesToIncome+NewLoanMonthlyPayment+NewPaymentToIncome+SumOfBankCredits+SumOfOtherCredits-1)
ints_formula<-update.formula(reals_formula, . ~ Age+LoanDuration+nr_of_dependants+CountOfBankCredits+CountOfPaydayLoans+CountOfOtherCredits+NoOfPreviousApplications+NoOfPreviousLoans-1   )
base_formula<-formula(defaulted_before_6m~VerificationType+Gender+UseOfLoan+LoanDuration+education_id+ 
  employment_status_id+Employment_Duration_Current_Employer+work_experience_10+occupation_area+
  marital_status_id+nr_of_dependants_1+home_ownership_type_id+  
  CountOfBankCredits+CountOfOtherCredits-1)
# factors_formula<-update.formula(reals_formula, . ~VerificationType+Gender+credit_score+CreditGroup+UseOfLoan+education_id+
#                                   marital_status_id+nr_of_dependants+
#                                   employment_status_id+Employment_Duration_Current_Employer+work_experience+occupation_area+
#                                   home_ownership_type_id+BondoraCreditHistory+Rating_V0+Rating_V1-1)
x1<-model.matrix(factors_formula,data=loans_selected)
x1<-model.matrix(defaulted_before_6m~VerificationType+AppliedAmountToIncome-1,data=loans_selected)

x1<-model.matrix(base_formula,data=loans_selected)

cv.fit<-cv.glmnet(x1,y1,family='binomial', type.measure='auc')
predict_tr<-predict(cv.fit,x1,type='response',s='lambda.1se')
coef(cv.fit,s='lambda.1se')
gini(predict_tr,y1)

ggplot(as.data.frame(predict_tr),aes(x=`1`))+geom_bar()



predict_tr<-predict(fit,x1,type='response',s='s1')
coef(fit)
gini(predict_tr,y1)

summary(loandata[(request_fields)])

#extract coefs
coef(cv.fit,s='lambda.1se')
predict_tr<-predict(cv.fit,x1,type='response',s='lambda.min')


loans_dt_reals_all[loans_dt_reals_all$real %in% rownames(coef(cv.fit,s='lambda.1se')),]

#library(grid)
#library(gridExtra)


# bootstrapping
glm_boot<-glm_boot_gen('binomial', 'auc', 'lambda.1se', 'response')
z<-boot(data,glm_boot,10,stype='f')
a<-z$t
b1<-apply(a,2,sd)
b<-colMeans(a)
c<-data.frame(m=b,s=b1/sqrt(10))
d<-c[order(c$m),]
ggplot(d,aes(x=1:647,y=m))+geom_point()+geom_errorbar(aes(ymax=m+s,ymin=m-s))
