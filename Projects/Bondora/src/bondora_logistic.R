require(xlsx)
require(plyr)
require(ggplot2)
require(gridExtra)
require(data.table)
require(lubridate)
require(ROCR)

summary_reals<-function(dt, target,real_vars){
  list_sum<-lapply(real_vars,function (f) dt[,c(variable=f,N=.N, as.list(summary(get(f)))),keyby=get(target)])
  df_sum<-do.call(rbind,list_sum)
  setnames(df_sum,'get',target)
}

summary_factors<-function(dt, target,factor_vars){
  # calc N, mean, std err
  
  list_sum<-lapply(factor_vars,function (f) l1_orig[,.(fact=f, N=.N, rate=sum(get(target)==1)/.N, std_err=sum(get(target)==1)*(.N-sum(get(target)==1))/.N^3),keyby=f])
  
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



dict<-read.xlsx('C:\\Users\\Sean Violante\\Documents\\Projects\\lendico\\Projects\\Bondora\\data\\BondoraAll.xlsm',
                sheetName='BondoraLoanDictionaryClean', stringsAsFactors=FALSE)


loandata<-read.csv('C:\\Users\\Sean Violante\\Documents\\Projects\\lendico\\Projects\\Bondora\\data\\LoanData_20150204_es.csv', fileEncoding="UTF-8")

loandata$LoanDate<-as.Date(loandata$LoanDate,format='%Y-%m-%d')
loandata$MaturityDate_Last<-as.Date(loandata$MaturityDate_Last,format='%Y-%m-%d')
loandata$MaturityDate_Original<-as.Date(loandata$MaturityDate_Original,format='%Y-%m-%d')

# glmnet needs NA removed
z1<-as.character(loandata$occupation_area)
z1[is.na(z1)]='blank'
loandata$occupation_area=as.factor(z1)

int_fields<-unique(dict[dict$type=='integer','column'])

factor_fields_orig<-unique(dict[dict$type=='categ','column'])
# read.csv calls make.names bydefault.
factor_fields_orig<-factor_fields_orig[!is.na(factor_fields_orig)]
factor_fields<-make.names(factor_fields_orig)
# factor_fields<-replace(factor_fields,factor_fields=='1D FromFirstPayment', "X1D.FromFirstPayment")
# factor_fields<-replace(factor_fields,factor_fields=='14D FromFirstPayment', "X14D.FromFirstPayment")
# factor_fields<-replace(factor_fields,factor_fields=='30D FromFirstPayment', "X30D.FromFirstPayment")
# factor_fields<-replace(factor_fields,factor_fields=='60D FromFirstPayment', "X60D.FromFirstPayment")


# for each factor (that isn't boolean)
#replace code by value


request_fields<-unique(dict[dict$category=='request','column'])
# first turn code variables  into factors
for (f in factor_fields)  loandata[,f]<-as.factor(loandata[,f])

# remove factors for which either already named factor or description too long
factor_fields_rename<-factor_fields_orig[!factor_fields_orig  %in% c('CreditGroup', 'Country','ApplicationSignedWeekday', 'ApplicationSignedHour', 'ApplicationType', 'Employment_Duration_Current_Employer', 'BondoraCreditHistory', 'MonthlyPaymentDay', 'Rating_V0', 'Rating_V1')]

# now put description in
for (f in factor_fields_rename){
  f_clean=make.names(f)
  # needs to be list for levels change to work
  code<-as.list(dict[dict$column==f,'value'])
  meaning<-as.list(dict[dict$column==f,'value.meaning'])
  levels(loandata[[f_clean]])<-setNames(code,meaning)
}


# datatable does fast grouping etc
l1<-data.table(loandata)

# filter out loans that have bene issued and NOT been extended
selected_loans=(!is.na(loandata$LoanDate) )  & (loandata$CurrentLoanHasBeenExtended==0) & (loandata$MaturityDate_Last==loandata$MaturityDate_Original)
#selected_loans[is.na(selected_loans)]=FALSE

l1_orig<-l1[selected_loans_6m,]
#l1_orig<-l1[(!is.na(LoanDate) )  & (CurrentLoanHasBeenExtended==0) & (MaturityDate_Last==MaturityDate_Original),]


request_reals<-intersect(real_fields,request_fields)
request_factors<-intersect(factor_fields,request_fields)


request_ints<-intersect(int_fields,request_fields)
drop_ints<-c('BidsInvestmentPlan','BidsManual','NoOfBids', 'TotalNumDebts','TotalMaxDebtMonths', 'NumDebtsFinance', 'MaxDebtMonthsFinance', 'NumDebtsTelco',  'MaxDebtMonthsTelco','NumDebtsOther',  'MaxDebtMonthsOther', 'NoOfInvestments')
request_ints<-request_ints[!request_ints %in% drop_ints]
drop_factors<-c('ApplicationType', 'Country','language_code')
paste('dropping', drop_factors)
request_factors<-request_factors [!request_factors  %in% drop_factors]

paste(request_factors)
drop_reals<-c('AmountOfInvestments',  'AmountOfBids')
request_reals<-request_reals [!request_reals  %in% drop_reals]
l1_orig_ints_all<-summary_factors(l1_orig, 'AD',request_ints)
l1_orig_facs_all<-summary_factors(l1_orig, 'defaulted_before_6m',request_factors)
l1_orig_ints_all<-summary_factors(l1_orig, 'defaulted_before_6m',request_ints)
l1_orig_facs_all<-summary_factors(l1_orig, 'AD',request_factors)

report_name<-'univariate_factors.pdf'

p<-ggplot(data=l1_orig_facs_all, aes(x=value, y=rate*100,size=N, ymin=rate*100-100*std_err,ymax=rate*100+100*std_err) ) +  geom_point()+scale_size_area()+geom_hline(yintercept=rate_overall$rate*100) + coord_flip()
plots<-dlply(l1_orig_facs_all,"fact", `%+%`,e1=p)
ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
ggsave(report_name, ml, width=21,height=27)

p<-ggplot(data=l1_orig_ints_all, aes(x=value, y=rate*100,ymin=rate*100-100*std_err,ymax=rate*100+100*std_err) ) +  xlab(fact)+geom_pointrange()+geom_hline(yintercept=rate_overall$rate*100) + coord_flip()
plots<-dlply(l1_orig_ints_all,"fact", `%+%`,e1=p)
ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
ggsave('ints_univariate.pdf', ml, width=21,height=27)


l1_orig_reals_all<-summary_reals(l1_orig,' 'defaulted_before_6m',request_reals)

ggplot(data=l1_orig_reals_all,aes(x=AD,ymin=`Min.`,lower=`X1st.Qu.`, middle=`Median`, upper=`X3rd.Qu.`, ymax=`Max.`))+geom_boxplot(stat='identity') +facet_wrap(~real,scales='free')
ggsave('reals_univariate.pdf', ml, width=21,height=27)



require(glmnet)
predict_cols<-c('AppliedAmount','AppliedAmountToIncome','DebtToIncome','FreeCash','LiabilitiesToIncome','NewLoanMonthlyPayment', 'NewPaymentToIncome','SumOfBankCredits', 'SumOfOtherCredits')
#predict_cols<-request_reals
predict_cols<-c('NewPaymentToIncome','LiabilitiesToIncome','VerificationType','Gender','UseOfLoan','education_id','marital_status_id','employment_status_id','Employment_Duration_Current_Employer','occupation_area','home_ownership_type_id')



loandata$selected_loans_6m<-( !is.na(loandata$LoanDate) & (interval(loandata$LoanDate,loandata$ReportAsOfEOD)/edays(1)>180))
loandata$defaulted_before_6m<-NA
#loandata$defaulted_before_6m[loandata$selected_loans_6m]<-!is.na(loandata$DefaultedOnDay[loandata$selected_loans_6m])

loandata$defaulted_before_6m[loandata$selected_loans_6m]<-!is.na(loandata$DefaultedOnDay[loandata$selected_loans_6m]) & loandata$DefaultedOnDay[loandata$selected_loans_6m]<=180

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
l1_orig_reals_all[l1_orig_reals_all$real %in% rownames(coef(cv.fit,s='lambda.1se')),]

#library(grid)
#library(gridExtra)


