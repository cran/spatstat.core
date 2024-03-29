#'
#'   Header for all (concatenated) test files
#'
#'   Require spatstat.core
#'   Obtain environment variable controlling tests.
#'
#'   $Revision: 1.5 $ $Date: 2020/04/30 05:31:37 $

require(spatstat.core)
FULLTEST <- (nchar(Sys.getenv("SPATSTAT_TEST", unset="")) > 0)
ALWAYS   <- TRUE
cat(paste("--------- Executing",
          if(FULLTEST) "** ALL **" else "**RESTRICTED** subset of",
          "test code -----------\n"))
#'
#'    tests/deltasuffstat.R
#' 
#'    Explicit tests of 'deltasuffstat'
#' 
#' $Revision: 1.4 $ $Date: 2021/01/22 08:08:48 $

if(!FULLTEST)
  spatstat.options(npixel=32, ndummy.min=16)

if(ALWAYS) {  # depends on C code
local({
  
  disagree <- function(x, y, tol=1e-7) { !is.null(x) && !is.null(y) && max(abs(x-y)) > tol }

  flydelta <- function(model, modelname="") {
    ## Check execution of different algorithms for 'deltasuffstat' 
    dSS <- deltasuffstat(model, sparseOK=TRUE)
    dBS <- deltasuffstat(model, sparseOK=TRUE,  use.special=FALSE, force=TRUE)
    dBF <- deltasuffstat(model, sparseOK=FALSE, use.special=FALSE, force=TRUE)
    ## Compare results
    if(disagree(dBS, dSS))
      stop(paste(modelname, "model: Brute force algorithm disagrees with special algorithm"))
    if(disagree(dBF, dBS))
      stop(paste(modelname, "model: Sparse and full versions of brute force algorithm disagree"))
    return(invisible(NULL))
  }

  modelS <- ppm(cells ~ x, Strauss(0.13), nd=10)
  flydelta(modelS, "Strauss")

  antsub <- ants[c(FALSE,TRUE,FALSE)]
  rmat <- matrix(c(130, 90, 90, 60), 2, 2)
  
  modelM <- ppm(antsub ~ 1, MultiStrauss(rmat), nd=16)
  flydelta(modelM, "MultiStrauss")
                
  modelA <- ppm(antsub ~ 1, HierStrauss(rmat, archy=c(2,1)), nd=16)
  flydelta(modelA, "HierStrauss")
})

}

reset.spatstat.options()
#'
#'  tests/density.R
#'
#'  Test behaviour of density() methods,
#'                    relrisk(), Smooth()
#'                    and inhomogeneous summary functions
#'                    and idw, adaptive.density, intensity
#'
#'  $Revision: 1.61 $  $Date: 2022/04/17 00:54:34 $
#'

if(!FULLTEST)
  spatstat.options(npixel=32, ndummy.min=16)

