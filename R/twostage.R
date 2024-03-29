##
##  twostage.R
##
##  Two-stage Monte Carlo tests and envelopes
##
##  $Revision: 1.18 $  $Date: 2022/04/06 07:49:20 $
##

bits.test <- function(X, ..., exponent=2, nsim=19,
                    alternative=c("two.sided", "less", "greater"),
                    leaveout=1, interpolate=FALSE,
                    savefuns=FALSE, savepatterns=FALSE,
                    verbose=TRUE) {
  twostage.test(X, ..., exponent=exponent,
                 nsim=nsim, nsimsub=nsim, reuse=FALSE, 
                 alternative=match.arg(alternative),
                 leaveout=leaveout, interpolate=interpolate,
                 savefuns=savefuns, savepatterns=savepatterns,
                 verbose=verbose,
		 testblurb="Balanced Independent Two-stage Test") 
}		    

dg.test <- function(X, ..., exponent=2, nsim=19, nsimsub=nsim-1,
                    alternative=c("two.sided", "less", "greater"),
                    reuse=TRUE, leaveout=1, interpolate=FALSE,
                    savefuns=FALSE, savepatterns=FALSE,
                    verbose=TRUE) {
  check.1.integer(nsim)
  stopifnot(nsim >= 2)
  if(!missing(nsimsub) && (nsimsub < 1 || !relatively.prime(nsim, nsimsub)))
    stop("nsim and nsimsub must be relatively prime")
  twostage.test(X, ..., exponent=exponent,
                 nsim=nsim, nsimsub=nsimsub, reuse=reuse, 
                 alternative=match.arg(alternative),
                 leaveout=leaveout, interpolate=interpolate,
                 savefuns=savefuns, savepatterns=savepatterns,
                 verbose=verbose,
		 testblurb="Dao-Genton adjusted goodness-of-fit test")
}		 
		    
twostage.test <- function(X, ..., exponent=2, nsim=19, nsimsub=nsim,
                    alternative=c("two.sided", "less", "greater"),
                    reuse=FALSE, leaveout=1, interpolate=FALSE,
                    savefuns=FALSE, savepatterns=FALSE,
                    verbose=TRUE, badXfatal=TRUE,
		    testblurb="Two-stage Monte Carlo test") {
  Xname <- short.deparse(substitute(X))
  alternative <- match.arg(alternative)
  env.here <- sys.frame(sys.nframe())
  Xismodel <- is.ppm(X) || is.kppm(X) || is.lppm(X) || is.slrm(X)
  check.1.integer(nsim)
  check.1.integer(nsimsub)
  stopifnot(nsim >= 2)
  stopifnot(nsimsub >= 2)
  ## first-stage p-value
  if(verbose) cat("Applying first-stage test to original data... ")
  tX <- envelopeTest(X, ...,
                     nsim=if(reuse) nsim else nsimsub,
                     alternative=alternative,
                     leaveout=leaveout,
                     interpolate=interpolate,
                     exponent=exponent,
                     savefuns=savefuns,
                     savepatterns=savepatterns || reuse,
                     verbose=FALSE, badXfatal=badXfatal,
                     envir.simul=env.here)
  pX <- tX$p.value
  ## check special case
  afortiori <- !interpolate && !reuse && (nsimsub < nsim) &&
               (pX == (1/(nsim+1)) || pX == 1)
  if(afortiori) {
    ## result is determined
    padj <- pX
    pY <- NULL
  } else {
    ## result is not yet determined
    if(!reuse) {
      if(verbose) cat("Repeating first-stage test... ")
      tXX <- envelopeTest(X, ...,
                          nsim=nsim, alternative=alternative,
                          leaveout=leaveout,
                          interpolate=interpolate,
                          exponent=exponent,
                          savefuns=savefuns, savepatterns=TRUE,
                          verbose=FALSE, badXfatal=badXfatal,
                          envir.simul=env.here)
      ## extract simulated patterns 
      Ylist <- attr(attr(tXX, "envelope"), "simpatterns")
    } else {
      Ylist <- attr(attr(tX, "envelope"), "simpatterns")
    }
    if(verbose) cat("Done.\n")
    ## apply same test to each simulated pattern
    if(verbose) cat(paste("Running second-stage tests on",
                          nsim, "simulated patterns... "))
    pY <- numeric(nsim)
    for(i in 1:nsim) {
      if(verbose) progressreport(i, nsim)
      Yi <- Ylist[[i]]
      ## if X is a model, fit it to Yi. Otherwise the implicit model is CSR.
      if(Xismodel) Yi <- update(X, Yi)
      tYi <- envelopeTest(Yi, ...,
                          nsim=nsimsub, alternative=alternative,
                          leaveout=leaveout,
                          interpolate=interpolate,
                          exponent=exponent, savepatterns=TRUE,
                          verbose=FALSE, badXfatal=FALSE,
                          envir.simul=env.here)
      pY[i] <- tYi$p.value
    }
    pY <- sort(pY)
    ## compute adjusted p-value
    padj <- (1 + sum(pY <= pX))/(1+nsim)
  }
  # pack up
  method <- tX$method
  method <- c(testblurb,
              paste("based on", method[1L]),
              paste("First stage:", method[2L]),
              method[-(1:2)],
              if(afortiori) {
                paren(paste("Second stage was omitted: p0 =", pX,
                            "implies p-value =", padj))
              } else if(reuse) {
                paste("Second stage: nested, ", nsimsub,
                      "simulations for each first-stage simulation")
              } else {
                paste("Second stage:", nsim, "*", nsimsub,
                      "nested simulations independent of first stage")
              }
              )
  names(pX) <- "p0"
  result <- structure(list(statistic = pX,
                           p.value = padj,
                           method = method,
                           data.name = Xname),
                      class="htest") 
  attr(result, "rinterval") <- attr(tX, "rinterval")
  attr(result, "pX") <- pX
  attr(result, "pY") <- pY
  if(savefuns || savepatterns)
    result <- hasenvelope(result, attr(tX, "envelope"))
  return(result)
}

