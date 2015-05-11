library('RPostgreSQL')

get_con <- function(){
  drv <- dbDriver("PostgreSQL")
  return c(dbConnect(drv, host="10.11.0.1",dbname="lendico", user="sviolante", password="3qcqHngX"),drv)
}
  
dis_con<- function(con){
  dbDisconnect(con)  
}


# dbUnloadDriver(drv)