local({

  # test all cases of density.ppp and densityfun.ppp
  
  tryit <- function(..., do.fun=TRUE, badones=FALSE) {
    Z <- density(cells, ..., at="pixels")
    Z <- density(cells, ..., at="points")
    if(do.fun) {
      f <- densityfun(cells, ...)
      U <- f(0.1, 0.3)
      if(badones) {
        U2 <- f(1.1, 0.3)
        U3 <- f(1.1, 0.3, drop=FALSE)
      }
    }
    return(invisible(NULL))
  }

  if(ALWAYS) {
    tryit(0.05)
    tryit(0.05, diggle=TRUE)
    tryit(0.05, se=TRUE)
    tryit(0.05, weights=expression(x))
    tryit(0.07, kernel="epa")
    tryit(sigma=Inf)
    tryit(0.05, badones=TRUE)
  }
  if(FULLTEST) {
    tryit(0.07, kernel="quartic")
    tryit(0.07, kernel="disc")
    tryit(0.07, kernel="epa", weights=expression(x))
    tryit(sigma=Inf, weights=expression(x))
  }
  
  V <- diag(c(0.05^2, 0.07^2))

  if(ALWAYS) {
    tryit(varcov=V)
  }
  if(FULLTEST) {
    tryit(varcov=V, diggle=TRUE)
    tryit(varcov=V, weights=expression(x))
    tryit(varcov=V, weights=expression(x), diggle=TRUE)
    Z <- distmap(runifpoint(5, Window(cells)))
    tryit(0.05, weights=Z)
    tryit(0.05, weights=Z, diggle=TRUE)
  }

  trymost <- function(...) tryit(..., do.fun=FALSE) 
  wdf <- data.frame(a=1:42,b=42:1)
  if(ALWAYS) {
    trymost(0.05, weights=wdf)
    trymost(sigma=Inf, weights=wdf)
  }
  if(FULLTEST) {
    trymost(0.05, weights=wdf, diggle=TRUE)
    trymost(varcov=V, weights=wdf)
    trymost(varcov=V, weights=expression(cbind(x,y)))
  }

  ## check conservation of mass
  checkconserve <- function(X, xname, sigma, toler=0.01) {
    veritas <- npoints(X)
    vino <- integral(density(X, sigma, diggle=TRUE))
    relerr <- abs(vino - veritas)/veritas
    if(relerr > toler)
      stop(paste("density.ppp(diggle=TRUE) fails to conserve mass:",
                 vino, "!=", veritas,
                 "for", sQuote(xname)),
           call.=FALSE)
    return(relerr)
  }
  if(FULLTEST) {
    checkconserve(cells, "cells", 0.15)
  }
  if(ALWAYS) {
    checkconserve(split(chorley)[["lung"]], "lung", 2)
  }
  
  ## run C algorithm 'denspt'
  opa <- spatstat.options(densityC=TRUE, densityTransform=FALSE)
  if(ALWAYS) {
    tryit(varcov=V)
  }
  if(FULLTEST) {
    tryit(varcov=V, weights=expression(x))
    trymost(varcov=V, weights=wdf)
  }
  spatstat.options(opa)

  crossit <- function(..., sigma=NULL) {
    U <- runifpoint(20, Window(cells))
    a <- densitycrossEngine(cells, U, ..., sigma=sigma)
    a <- densitycrossEngine(cells, U, ..., sigma=sigma, diggle=TRUE)
    invisible(NULL)
  }
  if(ALWAYS) {
    crossit(varcov=V, weights=cells$x)
    crossit(sigma=Inf)
  }
  if(FULLTEST) {
    crossit(varcov=V, weights=wdf)
    crossit(sigma=0.1, weights=wdf)
    crossit(sigma=0.1, kernel="epa", weights=wdf)
  }
  
  ## apply different discretisation rules
  if(ALWAYS) {
    Z <- density(cells, 0.05, fractional=TRUE)
  }
  if(FULLTEST) {
    Z <- density(cells, 0.05, preserve=TRUE)
    Z <- density(cells, 0.05, fractional=TRUE, preserve=TRUE)
  }
        
  ## compare results with different algorithms
  crosscheque <- function(expr) {
    e <- as.expression(substitute(expr))
    ename <- sQuote(deparse(substitute(expr)))
    ## interpreted R
    opa <- spatstat.options(densityC=FALSE, densityTransform=FALSE)
    val.interpreted <- eval(e)
    ## established C algorithm 'denspt'
    spatstat.options(densityC=TRUE, densityTransform=FALSE)
    val.C <- eval(e)
    ## new C algorithm 'Gdenspt' using transformed coordinates
    spatstat.options(densityC=TRUE, densityTransform=TRUE)
    val.Transform <- eval(e)
    spatstat.options(opa)
    if(max(abs(val.interpreted - val.C)) > 0.001)
      stop(paste("Numerical discrepancy between R and C algorithms in",
                 ename))
    if(max(abs(val.C - val.Transform)) > 0.001)
      stop(paste("Numerical discrepancy between C algorithms",
                 "using transformed and untransformed coordinates in",
                 ename))
    invisible(NULL)
  }

  ## execute & compare results of density(at="points") with different algorithms
  wdfr <- cbind(1:npoints(redwood), 2)
  if(ALWAYS) {
    crosscheque(density(redwood, at="points", sigma=0.13, edge=FALSE))
    crosscheque(density(redwood, at="points", sigma=0.13, edge=FALSE,
                        weights=wdfr[,1]))
    crosscheque(density(redwood, at="points", sigma=0.13, edge=FALSE,
                        weights=wdfr))
  }

  ## correctness of non-Gaussian kernel calculation
  leavein <- function(ker, maxd=0.025) {
    ZI <- density(redwood, 0.12, kernel=ker, edge=FALSE,
                  dimyx=256)[redwood]
    ZP <- density(redwood, 0.12, kernel=ker, edge=FALSE,
                  at="points", leaveoneout=FALSE)
    discrep <- max(abs(ZP - ZI))/npoints(redwood)
    if(discrep > maxd) 
      stop(paste("Discrepancy",
                 signif(discrep, 3),
                 "in calculation for", ker, "kernel"))
    return(invisible(NULL))
  }
  if(ALWAYS) {
    leavein("epanechnikov", 0.015)
  }
  if(FULLTEST) {
    leavein("quartic",      0.010)
    leavein("disc",         0.100)
  }

  ## bandwidth selection code blocks
  sigvec <- 0.01 * 2:15
  sigran <- range(sigvec)
  if(ALWAYS) {
    bw.ppl(redwood, sigma=sigvec)
    bw.CvL(redwood, sigma=sigvec)
  }
  if(FULLTEST) {
    bw.ppl(redwood, srange=sigran, ns=5)
    bw.CvL(redwood, srange=sigran, ns=5)
  }
  ## adaptive bandwidth
  if(ALWAYS) {
    a <- bw.abram(redwood)
  }
  if(FULLTEST) {
    a <- bw.abram(redwood, pilot=density(redwood, 0.2))
    a <- bw.abram(redwood, smoother="densityVoronoi", at="pixels")
  }
  
  ## Kinhom
  if(ALWAYS) {
    lam <- density(redwood)
    K <- Kinhom(redwood, lam)
  
    lamX <- density(redwood, at="points")
    KX <- Kinhom(redwood, lamX)
  }

  ## test all code cases of new 'relrisk.ppp' algorithm
  pants <- function(..., X=ants, sigma=100, se=TRUE) {
    a <- relrisk(X, sigma=sigma, se=se, ...)
    return(TRUE)
  }
  if(ALWAYS) {
    pants()
    pants(diggle=TRUE)
    pants(edge=FALSE)
    pants(at="points")
    pants(casecontrol=FALSE)
    pants(relative=TRUE)
    pants(sigma=Inf)
    pants(sigma=NULL, varcov=diag(c(100,100)^2))
  }
  if(FULLTEST) {
    pants(diggle=TRUE, at="points")
    pants(edge=FALSE, at="points")
    pants(casecontrol=FALSE, relative=TRUE)
    pants(casecontrol=FALSE,at="points")
    pants(relative=TRUE,at="points")
    pants(casecontrol=FALSE, relative=TRUE,at="points")
    pants(relative=TRUE, control="Cataglyphis", case="Messor")
    pants(relative=TRUE, control="Cataglyphis", case="Messor", at="points")
    pants(casecontrol=FALSE, case="Messor", se=FALSE)
    pants(case=2, at="pixels", relative=TRUE)
    pants(case=2, at="points", relative=TRUE)
    pants(case=2, at="pixels", relative=FALSE)
    pants(case=2, at="points", relative=FALSE)
  }
  if(ALWAYS) {
    ## underflow example from stackoverflow!
    funky <- scanpp("funky.tab", owin(c(4, 38), c(0.3, 17)))
    P <- relrisk(funky, 0.5)
    R <- relrisk(funky, 0.5, relative=TRUE)
  }
  ## more than 2 types
  if(ALWAYS) {
    pants(X=sporophores)
    pants(X=sporophores, sigma=20, at="points")
    bw.relrisk(sporophores, method="leastsquares")
  }
  if(FULLTEST) {
    pants(X=sporophores, sigma=20, relative=TRUE, at="points")
    pants(X=sporophores, sigma=20, at="pixels", se=FALSE)
    pants(X=sporophores, sigma=20, relative=TRUE, at="pixels", se=FALSE)
    bw.relrisk(sporophores, method="weightedleastsquares")
  }
  
  ## likewise 'relrisk.ppm'
  fit <- ppm(ants ~ x)
  rants <- function(..., model=fit) {
    a <- relrisk(model, sigma=100, se=TRUE, ...)
    return(TRUE)
  }
  if(ALWAYS) {
    rants()
    rants(diggle=TRUE)
    rants(edge=FALSE)
    rants(at="points")
    rants(casecontrol=FALSE)
    rants(relative=TRUE)
  }
  if(FULLTEST) {
    rants(diggle=TRUE, at="points")
    rants(edge=FALSE, at="points")
    rants(casecontrol=FALSE, relative=TRUE)
    rants(casecontrol=FALSE,at="points")
    rants(relative=TRUE,at="points")
    rants(casecontrol=FALSE, relative=TRUE,at="points")
    rants(relative=TRUE, control="Cataglyphis", case="Messor")
    rants(relative=TRUE, control="Cataglyphis", case="Messor", at="points")
  }
  ## more than 2 types
  fut <- ppm(sporophores ~ x)
  if(ALWAYS) {
    rants(model=fut)
  }
  if(FULLTEST) {
    rants(model=fut, at="points")
    rants(model=fut, relative=TRUE, at="points")
  }
  
  ## execute Smooth.ppp and Smoothfun.ppp in all cases
  stroke <- function(..., Y = longleaf, FUN=TRUE) {
    Z <- Smooth(Y, ..., at="pixels")
    Z <- Smooth(Y, ..., at="points", leaveoneout=TRUE)
    Z <- Smooth(Y, ..., at="points", leaveoneout=FALSE)
    if(FUN) {
      f <- Smoothfun(Y, ...)
      f(120, 80)
      f(Y[1:2])
      f(Y[FALSE])
      U <- as.im(f)
    }
    return(invisible(NULL))
  }
  if(ALWAYS) {
    stroke()
    stroke(5, diggle=TRUE)
    stroke(5, geometric=TRUE)
    stroke(1e-6) # generates warning about small bandwidth
    stroke(5, weights=expression(x))
    stroke(5, kernel="epa")
    stroke(sigma=Inf)
  }
  if(FULLTEST) {
    Z <- as.im(function(x,y){abs(x)+1}, Window(longleaf))
    stroke(5, weights=Z)
    stroke(5, weights=runif(npoints(longleaf)))
    stroke(varcov=diag(c(25, 36)))
    stroke(varcov=diag(c(25, 36)), weights=runif(npoints(longleaf)))
    stroke(5, Y=longleaf %mark% 1)
    stroke(5, Y=cut(longleaf,breaks=3))
    stroke(5, weights=Z, geometric=TRUE)
    g <- function(x,y) { dnorm(x, sd=10) * dnorm(y, sd=10) }
    stroke(kernel=g, cutoff=30, FUN=FALSE)
    stroke(kernel=g, cutoff=30, scalekernel=TRUE, sigma=1, FUN=FALSE)
  }
  
  markmean(longleaf, 9)
  
  strike <- function(..., Y=finpines) {
    Z <- Smooth(Y, ..., at="pixels")
    Z <- Smooth(Y, ..., at="points", leaveoneout=TRUE)
    Z <- Smooth(Y, ..., at="points", leaveoneout=FALSE)
    f <- Smoothfun(Y, ...)
    f(4, 1)
    f(Y[1:2])
    f(Y[FALSE])
    U <- as.im(f)
    return(invisible(NULL))
  }
  if(ALWAYS) {
    strike()
    strike(sigma=1.5, kernel="epa")
    strike(varcov=diag(c(1.2, 2.1)))
    strike(sigma=1e-6)
    strike(sigma=Inf)
  }
  if(FULLTEST) {
    strike(sigma=1e-6, kernel="epa")
    strike(1.5, weights=runif(npoints(finpines)))
    strike(1.5, weights=expression(y))
    strike(1.5, geometric=TRUE)
    strike(1.5, Y=finpines[FALSE])
    flatfin <- finpines %mark% data.frame(a=rep(1, npoints(finpines)), b=2)
    strike(1.5, Y=flatfin)
    strike(1.5, Y=flatfin, geometric=TRUE)
  }
  opx <- spatstat.options(densityTransform=FALSE)
  if(ALWAYS) {
    stroke(5, Y=longleaf[order(longleaf$x)], sorted=TRUE)
  }
  if(FULLTEST) {
    strike(1.5, Y=finpines[order(finpines$x)], sorted=TRUE)
  }
  spatstat.options(opx)

  ## detect special cases
  if(ALWAYS) {
    Smooth(longleaf[FALSE])
    Smooth(longleaf, minnndist(longleaf))
    Xconst <- cells %mark% 1
    Smooth(Xconst, 0.1)
    Smooth(Xconst, 0.1, at="points")
    Smooth(cells %mark% runif(42), sigma=Inf)
    Smooth(cells %mark% runif(42), sigma=Inf, at="points")
    Smooth(cells %mark% runif(42), sigma=Inf, at="points", leaveoneout=FALSE)
    Smooth(cut(longleaf, breaks=4))
  }
  
  ## code not otherwise reached
  if(ALWAYS) {
    smoothpointsEngine(cells, values=rep(1, npoints(cells)), sigma=0.2)
  }
  if(FULLTEST) {
    smoothpointsEngine(cells, values=runif(npoints(cells)), sigma=Inf)
    smoothpointsEngine(cells, values=runif(npoints(cells)), sigma=1e-16)
  }
  
  ## validity of Smooth.ppp(at='points')
  Y <- longleaf %mark% runif(npoints(longleaf), min=41, max=43)
  Z <- Smooth(Y, 5, at="points", leaveoneout=TRUE)
  rZ <- range(Z)
  if(rZ[1] < 40 || rZ[2] > 44)
    stop("Implausible results from Smooth.ppp(at=points, leaveoneout=TRUE)")

  Z <- Smooth(Y, 5, at="points", leaveoneout=FALSE)
  rZ <- range(Z)
  if(rZ[1] < 40 || rZ[2] > 44)
    stop("Implausible results from Smooth.ppp(at=points, leaveoneout=FALSE)")

  ## compare Smooth.ppp results with different algorithms
  if(ALWAYS) {
    crosscheque(Smooth(longleaf, at="points", sigma=6))
    wt <- runif(npoints(longleaf))
    crosscheque(Smooth(longleaf, at="points", sigma=6, weights=wt))
  }
  if(FULLTEST) {
    vc <- diag(c(25,36))
    crosscheque(Smooth(longleaf, at="points", varcov=vc))
    crosscheque(Smooth(longleaf, at="points", varcov=vc, weights=wt))
  }
  ## drop-dimension coding errors
  if(FULLTEST) {
    X <- longleaf
    marks(X) <- cbind(marks(X), 1)
    Z <- Smooth(X, 5)

    ZZ <- bw.smoothppp(finpines, hmin=0.01, hmax=0.012, nh=2) # reshaping problem
  }

  ## geometric-mean smoothing
  if(ALWAYS) {
    U <- Smooth(longleaf, 5, geometric=TRUE)
  }
  if(FULLTEST) {
    UU <- Smooth(X, 5, geometric=TRUE)
    V <- Smooth(longleaf, 5, geometric=TRUE, at="points")
    VV <- Smooth(X, 5, geometric=TRUE, at="points")
  }
})

