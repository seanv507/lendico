require('RPostgreSQL')

read_string<-function(filename){
    paste(readLines(filename), collapse="\n")
}


get_con <- function(){
  drv <- dbDriver("PostgreSQL")
  con<-dbConnect(drv, host="10.11.0.1",dbname="lendico", user="sviolante", password="3qcqHngX")
  con_drv<-c(con,drv)
  return (con_drv)
}
  
dis_con<- function(con){
  dbDisconnect(con)  
}


# dbUnloadDriver(drv)

