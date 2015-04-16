				
business_after_tax<-function(from_business){
from_business[is.na(from_business)]<-0
from_business *
	ifelse(from_business<208400,.75,
		ifelse(from_business<416700,.65,
			ifelse(from_business<625100,.60,.55)))
}

replaceNA<-function (x,repl=0){
	x[is.na(x)]<-repl
	x
}	

inc_cols<-c(
  "user_income_alimony", "user_income_business","user_income_child_benefit","user_income_net_income","user_income_net_income_from_business",
  "user_income_net_income_if_any","user_income_net_income_other","user_income_net_income_pension","user_income_pension","user_income_rent")

strip_ui<-function(x){substring(x,13,999)}

inc_cols1<-lapply(inc_cols,strip_ui)
plotting<-function(){
  attach(loans_attribute_late2)
  xlims=c(ymd('20140101'),ymd('20150430'))
  ylims=c(0,30000)
  par(mfrow=c(2,2))
  ylims=c(0,3000)
  plot(loan_request_creation_date,user_income_alimony/100,col=1,ylab="income (EUR)",ylim=ylims,xlim=xlims) 
  points(loan_request_creation_date,user_income_child_benefit/100,col=2)
  legend(x=ymd("20140101"),y=3000,legend=c("alimony","child_benefit"),fill=seq(2))
  ylims=c(0,5000)
  plot(loan_request_creation_date,user_income_business/100,col=1,ylab="income (EUR)",ylim=ylims,xlim=xlims)
  points(loan_request_creation_date,user_income_net_income_from_business/100,col=2)
  legend(x=ymd("20140101"),y=4000,legend=c("net_income_from_business"),fill=seq(2))
  
  ylims=c(0,20000)
  plot(loan_request_creation_date,user_income_net_income/100,col=1,ylab="income (EUR)",ylim=ylims,xlim=xlims)
  points(loan_request_creation_date,user_income_net_income_other/100,col=4)
  points(loan_request_creation_date,user_income_net_income_if_any/100,col=3)
  points(loan_request_creation_date,user_income_net_income2/100,col=2)
  legend(x=ymd("20140101"),y=20000,legend=c("net_income","user_income_net_income2","net_income_if_any","net_income_other"),fill=seq(4),cex=0.5)
  
  ylims=c(0,20000)
  plot(loan_request_creation_date,user_income_net_income_pension/100,col=1,ylab="income (EUR)",ylim=ylims,xlim=xlims)
  points(loan_request_creation_date,user_income_pension/100,col=2)
  points(loan_request_creation_date,user_income_rent/100,col=3)
  legend(x=ymd("20140101"),y=20000,legend=c("net_income_pension","user_income_pension","rent"),fill=seq(3))
  
  detach(loans_attribute_late2)
}

total_net_income<-function(dat){
# before '2014-08-06'

  z1<-dat$loan_request_creation_date<=ymd('2014-08-06')

  inc_cols<-c("user_income_net_income_if_any","user_income_net_income","user_income_net_income_other",
              "user_income_net_income_from_business",
	  "user_income_child_benefit","user_income_alimony", "user_income_pension","user_income_rent")

	# fix NAS	
  dat[,inc_cols]<-lapply(dat[,inc_cols],replaceNA)

  tni<-rep(NA,nrow(dat))
  z_any<-dat$income_employment_status %in% c('house_wife_husband', 'student', 'without_employment', 'retired')
  tni[z1 & z_any]<-dat$user_income_net_income_if_any[z1 & z_any]

  z_norm<-dat$income_employment_status %in% c('manual_worker', 'public_official', 'salaried', 'soldier') 
  tni[z1 & z_norm]<-rowSums(dat[z1 & z_norm,c("user_income_net_income","user_income_net_income_other")]) 

  z_self<-dat$income_employment_status %in% c('self_employed', 'freelancer')
  tni[z1 & z_self]<-business_after_tax(dat[z1 & z_self,"user_income_net_income_from_business"]) + 	
  	dat[z1 & z_self,"user_income_net_income_other"]
	
  tni[!z1]<-rowSums(dat[!z1,c("user_income_net_income","user_income_child_benefit","user_income_alimony", "user_income_pension",
    "user_income_net_income_other")])+dat[!z1,"user_income_rent"]*0.7 + business_after_tax(dat[!z1,"user_income_net_income_from_business"])
	# DON'T KNOW what fields are really being used
	
  tni<-tni/100.0

}


