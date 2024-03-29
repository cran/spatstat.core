#'
#'     dppm.R
#'
#'     $Revision: 1.16 $   $Date: 2022/02/21 02:23:49 $

dppm <-
  function(formula, family, data=NULL,
           ...,
           startpar = NULL,
           method = c("mincon", "clik2", "palm", "adapcl"),
           weightfun=NULL,
           control=list(),
           algorithm,
           statistic="K",
           statargs=list(),
           rmax = NULL,
           epsilon = 0.01,
           covfunargs=NULL,
           use.gam=FALSE,
           nd=NULL, eps=NULL) {

  method <- match.arg(method)
    
  # Instantiate family if not already done.
  if(is.character(family))
    family <- get(family, mode="function")
  if(inherits(family, "detpointprocfamilyfun")) {
    familyfun <- family
    family <- familyfun()
  }
  verifyclass(family, "detpointprocfamily")

  # Check for intensity as only unknown and exit (should be changed for likelihood method)
  if(length(family$freepar)==1 && (family$freepar %in% family$intensity))
      stop("Only the intensity needs to be estimated. Please do this with ppm yourself.")
  # Detect missing rhs of 'formula' and fix
  if(inherits(formula, c("ppp", "quad"))){
    Xname <- short.deparse(substitute(formula))
    formula <- as.formula(paste(Xname, "~ 1"))
  }
  if(!inherits(formula, "formula"))
    stop(paste("Argument 'formula' should be a formula"))

#  kppm(formula, DPP = family, data = data, covariates = data,
#       startpar = startpar, method = method, weightfun = weightfun,
#       control = control, algorithm = algorithm, statistic = statistic,
#       statargs = statargs, rmax = rmax, covfunargs = covfunargs,
#       use.gam = use.gam, nd = nd, eps = eps, ...)

  if(missing(algorithm)) {
    algorithm <- if(method == "adapcl") "Broyden" else "Nelder-Mead"
  } else check.1.string(algorithm)

  thecall <- call("kppm",
                  X=formula,
                  DPP=family,
                  data = data, covariates = data,
                  startpar = startpar, method = method,
                  weightfun = weightfun, control = control,
                  algorithm = algorithm, statistic = statistic,
                  statargs = statargs, rmax = rmax, covfunargs = covfunargs,
                  use.gam = use.gam, nd = nd, eps = eps)
  ncall <- length(thecall)
  argh <- list(...)
  nargh <- length(argh)
  if(nargh > 0) {
    thecall[ncall + 1:nargh] <- argh
    names(thecall)[ncall + 1:nargh] <- names(argh)
  }
  callenv <- parent.frame()
  if(!is.null(data)) callenv <- list2env(data, parent=callenv)
  result <- eval(thecall, envir=callenv, enclos=baseenv())
  return(result)
}

## Auxiliary function to mimic cluster models for DPPs in kppm code
spatstatDPPModelInfo <- function(model){
  out <- list(
    modelname = paste(model$name, "DPP"), # In modelname field of mincon fv obj.
    descname = paste(model$name, "DPP"), # In desc field of mincon fv obj.
    modelabbrev = paste(model$name, "DPP"), # In fitted obj.
    printmodelname = function(...) paste(model$name, "DPP"), # Used by print.kppm
    parnames = model$freepar,
    shapenames = NULL,
    clustargsnames = NULL, # deprecated
    checkpar = function(par, ...){ return(par) },
    outputshape = function(margs) list(),
    checkclustargs = function(margs, native=old, ..., old = TRUE) { # deprecated
      return(list())
    }, 
    resolveshape = function(...) { return(list(...)) },
    resolvedots = function(...){ return(list(...)) }, # deprecated
    parhandler = function(...){ return(list(...)) }, # deprecated
    ## K-function
    K = function(par, rvals, ...){
      if(length(par)==1 && is.null(names(par)))
        names(par) <- model$freepar
      mod <- update(model, as.list(par))
      if(!valid(mod)){
        return(rep(Inf, length(rvals)))
      } else{
        return(Kmodel(mod)(rvals))
      }
    },
    ## pair correlation function
    pcf = function(par, rvals, ...){
      if(length(par)==1 && is.null(names(par)))
        names(par) <- model$freepar
      mod <- update(model, as.list(par))
      if(!valid(mod)){
        return(rep(Inf, length(rvals)))
      } else{
        return(pcfmodel(mod)(rvals))
      }
    },
    Dpcf = function(par, rvals, ...){
      if(length(par)==1 && is.null(names(par)))
        names(par) <- model$freepar
      mod <- update(model, as.list(par))
      if(!valid(mod)){
        return(rep(Inf, length(rvals)))
      } else{
        return(sapply(rvals, FUN = dppDpcf(mod)))
      }
    },
    ## sensible starting parameters
    selfstart = function(X) {
      return(model$startpar(model, X))
    }
  )
  return(out)
}

## Auxilliary function used for DPP stuff in kppm.R
dppmFixIntensity <- function(DPP, lambda, po){
  lambdaname <- DPP$intensity
  if(is.null(lambdaname))
    warning("The model has no intensity parameter.\n",
            "Prediction from the fitted model is invalid ",
            "(but no warning or error will be given by predict.dppm).")
  ## Update model object with estimated intensity if it is a free model parameter
  if(lambdaname %in% DPP$freepar){
    clusters <- update(DPP, structure(list(lambda), .Names=lambdaname))
  } else{
    clusters <- DPP
    lambda <- intensity(clusters)
    ## Overwrite po object with fake version
    X <- po$Q$data
    dont.complain.about(X)
    po <- ppm(X~offset(log(lambda))-1)
    po$fitter <- "dppm"
    ## update pseudolikelihood value using code in logLik.ppm
    po$maxlogpl.orig <- po$maxlogpl
    po$maxlogpl <- logLik(po, warn=FALSE)
    #########################################
  }
  return(list(clusters=clusters, lambda=lambda, po=po))
}

## Auxiliary function used for DPP stuff in kppm.R
dppmFixAlgorithm <- function(algorithm, changealgorithm, clusters, startpar){
  if(!setequal(clusters$freepar, names(startpar)))
    stop("Names of startpar vector does not match the free parameters of the model.")
  lower <- upper <- NULL
  if(changealgorithm){
    bb <- dppparbounds(clusters, names(startpar))
    if(all(is.finite(bb))){
      algorithm <- "Brent"
      lower <- bb[1L]
      upper <- bb[2L]
    } else{
      algorithm <- "BFGS"
    }
  }
  return(list(algorithm = algorithm, lower = lower, upper = upper))
}
