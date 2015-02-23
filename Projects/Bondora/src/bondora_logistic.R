require(xlsx)
require(plyr)
require(ggplot2)
require(gridExtra)
require(data.table)
require(lubridate)
require(glmnet)
require(ROCR)


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

gini<-function(predictions,labels){
  pred<-prediction(predictions,labels)
  perf<-performance(pred, measure = "auc")
  perf@'y.values'[[1]]*2-1
  
}

logloss<-function(actual,target){
  err=-((target==1)*log(actual)+(target==0)*log(1-actual))
  mean(err)
}
# load & format
# select
# train test
# model list
# train ->test score
# plot results

dict<-read.xlsx('C:\\Users\\Sean Violante\\Documents\\Projects\\lendico\\Projects\\Bondora\\data\\BondoraAll.xlsm',
                sheetName='BondoraLoanDictionaryClean', stringsAsFactors=FALSE)

load_data<-function(dict){
  dates_names<-unique(dict$column[dict$type=='date'])
  loandata<-read.csv('C:\\Users\\Sean Violante\\Documents\\Projects\\lendico\\Projects\\Bondora\\data\\LoanData_20150204_es.csv', 
                     fileEncoding="UTF-8")
  
  loandata[dates_names]<-lapply(loandata[dates_names], function (x) as.Date(x,format='%Y-%m-%d'))
# for each factor (that isn't boolean)
#replace code by value
# first turn code variables  into factors
  factor_fields_orig<-unique(dict[dict$type=='categ','column'])
# read.csv calls make.names bydefault.
  factor_fields<-make.names(factor_fields_orig)

  loandata[factor_fields]<-lapply(loandata[factor_fields], as.factor)

# remove factors for which either already named factor or description too long
  dont_relevel<-c('CreditGroup', 'Country','ApplicationSignedWeekday', 'ApplicationSignedHour', 'ApplicationType', 
                  'Employment_Duration_Current_Employer', 'BondoraCreditHistory', 'MonthlyPaymentDay', 
                  'work_experience','Rating_V0', 'Rating_V1')
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




# select data
# filter out loans that have been issued and NOT been extended
selected_loans=(!is.na(loandata$LoanDate) )  & (loandata$CurrentLoanHasBeenExtended==0) & (loandata$MaturityDate_Last==loandata$MaturityDate_Original)

loandata$selected_loans_6m<-( !is.na(loandata$LoanDate) & (interval(loandata$LoanDate,loandata$ReportAsOfEOD)/edays(1)>180))
loandata$selected_loans_6m<-loandata$selected_loans_6m & selected_loans
# define default
loandata$defaulted_before_6m[loandata$selected_loans_6m]<-!is.na(loandata$DefaultedOnDay[loandata$selected_loans_6m]) & loandata$DefaultedOnDay[loandata$selected_loans_6m]<=180

# datatable does fast grouping etc
loandata_dt<-data.table(loandata)


loans<-loandata[loandata$selected_loans_6m,]
loans_dt<-loandata_dt[loandata_dt$selected_loans_6m,]


target_variable<-'defaulted_before_6m'


rate_overall<-loans_dt[,c(N=.N,rate=mean(get(target_variable)))]

loans_dt_ints_all<-summary_factors(loans_dt, target_variable,request_ints)
loans_dt_facs_all<-summary_factors(loans_dt, target_variable,request_factors)
loans_dt_reals_all<-summary_reals(loans_dt, target_variable,request_reals)

report_name<-paste0('univariate_factors_no_resched',target_variable,'.pdf')

p<-ggplot(data=loans_dt_facs_all, aes(x=value, y=rate*100,size=N, ymin=rate*100-100*std_err,ymax=rate*100+100*std_err) ) +  
  geom_point()+scale_size_area()+geom_hline(yintercept=rate_overall[['rate']]*100) + coord_flip()
plots<-dlply(loans_dt_facs_all,"fact",  function(x) `%+%`(p,x)+xlab(x$fact[[1]])  )
ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
ggsave(report_name, ml, width=21,height=27)

report_name<-paste0('univariate_ints_',target_variable,'.pdf')
p<-ggplot(data=loans_dt_ints_all, aes(x=value, y=rate*100,ymin=rate*100-100*std_err,ymax=rate*100+100*std_err) ) +  
  geom_point()+scale_size_range()+geom_hline(yintercept=rate_overall[['rate']]*100) + coord_flip()
# replace current dataframe `%+%`, and provide labels
plots<-dlply(loans_dt_ints_all,"fact",  function(x) `%+%`(p,x)+xlab(x$fact[[1]])  )
ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
ggsave(report_name, ml, width=21,height=27)


report_name<-paste0('univariate_reals_',target_variable,'.pdf')
loans_dt_reals_all$default<-loans_dt_reals_all$defaulted_before_6m==TRUE
ml<-ggplot(data=loans_dt_reals_all,aes(x=defaulted_before_6m,ymin=`Min.`,lower=`1st Qu.`, middle=`Median`, upper=`3rd Qu.`, ymax=`Max.`))+geom_boxplot(stat='identity') +facet_wrap(~variable,scales='free')
ggsave(report_name, ml, width=21,height=27)




predict_cols<-c('AppliedAmount','AppliedAmountToIncome','DebtToIncome','FreeCash','LiabilitiesToIncome','NewLoanMonthlyPayment', 'NewPaymentToIncome','SumOfBankCredits', 'SumOfOtherCredits')
#predict_cols<-request_reals
predict_cols<-c('NewPaymentToIncome','LiabilitiesToIncome','VerificationType','Gender','UseOfLoan','education_id','marital_status_id','employment_status_id','Employment_Duration_Current_Employer','occupation_area','home_ownership_type_id')




loans_selected<-loandata[loandata$selected_loans_6m,]

#x1<-model.matrix(AD~(NewPaymentToIncome+LiabilitiesToIncome)*(VerificationType + Gender+ UseOfLoan+education_id+marital_status_id+employment_status_id+Employment_Duration_Current_Employer+occupation_area+home_ownership_type_id)-1,data=loandata[selected_loans,])
#y<-loandata[selected_loans,'AD']==1


x1<-model.matrix(defaulted_before_6m~AppliedAmount+AppliedAmountToIncome+DebtToIncome+FreeCash+LiabilitiesToIncome+NewLoanMonthlyPayment+NewPaymentToIncome+SumOfBankCredits+SumOfOtherCredits-1,data=loans_selected)
y1<-as.matrix(loans_selected$defaulted_before_6m==TRUE)
cv.fit<-cv.glmnet(x1,y1,family='binomial')

fit<-glmnet(x1,y1,family='binomial')
summary(loandata[(request_fields)])

#extract coefs
coef(cv.fit,s='lambda.1se')
predict_tr<-predict(cv.fit,x1,type='response',s='lambda.min')


z1a<-prediction(predict_tr,y1)
z2a<-performance(z1a, measure = "auc")
z2a@'y.values'[[1]]
loans_dt_reals_all[loans_dt_reals_all$real %in% rownames(coef(cv.fit,s='lambda.1se')),]

#library(grid)
#library(gridExtra)


