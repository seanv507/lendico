amounts=data.frame(amounts=c(1000,5000,10000,25000),prob=.25)
defs=data.frame(defs=c(.01,0.05,0.10),prob=c(.10,.80,.10))
amount_portfolio=sample(amounts$amounts,prob=amounts$prob)
n_portfolio=100
amount_portfolio=sample(amounts$amounts,size=n_portfolio,replace=TRUE,prob=amounts$prob)
def_portfolio=sample(defs$defs,size=n_portfolio,replace=TRUE,prob=defs$prob)
defs=data.frame(defs=c(.01,0.05,0.10),prob=c(.10,.80,.10))
def_portfolio=sample(defs$defs,size=n_portfolio,replace=TRUE,prob=defs$prob)
portfolio=data.frame(amounts=amount_portfolio,defs=def_portfolio)

portfolio_stats=c(N=nrow(portfolio),mean=sum(portfolio$amounts*portfolio$defs),std=sqrt(sum(portfolio$amounts*portfolio$amounts*portfolio$defs*(1-portfolio$defs))))



n_samples=1000000
trials=matrix(runif(n_samples*n_portfolio),nrow=n_portfolio)
trials=(trials<=def_portfolio)*amount_portfolio
port_trials=colSums(trials)
portfolio_stats
mean(port_trials)
sd(port_trials)
hist(port_trials,freq=F)
trials_stats=c(mean=mean(port_trials), std= sd(port_trials))
lines(dx,dnorm(dx,portfolio_stats[['mean']],portfolio_stats[['std']]))