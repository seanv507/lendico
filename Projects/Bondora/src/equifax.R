equi_age<-function(x){ 
  18*is.na(x) +
    
    (!is.na(x) & x<=23)*0+(!is.na(x) & x>23 & x<=28)*7+
    (!is.na(x) & x>28 & x<=40)*15+
    (!is.na(x) & x>40 & x<=51)*25+(!is.na(x) & x>51)*32

}

equi_city<-function(x){
  13*is.na(x)+
  0*(!is.na(x) & x=='ES')+
  11*(!is.na(x) & x!='ES')

}

levels(loandata$marital_status_id)
equi_marital<-c(Blank=12,Married=22, Cohabitant=22,Divorced=0,Single=7,Widow=7)
levels(loandata$education_id)

equi_education<-c(Blank=10,
                  `Primary education`=0,`Basic education`=0, 
                  `Vocational education`=7,
                  `Secondary education`=7,
                  `Higher education`=13)

equi_time_at_bank<-function(x){
  6*is.na(x)+
    
    (!is.na(x) & x<=12)*0 +
    (!is.na(x) & 12<x & x<=48)*4 +
    (!is.na(x) & 48<x & x<=120)*11 +
    (!is.na(x) & 120<x )*18 

}
  
# equi_payment_card_type
equi_payment_card_type<-c(Blank=8,
                  `Debit Cards`=11,`Credit Card Offset Monthly`=5, 
                  `Revolving`=0)

equi_employment_status<-function(bondora){
  
  (bondora$occupation_area %in% c("blank"))*16 +
  (bondora$occupation_area %in% c("Civil service & military"))*30+
  ((!bondora$occupation_area %in% c("blank", "Civil service & military")) &
    bondora$employment_status_id %in% c("Fully employed"))*22+
  ((!bondora$occupation_area %in% c("blank", "Civil service & military")) &
    (bondora$employment_status_id %in% c("Partially employed","Self-employed")))*10

  
}


equi_employment_length<-function(bondora){
  
  (bondora$employment_status_id %in% c("blank"))*14 +
    (bondora$employment_status_id %in% c("Retiree"))*35+
    ((!bondora$employment_status_id %in% c("blank","Retiree")) & 
      (bondora$Employment_Duration_Current_Employer  %in% c("MoreThan5Years")))*28 +
    ((!bondora$employment_status_id %in% c("blank","Retiree")) & 
       (bondora$Employment_Duration_Current_Employer  %in% c("UpTo4Years","UpTo5Years")))*21 +
    ((!bondora$employment_status_id %in% c("blank","Retiree")) & 
       (bondora$Employment_Duration_Current_Employer  %in% c("UpTo2Years","UpTo3Years")))*9 
    
  
}

equi_net_income<-function(x){
  # na -> 6
  (x<=900)*0+  (900<x & x<=1500)*7 + (1500<x & x<=2000)*13 + (2000<x )*24 
}

equi_principal_duration<-function(bondora){
  47*(bondora$LoanDuration<=12 & bondora$FundedAmount<=6000) +
  32*(bondora$LoanDuration<=12 & bondora$FundedAmount>6000) +
  0*(bondora$LoanDuration>12 & bondora$LoanDuration<=24 & bondora$FundedAmount<=3000) +
  47*(bondora$LoanDuration>12 & bondora$LoanDuration<=24 & bondora$FundedAmount>3000 & bondora$FundedAmount<=6000) +
  32*(bondora$LoanDuration>12 & bondora$LoanDuration<=24 & bondora$FundedAmount>6000) +
  0*(bondora$LoanDuration>24 & bondora$LoanDuration<=59 & bondora$FundedAmount<=3000) +
  32*(bondora$LoanDuration>24 & bondora$LoanDuration<=59 & bondora$FundedAmount>3000) +
  17*(bondora$LoanDuration>=60 & bondora$FundedAmount>9000) +
  17*(bondora$LoanDuration>=60 & bondora$FundedAmount<9000)
    
}

#UseOfLoan
equi_loan_purpose<-function(x){
    # 2 NA
  0* (!is.na(x) & x %in% c('Vehicle','Loan consolidation')) +
  20*(!is.na(x) & x %in% c('Home improvement'))+
  7* (is.na(x) | !x %in% c('Vehicle','Loan consolidation','Home improvement'))  
  
  
}

equi_pd<-read.xlsx('..\\data\\Calculo PD Modelo Experto Lendico V2_AR.xlsx',
                sheetName='PD', rowIndex=seq(12,345),colIndex=seq(2,11),stringsAsFactors=FALSE)

equi_make_fac<-function(ld){
  equi_labels<-grepl('equi_',colnames(ld))
  for (e in colnames(ld)[equi_labels]){
    ld[paste0(e,"_fac")]<-as.factor(ld[[e]])
  }
  ld
  
}



equi_loandata<-function(ld){
  ld$equi_age<-equi_age(ld$Age)
  ld$equi_city<-equi_city(NA)
  
  ld$equi_marital<-equi_marital[as.character(ld$marital_status_id)]
  ld$equi_education<-equi_education[as.character(ld$education_id)]
  ld$equi_time_at_bank<-equi_time_at_bank(NA)
  ld$equi_payment_card_type<-equi_payment_card_type["Blank"]
  ld$equi_employment_status<-equi_employment_status(ld)
  ld$equi_employment_length<-equi_employment_length(ld)
  ld$equi_net_income<-equi_net_income(ld$income_total)
  ld$equi_principal_duration<-equi_principal_duration(ld)
  ld$equi_second_holder<-0 #no second holder
  ld$equi_loan_purpose<-equi_loan_purpose(ld$UseOfLoan)
  ld$equi_risk_score<-25
  # take variables and turn them into factors for model
  
  ld$eqi_score<-rowSums(ld[grepl('equi_',colnames(ld))])
  # should rename so distinguish
  ld<-equi_make_fac(ld)
  
  z1<-merge(ld[c('eqi_score')],equi_pd[c("Score","Estimated.Bad.Rate")],all.x=TRUE,by.x='eqi_score',by.y='Score')
  ld$eqi_pd<-z1$Estimated.Bad.Rate
  ld$eqi_pd_6m<- 1-(1-ld$eqi_pd)^.5
  ld
}

loandata<-equi_loandata(loandata)

table(loandata$Age,loandata$equi_age)
table(loandata$equi_city)
table(loandata$marital_status_id,loandata$equi_marital)
table(loandata$education_id,loandata$equi_education)
table(loandata$equi_time_at_bank)
table(loandata$equi_payment_card_type)
table(loandata$employment_status_id,loandata$occupation_area=='Civil service & military',loandata$equi_employment_status)
table(loandata$employment_status_id=="Retiree",loandata$Employment_Duration_Current_Employer,loandata$equi_employment_length)
table(floor(loandata$income_total/100)*100,loandata$equi_net_income)
table(floor(loandata$FundedAmount/1000)*1000,loandata$LoanDuration,loandata$equi_principal_duration)
table(loandata$equi_second_holder)
table(loandata$UseOfLoan, loandata$equi_loan_purpose)
