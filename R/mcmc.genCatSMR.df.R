#' Fit the generalized categorical spatial mark resight model with detection function parameters that vary
#' by the category levels of one categorical identity covariate, e.g. sex
#' @param data a data list as formatted by sim.genCatSMR(). See description for more details.
#' @param niter the number of MCMC iterations to perform
#' @param nburn the number of MCMC iterations to discard as burnin
#' @param nthin the MCMC thinning interval. Keep every nthin iterations.
#' @param M the level of data augmentation
#' @param inits a list of initial values for lam0.mark,lam0.sight, sigma, gamma, and psi. The list element for 
#' gamma is itself a list with ncat elements. List elements for lam0.mark, lam0.sight, and sigma are
#' themselves a list, housing starting vectors the same length as the first list element in IDcovs. 
#' See the example below.
#' @param obstype a vector of length two indicating the observation model, "bernoulli" or "poisson", for the 
#' marking and sighting process
#' @param nswap an integer indicating how many samples for which the latent identities
#' are updated on each iteration.
#' @param propars a list of proposal distribution tuning parameters for lam0.mark, lam0.sight, sigma, s, and st, for the
#' the activity centers of untelemetered and telemetered individuals, respectively. The tuning parameter
#' should be smaller for individuals with telemetry and increasingly so as the number of locations per
#' individual increases. List elements for lam0.mark, lam0.sight, and sigma are
#' themselves a list, housing vectors of tuning parameters the same length as the first list element in IDcovs.
#' @param storeLatent a logical indicator for whether or not the posteriors of the latent individual identities, z, and s are
#' stored and returned
#' @param storeGamma a logical indicator for whether or not the posteriors for gamma are stored and returned
#' @param IDup a character string indicating whether the latent identity update is done by Gibbs or Metropolis-
#' Hastings, "Gibbs", or "MH". For obstype="bernoulli", only "MH" is available because the full conditional is not known.
#' @param tf1 a trap operation vector or matrix for the marking process. If exposure to capture does
#' not vary by indiviudal, tf1 should be a vector of length J1 indicating how many of the K1 occasions
#' each marking location was operational. If exposure to capture varies by individual or by trap and
#' individual, tf1 should be a matrix of dimension M x J1 indicating how many of the K1 occasions individual
#' i was exposed to at trap j. This allows known additions or removals during the marking process
#'  to be accounted for. Exposure for the n.marked+1 ... M uncaptured individuals should be the
#'  same as the number of occasions each trap was operational. We can't account for unknown
#'  additions and removals.
#' @param tf2 a trap operation vector or matrix for the sighting process. If exposure to capture does
#' not vary by indiviudal, tf1 should be a vector of length J2 indicating how many of the K2 occasions
#' each sighting location was operational. If exposure to capture varies by individual or by trap and
#' individual, tf2 should be a matrix of dimension M x J2 indicating how many of the K2 occasions individual
#' i was exposed to at trap j. This allows known additions or removals between the marking and
#' sighting processes and during the sighting process to be accounted for. Exposure for 
#' the n.marked+1 ... M uncaptured individuals should be the
#'  same as the number of occasions each trap was operational. We can't account for unknown
#'  additions and removals.
#' @description This function fits the generalized categorical spatial mark resight model with detection function parameters that vary
#' by the category levels of one categorical identity covariate, e.g. sex.
#' Modelling the marking process relaxes the assumption that the distribution of marked 
#' individuals across the landscape is spatially uniform. Category level-specific detection function
#' parameters reduces individual heterogeneity and improves the probabilistic association of latent
#' and partial identity samples. This is an expanded version of the sampler located in mcmc.genCatSMR.df().
#'  A version of that sampler
#' that allows individual activity centers to move between marking and sighting processes
#' is in mcmc.conCatSMR.move(). Email Ben if you need both of these features simultaneously.
#' 
#' the data list should be formatted to match the list outputted by sim.genCatSMR.df(), but not all elements
#' of that object are necessary. y.mark, y.sight.marked, y.sight.unmarked, G.marked, and G.unmarked are necessary
#' list elements. y.sight.x and G.x for x=unk and marke.noID are necessary if there are samples
#' of unknown marked status or samples from marked samples without individual identities.
#' 
#' An element "X1", a matrix of marking coordinates, an element "X2", a matrix of sighting coordinates, ,
#' an element "K1", the integer number of marking occasions, and an element "K2", the integer number of sighting occasions
#'  are necessary.
#' 
#' IDlist is a list containing elements ncat and IDcovs. ncat is an integer for the number
#' of categorical identity covariates and IDcovs is a list of length ncat with elements containing the
#' values each categorical identity covariate may take.
#' 
#' An element "locs", an n.marked x nloc x  2 array of telemetry locations is optional. This array can
#' have missing values if not all individuals have the same number of locations and the entry for individuals
#' with no telemetry should all be missing values (coded NA).
#'
#' An element "markedS" is required if marking and sighting sessions are interspersed. This is a
#' n_marked x K2 matrix with 0 indicating an individual was not marked on occasion k and 1 if it
#' was.
#'   
#' I will write a function to build the data object with "secr-like" input in the near future.
#' 
#' @author Ben Augustine
#' @examples
#' \dontrun{
#' #Using categorical identity covariates
#' N=100
#' lam0.mark=c(0.075,0.01)
#' lam0.sight=c(0.3,0.2)
#' sigma=c(0.6,0.5)
#' K1=10 #number of marking occasions
#' K2=10 #number of sighting occasions
#' buff=2 #state space buffer
#' X1<- expand.grid(3:11,3:11) #marking locations
#' X2<- expand.grid(3:11+0.5,3:11+0.5) #sighting locations
#' pMarkID=c(0.8,0.8) #probability of observing marked status of marked and unmarked individuals
#' pID=0.8 #probability of determining identity of marked individuals
#' obstype=c("bernoulli","poisson") #observation model of both processes
#' ncat=3  #number of categorical identity covariates
#' gamma=IDcovs=vector("list",ncat) 
#' nlevels=rep(2,ncat) #number of IDcovs per loci
#' for(i in 1:ncat){ 
#'   gamma[[i]]=rep(1/nlevels[i],nlevels[i])
#'   IDcovs[[i]]=1:nlevels[i]
#' }
#' #inspect ID covariates and level probabilities
#' str(IDcovs) #3 covariates with 2 levels
#' str(gamma) #each of the two levels are equally probable
#' pIDcat=rep(1,ncat) #category observation probabilities
#' #Example of interspersed marking and sighting. 
#' Korder=c("M","M","S","S","S","S","M","M","S","M","M","S","M","M","S","S","S","S","M","M")
#' #Example with no interspersed marking and sighting.
#' Korder=c(rep("M",10),rep("S",10))
#' tlocs=5
#' data=sim.genCatSMR.df(N=N,lam0.mark=lam0.mark,lam0.sight=lam0.sight,sigma=sigma,K1=K1,
#'                       K2=K2,Korder=Korder,X1=X1,X2=X2,buff=buff,obstype=obstype,ncat=ncat,
#'                       pIDcat=pIDcat,IDcovs=IDcovs,gamma=gamma,pMarkID=pMarkID,pID=pID,tlocs=tlocs)
#' 
#' 
#' inits=list(lam0.mark=lam0.mark,lam0.sight=lam0.sight,sigma=sigma,gamma=gamma,psi=0.7)
#' proppars=list(lam0.mark=c(0.05,0.025),lam0.sight=c(0.09,0.09),sigma=c(0.04,0.045),s=0.45,st=0.45)
#' M=150
#' storeLatent=TRUE
#' storeGamma=FALSE
#' niter=500
#' nburn=0
#' nthin=1
#' IDup="Gibbs"
#' out=mcmc.genCatSMR.df(data,niter=niter,nburn=nburn, nthin=nthin, M = M, inits=inits,obstype=obstype,
#'                       proppars=proppars,storeLatent=TRUE,storeGamma=TRUE,IDup=IDup)
#' 
#' plot(mcmc(out$out))
#' 1-rejectionRate(mcmc(out$out))#shoot for between 0.2 and 0.4 for df parameters
#' 1-rejectionRate(mcmc(out$sxout))#make sure none are <0.1?
#' length(unique(data$IDum)) #true number of unmarked individuals captured
#'
#' #####regular generalized SMR with no identity covariates
#' N=100
#' lam0.mark=c(0.075,0.01)
#' lam0.sight=c(0.3,0.2)
#' sigma=c(0.6,0.5)
#' K1=10 #number of marking occasions
#' K2=10 #number of sighting occasions
#' buff=2 #state space buffer
#' X1<- expand.grid(3:11,3:11) #marking locations
#' X2<- expand.grid(3:11+0.5,3:11+0.5) #sighting locations
#' pMarkID=c(0.8,0.8) #probability of observing marked status of marked and unmarked individuals
#' pID=0.8 #probability of determining identity of marked individuals
#' obstype=c("bernoulli","poisson") #observation model of both processes
#' ncat=1  #just 1 covariate
#' gamma=IDcovs=vector("list",ncat) 
#' nlevels=rep(1,ncat) #just 1 value. We have simplified to regular generalized SMR.
#' for(i in 1:ncat){ 
#'   gamma[[i]]=rep(1/nlevels[i],nlevels[i])
#'   IDcovs[[i]]=1:nlevels[i]
#' }
#' pIDcat=rep(1,ncat) #category observation probabilities
#' #Example of interspersed marking and sighting. 
#' Korder=c("M","M","S","S","S","S","M","M","S","M","M","S","M","M","S","S","S","S","M","M")
#' #Example with no interspersed marking and sighting.
#' Korder=c(rep("M",10),rep("S",10))
#' tlocs=5
#' data=sim.genCatSMR.df(N=N,lam0.mark=lam0.mark,lam0.sight=lam0.sight,sigma=sigma,K1=K1,
#'                       K2=K2,Korder=Korder,X1=X1,X2=X2,buff=buff,obstype=obstype,ncat=ncat,
#'                       pIDcat=pIDcat,IDcovs=IDcovs,gamma=gamma,pMarkID=pMarkID,pID=pID,tlocs=tlocs)
#' 
#' 
#' inits=list(lam0.mark=lam0.mark,lam0.sight=lam0.sight,sigma=sigma,gamma=gamma,psi=0.7)
#' proppars=list(lam0.mark=c(0.05,0.025),lam0.sight=c(0.09,0.09),sigma=c(0.04,0.045),s=0.45,st=0.45)
#' M=150
#' storeLatent=TRUE
#' storeGamma=FALSE
#' niter=500
#' nburn=0
#' nthin=1
#' IDup="Gibbs"
#' out=mcmc.genCatSMR.df(data,niter=niter,nburn=nburn, nthin=nthin, M = M, inits=inits,obstype=obstype,
#'                       proppars=proppars,storeLatent=TRUE,storeGamma=TRUE,IDup=IDup)
#' plot(mcmc(out$out))
#' }
#' @export

mcmc.genCatSMR.df <-
  function(data,niter=2400,nburn=1200, nthin=5, M = 200, inits=NA,obstype=c("bernoulli","poisson"),nswap=NA,
           proppars=list(lam0=0.05,sigma=0.1,sx=0.2,sy=0.2),
           storeLatent=TRUE,storeGamma=TRUE,IDup="Gibbs",tf1=NA,tf2=NA){
    if(any(data$markedS==0)){#capture order constraints
      mcmc.genCatSMR.dfb(data,niter=niter,nburn=nburn,nthin=nthin,M=M,inits=inits,
                      obstype=obstype,nswap=nswap,proppars=proppars,
                      storeLatent=storeLatent,storeGamma=storeGamma,IDup=IDup,tf1=tf1,tf2=tf2)
    }else{#no capture order constraints
      mcmc.genCatSMR.dfa(data,niter=niter,nburn=nburn,nthin=nthin,M=M,inits=inits,
                      obstype=obstype,nswap=nswap,proppars=proppars,
                      storeLatent=storeLatent,storeGamma=storeGamma,IDup=IDup,tf1=tf1,tf2=tf2)
    }
  }

