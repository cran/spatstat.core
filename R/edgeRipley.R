#
#        edgeRipley.R
#
#    $Revision: 1.20 $    $Date: 2021/10/25 10:26:05 $
#
#    Ripley isotropic edge correction weights
#
#  edge.Ripley(X, r, W)      compute isotropic correction weights
#                            for centres X[i], radii r[i,j], window W
#
#  To estimate the K-function see the idiom in "Kest.S"
#
#######################################################################

edge.Ripley <- local({

  small <- function(x) { abs(x) < .Machine$double.eps }

  hang <- function(d, r) {
    nr <- nrow(r)
    nc <- ncol(r)
    answer <- matrix(0, nrow=nr, ncol=nc)
    # replicate d[i] over j index
    d <- matrix(d, nrow=nr, ncol=nc)
    hit <- (d < r)
    answer[hit] <- acos(d[hit]/r[hit])
    answer
  }

  edge.Ripley <- function(X, r, W=Window(X),
                          method=c("C", "interpreted"),
                          maxweight=100, internal=list()) {
    # X is a point pattern, or equivalent
    X <- as.ppp(X, W)
    W <- X$window

    method <- match.arg(method)
    debug  <- resolve.1.default(list(debug=FALSE), internal)
    repair <- resolve.1.default(list(repair=TRUE), internal)
    
    switch(W$type,
           rectangle={},
           polygonal={
             if(method != "C")
               stop(paste("Ripley isotropic correction for polygonal windows",
                          "requires method = ", dQuote("C")))
           },
           mask={
             stop(paste("sorry, Ripley isotropic correction",
                        "is not implemented for binary masks"))
           }
           )

    n <- npoints(X)

    if(is.matrix(r) && nrow(r) != n)
      stop("the number of rows of r should match the number of points in X")
    if(!is.matrix(r)) {
      if(length(r) != n)
        stop("length of r is incompatible with the number of points in X")
      r <- matrix(r, nrow=n)
    }

    #
    Nr <- nrow(r)
    Nc <- ncol(r)
    if(Nr * Nc == 0) return(r)
    
    ##########
  
    x <- X$x
    y <- X$y

    switch(method,
           interpreted = {
           ######## interpreted R code for rectangular case #########

             # perpendicular distance from point to each edge of rectangle
             # L = left, R = right, D = down, U = up
             dL  <- x - W$xrange[1L]
             dR  <- W$xrange[2L] - x
             dD  <- y - W$yrange[1L]
             dU  <- W$yrange[2L] - y

             # detect whether any points are corners of the rectangle
             corner <- (small(dL) + small(dR) + small(dD) + small(dU) >= 2)
  
             # angle between (a) perpendicular to edge of rectangle
             # and (b) line from point to corner of rectangle
             bLU <- atan2(dU, dL)
             bLD <- atan2(dD, dL)
             bRU <- atan2(dU, dR)
             bRD <- atan2(dD, dR)
             bUL <- atan2(dL, dU)
             bUR <- atan2(dR, dU)
             bDL <- atan2(dL, dD)
             bDR <- atan2(dR, dD)

             # The above are all vectors [i]
             # Now we compute matrices [i,j]

             # half the angle subtended by the intersection between
             # the circle of radius r[i,j] centred on point i
             # and each edge of the rectangle (prolonged to an infinite line)

             aL <- hang(dL, r)
             aR <- hang(dR, r)
             aD <- hang(dD, r) 
             aU <- hang(dU, r)

             # apply maxima
             # note: a* are matrices; b** are vectors;
             # b** are implicitly replicated over j index
             cL <- pmin.int(aL, bLU) + pmin.int(aL, bLD)
             cR <- pmin.int(aR, bRU) + pmin.int(aR, bRD)
             cU <- pmin.int(aU, bUL) + pmin.int(aU, bUR)
             cD <- pmin.int(aD, bDL) + pmin.int(aD, bDR)

             # total exterior angle
             ext <- cL + cR + cU + cD
	     ext <- matrix(ext, Nr, Nc)
	     
             # add pi/2 for corners 
             if(any(corner))
               ext[corner,] <- ext[corner,] + pi/2

             # OK, now compute weight
             weight <- 1 / (1 - ext/(2 * pi))

           },
           C = {
             ############ C code #############################
             switch(W$type,
                    rectangle={
		      if(!debug) {
                        z <- .C(SC_ripleybox,
                                nx=as.integer(n),
                                x=as.double(x),
                                y=as.double(y),
                                rmat=as.double(r),
                                nr=as.integer(Nc), #sic
                                xmin=as.double(W$xrange[1L]),
                                ymin=as.double(W$yrange[1L]),
                                xmax=as.double(W$xrange[2L]),
                                ymax=as.double(W$yrange[2L]),
                                epsilon=as.double(.Machine$double.eps),
                                out=as.double(numeric(Nr * Nc)),
                                PACKAGE="spatstat.core")
		        } else {
                        z <- .C(SC_ripboxDebug,
                                nx=as.integer(n),
                                x=as.double(x),
                                y=as.double(y),
                                rmat=as.double(r),
                                nr=as.integer(Nc), #sic
                                xmin=as.double(W$xrange[1L]),
                                ymin=as.double(W$yrange[1L]),
                                xmax=as.double(W$xrange[2L]),
                                ymax=as.double(W$yrange[2L]),
                                epsilon=as.double(.Machine$double.eps),
                                out=as.double(numeric(Nr * Nc)),
                                PACKAGE="spatstat.core")
	              }
                      weight <- matrix(z$out, nrow=Nr, ncol=Nc)
                    },
                    polygonal={
                      Y <- edges(W)
                      bd <- bdist.points(X)
                      if(!debug) {
                        z <- .C(SC_ripleypoly,
                                nc=as.integer(n),
                                xc=as.double(x),
                                yc=as.double(y),
                                bd=as.double(bd),
                                nr=as.integer(Nc),
                                rmat=as.double(r),
                                nseg=as.integer(Y$n),
                                x0=as.double(Y$ends$x0),
                                y0=as.double(Y$ends$y0),
                                x1=as.double(Y$ends$x1),
                                y1=as.double(Y$ends$y1),
                                out=as.double(numeric(Nr * Nc)),
                                PACKAGE="spatstat.core")
                      } else {
                        z <- .C(SC_rippolDebug,
                                nc=as.integer(n),
                                xc=as.double(x),
                                yc=as.double(y),
                                bd=as.double(bd),
                                nr=as.integer(Nc),
                                rmat=as.double(r),
                                nseg=as.integer(Y$n),
                                x0=as.double(Y$ends$x0),
                                y0=as.double(Y$ends$y0),
                                x1=as.double(Y$ends$x1),
                                y1=as.double(Y$ends$y1),
                                out=as.double(numeric(Nr * Nc)),
                                PACKAGE="spatstat.core")
                      }
                      angles <- matrix(z$out, nrow = Nr, ncol = Nc)
                      weight <- 2 * pi/angles
                    }
                    )
           }
    )
    ## eliminate wild values
    if(repair)
      weight <- matrix(pmax.int(1, pmin.int(maxweight, weight)),
                       nrow=Nr, ncol=Nc)
    return(weight)
  }

  edge.Ripley
})

rmax.Ripley <- function(W) {
  W <- as.owin(W)
  if(is.rectangle(W))
    return(boundingradius(W))
  if(is.polygonal(W) && length(W$bdry) == 1L)
    return(boundingradius(W))
  ## could have multiple connected components
  pieces <- tiles(tess(image=connected(W)))
  answer <- sapply(pieces, boundingradius)
  return(as.numeric(answer))
}