reset.spatstat.options()

local({
  if(ALWAYS) {
    #' Kmeasure, second.moment.engine
    #' Expansion of window
    Zno  <- Kmeasure(redwood, sigma=0.2, expand=FALSE)
    Zyes <- Kmeasure(redwood, sigma=0.2, expand=TRUE)
    #' All code blocks
    sigmadouble <- rep(0.1, 2)
    diagmat <- diag(sigmadouble^2)
    generalmat <- matrix(c(1, 0.5, 0.5, 1)/100, 2, 2)
    Z <- Kmeasure(redwood, sigma=sigmadouble)
    Z <- Kmeasure(redwood, varcov=diagmat)
    Z <- Kmeasure(redwood, varcov=generalmat)
    A <- second.moment.calc(redwood, 0.1, what="all", debug=TRUE)
    B <- second.moment.calc(redwood, varcov=diagmat,    what="all")
    B <- second.moment.calc(redwood, varcov=diagmat,    what="all")
    D <- second.moment.calc(redwood, varcov=generalmat, what="all")
    PR <- pixellate(redwood)
    DRno  <- second.moment.calc(PR, 0.2, debug=TRUE, expand=FALSE,
                                npts=npoints(redwood), obswin=Window(redwood))
    DRyes <- second.moment.calc(PR, 0.2, debug=TRUE, expand=TRUE,
                                npts=npoints(redwood), obswin=Window(redwood))
    DR2 <- second.moment.calc(solist(PR, PR), 0.2, debug=TRUE, expand=TRUE,
                              npts=npoints(redwood), obswin=Window(redwood))
    Gmat <- generalmat * 100
    isoGauss <- function(x,y) {dnorm(x) * dnorm(y)}
    ee <- evaluate2Dkernel(isoGauss, runif(10), runif(10),
                           varcov=Gmat, scalekernel=TRUE)
    isoGaussIm <- as.im(isoGauss, square(c(-3,3)))
    gg <- evaluate2Dkernel(isoGaussIm, runif(10), runif(10),
                           varcov=Gmat, scalekernel=TRUE)
    ## experimental code
    op <- spatstat.options(developer=TRUE)
    DR <- density(redwood, 0.1)
    spatstat.options(op)
  }
})