total_net_income_it<-function(dat){
  # sebastian function does not use "user_income_net_income_pension", or user_income_business
  
  # removing health insurance too
  inc_cols<-c(
    "user_income_alimony", "user_income_business","user_income_child_benefit","user_income_net_income",
    "user_income_net_income_from_business",
    "user_income_net_income_if_any","user_income_net_income_other",
    #"user_income_net_income_pension",
    "user_income_pension","user_income_rent",
    "user_expenses_health_insurance")
  
  inc_cols_100<-c(
    "user_income_alimony","user_income_child_benefit","user_income_net_income",
    "user_income_net_income_if_any","user_income_net_income_other",
    #"user_income_net_income_pension"
    "user_income_pension")
  #bus_cols<-c("user_income_business","user_income_net_income_from_business")
  bus_cols<-c("user_income_net_income_from_business")
  dat[,inc_cols]<-lapply(dat[,inc_cols],replaceNA)
  dat["user_income_child_benefit"]<-dat["user_income_child_benefit"]*100 # to make consistent with other columns
  
  tni<-rowSums(dat[inc_cols_100]) + 
      .7*dat$user_income_rent + 
      business_after_tax(rowSums(dat[bus_cols])) -
      dat$user_expenses_health_insurance
  tni<-tni/100.0
}


loan_costs<-function(dat){
  loan_cols<-c("category", "user_expenses_current_loans", "interval_payment")
  dat<-dat[loan_cols]
  dat[]<-lapply(dat[],replaceNA)
  ifelse(dat$category=="debt_consolidation",
         pmin(dat$user_expenses_current_loans,dat$interval_payment),
         dat$user_expenses_current_loans)
}


total_costs<-function(dat){
  #"user_expenses_dependants"
  costs_cols<-c("total_net_income", "category", "interval_payment",
                "user_expenses_children","marital_status","user_expenses_home",
                "user_expenses_alimony","user_expenses_current_loans", "user_expenses_leasing",
                "user_expenses_monthly_mortgage","user_expenses_monthly_rent")
  
  dat<-dat[costs_cols]
  dat[]<-lapply(dat[],replaceNA)
  costs_other<-rowSums(dat[c("user_expenses_alimony", "user_expenses_leasing")])/100
  flat_cost<-403 + 
              391*(dat$marital_status %in% c("married", "domestic_partnership")) + 
              212*dat$user_expenses_children 
  #pc_inc<-pmin(.3*dat$total_net_income,1500)
  #costs_living<-pmax(flat_cost,pc_inc)
  costs_living<-ifelse(dat$total_net_income>5000,1500,pmax(flat_cost,.30*dat$total_net_income))
  costs_accom<-ifelse(dat$user_expenses_home=="own", pmax(212,0.10*dat$total_net_income)+dat$user_expenses_monthly_mortgage/100,
                     ifelse(dat$user_expenses_home=="rent",pmax(265,0.20*dat$total_net_income,dat$user_expenses_monthly_rent/100),
                            pmax(53,0.05*dat$total_net_income,dat$user_expenses_monthly_rent/100)) # else living_with_parents
                     )
  expenses_without_loans<-costs_other+costs_living+costs_accom
  expenses<-expenses_without_loans + loan_costs(dat)
  pre_capacity<-dat$total_net_income - expenses_without_loans
  post_capacity<-dat$total_net_income - expenses - ifelse(dat$category=="debt_consolidation",0,dat$interval_payment)
  list("expenses_without_loans"=expenses_without_loans,
    "expenses"=expenses,
    "pre_capacity"=pre_capacity,
    "post_capacity"=post_capacity,
    "costs_other"=costs_other,
    "flat_cost"=flat_cost,
    "costs_living"=costs_living,
    "costs_accom"=costs_accom
    )
  
}



loans_attribute_late3$total_net_income_nib_p<-total_net_income_it(loans_attribute_late3)


loans_attribute_late3[c(1416,1451),grep("user_income",names(loans_attribute_late3))]

