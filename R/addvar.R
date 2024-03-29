#
# addvar.R
#
# added variable plot
#
#   $Revision: 1.13 $  $Date: 2022/01/19 00:49:17 $
#


addvar <- function(model, covariate, ...,
                   subregion=NULL,
                   bw="nrd0", adjust=1,
                   from=NULL, to=NULL, n=512,
                   bw.input = c("points", "quad"),
                   bw.restrict = FALSE,
                   covname, crosscheck=FALSE) {  

  if(missing(covname))
    covname <- sensiblevarname(deparse(substitute(covariate)), "X")
  callstring <- paste(deparse(sys.call()), collapse = "")
  
  if(is.marked(model))
    stop("Sorry, this is not yet implemented for marked models")
      
  if(is.null(adjust)) adjust <- 1
  
  bw.input <- match.arg(bw.input)
  
  # validate model
  stopifnot(is.ppm(model))
  if(is.null(getglmfit(model)))
    model <- update(model, forcefit=TRUE)
  modelcall <- model$callstring
  if(is.null(modelcall))
    modelcall <- model$call
  
  # extract spatial locations
  Q <- quad.ppm(model)
#  datapoints <- Q$data
  quadpoints <- union.quad(Q)
  Z <- is.data(Q)
  wts <- w.quad(Q)
  nQ <- n.quad(Q)
  # fitted intensity
  lam <- fitted(model, type="trend")
  # subset of quadrature points used to fit model
  subQset <- getglmsubset(model)
  if(is.null(subQset)) subQset <- rep.int(TRUE, nQ)
  # restriction to subregion
  insubregion <- if(!is.null(subregion)) {
    inside.owin(quadpoints, w=subregion)
  } else rep.int(TRUE, nQ)

  ################################################################
  # Pearson residuals from point process model

  yr <- residuals(model, type="Pearson")
  yresid <- with(yr, "increment")
  # averaged (then sum with weight 'wts')
  yresid <- yresid/wts

  #################################################################
  # Covariates
  #
  # covariate data frame
  df <- getglmdata(model)
  if(!all(c("x", "y") %in% names(df))) {
    xy <- as.data.frame(quadpoints)
    notxy <- !(colnames(df) %in% c("x", "y"))
    other <- df[, notxy]
    df <- cbind(xy, other)
  }
  #
  avail.covars <- names(df)
  # covariates used in model 
  used.covars   <- model.covariates(model)
  fitted.covars <- model.covariates(model, offset=FALSE)
  #
  #################################################################
  # identify the covariate
  #
  if(!is.character(covariate)) {
    # Covariate is some kind of data, treated as external covariate
    if(covname %in% fitted.covars)
      stop(paste("covariate named", dQuote(covname),
                 "is already used in model"))
    covvalues <- evalCovariate(covariate, quadpoints)
    # validate covvalues
    if(is.null(covvalues))
      stop("Unable to extract covariate values")
    else if(length(covvalues) != npoints(quadpoints))
      stop(paste("Internal error: number of covariate values =",
                 length(covvalues), "!=", npoints(quadpoints),
                 "= number of quadrature points"))
    # tack onto data frame
    covdf <- data.frame(covvalues)
    names(covdf) <- covname
    df <- cbind(df, covdf)
  } else {
    # Argument is name of covariate
    covname <- covariate
    if(length(covname) > 1)
      stop("Must specify only one covariate")
    #
    if(covname %in% fitted.covars)
      stop(paste("covariate", dQuote(covname), "already used in model"))
    #
    if(!(covname %in% avail.covars))
      stop(paste("covariate", dQuote(covname), "not available"))
    # 
    covvalues <- df[, covname]
  }
  
  ################################################################
  # Pearson residuals from weighted linear regression of new covariate on others

  rhs <- formula(model)
  fo <- as.formula(paste(covname, paste(rhs, collapse=" ")))

  fit <- lm(fo, data=df, weights=lam * wts, na.action=na.exclude)
  xresid <- residuals(fit, type="pearson")/sqrt(wts)

  if(crosscheck) {
    message("Cross-checking...")
    X <- model.matrix(fo, data=df)
    V <- diag(lam * wts)
    sqrtV <- diag(sqrt(lam * wts))
    Info <- t(X) %*% V %*% X
    H <- sqrtV %*% X  %*% solve(Info) %*% t(X) %*% sqrtV
    nQ <- length(lam)
    Id <- diag(1, nQ, nQ)
    xresid.pearson <- (Id - H) %*% sqrtV %*% covvalues
    xresid.correct <- xresid.pearson/sqrt(wts)
    abserr <- max(abs(xresid - xresid.correct), na.rm=TRUE)
    relerr <- abserr/diff(range(xresid.correct, finite=TRUE))
    if(is.finite(relerr) && relerr > 0.01) {
      warning("Large relative error in residual computation")
    }
    message("Done.")
  }
  # experiment suggests residuals(fit, "pearson") == xresid.correct
  # and residuals(fit) equivalent to
  # covvalues - X  %*% solve(t(X) %*% V %*% X) %*% t(X) %*% V %*% covvalues

  #################################################################
  # check for NA's etc

  # locations that must have finite values 
  operative <- if(bw.restrict) insubregion & subQset else subQset
 
  nbg <- !is.finite(xresid) |  !is.finite(yresid)
  if(any(offending <- nbg & operative)) {
    warning(paste(sum(offending), "out of", length(offending),
                  "covariate values discarded because",
                  ngettext(sum(offending), "it is", "they are"),
                  "NA or infinite"))
  }
  #################################################################
  # Restrict data to 'operative' points
  #                            with finite values

  ok <- !nbg & operative
  Q           <- Q[ok]
  xresid      <- xresid[ok]
  yresid      <- yresid[ok]
  covvalues   <- covvalues[ok]
  df          <- df[ok, ]
  lam         <- lam[ok]
  wts         <- wts[ok]
  Z           <- Z[ok]
  insubregion <- insubregion[ok]

  ####################################################
  # assemble data for smoothing 
  xx <- xresid
  yy <- yresid
  ww <- wts
  if(makefrom <- is.null(from))
    from <- min(xresid)
  if(maketo <- is.null(to))
    to   <- max(xresid)
  
  ####################################################
  # determine smoothing bandwidth
  #     from 'operative' data

  switch(bw.input,
          quad = {
           # bandwidth selection from covariate values at all quadrature points
           numer <- unnormdensity(xx, weights=yy * ww,
                                  bw=bw, adjust=adjust,
                                  n=n,from=from,to=to, ...)
           sigma <- numer$bw
         },
         points= {
           # bandwidth selection from covariate values at data points
           fake <- unnormdensity(xx[Z], weights=1/lam[Z],
                                 bw=bw, adjust=adjust,
                                 n=n,from=from,to=to, ...)
           sigma <- fake$bw
           numer <- unnormdensity(xx, weights=yy * ww,
                                  bw=sigma, adjust=1,
                                  n=n,from=from,to=to, ...)
         })

 ####################################################
  # Restrict data and recompute numerator if required

  if(!is.null(subregion) && !bw.restrict) {
    # Bandwidth was computed on all data
    # Restrict to subregion and recompute numerator
    xx   <- xx[insubregion]
    yy   <- yy[insubregion]
    ww   <- ww[insubregion]
    lam  <- lam[insubregion]
    Z    <- Z[insubregion]
    if(makefrom) from <- min(xx)
    if(maketo)     to <- max(xx)
    numer <- unnormdensity(xx, weights=yy * ww,
                           bw=sigma, adjust=1,
                           n=n,from=from,to=to, ...)
  }

 ####################################################
  # Compute denominator
  denom <- unnormdensity(xx,weights=ww,
                           bw=sigma, adjust=1,
                           n=n,from=from,to=to, ...)

  ####################################################
  # Determine recommended plot range

  xr <- range(xresid[Z], finite=TRUE)
  alim <- xr + 0.1 * diff(xr) * c(-1,1)
  alim <- intersect.ranges(alim, c(from, to))
  
  ####################################################
  # Compute terms 

  interpolate <- function(x,y) {
    if(inherits(x, "density") && missing(y))
      approxfun(x$x, x$y, rule=2)
    else 
      approxfun(x, y, rule=2)
  }
  numfun <- interpolate(numer)
  denfun <- interpolate(denom)
  xxx <- numer$x
  ratio <- function(y, x) { ifelseXB(x != 0, y/x, NA) }
  yyy <- ratio(numfun(xxx), denfun(xxx))
  # Null variance estimation
  # smooth with weight 1 and smaller bandwidth
  tau <- sigma/sqrt(2)
  varnumer <- unnormdensity(xx,weights=ww,
                            bw=tau,adjust=1,
                            n=n,from=from,to=to, ...)
  varnumfun <- interpolate(varnumer)
  vvv <- ratio(varnumfun(xxx), 2 * sigma * sqrt(pi) * denfun(xxx)^2)
  safesqrt <- function(x) {
    ok <- is.finite(x) & (x >= 0)
    y <- rep.int(NA_real_, length(x))
    y[ok] <- sqrt(x[ok])
    return(y)
  }
  twosd <- 2 * safesqrt(vvv)
  # pack into fv object
  rslt <- data.frame(rcov=xxx, rpts=yyy, theo=0, var=vvv, hi=twosd, lo=-twosd)
  nuc <- length(used.covars)
  if(nuc == 0) {
    given <- givenlab <- 1
  } else if(nuc == 1) {
    given <- givenlab <- used.covars
  } else {
    given <- commasep(used.covars, ", ")
    givenlab <- paste("list", paren(given))
  }
  given <- paste("|", given)
  xlab <- sprintf("r(paste(%s, '|', %s))", covname, givenlab)
  ylab <- sprintf("r(paste(points, '|', %s))", givenlab)
  yexpr <- parse(text=ylab)[[1L]]
  desc <- c(paste("Pearson residual of covariate", covname, given),
            paste("Smoothed Pearson residual of point process", given),
            "Null expected value of point process residual",
            "Null variance of point process residual",
            "Upper limit of pointwise 5%% significance band",
            "Lower limit of pointwise 5%% significance band")
  rslt <- fv(rslt,
             argu="rcov",
             ylab=yexpr,
             valu="rpts",
             fmla= (. ~ rcov),
             alim=alim,
             labl=c(xlab,
                    "%s",
                    "0",
                    "bold(var) ~ %s",
                    "%s[hi]",
                    "%s[lo]"),
             desc=desc,
             fname=ylab)
  attr(rslt, "dotnames") <- c("rpts", "theo", "hi", "lo")
  # data associated with quadrature points
  reserved <- (substr(colnames(df), 1L, 4L) == ".mpl")
  isxy <- colnames(df) %in% c("x", "y")
  dfpublic <- cbind(df[, !(reserved | isxy)], data.frame(xresid, yresid))
  attr(rslt, "spatial") <- union.quad(Q) %mark% dfpublic
  # auxiliary data
  attr(rslt, "stuff") <- list(covname     = covname,
                              xresid      = xresid,
                              yresid      = yresid,
                              covvalues   = covvalues,
                              wts         = wts,
                              bw          = bw,
                              adjust      = adjust,
                              sigma       = sigma,
                              used.covars = used.covars,
                              modelcall   = modelcall,
                              callstring  = callstring,
                              xlim        = c(from, to),
                              xlab        = xlab,
                              ylab        = ylab,
                              lmcoef      = coef(fit),
                              bw.input    = bw.input,
                              bw.restrict = bw.restrict,
                              restricted  = !is.null(subregion))
  # finish
  class(rslt) <- c("addvar", class(rslt))
  return(rslt)
}

