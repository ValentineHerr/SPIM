mcmc.genCatSMR.movea <-
  function(data,niter=2400,nburn=1200, nthin=5, M = 200, inits=NA,obstype="poisson",nswap=NA,
           proppars=list(lam0=0.05,sigma_d=0.1,sx=0.2,sy=0.2),
           storeLatent=TRUE,storeGamma=TRUE,IDup="Gibbs",tf1=NA,tf2=NA){
    ###
    library(abind)
    y.mark<-data$y.mark
    y.sight.marked=data$y.sight.marked
    y.sight.unmarked=data$y.sight.unmarked
    X1<-as.matrix(data$X1)
    X2<-as.matrix(data$X2)
    J1<-nrow(X1)
    J2<-nrow(X2)
    K1<- data$K1
    K2<- data$K2
    ncat=data$IDlist$ncat
    nallele=data$IDlist$nallele
    IDcovs=data$IDlist$IDcovs
    buff<- data$buff
    Xall=rbind(X1,X2)
    # n.samp.latent=nrow(y.sight.unmarked)
    n.marked=nrow(y.mark)
    G.marked=data$G.marked
    G.unmarked=data$G.unmarked
    if(any(is.na(G.marked))|any(is.na(G.unmarked))){
      stop("Code missing IDcovs with a 0")
    }
    if(!is.matrix(G.marked)){
      G.marked=matrix(G.marked)
    }
    if(!is.matrix(G.unmarked)){
      G.marked=matrix(G.unmarked)
    }
    if(!is.list(IDcovs)){
      stop("IDcovs must be a list")
    }
    nlevels=unlist(lapply(IDcovs,length))
    if(ncol(G.marked)!=ncat){
      stop("G.marked needs ncat number of columns")
    }
    if(ncol(G.unmarked)!=ncat){
      stop("G.unmarked needs ncat number of columns")
    }
    #Are there unknown marked status guys?
    useUnk=FALSE
    if("G.unk"%in%names(data)){
      if(!is.na(data$G.unk[1])){
        G.unk=data$G.unk
        if(!is.matrix(G.unk)){
          G.marked=matrix(G.unk)
        }
        if(ncol(G.unk)!=ncat){
          stop("G.unk needs ncat number of columns")
        }
        y.sight.unk=data$y.sight.unk
        useUnk=TRUE
      }
    }
    #Are there marked no ID guys?
    useMarkednoID=FALSE
    if("G.marked.noID"%in%names(data)){
      if(!is.na(data$G.marked.noID[1])){
        G.marked.noID=data$G.marked.noID
        if(!is.matrix(G.marked.noID)){
          G.marked.noID=matrix(G.marked.noID)
        }
        if(ncol(G.marked.noID)!=ncat){
          stop("G.marked.noID needs ncat number of columns")
        }
        y.sight.marked.noID=data$y.sight.marked.noID
        useMarkednoID=TRUE
      }
    }

    #data checks
    if(length(dim(y.mark))!=3){
      stop("dim(y.mark) must be 3. Reduced to 2 during initialization")
    }
    if(length(dim(y.sight.marked))!=3){
      stop("dim(y.sight.marked) must be 3. Reduced to 2 during initialization")
    }
    if(length(dim(y.sight.unmarked))!=3){
      stop("dim(y.sight.unmarked) must be 3. Reduced to 2 during initialization")
    }
    if(useUnk){
      if(length(dim(y.sight.unk))!=3){
        stop("dim(y.sight.unk) must be 3. Reduced to 2 during initialization")
      }
    }
    if(useMarkednoID){
      if(length(dim(y.sight.marked.noID))!=3){
        stop("dim(y.sight.marked.noID) must be 3. Reduced to 2 during initialization")
      }
    }

    
    if(!IDup%in%c("MH","Gibbs")){
      stop("IDup must be MH or Gibbs")
    }
    if(IDup=="MH"){
      # stop("MH not implemented, yet")
    }
    if(obstype[2]=="bernoulli"&IDup=="Gibbs"){
      stop("Must use MH IDup for bernoulli data")
    }
    
    #If using polygon state space
    if("vertices"%in%names(data)){
      vertices=data$vertices
      useverts=TRUE
      xlim=c(min(vertices[,1]),max(vertices[,1]))
      ylim=c(min(vertices[,2]),max(vertices[,2]))
    }else if("buff"%in%names(data)){
      buff<- data$buff
      xlim<- c(min(Xall[,1]),max(Xall[,1]))+c(-buff, buff)
      ylim<- c(min(Xall[,2]),max(Xall[,2]))+c(-buff, buff)
      vertices=cbind(xlim,ylim)
      useverts=FALSE
    }else{
      stop("user must supply either 'buff' or 'vertices' in data object")
    }
    
    ##pull out initial values
    psi<- inits$psi
    lam0.mark<- inits$lam0.mark
    lam0.sight=inits$lam0.sight
    sigma_d<- inits$sigma_d
    sigma_p<- inits$sigma_p
    gamma=inits$gamma
    if(!is.list(gamma)){
      stop("inits$gamma must be a list")
    }
    
    if(useUnk&!useMarkednoID){
      G.use=rbind(G.unmarked,G.unk)
      status=c(rep(2,nrow(G.unmarked)),rep(0,nrow(G.unk)))
      G.use=cbind(G.use,status)
      G.marked=cbind(G.marked,rep(1,nrow(G.marked)))
      ncat=ncat+1
      y.sight.latent=abind(y.sight.unmarked,y.sight.unk,along=1)
    }else if(!useUnk&useMarkednoID){
      G.use=rbind(G.unmarked,G.marked.noID)
      status=c(rep(2,nrow(G.unmarked)),rep(1,nrow(G.marked.noID)))
      G.use=cbind(G.use,status)
      G.marked=cbind(G.marked,rep(1,nrow(G.marked)))
      ncat=ncat+1
      y.sight.latent=abind(y.sight.unmarked,y.sight.marked.noID,along=1)
    }else if(useUnk&useMarkednoID){
      G.use=rbind(G.unmarked,G.unk,G.marked.noID)
      status=c(rep(2,nrow(G.unmarked)),rep(0,nrow(G.unk)),rep(1,nrow(G.marked.noID)))
      G.use=cbind(G.use,status)
      G.marked=cbind(G.marked,rep(1,nrow(G.marked)))
      ncat=ncat+1
      nlevels=c(nlevels,2)
      y.sight.latent=abind(y.sight.unmarked,y.sight.unk,y.sight.marked.noID,along=1)
    }else{
      G.use=G.unmarked
      y.sight.latent=y.sight.unmarked
    }
    n.samp.latent=nrow(y.sight.latent)
    if(is.na(nswap)){
      nswap=round(n.samp.latent/2)
      warning("nswap not specified, using round(n.samp.latent/2)")
    }
    
    #make constraints for data initialization
      constraints=matrix(1,nrow=n.samp.latent,ncol=n.samp.latent)
      for(i in 1:n.samp.latent){
        for(j in 1:n.samp.latent){
          guys1=which(G.use[i,]!=0)
          guys2=which(G.use[j,]!=0)
          comp=guys1[which(guys1%in%guys2)]
          if(any(G.use[i,comp]!=G.use[j,comp])){
            constraints[i,j]=0
          }
        }
      }
      #If bernoulli data, add constraints that prevent y.true[i,j,k]>1
      binconstraints=FALSE
      if(obstype[2]=="bernoulli"){
        idx=t(apply(y.sight.latent,1,function(x){which(x>0,arr.ind=TRUE)}))
        for(i in 1:n.samp.latent){
          for(j in 1:n.samp.latent){
            if(i!=j){
              if(all(idx[i,1:2]==idx[j,1:2])){
                constraints[i,j]=0 #can't combine samples from same trap and occasion in binomial model
                constraints[j,i]=0
                binconstraints=TRUE
              }
            }
          }
        }
      }
 
    
    
    #Build y.sight.true
    y.sight.true=array(0,dim=c(M,J2,K2))
    y.sight.true[1:n.marked,,]=y.sight.marked
    ID=rep(NA,n.samp.latent)
    idx=n.marked+1
    for(i in 1:n.samp.latent){
      if(useMarkednoID){
        if(status[i]==1)next
      }
      if(idx>M){
        stop("Need to raise M to initialize y.true")
      }
      traps=which(rowSums(y.sight.latent[i,,])>0)
      y.sight.true2D=apply(y.sight.true,c(1,2),sum)
      if(length(traps)==1){
        cand=which(y.sight.true2D[,traps]>0)#guys caught at same traps
      }else{
        cand=which(rowSums(y.sight.true2D[,traps])>0)#guys caught at same traps
      }
      cand=cand[cand>n.marked]
      if(length(cand)>0){
        if(length(cand)>1){#if more than 1 ID to match to, choose first one
          cand=cand[1]
        }
        #Check constraint matrix
        cands=which(ID%in%cand)#everyone assigned this ID
        if(all(constraints[i,cands]==1)){#focal consistent with all partials already assigned
          y.sight.true[cand,,]=y.sight.true[cand,,]+y.sight.latent[i,,]
          ID[i]=cand
        }else{#focal not consistent
          y.sight.true[idx,,]=y.sight.latent[i,,]
          ID[i]=idx
          idx=idx+1
        }
      }else{#no assigned samples at this trap
        y.sight.true[idx,,]=y.sight.latent[i,,]
        ID[i]=idx
        idx=idx+1
      }
    }

    #assign marked unknown ID guys
    if(useMarkednoID){#Need to initialize these guys to marked guys
      fix=which(status==1)
      meanloc=matrix(NA,nrow=n.marked,ncol=2)
      for(i in 1:n.marked){
        trap1=which(rowSums(y.mark[i,,])>0)
        trap2=which(rowSums(y.sight.marked[i,,])>0)
        locs2=matrix(0,nrow=0,ncol=2)
        if(length(trap1)>0){
          locs2=rbind(locs2,X1[trap1,])
        }
        if(length(trap2)>0){
          locs2=rbind(locs2,X2[trap2,])
        }
        if(nrow(locs2)>1){
          meanloc[i,]=colMeans(locs2)
        }else if(nrow(locs2)>0){
          meanloc[i,]=locs2
        }
      }
      for(i in 1:nrow(G.marked.noID)){
        trap=which(rowSums(y.sight.latent[i,,])>0)
        compatible=rep(FALSE,n.marked)
        for(j in 1:n.marked){
          nonzero1=G.marked[j,1:(ncat-1)]!=0
          nonzero2=G.marked.noID[i,]!=0
          nonzero=which(nonzero1&nonzero2)
          if(all(G.marked[j,nonzero]==G.marked.noID[i,nonzero])){
            compatible[j]=TRUE
          }
        }
        if(all(compatible==FALSE)){
          stop(paste("No G.marked compatible with G.marked.noID "),i)
        }
        dists=sqrt((X2[trap,1]-meanloc[,1])^2+(X2[trap,2]-meanloc[,2])^2)
        dists[!compatible]=Inf
        dists[which(Kconstraints[1:n.marked,fix[i]]==0)]=Inf #Exclude guys not marked yet
        if(all(is.finite(dists)==FALSE)){
          stop(paste("No G.marked compatible with G.marked.noID "),i)
        }
        ID[fix[i]]=which(dists==min(dists,na.rm=TRUE))[1]
        y.sight.true[ID[fix[i]],,]=y.sight.true[ID[fix[i]],,]+y.sight.latent[fix[i],,]
      }
    }
    if(binconstraints){
      if(any(y.sight.true>1))stop("bernoulli data not initialized correctly")
    }
    
    
    
    #Check assignment consistency with constraints
    checkID=unique(ID)
    checkID=checkID[checkID>n.marked]
    for(i in 1:length(checkID)){
      idx=which(ID==checkID[i])
      if(!all(constraints[idx,idx]==1)){
        stop("ID initialized improperly")
      }
    }
   
    y.sight.true=apply(y.sight.true,c(1,2),sum)
    y.mark=abind(y.mark,array(0,dim=c(M-n.marked,J1,K1)),along=1)
    y.mark2D=apply(y.mark,c(1,2),sum)
    known.vector=c(rep(1,n.marked),rep(0,M-n.marked))
    known.vector[(n.marked+1):M]=1*(rowSums(y.sight.true[(n.marked+1):M,])>0)
    
    #Initialize z
    z=1*(known.vector>0)
    add=M*(0.5-sum(z)/M)
    if(add>0){
      z[sample(which(z==0),add)]=1 #switch some uncaptured z's to 1.
    }
    unmarked=c(rep(FALSE,n.marked),rep(TRUE,M-n.marked))
    
    #Optimize starting locations given where they are trapped.
    s1<- cbind(runif(M,xlim[1],xlim[2]), runif(M,ylim[1],ylim[2])) #assign random locations
    y.all2D=cbind(y.mark2D,y.sight.true)
    idx=which(rowSums(y.all2D)>0) #switch for those actually caught
    for(i in idx){
      trps<- matrix(Xall[y.all2D[i,]>0,1:2],ncol=2,byrow=FALSE)
      if(nrow(trps)>1){
        s1[i,]<- c(mean(trps[,1]),mean(trps[,2]))
      }else{
        s1[i,]<- trps
      }
    }
    if(useverts==TRUE){
      inside=rep(NA,nrow(s1))
      for(i in 1:nrow(s1)){
        inside[i]=inout(s1[i,],vertices)
      }
      idx=which(inside==FALSE)
      if(length(idx)>0){
        for(i in 1:length(idx)){
          while(inside[idx[i]]==FALSE){
            s1[idx[i],]=c(runif(1,xlim[1],xlim[2]), runif(1,ylim[1],ylim[2]))
            inside[idx[i]]=inout(s1[idx[i],],vertices)
          }
        }
      }
    }
    s2=s1
    
    #collapse unmarked data to 2D
    y.sight.latent=apply(y.sight.latent,c(1,2),sum)
    
    #Initialize G.true
    G.true=matrix(0,nrow=M,ncol=ncat)
    G.true[1:n.marked,]=G.marked
    for(i in unique(ID)){
      idx=which(ID==i)
      if(length(idx)==1){
        G.true[i,]=G.use[idx,]
      }else{
        if(ncol(G.use)>1){
          G.true[i,]=apply(G.use[idx,],2, max) #consensus
        }else{
          G.true[i,]=max(G.use[idx,])
        }
      }
    }
    if(useUnk|useMarkednoID){#augmented guys are unmarked.
      if(max(ID)<M){
        G.true[(max(ID)+1):M,ncol(G.true)]=2
      }
      unkguys=which(G.use[,ncol(G.use)]==0)
    }
    
    G.latent=G.true==0#Which genos can be updated?
    if(!(useUnk|useMarkednoID)){
      for(j in 1:(ncat)){
        fix=G.true[,j]==0
        G.true[fix,j]=sample(IDcovs[[j]],sum(fix),replace=TRUE,prob=gamma[[j]])
      }
    }else{
      for(j in 1:(ncat-1)){
        fix=G.true[,j]==0
        G.true[fix,j]=sample(IDcovs[[j]],sum(fix),replace=TRUE,prob=gamma[[j]])
      }
      #Split marked status back off
      Mark.obs=G.use[,ncat]
      # Mark.status=G.true[,ncat]
      ncat=ncat-1
      G.use=G.use[,1:ncat]
      G.true=G.true[,1:ncat]
    }
    if(!is.matrix(G.use)){
      G.use=matrix(G.use,ncol=1)
    }
    if(!is.matrix(G.true)){
      G.true=matrix(G.true,ncol=1)
    }
    # some objects to hold the MCMC output
    nstore=(niter-nburn)/nthin
    if(nburn%%nthin!=0){
      nstore=nstore+1
    }
    out<-matrix(NA,nrow=nstore,ncol=7)
    dimnames(out)<-list(NULL,c("lam0.mark","lam0.sight","sigma_d","sigma_p","N","n.um","psi"))
    if(storeLatent){
      s1xout<- s1yout<-s2xout<- s2yout<- zout<-matrix(NA,nrow=nstore,ncol=M)
      IDout=matrix(NA,nrow=nstore,ncol=length(ID))
    }
    idx=1 #for storing output not recorded every iteration
    if(storeGamma){
      gammaOut=vector("list",ncat)
      for(i in 1:ncat){
        gammaOut[[i]]=matrix(NA,nrow=nstore,ncol=nlevels[i])
        colnames(gammaOut[[i]])=paste("Lo",i,"G",1:nlevels[i],sep="")
      }
    }
    if(!is.na(data$locs[1])){
      uselocs=TRUE
      locs=data$locs
      telguys=which(rowSums(!is.na(locs[,,1]))>0)
      ll.tel=matrix(0,nrow=length(telguys),ncol=dim(locs)[2])
      #update starting locations using telemetry data
      for(i in telguys){
          s2[i,]<- c(mean(locs[i,,1],na.rm=TRUE),mean(locs[i,,2],na.rm=TRUE))
      }
      for(i in telguys){
        ll.tel[i,]=dnorm(locs[i,,1],s2[i,1],sigma_d,log=TRUE)+dnorm(locs[i,,2],s2[i,2],sigma_d,log=TRUE)
      }
      ll.tel.cand=ll.tel
    }else{
      uselocs=FALSE
      telguys=c()
    }
    if(!any(is.na(tf1))){
      if(any(tf1>K1)){
        stop("Some entries in tf1 are greater than K1.")
      }
      if(is.null(dim(tf1))){
        if(length(tf1)!=J1){
          stop("2D tf1 vector must be of length J1.")
        }
        K2D1=matrix(rep(tf1,M),nrow=M,ncol=J1,byrow=TRUE)
        warning("Since 1D tf1 entered, assuming all individuals exposed to equal capture")
      }else{
        if(!all(dim(tf1)==c(M,J1))){
          stop("tf1 must be dim M by J1 if tf1 varies by individual")
        }
        K2D1=tf1
        warning("Since 2D tf1 entered, assuming individual exposure to traps differ")
      }
    }else{
      tf1=rep(K1,J1)
      K2D1=matrix(rep(tf1,M),nrow=M,ncol=J1,byrow=TRUE)
    }
    if(!any(is.na(tf2))){
      if(any(tf2>K2)){
        stop("Some entries in tf2 are greater than K2.")
      }
      if(is.null(dim(tf2))){
        if(length(tf2)!=J2){
          stop("tf2 vector must be of length J2.")
        }
        if(!all(dim(K2D2)==c(M,J2))){
          stop("K2D2 must be dim M by J2 if K2D2 varies by individual")
        }
        K2D2=matrix(rep(tf2,M),nrow=M,ncol=J2,byrow=TRUE)
        warning("Since 1D tf2 entered, assuming all individuals exposed to equal sighting effort")
      }else{
        K2D2=tf2
        warning("Since 2D tf2 entered, assuming individual exposure to sighting effort differs")
      }
    }else{
      tf2=rep(K2,J2)
      K2D2=matrix(rep(tf2,M),nrow=M,ncol=J2,byrow=TRUE)
    }
    K2D1=matrix(rep(tf1,M),nrow=M,ncol=J1,byrow=TRUE)
    D1=e2dist(s1, X1)
    D2=e2dist(s2, X2)
    lamd.trap<- lam0.mark*exp(-D1*D1/(2*sigma_d*sigma_d))
    lamd.sight<- lam0.sight*exp(-D2*D2/(2*sigma_d*sigma_d))
    ll.y.mark=array(0,dim=c(M,J1))
    ll.y.sight=array(0,dim=c(M,J2))
    if(obstype[1]=="bernoulli"){
      pd.trap=1-exp(-lamd.trap)
      pd.trap.cand=pd.trap
      ll.y.mark=dbinom(y.mark2D,K2D1,pd.trap*z,log=TRUE)
    }else if(obstype[1]=="poisson"){
      ll.y.mark=dpois(y.mark2D,K2D1*lamd.trap*z,log=TRUE)
    }
    if(obstype[2]=="bernoulli"){
      pd.sight=1-exp(-lamd.sight)
      pd.sight.cand=pd.sight
      ll.y.sight=dbinom(y.sight.true,K2D2,pd.sight*z,log=TRUE)
    }else if(obstype[2]=="poisson"){
      ll.y.sight=dpois(y.sight.true,K2D2*lamd.sight*z,log=TRUE)
    }
    
    lamd.trap.cand=lamd.trap
    lamd.sight.cand=lamd.sight
    ll.y.mark.cand=ll.y.mark
    ll.y.sight.cand=ll.y.sight
    if(!is.finite(sum(ll.y.mark))){
      stop("Trap obs likelihood not finite. Try raising lam0.mark and/or sigma_d inits")
    }
    if(!is.finite(sum(ll.y.sight))){
      stop("Sighting obs likelihood not finite. Try raising lam0.sight and/or sigma_d inits")
    }
    #movement likelihood.
    ll.s2=log(dnorm(s2[,1],s1[,1],sigma_p)/
                (pnorm(xlim[2],s1[,1],sigma_p)-pnorm(xlim[1],s1[,1],sigma_p)))
    ll.s2=ll.s2+log(dnorm(s2[,2],s1[,2],sigma_p)/
                      (pnorm(ylim[2],s1[,2],sigma_p)-pnorm(ylim[1],s1[,2],sigma_p)))
    ll.s2.cand=ll.s2
    
    
    
    for(iter in 1:niter){
      #Update lam0.mark
      llytrapsum=sum(ll.y.mark)
      lam0.mark.cand<- rnorm(1,lam0.mark,proppars$lam0.mark)
      if(lam0.mark.cand > 0){
        if(obstype[1]=="bernoulli"){
          lamd.trap.cand<- lam0.mark.cand*exp(-D1*D1/(2*sigma_d*sigma_d))
          pd.trap.cand=1-exp(-lamd.trap.cand)
          ll.y.mark.cand= dbinom(y.mark2D,K2D1,pd.trap.cand*z,log=TRUE)
          llytrapcandsum=sum(ll.y.mark.cand)
          if(runif(1) < exp(llytrapcandsum-llytrapsum)){
            lam0.mark<- lam0.mark.cand
            lamd.trap=lamd.trap.cand
            pd.trap=pd.trap.cand
            ll.y.mark=ll.y.mark.cand
            llytrapsum=llytrapcandsum
          }
        }else{#poisson
          llytrapsum=sum(ll.y.mark)
          lam0.mark.cand<- rnorm(1,lam0.mark,proppars$lam0.mark)
          if(lam0.mark.cand > 0){
            lamd.trap.cand<- lam0.mark.cand*exp(-D1*D1/(2*sigma_d*sigma_d))
            ll.y.mark.cand= dpois(y.mark2D,K2D1*lamd.trap.cand*z,log=TRUE)
            llytrapcandsum=sum(ll.y.mark.cand)
            if(runif(1) < exp(llytrapcandsum-llytrapsum)){
              lam0.mark<- lam0.mark.cand
              lamd.trap=lamd.trap.cand
              ll.y.mark=ll.y.mark.cand
              llytrapsum=llytrapcandsum
            }
          }
        }
      }
      #Update lam0.sight
      llysightsum=sum(ll.y.sight)
      lam0.sight.cand<- rnorm(1,lam0.sight,proppars$lam0.sight)
      if(lam0.sight.cand > 0){
        if(obstype[2]=="bernoulli"){
          lamd.sight.cand<- lam0.sight.cand*exp(-D2*D2/(2*sigma_d*sigma_d))
          pd.sight.cand=1-exp(-lamd.sight.cand)
          ll.y.sight.cand= dbinom(y.sight.true,K2D2,pd.sight.cand*z,log=TRUE)
          llysightcandsum=sum(ll.y.sight.cand)
          if(runif(1) < exp(llysightcandsum-llysightsum)){
            lam0.sight<- lam0.sight.cand
            lamd.sight=lamd.sight.cand
            pd.sight=pd.sight.cand
            ll.y.sight=ll.y.sight.cand
            llysightsum=llysightcandsum
          }
        }else{#poisson
          llysightsum=sum(ll.y.sight)
          lam0.sight.cand<- rnorm(1,lam0.sight,proppars$lam0.sight)
          if(lam0.sight.cand > 0){
            lamd.sight.cand<- lam0.sight.cand*exp(-D2*D2/(2*sigma_d*sigma_d))
            ll.y.sight.cand= dpois(y.sight.true,K2D2*lamd.sight.cand*z,log=TRUE)
            llysightcandsum=sum(ll.y.sight.cand)
            if(runif(1) < exp(llysightcandsum-llysightsum)){
              lam0.sight<- lam0.sight.cand
              lamd.sight=lamd.sight.cand
              ll.y.sight=ll.y.sight.cand
              llysightsum=llysightcandsum
            }
          }
        }
      }
      #Update sigma_d
      sigma_d.cand<- rnorm(1,sigma_d,proppars$sigma_d)
      if(sigma_d.cand > 0){
        if(obstype[1]=="bernoulli"){
          lamd.trap.cand<- lam0.mark*exp(-D1*D1/(2*sigma_d.cand*sigma_d.cand))
          pd.trap.cand=1-exp(-lamd.trap.cand)
          ll.y.mark.cand= dbinom(y.mark2D,K2D1,pd.trap.cand*z,log=TRUE)
        }else{
          lamd.trap.cand<- lam0.mark*exp(-D1*D1/(2*sigma_d.cand*sigma_d.cand))
          ll.y.mark.cand= dpois(y.mark2D,K2D1*lamd.trap.cand*z,log=TRUE)
          llytrapcandsum=sum(ll.y.mark.cand)
        }
        llytrapcandsum=sum(ll.y.mark.cand)
        if(obstype[2]=="bernoulli"){
          lamd.sight.cand<- lam0.sight*exp(-D2*D2/(2*sigma_d.cand*sigma_d.cand))
          pd.sight.cand=1-exp(-lamd.sight.cand)
          ll.y.sight.cand= dbinom(y.sight.true,K2D2,pd.sight.cand*z,log=TRUE)
        }else{
          lamd.sight.cand<- lam0.sight*exp(-D2*D2/(2*sigma_d.cand*sigma_d.cand))
          ll.y.sight.cand= dpois(y.sight.true,K2D2*lamd.sight.cand*z,log=TRUE)
        }
        llysightcandsum=sum(ll.y.sight.cand)
        if(uselocs){
          for(i in telguys){
            ll.tel.cand[i,]=dnorm(locs[i,,1],s2[i,1],sigma_d.cand,log=TRUE)+dnorm(locs[i,,2],s2[i,2],sigma_d.cand,log=TRUE)
          }
        }else{
          ll.tel.cand=ll.tel=0
        }
        if(runif(1) < exp((llytrapcandsum+llysightcandsum+sum(ll.tel.cand,na.rm=TRUE))-
                          (llytrapsum+llysightsum+sum(ll.tel,na.rm=TRUE)))){
          sigma_d<- sigma_d.cand
          lamd.trap=lamd.trap.cand
          lamd.sight=lamd.sight.cand
          ll.y.mark=ll.y.mark.cand
          ll.y.sight=ll.y.sight.cand
          ll.tel=ll.tel.cand
          if(obstype[1]=="bernoulli"){
            pd.trap=pd.trap.cand
          }
          if(obstype[2]=="bernoulli"){
            pd.sight=pd.sight.cand
          }
        }
      }
      
      # ID update
      if(IDup=="Gibbs"){
        #Update y.sight.true from full conditional canceling out inconsistent combos with constraints.
        up=sample(1:n.samp.latent,nswap,replace=FALSE)
        for(l in up){
          nj=which(y.sight.latent[l,]>0)
          #Can only swap if IDcovs match
          idx2=which(G.use[l,]!=0)
          if(length(idx2)>1){#multiple loci observed
            possible=which(z==1&apply(G.true[,idx2],1,function(x){all(x==G.use[l,idx2])}))
          }else if(length(idx2)==1){#single loci observed
            possible=which(z==1&G.true[,idx2]==G.use[l,idx2])
          }else{#fully latent G.obs
            possible=which(z==1)#Can match anyone
          }
          if(!(useUnk|useMarkednoID)){#mark status exclusions handled through G.true
            possible=possible[possible>n.marked]#Can't swap to a marked guy
          }else{
            if(Mark.obs[l]==2){#This is an unmarked sample
              possible=possible[possible>n.marked]#Can't swap to a marked guy
            }
            if(Mark.obs[l]==1){#This is a marked sample
              possible=possible[possible<=n.marked]#Can't swap to an unmarked guy
            }
          }
          if(length(possible)==0)next
          njprobs=lamd.sight[,nj]
          njprobs[setdiff(1:M,possible)]=0
          njprobs=njprobs/sum(njprobs)
          newID=sample(1:M,1,prob=njprobs)
          if(ID[l]!=newID){
            swapped=c(ID[l],newID)
            #update y.true
            y.sight.true[ID[l],]=y.sight.true[ID[l],]-y.sight.latent[l,]
            y.sight.true[newID,]=y.sight.true[newID,]+y.sight.latent[l,]
            ID[l]=newID
            if(obstype[2]=="bernoulli"){
              ll.y.sight[swapped,]= dbinom(y.sight.true[swapped,],K2D2[swapped,],pd.sight[swapped,],log=TRUE)
            }else{
              ll.y.sight[swapped,]= dpois(y.sight.true[swapped,],K2D2[swapped,]*lamd.sight[swapped,],log=TRUE)
            }
          }
        }
      }else{
        up=sample(1:n.samp.latent,nswap,replace=FALSE)
        y.sight.cand=y.sight.true
        for(l in up){
          #find legal guys to swap with. z=1 and consistent constraints
          nj=which(y.sight.latent[l,]>0)
          #Can only swap if IDcovs match
          idx2=which(G.use[l,]!=0)
          if(length(idx2)>1){#multiple loci observed
            possible=which(z==1&apply(G.true[,idx2],1,function(x){all(x==G.use[l,idx2])}))
          }else if(length(idx2)==1){#single loci observed
            possible=which(z==1&G.true[,idx2]==G.use[l,idx2])
          }else{#fully latent G.obs
            possible=which(z==1)#Can match anyone
          }
          if(!(useUnk|useMarkednoID)){#mark status exclusions handled through G.true
            possible=possible[possible>n.marked]#Can't swap to a marked guy
          }else{
            if(Mark.obs[l]==2){#This is an unmarked sample
              possible=possible[possible>n.marked]#Can't swap to a marked guy
            }
            if(Mark.obs[l]==1){#This is a marked sample
              possible=possible[possible<=n.marked]#Can't swap to an unmarked guy
            }
          }
          if(binconstraints){#can't have a y[i,j,k]>1
            legal=rep(TRUE,length(possible))
            for(i in 1:length(possible)){
              check=which(ID==possible[i])#Who else is currently assigned this possible new ID?
              if(length(check)>0){#if false, no samples assigned to this guy and legal stays true
                if(any(constraints[l,check]==0)){#if any members of the possible cluster are inconsistent with sample, illegal move
                  legal[i]=FALSE
                }
              }
            }
            possible=possible[legal]
          }
          if(length(possible)==0)next
          njprobs=lamd.sight[,nj]
          njprobs[setdiff(1:M,possible)]=0
          njprobs=njprobs/sum(njprobs)
          newID=ID
          newID[l]=sample(1:M,1,prob=njprobs)
          if(ID[l]==newID[l])next

          swapped=c(ID[l],newID[l])#order swap.out then swap.in
          propprob=njprobs[swapped[2]]
          backprob=njprobs[swapped[1]]
          # focalprob=1/n.samp.latent
          # focalbackprob=1/length(possible)
          #update y.true
          y.sight.cand[ID[l],]=y.sight.true[ID[l],]-y.sight.latent[l,]
          y.sight.cand[newID[l],]=y.sight.true[newID[l],]+y.sight.latent[l,]
          focalprob=(sum(ID==ID[l])/n.samp.latent)*(y.sight.true[ID[l],nj]/sum(y.sight.true[ID[l],]))
          focalbackprob=(sum(newID==newID[l])/n.samp.latent)*(y.sight.cand[newID[l],nj]/sum(y.sight.cand[newID[l],]))
          ##update ll.y
          if(obstype[2]=="poisson"){
            ll.y.sight.cand[swapped,]=dpois(y.sight.cand[swapped,],K2D2[swapped,]*lamd.sight[swapped,],log=TRUE)
          }else{
            ll.y.sight.cand[swapped,]=dbinom(y.sight.cand[swapped,],K2D2[swapped,],pd.sight[swapped,],log=TRUE)
          }
          if(runif(1)<exp(sum(ll.y.sight.cand[swapped,])-sum(ll.y.sight[swapped,]))*
             (backprob/propprob)*(focalbackprob/focalprob)){
            y.sight.true[swapped,]=y.sight.cand[swapped,]
            ll.y.sight[swapped,]=ll.y.sight.cand[swapped,]
            ID[l]=newID[l]
          }
        }
      }
      # #update known.vector and G.latent
      known.vector[(n.marked+1):M]=1*(rowSums(y.sight.true[(n.marked+1):M,])>0)
      G.true.tmp=matrix(0, nrow=M,ncol=ncat)
      G.true.tmp[1:n.marked,]=1
      for(i in unique(ID[ID>n.marked])){
        idx2=which(ID==i)
        if(length(idx2)==1){
          G.true.tmp[i,]=G.use[idx2,]
        }else{
          if(ncol(G.use)>1){
            G.true.tmp[i,]=apply(G.use[idx2,],2, max) #consensus
          }else{
            G.true.tmp[i,]=max(G.use[idx2,]) #consensus
          }
        }
      }
      G.latent=G.true.tmp==0
      #update G.true
      for(j in 1:ncat){
        swap=G.latent[,j]
        G.true[swap,j]=sample(IDcovs[[j]],sum(swap),replace=TRUE,prob=gamma[[j]])
      }
      
      #update genotype frequencies
      for(j in 1:ncat){
        x=rep(NA,nlevels[[j]])
        for(k in 1:nlevels[[j]]){
          x[k]=sum(G.true[z==1,j]==k)#genotype freqs in pop
        }
        gam=rgamma(rep(1,nlevels[[j]]),1+x)
        gamma[[j]]=gam/sum(gam)
      }
      
      ## probability of not being captured in a trap AT ALL by either method
      if(obstype[1]=="poisson"){
        pd.trap=1-exp(-lamd.trap)
      }
      if(obstype[2]=="poisson"){
        pd.sight=1-exp(-lamd.sight)
      }
      pbar.trap=(1-pd.trap)^K2D1
      pbar.sight=(1-pd.sight)^K2D2
      prob0.trap<- exp(rowSums(log(pbar.trap)))
      prob0.sight<- exp(rowSums(log(pbar.sight)))
      prob0=prob0.trap*prob0.sight
      
      
      fc<- prob0*psi/(prob0*psi + 1-psi)
      z[known.vector==0]<- rbinom(sum(known.vector ==0), 1, fc[known.vector==0])
      if(obstype[1]=="bernoulli"){
        ll.y.mark= dbinom(y.mark2D,K2D1,pd.trap*z,log=TRUE)
      }else{
        ll.y.mark= dpois(y.mark2D,K2D1*lamd.trap*z,log=TRUE)
      }
      if(obstype[2]=="bernoulli"){
        ll.y.sight= dbinom(y.sight.true,K2D2,pd.sight*z,log=TRUE)
      }else{
        ll.y.sight= dpois(y.sight.true,K2D2*lamd.sight*z,log=TRUE)
      }
      psi=rbeta(1,1+sum(z),1+M-sum(z))
      ## Now we have to update the activity centers
      #s1
      for (i in 1:M) {
        Scand <- c(rnorm(1, s1[i, 1], proppars$s1), rnorm(1, s1[i, 2], proppars$s1))
        if(useverts==FALSE){
          inbox <- Scand[1] < xlim[2] & Scand[1] > xlim[1] & Scand[2] < ylim[2] & Scand[2] > ylim[1]
        }else{
          inbox=inout(Scand,vertices)
        }
        if (inbox) {
          d1tmp <- sqrt((Scand[1] - X1[, 1])^2 + (Scand[2] - X1[, 2])^2)
          lamd.trap.cand[i,]<- lam0.mark*exp(-d1tmp*d1tmp/(2*sigma_d*sigma_d))
          #update ll.s2
          ll.s2.cand[i]=log(dnorm(s2[i,1],Scand[1],sigma_p)/
                              (pnorm(xlim[2],Scand[1],sigma_p)-pnorm(xlim[1],Scand[1],sigma_p)))
          ll.s2.cand[i]=ll.s2.cand[i]+log(dnorm(s2[i,2],Scand[2],sigma_p)/
                                            (pnorm(ylim[2],Scand[2],sigma_p)-pnorm(ylim[1],Scand[2],sigma_p)))
          if(obstype[1]=="bernoulli"){
            pd.trap.cand[i,]=1-exp(-lamd.trap.cand[i,])
            ll.y.mark.cand[i,]= dbinom(y.mark2D[i,],K2D1[i,],pd.trap.cand[i,]*z[i],log=TRUE)
            if (runif(1) < exp((sum(ll.y.mark.cand[i,])+ll.s2.cand[i]) -
                (sum(ll.y.mark[i,])+ll.s2[i]))) {
              s1[i,]=Scand
              D1[i,]=d1tmp
              lamd.trap[i,]=lamd.trap.cand[i,]
              pd.trap[i,]=pd.trap.cand[i,]
              ll.y.mark[i,]=ll.y.mark.cand[i,]
              ll.s2[i]=ll.s2.cand[i]
            }
          }else{#poisson
            ll.y.mark.cand[i,]= dpois(y.mark2D[i,],K2D1[i,]*lamd.trap.cand[i,]*z[i],log=TRUE)
            if (runif(1) < exp((sum(ll.y.mark.cand[i,])+ll.s2.cand[i]) -
                               (sum(ll.y.mark[i,])+ll.s2[i]))) {
              s1[i,]=Scand
              D1[i,]=d1tmp
              lamd.trap[i,]=lamd.trap.cand[i,]
              ll.y.mark[i,]=ll.y.mark.cand[i,]
              ll.s2[i]=ll.s2.cand[i]
            }
          }
        }
      }
      #s2
      for (i in 1:M) {
        if(i%in%telguys){
          Scand <- c(rnorm(1, s2[i, 1], proppars$s2t), rnorm(1, s2[i, 2], proppars$s2t))
        }else{
          Scand <- c(rnorm(1, s2[i, 1], proppars$s2), rnorm(1, s2[i, 2], proppars$s2))
        }
        if(useverts==FALSE){
          inbox <- Scand[1] < xlim[2] & Scand[1] > xlim[1] & Scand[2] < ylim[2] & Scand[2] > ylim[1]
        }else{
          inbox=inout(Scand,vertices)
        }
        if (inbox) {
          d2tmp <- sqrt((Scand[1] - X2[, 1])^2 + (Scand[2] - X2[, 2])^2)
          lamd.sight.cand[i,]<- lam0.sight*exp(-d2tmp*d2tmp/(2*sigma_d*sigma_d))
          #movement likelhood
          ll.s2.cand[i]=log(dnorm(Scand[1],s1[i,1],sigma_p)/
                              (pnorm(xlim[2],s1[i,1],sigma_p)-pnorm(xlim[1],s1[i,1],sigma_p)))
          ll.s2.cand[i]=ll.s2.cand[i]+log(dnorm(Scand[2],s1[i,2],sigma_p)/
                                            (pnorm(ylim[2],s1[i,2],sigma_p)-pnorm(ylim[1],s1[i,2],sigma_p)))
          if(obstype[2]=="bernoulli"){
            pd.sight.cand[i,]=1-exp(-lamd.sight.cand[i,])
            ll.y.sight.cand[i,]= dbinom(y.sight.true[i,],K2D2[i,],pd.sight.cand[i,]*z[i],log=TRUE)
            if(uselocs&(i%in%telguys)){
              ll.tel.cand[i,]=dnorm(locs[i,,1],Scand[1],sigma_d,log=TRUE)+dnorm(locs[i,,2],Scand[2],sigma_d,log=TRUE)
              if (runif(1) < exp((sum(ll.y.sight.cand[i,])+sum(ll.tel.cand[i,],na.rm=TRUE)+ll.s2.cand[i]) -
                                 (sum(ll.y.sight[i,])+sum(ll.tel[i,],na.rm=TRUE)+ll.s2[i]))) {
                s2[i,]=Scand
                D2[i,]=d2tmp
                lamd.sight[i,]=lamd.sight.cand[i,]
                pd.sight[i,]=pd.sight.cand[i,]
                ll.y.sight[i,]=ll.y.sight.cand[i,]
                ll.tel[i,]=ll.tel.cand[i,]
                ll.s2[i]=ll.s2.cand[i]
              }
            }else{
              if (runif(1) < exp((sum(ll.y.sight.cand[i,])+ll.s2.cand[i]) -
                                 (sum(ll.y.sight[i,])+ll.s2[i]))) {
                s2[i,]=Scand
                D2[i,]=d2tmp
                lamd.sight[i,]=lamd.sight.cand[i,]
                pd.sight[i,]=pd.sight.cand[i,]
                ll.y.sight[i,]=ll.y.sight.cand[i,]
                ll.s2[i]=ll.s2.cand[i]
              }
            }
          }else{#poisson
            ll.y.sight.cand[i,]= dpois(y.sight.true[i,],K2D2[i,]*lamd.sight.cand[i,]*z[i],log=TRUE)
            if(uselocs&(i%in%telguys)){
              ll.tel.cand[i,]=dnorm(locs[i,,1],Scand[1],sigma_d,log=TRUE)+dnorm(locs[i,,2],Scand[2],sigma_d,log=TRUE)
              if (runif(1) < exp((sum(ll.y.sight.cand[i,])+sum(ll.tel.cand[i,],na.rm=TRUE)+ll.s2.cand[i]) -
                                 (sum(ll.y.sight[i,])+sum(ll.tel[i,],na.rm=TRUE)+ll.s2[i]))) {
                s2[i,]=Scand
                D2[i,]=d2tmp
                lamd.sight[i,]=lamd.sight.cand[i,]
                ll.y.sight[i,]=ll.y.sight.cand[i,]
                ll.tel[i,]=ll.tel.cand[i,]
                ll.s2.cand[i]=ll.s2.cand[i]
              }
            }else{
              if (runif(1) < exp((sum(ll.y.sight.cand[i,])+ll.s2.cand[i]) -
                                 (sum(ll.y.sight[i,])+ll.s2[i]))) {
                s2[i,]=Scand
                D2[i,]=d2tmp
                lamd.sight[i,]=lamd.sight.cand[i,]
                ll.y.sight[i,]=ll.y.sight.cand[i,]
                ll.s2[i]=ll.s2.cand[i]
              }
            }
          }
        }
      }
      # #update sigma_p
      sigma_p.cand <- rnorm(1,sigma_p,proppars$sigma_p)
      if(sigma_p.cand > 0){
        ll.s2.cand=log(dnorm(s2[,1],s1[,1],sigma_p.cand)/
                    (pnorm(xlim[2],s1[,1],sigma_p.cand)-pnorm(xlim[1],s1[,1],sigma_p.cand)))
        ll.s2.cand=ll.s2.cand+log(dnorm(s2[,2],s1[,2],sigma_p.cand)/
                          (pnorm(ylim[2],s1[,2],sigma_p.cand)-pnorm(ylim[1],s1[,2],sigma_p.cand)))


        if (runif(1) < exp(sum(ll.s2.cand) - sum(ll.s2))) {
          sigma_p=sigma_p.cand
          ll.s2=ll.s2.cand
        }
      }
      
      #Do we record output on this iteration?
      if(iter>nburn&iter%%nthin==0){
        if(storeLatent){
          s1xout[idx,]<- s1[,1]
          s1yout[idx,]<- s1[,2]
          s2xout[idx,]<- s2[,1]
          s2yout[idx,]<- s2[,2]
          zout[idx,]<- z
          IDout[idx,]=ID
        }
        if(storeGamma){
          for(k in 1:ncat){
            gammaOut[[k]][idx,]=gamma[[k]]
          }
        }
        if(useUnk|useMarkednoID){
          n=length(unique(ID[ID>n.marked]))
        }else{
          n=length(unique(ID))
        }
          
        out[idx,]<- c(lam0.mark,lam0.sight,sigma_d,sigma_p,sum(z),n,psi)
        idx=idx+1
      }
    }  # end of MCMC algorithm
    
    if(storeLatent&storeGamma){
      list(out=out, s1xout=s1xout, s1yout=s1yout,s2xout=s2xout, s2yout=s2yout, zout=zout,IDout=IDout,gammaOut=gammaOut)
    }else if(storeLatent&!storeGamma){
      list(out=out, s1xout=s1xout, s1yout=s1yout,s2xout=s2xout, s2yout=s2yout, zout=zout,IDout=IDout)
    }else if(!storeLatent&storeGamma){
      list(out=out,gammaOut=gammaOut)
    }else{ 
      list(out=out)
    }
  }

