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
require(survival)

# load & format
# select
# train test
# model list
# train ->test score
# plot results
# store models and results 
# store models with training data
# split out model from generic code...


logistic<-function(x) 1/(1 + exp (- x))
#inverse logistic
logit<-function (p) log(p) -log(1-p)


summary_reals<-function(dt, target,real_vars){
  list_sum<-lapply(real_vars,function (f) dt[,c(variable=f,N=.N, as.list(summary(get(f)))),keyby=get(target)])
  df_sum<-do.call(rbind,list_sum)
  setnames(df_sum,'get',target)
}

summary_factors<-function(dt, target,factor_vars, add_var=NULL){
  # calc N, mean, std err
    if (is.null(add_var)){
        list_sum<-lapply(factor_vars,
                         function (f) dt[,.(fact=f, 
                                            N=.N, 
                                            rate=sum(get(target)==1)/.N, 
                                            std_err=sqrt(sum(get(target)==1)*(.N-sum(get(target)==1))/.N^3)),
                                         keyby=f])
        
        
    }else{
        # couldn't get to work - eval problem? 
        # The items in the 'by' or 'keyby' list are length (1,1). Each must be same length as rows in x
        list_sum<-lapply(factor_vars,
                         function (f) dt[,.(fact=f, 
                                            N=.N, 
                                            rate=sum(get(target)==1)/.N, 
                                            std_err=sqrt(sum(get(target)==1)*(.N-sum(get(target)==1))/.N^3)),
                                         keyby=.(add_var,f)])
    }
  
    
    # create combined dataframe by adding column with variable name
    for (i in 1:length(factor_vars))   setnames(list_sum[[i]], factor_vars[i], 'value')
    df_sum<-do.call(rbind,list_sum)
    setcolorder(df_sum,c('fact','value', 'N', 'rate', 'std_err'))
}

summary_factors_p<-function(dt, target,factor_vars){
  # calc N, mean, std err
  
  list_sum<-lapply(factor_vars,function (f) dt[,.(fact=f, N=.N, rate=mean(get(target)), 
                                                  std_err=sqrt(mean(get(target))*(1-mean(get(target)))/.N)),keyby=f])
  
  # create combined dataframe by adding column with variable name
  for (i in 1:length(factor_vars))   setnames(list_sum[[i]], factor_vars[i], 'value')
  df_sum<-do.call(rbind,list_sum)
  df_sum<-df_sum[c('fact','value', 'N', 'rate', 'std_err')]
}

calc_rate_overall<-function (data_dt, target_variable){
    rate_overall<-data_dt[,c(N=.N,rate=mean(get(target_variable)))]
    # default rate 
    rate_overall["conf_min"]=qbeta(.0275, rate_overall[["N"]]*rate_overall[["rate"]]+0.5,
                                   rate_overall[["N"]]*(1-rate_overall[["rate"]])+0.5)
    rate_overall["conf_max"]=qbeta(.975,rate_overall[["N"]]*rate_overall[["rate"]]+0.5,
                                   rate_overall[["N"]]*(1-rate_overall[["rate"]])+0.5)
    rate_overall
}

gen_fac_graph<-function(filename, rate_overall, data_fac_all, target_variable){
    
    report_name<-paste0(filename,'_facs',target_variable,'.pdf')
    #"Chi-squared approximation may be incorrect"
    #chisq.test(as.data.frame(z)[c("AD","NAD")],p=z$N,rescale.p=TRUE,  simulate.p.value = TRUE, B = 10000)
    
    p<-ggplot(data=data_fac_all, 
              aes(color=value, x=value, y=rate*100,size=N, ymin=rate*100-100*std_err,ymax=rate*100+100*std_err) ,
              environment = environment()) +
        #environment :  https://github.com/hadley/ggplot2/issues/743
        #geom_ribbon(aes(ymin=rate_overall[['conf_min']]*100,
        #                ymax=rate_overall[['conf_max']]*100),color="black")+
        geom_point()+
        
        geom_hline(yintercept=rate_overall[['rate']]*100) + coord_flip()
    plots<-dlply(data_fac_all,"fact",  function(x) `%+%`(p,x)+xlab(x$fact[[1]])  )
    ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
    
    ggsave(report_name, ml, width=21,height=27)
}


