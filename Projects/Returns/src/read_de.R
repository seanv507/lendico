require('RPostgreSQL')

require("reshape2")
require("lubridate")

read_string<-function(filename){
  paste(readLines(filename), collapse="\n")
}

get_accounts<-function(con_drv,borrowers_str){
  sql_borrowers=paste0("select * from  base.user_account  where dwh_country_id =1 and id_user in (",borrowers_str,
                       ")",collapse=' ')
  dbGetQuery(con_drv[[1]],sql_borrowers)
}

# dwh_country_id" 
# "country_name"
# "currency_code"
# "user_age"
# "title"                   
# "state"
# "created_at"
# "updated_at"
# "dwh_created"
# "dwh_last_modified"
# "user_campaign"
# "net_income_precheck"
# "net_income"
# "expenses_precheck"
# "expenses"
# "expenses_current_loans"
# "pre_capacity"
# "first_name"
# "gender"
# "last_name"
# "loan_request_description"
# "loan_request_title"
# "marital_status"
# "newsletter_subscription"
# "postal_code"
# "street"
# "street_number"
# "voucher_code"

get_attributes<-function(con_drv,borrowers_str){
  sql_user_attribute1=paste0(
  "select 
       dwh_country_id,max(id_attribute) id_attribute 
   from  backend.user_attribute 
  
   where dwh_country_id=1 and fk_user in (",borrowers_str,
                            ")  group by dwh_country_id, fk_user,key",collapse=' ')
  sql_user_attribute=paste0("select ua.dwh_country_id, ua.fk_user,ua.key,ua.value from backend.user_attribute ua join (",sql_user_attribute1,") unis 
                            on ua.id_attribute=unis.id_attribute and ua.dwh_country_id=unis.dwh_country_id",collapse=' ')
  borrower_attribute_narrow<-dbGetQuery(con_drv[[1]],sql_user_attribute)
  
}


clean_attributes<-function(baa){
    # converts to numbers/factors, 
    # replaces ','->'.' (ie decimal point)
    # divides all amounts except child benefits
    
    # turn into wide format
    ba<-dcast(baa, dwh_country_id+fk_user~key,value.var='value')
    
    # drop tile (always null and conflicts with loan title)
    ba$title <- NULL
    # remove new lines to paste into excel
  
    ba$loan_request_description<-gsub("\r\n","  ",ba$loan_request_description)
    ba$user_income_description<-gsub("\r\n","  ",ba$user_income_description)
    ba$user_income_employment_length_date<-
    floor_date(parse_date_time(ba$user_income_employment_length,
                               c("%m%y","Y%m%d","%d%m%Y")),"month")
    #which(is.na(borrower_attribute$user_income_employment_length_date) & !is.na(borrower_attribute$user_income_employment_length))
    ba$user_income_employment_length_date[ba$user_income_employment_length=="01.12.21985"]=ymd("19851201")
    ba$user_income_employment_length_date[ba$user_income_employment_length=="2012-01-01.2012"]=ymd("20120101")  
    
    
    # euros marks not cents as opposed to normal meaning of exchange rate
    
    num_cols<-c(
    "user_income_alimony", "user_income_business","user_income_child_benefit","user_income_net_income",
    "user_income_net_income2",
    "user_income_net_income_from_business",
    "user_income_net_income_if_any","user_income_net_income_other",
    "user_income_net_income_pension",
    "user_income_pension","user_income_rent",
    "user_expenses_health_insurance",
     "user_expenses_children","user_expenses_home",
     "user_expenses_alimony","user_expenses_current_loans", "user_expenses_leasing",
     "user_expenses_monthly_mortgage","user_expenses_monthly_rent")
    
    # WARNING needed because MY R fails to parse ...
    replace_comma<-function(x){gsub(",","",x)} #assumes if , then both digits (ie not 0,9 but 0,99)
    
    ba[,num_cols]<-lapply(ba[,num_cols],replace_comma)
    ba[,num_cols]<-lapply(ba[,num_cols],as.numeric)
    cents_cols<-num_cols[!(num_cols %in% c("user_income_child_benefit","user_expenses_children" ))]
    ba[cents_cols]<-ba[cents_cols]/100
    
    # child benefit already in euros not cents
    
    facs<-c("gender", "marital_status","user_expenses_home","user_income_employment_status","user_income_employment_type")
    ba[,facs]<-lapply(ba[,facs],as.factor)
    ba
}



get_first_lates<-function(con_drv){
  sql_first_lates<-"
      select latest.fk_loan
  ,earliest_date,latest_date
  ,in_arrears_since_days_7_plus_first
  ,in_arrears_since_days_14_plus_first 
  ,in_arrears_since_days_30_plus_first 
  ,in_arrears_since_days_60_plus_first
  ,in_arrears_since_days_90_plus_first 
  ,coalesce(in_arrears_since_days_7_plus_first,latest_date)-earliest_date as surv_time_7
  ,coalesce(in_arrears_since_days_14_plus_first,latest_date)-earliest_date as surv_time_14
  ,coalesce(in_arrears_since_days_30_plus_first,latest_date)-earliest_date as surv_time_30
  ,coalesce(in_arrears_since_days_60_plus_first,latest_date)-earliest_date as surv_time_60
  ,coalesce(in_arrears_since_days_90_plus_first,latest_date)-earliest_date as surv_time_90
  ,in_arrears_since_days_7_plus_first is not null as late_7
  ,in_arrears_since_days_14_plus_first is not null as late_14
  ,in_arrears_since_days_30_plus_first is not null as late_30
  ,in_arrears_since_days_60_plus_first is not null as late_60
  ,in_arrears_since_days_90_plus_first is not null as late_90
  FROM 
  (select  fk_loan, min(iso_date) earliest_date, max(iso_date) latest_date from base.de_payments  group by fk_loan) latest
  left join (select  fk_loan, min(iso_date) in_arrears_since_days_7_plus_first from base.de_payments where in_arrears_since_days>7 group by fk_loan ) f7  on (latest.fk_loan=f7.fk_loan)
  left join (select  fk_loan, min(iso_date) in_arrears_since_days_14_plus_first from base.de_payments where in_arrears_since_days>14 group by fk_loan ) f14 on (latest.fk_loan=f14.fk_loan)
  left join (select  fk_loan, min(iso_date) in_arrears_since_days_30_plus_first from base.de_payments where in_arrears_since_days>30 group by fk_loan ) f30 on (latest.fk_loan=f30.fk_loan)
  left join (select  fk_loan, min(iso_date) in_arrears_since_days_60_plus_first from base.de_payments where in_arrears_since_days>60 group by fk_loan ) f60 on (latest.fk_loan=f60.fk_loan)
  left join (select  fk_loan, min(iso_date) in_arrears_since_days_90_plus_first from base.de_payments where in_arrears_since_days>90 group by fk_loan ) f90 on (latest.fk_loan=f90.fk_loan)
  order by fk_loan"
  
  dbGetQuery(con_drv[[1]],sql_first_lates)
  
}


business_after_tax<-function(from_business){
  from_business[is.na(from_business)]<-0
  from_business *
    ifelse(from_business<2084,.75,
           ifelse(from_business<4167,.65,
                  ifelse(from_business<6251,.60,.55)))
}

replaceNA<-function (x,repl=0){
  x[is.na(x)]<-repl
  x
}	


# strip_ui<-function(x){substring(x,13,999)}
# inc_cols1<-lapply(inc_cols,strip_ui)


plotting<-function(){
  attach(loans_attribute_late2)
  xlims=c(ymd('20140101'),ymd('20150430'))
  ylims=c(0,30000)
  par(mfrow=c(2,2))
  ylims=c(0,3000)
  plot(loan_request_creation_date,user_income_alimony,col=1,ylab="income (EUR)",ylim=ylims,xlim=xlims) 
  points(loan_request_creation_date,user_income_child_benefit/100,col=2)
  legend(x=ymd("20140101"),y=3000,legend=c("alimony","child_benefit"),fill=seq(2))
  ylims=c(0,5000)
  plot(loan_request_creation_date,user_income_business,col=1,ylab="income (EUR)",ylim=ylims,xlim=xlims)
  points(loan_request_creation_date,user_income_net_income_from_business/100,col=2)
  legend(x=ymd("20140101"),y=4000,legend=c("net_income_from_business"),fill=seq(2))
  
  ylims=c(0,20000)
  plot(loan_request_creation_date,user_income_net_income,col=1,ylab="income (EUR)",ylim=ylims,xlim=xlims)
  points(loan_request_creation_date,user_income_net_income_other,col=4)
  points(loan_request_creation_date,user_income_net_income_if_any,col=3)
  points(loan_request_creation_date,user_income_net_income2,col=2)
  legend(x=ymd("20140101"),y=20000,legend=c("net_income","user_income_net_income2","net_income_if_any","net_income_other"),fill=seq(4),cex=0.5)
  
  ylims=c(0,20000)
  plot(loan_request_creation_date,user_income_net_income_pension,col=1,ylab="income (EUR)",ylim=ylims,xlim=xlims)
  points(loan_request_creation_date,user_income_pension,col=2)
  points(loan_request_creation_date,user_income_rent,col=3)
  legend(x=ymd("20140101"),y=20000,legend=c("net_income_pension","user_income_pension","rent"),fill=seq(3))
  
  detach(loans_attribute_late2)
}

# total_net_income<-function(dat){
#   NOT WORKING
#   # before '2014-08-06'
#   
#   z1<-dat$loan_request_creation_date<=ymd('2014-08-06')
#   
#   inc_cols<-c("user_income_net_income_if_any","user_income_net_income","user_income_net_income_other",
#               "user_income_net_income_from_business",
#               "user_income_child_benefit","user_income_alimony", "user_income_pension","user_income_rent")
#   
#   # fix NAS	
#   dat[,inc_cols]<-lapply(dat[,inc_cols],replaceNA)
#   
#   tni<-rep(NA,nrow(dat))
#   z_any<-dat$income_employment_status %in% c('house_wife_husband', 'student', 'without_employment', 'retired')
#   tni[z1 & z_any]<-dat$user_income_net_income_if_any[z1 & z_any]
#   
#   z_norm<-dat$income_employment_status %in% c('manual_worker', 'public_official', 'salaried', 'soldier') 
#   tni[z1 & z_norm]<-rowSums(dat[z1 & z_norm,c("user_income_net_income","user_income_net_income_other")]) 
#   
#   z_self<-dat$income_employment_status %in% c('self_employed', 'freelancer')
#   tni[z1 & z_self]<-business_after_tax(dat[z1 & z_self,"user_income_net_income_from_business"]) + 	
#     dat[z1 & z_self,"user_income_net_income_other"]
#   
#   tni[!z1]<-rowSums(dat[!z1,c("user_income_net_income","user_income_child_benefit","user_income_alimony", "user_income_pension",
#                               "user_income_net_income_other")])+dat[!z1,"user_income_rent"]*0.7 + business_after_tax(dat[!z1,"user_income_net_income_from_business"])
#   # DON'T KNOW what fields are really being used
#   
#   tni<-tni
#   
# }


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
  
  # columns we don't weight by x%
  inc_cols_100<-c(
    "user_income_alimony","user_income_child_benefit","user_income_net_income",
    "user_income_net_income_if_any","user_income_net_income_other",
    #"user_income_net_income_pension"
    "user_income_pension")
  #bus_cols<-c("user_income_business","user_income_net_income_from_business")
  bus_cols<-c("user_income_net_income_from_business")
  dat[,inc_cols]<-lapply(dat[,inc_cols],replaceNA)
  
  
  tni<-rowSums(dat[inc_cols_100]) + 
    .7*dat$user_income_rent + 
    business_after_tax(rowSums(dat[bus_cols])) -
    dat$user_expenses_health_insurance
  tni<-tni
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
  dat$category<-as.character(dat$category)
  dat$user_expenses_home<-as.character(dat$user_expenses_home)
  dat$marital_status<-as.character(dat$marital_status)
  costs_cols<-c("total_net_income", "category", "interval_payment",
                "user_expenses_children","marital_status","user_expenses_home",
                "user_expenses_alimony","user_expenses_current_loans", "user_expenses_leasing",
                "user_expenses_monthly_mortgage","user_expenses_monthly_rent")
  
  dat<-dat[costs_cols]
  dat[]<-lapply(dat[],replaceNA)
  costs_other<-rowSums(dat[c("user_expenses_alimony", "user_expenses_leasing")])
  flat_cost<-403 + 
    391*(dat$marital_status %in% c("married", "domestic_partnership")) + 
    212*dat$user_expenses_children 
  #pc_inc<-pmin(.3*dat$total_net_income,1500)
  #costs_living<-pmax(flat_cost,pc_inc)
  costs_living<-ifelse(dat$total_net_income>5000,1500,pmax(flat_cost,.30*dat$total_net_income))
  costs_accom<-ifelse(dat$user_expenses_home=="own", pmax(212,0.10*dat$total_net_income)+dat$user_expenses_monthly_mortgage,
                      ifelse(dat$user_expenses_home=="rent",pmax(265,0.20*dat$total_net_income,dat$user_expenses_monthly_rent),
                             pmax(53,0.05*dat$total_net_income,dat$user_expenses_monthly_rent)) # else living_with_parents
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