local({
  if(FULLTEST) {
    #' bandwidth selection
    op <- spatstat.options(n.bandwidth=8)
    bw.diggle(cells) 
    bw.diggle(cells, method="interpreted") # undocumented test
    ##  bw.relrisk(urkiola, hmax=20) is tested in man/bw.relrisk.Rd
    bw.relrisk(urkiola, hmax=20, method="leastsquares")
    bw.relrisk(urkiola, hmax=20, method="weightedleastsquares")
    ZX <- density(swedishpines, at="points")
    bw.pcf(swedishpines, lambda=ZX)
    bw.pcf(swedishpines, lambda=ZX,
           bias.correct=FALSE, simple=FALSE, cv.method="leastSQ")
    spatstat.options(op)
  }
})

local({
  if(FULLTEST) {
    #' code in kernels.R
    kernames <- c("gaussian", "rectangular", "triangular",
                  "epanechnikov", "biweight", "cosine", "optcosine")
    X <- rnorm(20)
    U <- runif(20)
    for(ker in kernames) {
      dX <- dkernel(X, ker)
      fX <- pkernel(X, ker)
      qU <- qkernel(U, ker)
      m0 <- kernel.moment(0, 0, ker)
      m1 <- kernel.moment(1, 0, ker)
      m2 <- kernel.moment(2, 0, ker)
      m3 <- kernel.moment(3, 0, ker)
    }
  }
})

