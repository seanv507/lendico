dict<-read.xlsx('..\\data\\BondoraAll03.xlsm',
                sheetName='BondoraLoanDictionaryClean', stringsAsFactors=FALSE)

load_data<-function(dict){
  dates_names<-unique(dict$column[dict$type=='date'])
  loandata<-read.csv('..\\data\\LoanData_20150204_es.csv', 
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
  
  
  # glmnet needs NA removed
  z1<-as.character(loandata$occupation_area)
  z1[is.na(z1)]='blank'
  loandata$occupation_area=as.factor(z1)
  
  
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