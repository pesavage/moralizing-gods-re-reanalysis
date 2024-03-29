#Constructing RegrDat file for regression analyses
#setwd("/Users/pesavage/Documents/Research/Oxford Seshat/Data/SCBigGodsOct2017")
load("HS.Rdata")
polities <- read.csv('polities.csv', header=TRUE) # There is an issue with compatibility between my polities.csv file and the one Peter was  using for HS. Resolving this as follows based on debugging the problem with non-matching PolID, identified by using the following code at the end of the original code rerun phylogeny section:
#setdiff(levels(polities$PolID),levels(PolID))
#setdiff(levels(PolID),levels(polities$PolID))
#[1] "GapDec"  "GapKP1"  "IrQajar" "TrOttm5" "YeOttoL" "YeTahir" "YeZiyad"
polities <- polities[polities$PolID != "GapDec",]
polities <- polities[polities$PolID != "GapKP1",]
polities <- polities[polities$PolID != "IrQajar",]
polities <- polities[polities$PolID != "TrOttm5",]
polities <- polities[polities$PolID != "YeOttoL",] 
write.csv(polities, file="polities.csv",  row.names=FALSE) 
polities <- read.csv('polities.csv', header=TRUE)
##
data <- read.table("PC1_traj_merged.csv", sep=",", header=TRUE)
data <- transform(data, MoralisingGods = ifelse(is.na(MoralisingGods) & Writing==1, 0, MoralisingGods)) #This converts unknowns to absent for only those cases where there is no evidence for moralizing gods despite the presence of writing
completeFun <- function(data, desiredCols) {
  completeVec <- complete.cases(data[, desiredCols])
  return(data[completeVec, ])
}
data<-completeFun(data, "MoralisingGods") #This is to check effect of treating moralising gods as "unknown" (NA) as 0. this analysis now omits all prehistoric centuries where moralising gods status is unknown

#data[is.na(data)] <- 0 #This treats NA values as 0. Commented out
#data$DoctrinalMode<-ifelse(data$ReligiousHier>=2,1,0) #to use only religious hierarchy as proxy for doctrinal mode
#data$DoctrinalMode<-ifelse(data$FreqLR>4.5 | data$FreqWR>4.5 | data$FreqFR>4.5 | data$FreqER>4.5 | data$FreqDR>4.5,1,0) #to use only ritual frequency as proxy for doctrinal mode
data$MG<-data$MoralisingGods

refcols <- c("NGA", "PolID","Time","MG")
data <- data[, c(refcols, setdiff(names(data), refcols))]
names(data)

### Add lags
RegrDat<-data #change label for compatibility with earlier code
dat <- cbind(RegrDat,matrix(NA,nrow(RegrDat),2))
nm <- colnames(dat)
nm[c((length(nm)-1),length(nm))] <- c("Lag1","Lag2")
colnames(dat) <- nm
for(i in 2:nrow(dat)){
  if(dat$Time[i] == dat$Time[i-1]+100){dat$Lag1[i] <- dat$MG[i-1]}
}
for(i in 3:nrow(dat)){
  if(dat$Time[i] == dat$Time[i-2]+200){dat$Lag2[i] <- dat$MG[i-2]}
}
RegrDat <- dat

#### Calculate Space using the estimated d = 1000 km (suggested by Peter Turchin as default because this is approximate average distance between NGAs - we later tested this with the range of parameters described in the paper and found that 1000 was indeed the optimal value)
dpar <- 1000
Space <- RegrDat[,1:4]
Space[,4] <- NA
colnames(Space) <- c("NGA","PolID","Time","Space")

colMat <- colnames(DistMatrix)
rowMat <- rownames(DistMatrix)
for(i in 1:nrow(RegrDat)){
  t1 <- RegrDat$Time[i] - 100
  dat <- RegrDat[RegrDat$Time==t1,1:4] 
  if(nrow(dat) > 1){
    delta <- vector(length=nrow(dat))
    for(j in 1:nrow(dat)){
      dt <- DistMatrix[colMat==dat$NGA[j],]
      delta[j] <- dt[rowMat==RegrDat$NGA[i]]
    }
    s <- exp(-delta/dpar)*dat$MG
    s <- s[delta != 0]  ### Exclude i=j
    Space$Space[i] <- mean(s)
  }
}
Space$Space[is.na(Space$Space)] <- mean(Space$Space, na.rm = TRUE) # Substitute NAs with the mean
Space$Space <- Space$Space/max(Space$Space)   ##### Scale to max = 1
RegrDat <- cbind(RegrDat,Space$Space)
nm <- colnames(RegrDat)
nm[length(nm)] <- "Space"
colnames(RegrDat) <- nm

#### Calculate Language = matrix of linguistic distances
Phylogeny <- RegrDat[,1:4]
Phylogeny[,4] <- NA
colnames(Phylogeny) <- c("NGA","PolID","Time","Phylogeny")

for(i in 1:nrow(RegrDat)){
  t1 <- RegrDat$Time[i] - 100
  dat <- RegrDat[RegrDat$Time==t1,1:4]
  dat <- dat[dat$NGA != RegrDat$NGA[i],]   ### Exclude i = j
  PolID <- RegrDat$PolID[i]
  PolLang <- polities[polities$PolID==PolID,9:11]
  if(nrow(dat) > 1){
    weight <- vector(length=nrow(dat)) * 0
    for(j in 1:nrow(dat)){
      dt <- dat[j,]
      PolLang2 <- polities[polities$PolID==dt$PolID,9:11]
      if(PolLang[1,3]==PolLang2[1,3]){weight[j] <- 0.25}
      if(PolLang[1,2]==PolLang2[1,2]){weight[j] <- 0.5}
      if(PolLang[1,1]==PolLang2[1,1]){weight[j] <- 1}
    }
    s <- weight*dat$MG
    Phylogeny$Phylogeny[i] <- mean(s)
  }
}
Phylogeny$Phylogeny[is.na(Phylogeny$Phylogeny)] <- 0 # Substitute NAs with 0 (NB: This does NOT replace NA codings for moralizing gods)
RegrDat <- cbind(RegrDat,Phylogeny$Phylogeny)
nm <- colnames(RegrDat)
nm[length(nm)] <- "Phylogeny"
colnames(RegrDat) <- nm