gen_univariate<-function(loans_dt,request_factors, request_ints, request_reals,filename, target_variable){
  rate_overall<-loans_dt[,c(N=.N,rate=mean(get(target_variable)))]
  # default rate 
  rate_overall["conf_min"]=qbeta(.0275, rate_overall[["N"]]*rate_overall[["rate"]]+0.5,
                                 rate_overall[["N"]]*(1-rate_overall[["rate"]])+0.5)
  rate_overall["conf_max"]=qbeta(.975,rate_overall[["N"]]*rate_overall[["rate"]]+0.5,
                                 rate_overall[["N"]]*(1-rate_overall[["rate"]])+0.5)
  #"Chi-squared approximation may be incorrect"
  chisq.test(as.data.frame(z)[c("AD","NAD")],p=z$N,rescale.p=TRUE,  simulate.p.value = TRUE, B = 10000)
  
  loans_dt_ints_all<-summary_factors(loans_dt, target_variable,request_ints)
  loans_dt_facs_all<-summary_factors(loans_dt, target_variable,request_factors)
  loans_dt_reals_all<-summary_reals(loans_dt, target_variable,request_reals)
  loans_dt_ints_all$data="train"
  loans_dt_facs_all$data="train"
  loans_dt_reals_all$data="train"
  
  
  loans_dt_eqi_ints_all<-summary_factors_p(loans_dt, "eqi_pd_6m",request_ints)
  loans_dt_eqi_facs_all<-summary_factors_p(loans_dt, "eqi_pd_6m",request_factors)
  loans_dt_eqi_reals_all<-summary_reals(loans_dt,"eqi_pd_6m",request_reals)
  loans_dt_eqi_ints_all$data="equi"
  loans_dt_eqi_facs_all$data="equi"
  loans_dt_eqi_reals_all$data="equi"
  
  
  
  report_name<-paste0(filename,'_ints',target_variable,'.pdf')
  mg<-rbind(loans_dt_ints_all, loans_dt_eqi_ints_all)
  p<-ggplot(data=mg, aes(color=data, x=value, y=rate*100,size=N, ymin=rate*100-100*std_err,ymax=rate*100+100*std_err) ) +  
    geom_point()+scale_size_area()+geom_hline(yintercept=rate_overall[['rate']]*100) + coord_flip()
  # replace current dataframe `%+%`, and provide labels
  plots<-dlply(mg,"fact",  function(x) `%+%`(p,x)+xlab(x$fact[[1]])  )
  ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
  ggsave(report_name, ml, width=21,height=27)
  
  
  report_name<-paste0(filename,'_reals_',target_variable,'.pdf')
  
  # mg<-rbind(loans_dt_reals_all,loans_dt_te_reals_all)
  # loans_dt_eqi_reals_all
  # loans_dt_reals_all$default<-loans_dt_reals_all$defaulted_before_6m==TRUE
  # # need dataframe just because of invalid column names
  ml<-ggplot(data=data.frame(loans_dt_reals_all),
             aes_string(x=target_variable,ymin='Min.',lower='X1st.Qu.', middle='Median', upper='X3rd.Qu.', ymax='Max.')) + 
    geom_boxplot(stat='identity') +facet_wrap(~variable,scales='free')
  ggsave(report_name, ml, width=21,height=27)
    
  # histogram & density
  
  #ggplot(data=loans,aes(x=LiabilitiesToIncome,y=..density..,fill=defaulted_before_6m))+geom_histogram(alpha=0.4,position='identity')
  #ggplot(data=loans,aes(x=LiabilitiesToIncome,colour=defaulted_before_6m))+geom_line(stat='density')
  
  report_name<-paste0(filename,'_reals_',target_variable,'.pdf')
  p<-ggplot(data=loans_dt_tr,aes(y=..density..,fill=defaulted_before_6m))+geom_histogram(alpha=0.4,position='identity')
  
  plots<-llply(request_reals,  function(x) p+aes_string(x)  )
  ml = do.call(marrangeGrob, c(plots, list(nrow=4, ncol=2)))
  ggsave(report_name, ml, width=21,height=27)
  
}




glmdf<-function(cv.fit){
  # create data frame of metric and coefficients
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


cv_test<-function (data, model_formula,target_variable,folds){
  nfolds<-max(folds)
  y<-as.matrix(data[[target_variable]])
  x<-model.matrix(model_formula,data=data)
  # model train/test 
  gini_tr=vector("numeric",nfolds)
  gini_te=vector("numeric",nfolds)
  ll_tr=vector("numeric",nfolds)
  ll_te=vector("numeric",nfolds)
  
  for (i in seq(nfolds)){
    x_tr=x[folds!=i,]
    y_tr=y[folds!=i,]
    x_te=x[folds==i,]
    y_te=y[folds==i,]
    m.fit<-glmnet(x_tr,y_tr, family='binomial', lambda=c(1,0))
    s=s_max(m.fit)

    trn<-test_glmnet(m.fit,s, x_tr,y_tr)
    
    tst<-test_glmnet(m.fit,s, x_te,y_te)
    gini_tr[i]=trn[["gini"]]
    gini_te[i]=tst[["gini"]]
    ll_tr[i]=trn[["logloss"]]
    ll_te[i]=tst[["logloss"]]
  }
  data.frame(model=deparse(model_formula,width.cutoff=500,nlines=1), fold=seq(nfolds), 
             gini_train=gini_tr,gini_test=gini_te, ll_train=ll_tr, ll_test=ll_te)
}

s_max<-function(m.fit) m.fit$lambda[length(m.fit$lambda)]

test_glmnet<-function(m.fit, s, x,y){
  
  #s='lambda.1se'
  #s='lambda.min'
  #s=s_max
  predictions<-predict(m.fit,x,type='response',s=s)
  gin<-gini(predictions,y)
  ll<-logloss(predictions,y)
  # return gini at diff lambdas
  c( gini=gin, logloss=ll)
}


gini<-function(predictions,labels){
  pred<-prediction(predictions,labels)
  perf<-performance(pred, measure = "auc")
  perf@'y.values'[[1]]*2-1
  
}



logloss<-function(actual,target){
  err=-(target*log(actual)+(!target)*log(1-actual))
  mean(err)
}



