cancel_reasons_str<-read_string('cancel_reasons.sql')
cancel_reasons<-dbGetQuery(con_drv[[1]],cancel_reasons_str)

cols<-c(
    "documents_activity_flag",
    "lendico_class_new",
    "event_month",
    "was_loan_offer_accepted_flag",
    "amount_bucket",
    "user_campaign",
    "rating",
    "income_employment_status",
    "category",
    "credit_agency_rating",
    "lendico_class",
    "rating_new",
    "user_age",
    "employment_length_years")

sensdata<-cancel_reasons[cancel_reasons$country=='Germany' & cancel_reasons$was_loan_offer_flag==1,cols]
sensdata$user_age_bucket=cut(sensdata$user_age, c(18,31,46,76),right=FALSE)
sensdata$employment_length_years_bucket<- cut(sensdata$employment_length_years, c(1,3,7,15))
sensdata_dt=data.table(sensdata)
facs<-c(
    "event_month",
    "amount_bucket",
    "user_campaign",
    "rating",
    "income_employment_status",
    "credit_agency_rating",
    "lendico_class",
    "rating_new",
    "user_age_bucket",
    "employment_length_years_bucket"
)

target_var<-"documents_activity_flag"
rate_overall<-calc_rate_overall(sensdata_dt, target_var)
sens_factors_df<-summary_factors(sensdata_dt, target_var,facs)

filename='sensitivity'

gen_fac_graph( filename, doc_rate, sens_factors_df, target_var)
    