print.addvar <- function(x, ...) {
  cat("Added variable plot diagnostic (class addvar)\n")
  s <- attr(x, "stuff")
  mc <- paste(s$modelcall, collapse="")
  cat(paste("for the covariate", dQuote(s$covname),
            "for the fitted model:",
            if(nchar(mc) <= 30) "" else "\n\t",
            mc, "\n\n"))
  if(identical(s$restricted, TRUE))
    cat("\t--Diagnostic computed for a subregion--\n")
   cat(paste("Call:", s$callstring, "\n"))
  cat(paste("Actual smoothing bandwidth sigma =", signif(s$sigma,5),
                    "\n\n"))
  NextMethod("print")
}

plot.addvar <- function(x, ..., do.points=FALSE) {
  xname <- short.deparse(substitute(x))
  s <- attr(x, "stuff")
#  covname <- s$covname
  xresid <- s$xresid
  yresid <- s$yresid
  # adjust y limits if intending to plot points as well
  ylimcover <- if(do.points) range(yresid, finite=TRUE) else NULL
  #
  do.call(plot.fv, resolve.defaults(list(quote(x)), list(...),
                                      list(main=xname,
                                           shade=c("hi", "lo"),
                                           legend=FALSE,
                                           ylim.covers=ylimcover)))
  # plot points
  if(do.points)
    do.call(points,
            resolve.defaults(list(x=xresid, y=yresid),
                             list(...),
                             list(pch=3, cex=0.5)))
  return(invisible(x))
}