dg.envelope <- function(X, ..., nsim=19,
                        nsimsub=nsim-1,
                        nrank=1,
                        alternative=c("two.sided", "less", "greater"),
                        leaveout=1,
                        interpolate = FALSE,
                        savefuns=FALSE, savepatterns=FALSE,
                        verbose=TRUE) {
  twostage.envelope(X, ...,
                    nsim=nsim, nsimsub=nsimsub, reuse=TRUE, nrank=nrank, 
                    alternative=match.arg(alternative),
                    leaveout=leaveout, interpolate=interpolate,
                    savefuns=savefuns, savepatterns=savepatterns,
                    verbose=verbose, testlabel="bits")
}

bits.envelope <- function(X, ..., nsim=19,
                          nrank=1,
                          alternative=c("two.sided", "less", "greater"),
                          leaveout=1,
                          interpolate = FALSE,
                          savefuns=FALSE, savepatterns=FALSE,
                          verbose=TRUE) {
  twostage.envelope(X, ...,
                    nsim=nsim, nsimsub=nsim, reuse=FALSE, nrank=nrank, 
                    alternative=match.arg(alternative),
                    leaveout=leaveout, interpolate=interpolate,
                    savefuns=savefuns, savepatterns=savepatterns,
                    verbose=verbose, testlabel="bits")
}

                          
twostage.envelope <- function(X, ..., nsim=19, nsimsub=nsim,
                              nrank=1,
                              alternative=c("two.sided", "less", "greater"),
                              reuse=FALSE, 
                              leaveout=1,
                              interpolate = FALSE,
                              savefuns=FALSE, savepatterns=FALSE,
                              verbose=TRUE, badXfatal=TRUE,
                              testlabel="twostage") {
  #  Xname <- short.deparse(substitute(X))
  alternative <- match.arg(alternative)
  env.here <- sys.frame(sys.nframe())
  Xismodel <- is.ppm(X) || is.kppm(X) || is.lppm(X) || is.slrm(X)
  check.1.integer(nsim)
  check.1.integer(nsimsub)
  stopifnot(nsim >= 2)
  stopifnot(nsimsub >= 1)
  ##############  first stage   ##################################
  if(verbose) cat("Applying first-stage test to original data... ")
  tX <- envelopeTest(X, ...,
                     alternative=alternative,
                     leaveout=leaveout,
                     interpolate = interpolate,
                     nsim=if(reuse) nsim else nsimsub,
                     nrank=nrank,
                     exponent=Inf, savepatterns=TRUE, savefuns=TRUE,
                     verbose=FALSE, badXfatal=badXfatal,
                     envir.simul=env.here)
  if(verbose) cat("Done.\n")
  envX <- attr(tX, "envelope")
  if(!reuse) {
    if(verbose) cat("Repeating first-stage test... ")
    tXX <- envelopeTest(X, ...,
                     alternative=alternative,
                     leaveout=leaveout,
                     interpolate = interpolate,
                     nsim=nsim, nrank=nrank,
                     exponent=Inf, savepatterns=TRUE, savefuns=TRUE,
                     verbose=FALSE, badXfatal=badXfatal,
                     envir.simul=env.here)
    ## extract simulated patterns 
    Ylist <- attr(attr(tXX, "envelope"), "simpatterns")
  } else {
    Ylist <- attr(attr(tX, "envelope"), "simpatterns")
  }
  if(verbose) cat("Done.\n")

  ##############  second stage   #################################
  ## apply same test to each simulated pattern
  if(verbose) cat(paste("Running tests on", nsim, "simulated patterns... "))
  pvalY <- numeric(nsim)
  for(i in 1:nsim) {
    if(verbose) progressreport(i, nsim)
    Yi <- Ylist[[i]]
    # if X is a model, fit it to Yi. Otherwise the implicit model is CSR.
    if(Xismodel) Yi <- update(X, Yi)
    tYi <- envelopeTest(Yi, ...,
                        alternative=alternative,
                        leaveout=leaveout,
                        interpolate = interpolate, save.interpolant = FALSE,
                        nsim=nsimsub, nrank=nrank,
                        exponent=Inf, savepatterns=TRUE,
                        verbose=FALSE, badXfatal=FALSE,
                        envir.simul=env.here)
    pvalY[i] <- tYi$p.value 
  }
  ## Find critical deviation
  if(!interpolate) {
    ## find critical rank 'l'
    rankY <- pvalY * (nsimsub + 1)
    twostage.rank <- orderstats(rankY, k=nrank)
    if(verbose) cat(paste0(testlabel, ".rank"), "=", twostage.rank, fill=TRUE)
    ## extract deviation values from top-level simulation
    simdev <- attr(tX, "statistics")[["sim"]]
    ## find critical deviation
    twostage.crit <- orderstats(simdev, decreasing=TRUE, k=twostage.rank)
    if(verbose) cat(paste0(testlabel, ".crit"), "=", twostage.crit, fill=TRUE)
  } else {
    ## compute estimated cdf of t
    fhat <- attr(tX, "density")[c("x", "y")]
    fhat$z <- with(fhat, cumsum(y)/sum(y))  # 'within' upsets package checker
    ## find critical (second stage) p-value
    pcrit <- orderstats(pvalY, k=nrank)
    ## compute corresponding upper quantile of estimated density of t
    twostage.crit <- with(fhat, { min(x[z >= 1 - pcrit]) })
  }
  ## make fv object, for now
  refname <- if("theo" %in% names(envX)) "theo" else "mmean"
  fname <- attr(envX, "fname")
  result <- (as.fv(envX))[, c(fvnames(envX, ".x"),
                            fvnames(envX, ".y"),
                            refname)]
  refval <- envX[[refname]]
  ## 
  newdata <- data.frame(hi=refval + twostage.crit,
                        lo=refval - twostage.crit)
  newlabl <- c(makefvlabel(NULL, NULL, fname, "hi"),
               makefvlabel(NULL, NULL, fname, "lo"))
  alpha <- nrank/(nsim+1)
  alphatext <- paste0(100*alpha, "%%")
  newdesc <- c(paste("upper", alphatext, "critical boundary for %s"),
               paste("lower", alphatext, "critical boundary for %s"))
  switch(alternative,
         two.sided = { },
         less = {
           newdata$hi <- Inf
           newlabl[1L] <- "infinity"
           newdesc[1L] <- "infinite upper limit"
         },
         greater = {
           newdata$lo <- -Inf
           newlabl[2L] <- "infinity"
           newdesc[2L] <- "infinite lower limit"
         })
  result <- bind.fv(result, newdata, newlabl, newdesc)
  fvnames(result, ".") <- rev(fvnames(result, "."))
  fvnames(result, ".s") <- c("lo", "hi")
  if(savefuns || savepatterns)
    result <- hasenvelope(result, envX)
  return(result)
}

