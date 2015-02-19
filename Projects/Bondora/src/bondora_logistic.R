require(xlsx)
require(plyr)
require(ggplot2)
require(data.table)

dict<-read.xlsx('C:\\Users\\Sean Violante\\Documents\\Projects\\lendico\\Projects\\Bondora\\data\\BondoraAll.xlsm',
                sheetName='BondoraLoanDictionaryClean', stringsAsFactors=FALSE)


loandata<-read.csv('C:\\Users\\Sean Violante\\Documents\\Projects\\lendico\\Projects\\Bondora\\data\\LoanData_20150204_es.csv', fileEncoding="UTF-8")

loandata$LoanDate<-as.Date(loandata$LoanDate,format='%Y-%m-%d')

loandata$MaturityDate_Last<-as.Date(loandata$MaturityDate_Last,format='%Y-%m-%d')
loandata$MaturityDate_Original<-as.Date(loandata$MaturityDate_Original,format='%Y-%m-%d')

z1<-as.character(loandata$occupation_area)
z1[is.na(z1)]='blank'
loandata$occupation_area=as.factor(z1)


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



l1<-data.table(loandata)

selected_loans=(!is.na(loandata$LoanDate) )  & (loandata$CurrentLoanHasBeenExtended==0) & (loandata$MaturityDate_Last==loandata$MaturityDate_Original)
#selected_loans[is.na(selected_loans)]=FALSE

l1_orig<-l1[selected_loans,]
l1_orig<-l1[(!is.na(LoanDate) )  & (CurrentLoanHasBeenExtended==0) & (MaturityDate_Last==MaturityDate_Original),]


request_reals<-intersect(real_fields,request_fields)
request_factors<-intersect(factor_fields,request_fields)

drop_factors<-c('ApplicationType', 'Country','language_code')
paste('dropping', drop_factors)
request_factors<-request_factors [!request_factors  %in% drop_factors]

drop_reals<-c('AmountOfInvestments',  'AmountOfBids')
request_reals<-request_reals [!request_reals  %in% drop_reals]

l1_orig_facs<-lapply(request_factors,function (f) l1_orig[,.(fact=f, N=.N, rate=sum(AD==1)/.N, std_err=sum(AD==1)*(.N-sum(AD==1))/.N^3),keyby=f])

for (i in 1:length(request_factors))   setnames(l1_orig_facs[[i]], request_factors[i], 'value')
l1_orig_facs_all<-do.call(rbind,l1_orig_facs)
ggplot() +  geom_point(data=l1_orig_facs_all,aes(x=value, y=rate*100,size=N))+  ylim(0,50)+facet_wrap(~fact, scales='free')+scale_size_area()+geom_hline(yintercept=rate_overall$rate*100)

  

l1_orig_reals<-lapply(request_reals,function (f) l1_orig[,c(N=.N, as.list(summary(f))),keyby=AD])

#l1_orig_reals_scaling<-lapply(request_reals,function (f) l1_orig[,c(real=f,N=.N,sd=sd(get(f)), as.list(summary(get(f))))])

#l1_orig_reals_scaling_all<-do.call(rbind,l1_orig_reals_scaling)

l1_orig_reals_all<-data.frame(do.call(rbind,l1_orig_reals))
ggplot(data=l1_orig_reals_all,aes(x=AD,ymin=`Min.`,lower=`X1st.Qu.`, middle=`Median`, upper=`X3rd.Qu.`, ymax=`Max.`))+geom_boxplot(stat='identity') +facet_wrap(~real,scales='free')

l1_orig_reals_all_scaled<-data.frame(l1_orig_reals_all)

rescale_cols<-c('Min.', 'X1st.Qu.' ,'Median',  'X3rd.Qu.',  'Max.')
for (r in request_reals)   l1_orig_reals_all_scaled[l1_orig_reals_all_scaled$real==r,rescale_cols]<-  (l1_orig_reals_all_scaled[l1_orig_reals_all_scaled$real==r,rescale_cols] - l1_orig_reals_scaling_all$Mean[l1_orig_reals_scaling_all$real==r])/(l1_orig_reals_scaling_all$sd[l1_orig_reals_scaling_all$real==r])
# rescale to 0- 1 for plot

for (r in request_reals)   l1_orig_reals_all_scaled[l1_orig_reals_all_scaled$real==r,rescale_cols]<-  (l1_orig_reals_all_scaled[l1_orig_reals_all_scaled$real==r,rescale_cols] - l1_orig_reals_scaling_all$Mean[l1_orig_reals_scaling_all$real==r])/(l1_orig_reals_scaling_all$sd[l1_orig_reals_scaling_all$real==r])

ggplot(data=l1_orig_reals_all,aes(x=AD,ymin=`Min.`,lower=`X1st.Qu.`, middle=`Median`, upper=`X3rd.Qu.`, ymax=`Max.`))+geom_boxplot(stat='identity') +facet_wrap(~real,scales='free')


require(glmnet)
predict_cols<-c('AppliedAmount','AppliedAmountToIncome','DebtToIncome','FreeCash','LiabilitiesToIncome','NewLoanMonthlyPayment', 'NewPaymentToIncome','SumOfBankCredits', 'SumOfOtherCredits')
#predict_cols<-request_reals
predict_cols<-c('NewPaymentToIncome','LiabilitiesToIncome','VerificationType','Gender','UseOfLoan','education_id','marital_status_id','employment_status_id','Employment_Duration_Current_Employer','occupation_area','home_ownership_type_id')



x1<-model.matrix(AD~(NewPaymentToIncome+LiabilitiesToIncome)*(VerificationType + Gender+ UseOfLoan+education_id+marital_status_id+employment_status_id+Employment_Duration_Current_Employer+occupation_area+home_ownership_type_id)-1,data=loandata[selected_loans,])

y<-loandata[selected_loans,'AD']==1
x<-loandata[selected_loans,predict_cols]
x1<-as.matrix(x)
y1<-as.matrix(y)

fit<-glmnet(x1,y1,family='binomial')
summary(loandata[(request_fields)])


#library(grid)
#library(gridExtra)


