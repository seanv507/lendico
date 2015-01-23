files<-c('LoanStats3a.csv.zip','LoanStats3b.csv.zip','LoanStats3c.csv.zip')
urlHead<-'https://resources.lendingclub.com/'
fileDir<-'C:\\Users\\Sean Violante\\Documents\\Data\\LendingClub'

for (file in files){
  fileUrl<-paste0(urlHead,file)
  fileLocal<-paste('C:\\Users\\Sean Violante\\Documents\\Data\\LendingClub',file, sep="\\")
  if (!file.exists(fileLocal)){
    download.file(fileUrl,destfile=fileLocal)  
  }
}

for (file in files){
  if (!file.exists(file)){
    unzip(file)  
  }
}

lapply(files,function(x) unzip(paste(fileDir,x,sep="\\"),exdir=fileDir))