local({
  if(FULLTEST) {
    ## idw
    Z <- idw(longleaf, power=4)
    Z <- idw(longleaf, power=4, se=TRUE)
    ZX <- idw(longleaf, power=4, at="points")
    ZX <- idw(longleaf, power=4, at="points", se=TRUE)
  }
  if(ALWAYS) {
    ## former bug in densityVoronoi.ppp 
    X <- redwood[1:2]
    A <- densityVoronoi(X, f=0.51, counting=FALSE, fixed=FALSE, nrep=50, verbose=FALSE)
    ## dodgy code blocks in densityVoronoi.R
    A <- adaptive.density(nztrees, nrep=2, f=0.5, counting=TRUE)
    B <- adaptive.density(nztrees, nrep=2, f=0.5, counting=TRUE, fixed=TRUE)
    D <- adaptive.density(nztrees, nrep=2, f=0.5, counting=FALSE)
    E <- adaptive.density(nztrees, nrep=2, f=0.5, counting=FALSE, fixed=TRUE)
  }
  if(FULLTEST) {
    #' adaptive kernel estimation
    d10 <- nndist(nztrees, k=10)
    d10fun <- distfun(nztrees, k=10)
    d10im  <- as.im(d10fun)
    uN <- 2 * runif(npoints(nztrees))
    AA <- densityAdaptiveKernel(nztrees, bw=d10)
    BB <- densityAdaptiveKernel(nztrees, bw=d10, weights=uN)
    DD <- densityAdaptiveKernel(nztrees, bw=d10fun, weights=uN)
    EE <- densityAdaptiveKernel(nztrees, bw=d10im, weights=uN)
  }
})

