reals_formula<-formula(~AppliedAmount+AppliedAmountToIncome+DebtToIncome+FreeCash+LiabilitiesToIncome+NewLoanMonthlyPayment+NewPaymentToIncome+SumOfBankCredits+SumOfOtherCredits-1)
ints_formula<-update.formula(reals_formula, . ~ Age+LoanDuration+nr_of_dependants+CountOfBankCredits+CountOfPaydayLoans+CountOfOtherCredits+NoOfPreviousApplications+NoOfPreviousLoans-1   )

base_formula<-formula(~VerificationType+Gender+UseOfLoan+LoanDuration+education_id+ 
                        employment_status_id+Employment_Duration_Current_Employer+work_experience_10+occupation_area+
                        marital_status_id+nr_of_dependants_1+home_ownership_type_id+  
                        CountOfBankCredits+CountOfOtherCredits-1)
base_formula_no_credits<-formula(~VerificationType+Gender+UseOfLoan+LoanDuration+education_id+ 
                                   employment_status_id+Employment_Duration_Current_Employer+work_experience_10+occupation_area+
                                   marital_status_id+nr_of_dependants_1+home_ownership_type_id  -1)


equi_formula<- formula(~
                         equi_age_fac + 
                         equi_marital_fac +
                         equi_education_fac +
                         equi_employment_status_fac + 
                         equi_employment_length_fac +
                         equi_net_income_fac +
                         equi_principal_duration_fac +
                         equi_loan_purpose_fac -1)
bondora_formula<- formula(defaulted_before_6m~Rating_V0+Rating_V1-1 )

verification_formula<-formula(defaulted_before_6m~VerificationType -1)

models<-c( equi=equi_formula, bond=bondora_formula, veri=verification_formula)




# determine where to label selection flags (& whether to include all other filters) ..
# better to label everything if write to main df (or likely to have old data in other rows via bugs)

# select data
# filter out loans that have been issued and NOT been extended
# loan_ (singular) is for boolean vector, loans_ is dataframe
loan_issued<-!is.na(loandata$LoanDate)

# NA if loan not issued, otherwise could have been cancelled, defaulted or still live
loandata$surv_time<-pmin(interval(loandata$LoanDate,loandata$ReportAsOfEOD)/edays(1), 
                interval(loandata$LoanDate,loandata$ContractEndDate)/edays(1),
                loandata$DefaultedOnDay,na.rm=TRUE)


loans_issued<-loandata[loan_issued, ]

loandata$loan_unchanged<-loan_issued & 
  (loandata$CurrentLoanHasBeenExtended==0) & 
  (loandata$MaturityDate_Last==loandata$MaturityDate_Original)
loandata$loan_cancelled<-loan_issued & 
  !is.na(loandata$ContractEndDate) & 
  (loandata$ContractEndDate==loandata$FirstPaymentDate) 

#loan_verified<-loan_issued &  loandata$VerificationType=='Income and expenses verified'
  
loan_elapsed_6m<-( loan_issued & (interval(loandata$LoanDate,loandata$ReportAsOfEOD)/edays(1)>180))
loan_elapsed_6m_mod<-( !is.na(loandata$FirstPaymentDate) & 
                         (interval(loandata$FirstPaymentDate,loandata$ReportAsOfEOD)/edays(1)>150))

loandata$defaulted_before_6m<-!is.na(loandata$DefaultedOnDay) & 
  loandata$DefaultedOnDay<=180
loandata$defaulted_before_6m_or_restructured<-loandata$defaulted_before_6m | 
  !loandata$loan_unchanged
loandata$defaulted_before_6m_mod<-!is.na(loandata$Default_StartDate) & 
  (interval(loandata$FirstPaymentDate,loandata$Default_StartDate)/edays(1)<=150)

loan_selections <- list(elapsed_6m=list(select=loan_elapsed_6m ,target="defaulted_before_6m"),
     elapsed_6m_unchanged=list(select=loan_elapsed_6m & loan_unchanged,target="defaulted_before_6m"),
     elapsed_6m_restructured=list(select=loan_elapsed_6m ,target="defaulted_before_6m_or_restructured"),
     elapsed_6m_mod=list(select=loan_elapsed_6m_mod, target="defaulted_before_6m_mod"),
     elapsed_6m_mod_unchanged=list(select=loan_elapsed_6m_mod & loan_unchanged, target="defaulted_before_6m_mod")
     )
z<-data.frame()
j<-0
for (data in loan_selections){
  
  j<-j+1
  loan_selected<-data$select
  target_variable<-data$target
  loans_selected<-loandata[loan_selected,]


  loans_selected_dt<-data.table(loans_selected)
  
  
  #x1<-model.matrix(AD~(NewPaymentToIncome+LiabilitiesToIncome)*(VerificationType + Gender+ UseOfLoan+education_id+marital_status_id+employment_status_id+Employment_Duration_Current_Employer+occupation_area+home_ownership_type_id)-1,data=loandata[selected_loans,])
  #y<-loandata[selected_loans,'AD']==1
  
  
  
  set.seed(1234)
  
  nfolds<-10
  cross_val<-sample(nfolds,nrow(loans_selected),replace=TRUE)
  
  #z<-cv_test(loans_selected, model_formula,target_variable, cross_val)
  z1<-lapply(models,function(x) cv_test(loans_selected, x,target_variable, cross_val))
  z2<-do.call(rbind,z1)
  z2$data=j
  z<-rbind(z,z2)  
}



z3<-ddply(z,~model+data,summarise,
          logloss_tr_mean=mean(ll_train),
          logloss_tr_se=sd(ll_train)/sqrt(length(ll_train)), 
          logloss_te_mean=mean(ll_test),
          logloss_te_se=sd(ll_test)/sqrt(length(ll_test)),
          gini_tr_mean=mean(gini_train),
          gini_tr_se=sd(gini_train)/sqrt(length(gini_train)), 
          gini_te_mean=mean(gini_test),
          gini_te_se=sd(gini_test)/sqrt(length(gini_test)),
          N=length(gini_test))


surv<-Surv(loans_issued$surv_time[loans_issued$surv_time>0 & !is.na(loans_issued$employment_status_id)],
           event=loans_issued$AD[loans_issued$surv_time>0 & !is.na(loans_issued$employment_status_id)])

z<-survfit(surv)
plot(z)
x<-model.matrix(base_formula,data=loans_issued[loans_issued$surv_time>0,])
cv.fit<-cv.glmnet(x,surv,family="cox")
plot(cv.fit)
coef(cv.fit,'lambda.min')
co<-coef(cv.fit,'lambda.min')
ind<-which(co!=0)
cos<-data.frame(row.names=rownames(co)[ind],value=co[ind])
qplot(x=rownames(cos),y=value,xlab="coeff",data=cos)+coord_flip()

#tr_te=rbinom(sum(loan_selected),1,1-test_frac)

#loans_selected$train_test<-tr_te

plot(cv.fit)

ggplot(as.data.frame(predict_tr),aes(x=`1`))+geom_bar()




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


loans_attribute$score_bd=logit(-0.547780803 +
                                 -0.099912729 +
                                 -0.002036076*loans_attribute$duration_months+
                                 0.118092729*(loans_attribute$user_income_employment_length_years<1))