local({
  if(ALWAYS) {
    ## unnormdensity
    x <- rnorm(20) 
    d0 <- unnormdensity(x, weights=rep(0, 20))
    dneg <- unnormdensity(x, weights=c(-runif(19), 0))
  }
  if(FULLTEST) {
    ## cases of 'intensity' etc
    a <- intensity(amacrine, weights=expression(x))
    SA <- split(amacrine)
    a <- intensity(SA, weights=expression(x))
    a <- intensity(SA, weights=amacrine$x)
    a <- intensity(ppm(amacrine ~ 1))

    ## check infrastructure for 'densityfun'
    f <- densityfun(cells, 0.05)
    Z <- as.im(f)
    Z <- as.im(f, W=square(0.5))
  }
})

reset.spatstat.options()

#'
#'      tests/diagnostique.R
#'
#'  Diagnostic tools such as diagnose.ppm, qqplot.ppm
#'
#'  $Revision: 1.6 $  $Date: 2020/04/28 12:58:26 $
#'

if(FULLTEST) {
local({
  fit <- ppm(cells ~ x)
  diagE <- diagnose.ppm(fit, type="eem")
  diagI <- diagnose.ppm(fit, type="inverse")
  diagP <- diagnose.ppm(fit, type="Pearson")
  plot(diagE, which="all")
  plot(diagI, which="smooth")
  plot(diagP, which="x")
  plot(diagP, which="marks", plot.neg="discrete")
  plot(diagP, which="marks", plot.neg="contour")
  plot(diagP, which="smooth", srange=c(-5,5))
  plot(diagP, which="smooth", plot.smooth="contour")
  plot(diagP, which="smooth", plot.smooth="image")

  fitS <- ppm(cells ~ x, Strauss(0.08))
  diagES <- diagnose.ppm(fitS, type="eem", clip=FALSE)
  diagIS <- diagnose.ppm(fitS, type="inverse", clip=FALSE)
  diagPS <- diagnose.ppm(fitS, type="Pearson", clip=FALSE)
  plot(diagES, which="marks", plot.neg="imagecontour")
  plot(diagPS, which="marks", plot.neg="discrete")
  plot(diagPS, which="marks", plot.neg="contour")
  plot(diagPS, which="smooth", plot.smooth="image")
  plot(diagPS, which="smooth", plot.smooth="contour")
  plot(diagPS, which="smooth", plot.smooth="persp")
  
  #' infinite reach, not border-corrected
  fut <- ppm(cells ~ x, Softcore(0.5), correction="isotropic")
  diagnose.ppm(fut)

  #' 
  diagPX <- diagnose.ppm(fit, type="Pearson", cumulative=FALSE)
  plot(diagPX, which="y")

  #' simulation based
  e <- envelope(cells, nsim=4, savepatterns=TRUE, savefuns=TRUE)
  Plist <- rpoispp(40, nsim=5)

  qf <- qqplot.ppm(fit, nsim=4, expr=e, plot.it=FALSE)
  print(qf)
  qp <- qqplot.ppm(fit, nsim=5, expr=Plist, fast=FALSE)
  print(qp)
  qp <- qqplot.ppm(fit, nsim=5, expr=expression(rpoispp(40)), plot.it=FALSE)
  print(qp)
  qg <- qqplot.ppm(fit, nsim=5, style="classical", plot.it=FALSE)
  print(qg)
  
  #' lurking.ppm
  #' covariate is numeric vector
  fitx <- ppm(cells ~ x)
  yvals <- coords(as.ppp(quad.ppm(fitx)))[,"y"]
  lurking(fitx, yvals)
  #' covariate is stored but is not used in model
  Z <- as.im(function(x,y){ x+y }, Window(cells))
  fitxx <- ppm(cells ~ x, data=solist(Zed=Z), allcovar=TRUE)
  lurking(fitxx, expression(Zed))
  #' envelope is a ppplist; length < nsim; glmdata=NULL
  fit <- ppm(cells ~ 1)
  stuff <- lurking(fit, expression(x), envelope=Plist, plot.sd=FALSE)
  #' plot.lurk
  plot(stuff, shade=NULL)
})
}

#'
#'  tests/discarea.R
#'
#'   $Revision: 1.3 $ $Date: 2020/04/28 12:58:26 $
#'

if(ALWAYS) {
local({
  u <- c(0.5,0.5)
  B <- owin(poly=list(x=c(0.3, 0.5, 0.7, 0.4), y=c(0.3, 0.3, 0.6, 0.8)))
  areaGain(u, cells, 0.1, exact=TRUE)
  areaGain(u, cells, 0.1, W=NULL)
  areaGain(u, cells, 0.1, W=B)

  X <- cells[square(0.4)]
  areaLoss(X, 0.1, exact=TRUE)  # -> areaLoss.diri
  areaLoss(X, 0.1, exact=FALSE) # -> areaLoss.grid
  areaLoss.poly(X, 0.1)

  areaLoss(X, 0.1, exact=FALSE, method="distmap")          # -> areaLoss.grid
  areaLoss(X, c(0.1, 0.15), exact=FALSE, method="distmap") # -> areaLoss.grid
})
}
#'
#'   tests/disconnected.R
#'
#'   disconnected linear networks
#'
#'    $Revision: 1.4 $ $Date: 2020/04/28 12:58:26 $


#'
#'    tests/deepeepee.R
#'
#'    Tests for determinantal point process models
#' 
#'    $Revision: 1.9 $ $Date: 2022/04/24 09:14:46 $

local({
  if(ALWAYS) {
    #' simulate.dppm
    jpines <- residualspaper$Fig1
    fit <- dppm(jpines ~ 1, dppGauss)
    set.seed(10981)
    simulate(fit, W=square(5))
  }
  if(FULLTEST) {
    #' simulate.detpointprocfamily - code blocks
    model <- dppGauss(lambda=100, alpha=.05, d=2)
    simulate(model, seed=1999, correction="border")
    u <- is.stationary(model)
    #' other methods for dppm
    kay <- Kmodel(fit)
    gee <- pcfmodel(fit)
    lam <- intensity(fit)
    arr <- reach(fit)
    pah <- parameters(fit)
    #' a user bug report - matrix dimension error
    set.seed(256)
    dat <- simulate( dppGauss(lambda = 8.5, alpha = 0.1, d = 2), nsim = 1)
  }
  if(FULLTEST) {
    ## cover print.summary.dppm
    jpines <- japanesepines[c(TRUE,FALSE,FALSE,FALSE)]
    print(summary(dppm(jpines ~ 1, dppGauss)))
    print(summary(dppm(jpines ~ 1, dppGauss, method="c")))
    print(summary(dppm(jpines ~ 1, dppGauss, method="p")))
    print(summary(dppm(jpines ~ 1, dppGauss, method="a")))
  }
  #' dppeigen code blocks
  if(ALWAYS) {
    mod <- dppMatern(lambda=2, alpha=0.01, nu=1, d=2)
    uT <- dppeigen(mod, trunc=1.1,  Wscale=c(1,1), stationary=TRUE)
  }
  if(FULLTEST) {
    uF <- dppeigen(mod, trunc=1.1,  Wscale=c(1,1), stationary=FALSE)
    vT <- dppeigen(mod, trunc=0.98, Wscale=c(1,1), stationary=TRUE)
    vF <- dppeigen(mod, trunc=0.98, Wscale=c(1,1), stationary=FALSE)
  }
})
