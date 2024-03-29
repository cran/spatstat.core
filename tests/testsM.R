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
##
##     tests/marcelino.R
##
##     $Revision: 1.4 $  $Date: 2020/04/30 02:18:23 $
##

local({
  if(FULLTEST) {
    Y <- split(urkiola)
    B <- Y$birch
    O <- Y$oak
    B.lam <- predict (ppm(B ~polynom(x,y,2)), type="trend")
    O.lam <- predict (ppm(O ~polynom(x,y,2)), type="trend")

    Kinhom(B, lambda=B.lam, correction="iso")
    Kinhom(B, lambda=B.lam, correction="border")
    
    Kcross.inhom(urkiola, i="birch", j="oak", B.lam, O.lam)
    Kcross.inhom(urkiola, i="birch", j="oak", B.lam, O.lam, correction = "iso")
    Kcross.inhom(urkiola, i="birch", j="oak", B.lam, O.lam, correction = "border")
  }
})


##
##    tests/markcor.R
##
##   Tests of mark correlation code (etc)
##
## $Revision: 1.7 $ $Date: 2020/11/25 01:23:32 $

local({
  if(ALWAYS) {
    ## check.testfun checks equality of functions
    ##  and is liable to break if the behaviour of all.equal is changed
    fe <- function(m1, m2) {m1 == m2}
    fm <- function(m1, m2) {m1 * m2}
    fs <- function(m1, m2) {sqrt(m1)}
    if(check.testfun(fe, X=amacrine)$ftype != "equ")
      warning("check.testfun fails to recognise mark equality function")
    if(check.testfun(fm, X=longleaf)$ftype != "mul")
      warning("check.testfun fails to recognise mark product function")
    check.testfun(fs, X=longleaf)
    check.testfun("mul")
    check.testfun("equ")
  }

  if(FULLTEST) {
    ## test all is well in Kmark -> Kinhom 
    MA <- Kmark(amacrine,function(m1,m2){m1==m2})
    set.seed(42)
    AR <- rlabel(amacrine)
    MR <- Kmark(AR,function(m1,m2){m1==m2})
    if(isTRUE(all.equal(MA,MR)))
      stop("Kmark unexpectedly ignores marks")

    ## cover code blocks in markcorr()
    X <- runifpoint(100) %mark% runif(100)
    Y <- X %mark% data.frame(u=runif(100), v=runif(100))
    ww <- runif(100)
    fone <- function(x) { x/2 }
    ffff <- function(x,y) { fone(x) * fone(y) }
    aa <- markcorr(Y)
    bb <- markcorr(Y, ffff, weights=ww, normalise=TRUE)
    bb <- markcorr(Y, ffff, weights=ww, normalise=FALSE)
    bb <- markcorr(Y, f1=fone, weights=ww, normalise=TRUE)
    bb <- markcorr(Y, f1=fone, weights=ww, normalise=FALSE)

    ## markcrosscorr
    a <- markcrosscorr(betacells, normalise=FALSE)
    if(require(sm)) {
      b <- markcrosscorr(betacells, method="sm")
    }

    ## Vmark with normalisation
    v <- Vmark(spruces, normalise=TRUE)
    v <- Vmark(finpines, normalise=TRUE)
  }
})
#' tests/mctests.R
#' Monte Carlo tests
#'        (mad.test, dclf.test, envelopeTest, hasenvelope)
#' $Revision: 1.4 $ $Date: 2020/06/12 06:10:47 $

local({
  if(FULLTEST) {
    envelopeTest(cells, Lest, exponent=1, nsim=9, savepatterns=TRUE)
    (a3 <- envelopeTest(cells, Lest, exponent=3, nsim=9, savepatterns=TRUE))
    
    envelopeTest(a3, Lest, exponent=3, nsim=9, alternative="less")
    
    fitx <- ppm(redwood~x)
    ax <- envelopeTest(fitx, exponent=2, nsim=9, savefuns=TRUE)
    print(ax)

    envelopeTest(redwood, Lest, exponent=1, nsim=19,
                 rinterval=c(0, 0.1), alternative="greater", clamp=TRUE)
    envelopeTest(redwood, pcf, exponent=Inf, nsim=19,
                 rinterval=c(0, 0.1), alternative="greater", clamp=TRUE)
  }
})

#
# tests/mppm.R
#
# Basic tests of mppm
#
# $Revision: 1.21 $ $Date: 2021/12/29 08:25:48 $
# 

if(!FULLTEST)
  spatstat.options(npixel=32, ndummy.min=16)

local({
  ## test interaction formulae and subfits
  fit1 <- mppm(Points ~ group, simba,
               hyperframe(po=Poisson(), str=Strauss(0.1)),
               iformula=~ifelse(group=="control", po, str))
  fit2 <- mppm(Points ~ group, simba,
               hyperframe(po=Poisson(), str=Strauss(0.1)),
               iformula=~str/id)
  fit2w <- mppm(Points ~ group, simba,
                hyperframe(po=Poisson(), str=Strauss(0.1)),
                iformula=~str/id, weights=runif(nrow(simba)))
# currently invalid  
#  fit3 <- mppm(Points ~ group, simba,
#               hyperframe(po=Poisson(), pie=PairPiece(c(0.05,0.1))),
#        iformula=~I((group=="control") * po) + I((group=="treatment") * pie))
  fit1
  fit2
  fit2w
#  fit3

  if(FULLTEST) {
    ## run summary.mppm which currently sits in spatstat-internal.Rd
    summary(fit1)
    summary(fit2)
    summary(fit2w)
    #  summary(fit3)
  }    

  ## test vcov algorithm
  vcov(fit1)
  vcov(fit2)
#  vcov(fit3)

  if(FULLTEST) {
    fit4 <- mppm(Points ~ group, simba, hyperframe(str=Strauss(0.1)), iformula=~str/group)
    fit4
    summary(fit4)
    vcov(fit4)
    fit0 <- mppm(Points ~ group, simba)
    anova(fit0, fit4, test="Chi")
  }
  
  ## test subfits algorithm
  if(FULLTEST) {
    s1 <- subfits(fit1)
    s2 <- subfits(fit2)
    #  s3 <- subfits(fit3)
    s4 <- subfits(fit4)
    
    ## validity of results of subfits()
    p1 <- solapply(s1, predict)
    p2 <- solapply(s2, predict)
    #  p3 <- solapply(s3, predict)
    p4 <- solapply(s4, predict)
  }
})

local({
  if(FULLTEST) {
    ## cases of predict.mppm
    W <- solapply(waterstriders, Window)
    Fakes <- solapply(W, runifpoint, n=30)
    FakeDist <- solapply(Fakes, distfun)
    H <- hyperframe(Bugs=waterstriders,
                    D=FakeDist)
    fit <- mppm(Bugs ~ D, data=H)
    p1 <- predict(fit)
    p2 <- predict(fit, locations=Fakes)
    p3 <- predict(fit, locations=solapply(W, erosion, r=4))
    locn <- as.data.frame(do.call(cbind, lapply(Fakes, coords)))
    df <- data.frame(id=sample(1:3, nrow(locn), replace=TRUE),
                     D=runif(nrow(locn)))
    p4 <- predict(fit, locations=locn, newdata=df)

    fitG <- mppm(Bugs ~ D, data=H, use.gam=TRUE)
    p1G <- predict(fitG)
    p2G <- predict(fitG, locations=Fakes)
    p3G <- predict(fitG, locations=solapply(W, erosion, r=4))
    p4G <- predict(fitG, locations=locn, newdata=df)
  }
})

local({
  ##  [thanks to Sven Wagner]
  ## factor covariate, with some levels unused in some rows
  if(FULLTEST) {
    set.seed(14921788)
    H <- hyperframe(X=replicate(3, runifpoint(20), simplify=FALSE),
                    Z=solist(as.im(function(x,y){x}, owin()),
                             as.im(function(x,y){y}, owin()),
                             as.im(function(x,y){x+y}, owin())))
    H$Z <- solapply(H$Z, cut, breaks=(0:4)/2)

    fit6 <- mppm(X ~ Z, H)
    v6 <- vcov(fit6)
    s6 <- subfits(fit6)
    p6 <- solapply(s6, predict)

    ## random effects
    fit7 <- mppm(X ~ Z, H, random=~1|id)
    v7 <- vcov(fit7)
    s7 <- subfits(fit7)
    p7 <- solapply(s7, predict)

    fit7a <- mppm(X ~ Z, H, random=~x|id)
    v7a <- vcov(fit7a)
    s7a <- subfits(fit7a)
    p7a <- solapply(s7a, predict)
    
    ## multitype: collisions in vcov.ppm, predict.ppm
    H$X <- lapply(H$X, rlabel, labels=factor(c("a","b")), permute=FALSE)
    M <- MultiStrauss(matrix(0.1, 2, 2), c("a","b"))
    fit8 <- mppm(X ~ Z, H, M)
    v8 <- vcov(fit8, fine=TRUE)
    s8 <- subfits(fit8)
    p8 <- lapply(s8, predict)
    c8 <- lapply(s8, predict, type="cif")

    fit9 <- mppm(X ~ Z, H, M, iformula=~Interaction * id)
    v9 <- vcov(fit9, fine=TRUE)
    s9 <- subfits(fit9)
    p9 <- lapply(s9, predict)
    c9 <- lapply(s9, predict, type="cif")

    ## and a simple error in recognising 'marks'
    fit10 <- mppm(X ~ marks, H)
  }
})

local({
  if(FULLTEST) {
    ## test handling of offsets and zero cif values in mppm
    H <- hyperframe(Y = waterstriders)
    (fit1 <- mppm(Y ~ 1,  data=H, Hardcore(1.5)))
    (fit2 <- mppm(Y ~ 1,  data=H, StraussHard(7, 1.5)))
    (fit3 <- mppm(Y ~ 1,  data=H, Hybrid(S=Strauss(7), H=Hardcore(1.5))))
    s1 <- subfits(fit1)
    s2 <- subfits(fit2)
    s3 <- subfits(fit3)

    ## prediction, in training/testing context
    ##    (example from Markus Herrmann and Ege Rubak)
    X <- waterstriders
    dist <- solapply(waterstriders,
                     function(z) distfun(runifpoint(1, Window(z))))
    i <- 3
    train <- hyperframe(pattern = X[-i], dist = dist[-i])
    test <- hyperframe(pattern = X[i], dist = dist[i])
    fit <- mppm(pattern ~ dist, data = train)
    pred <- predict(fit, type="cif", newdata=test, verbose=TRUE)

    ## examples from Robert Aue
    GH <- Hybrid(G=Geyer(r=0.1, sat=3), H=Hardcore(0.01))
    res <- mppm(Points ~ 1, interaction = GH, data=demohyper)
    print(summary(res))
    sub <- subfits(res, verbose=TRUE)
    print(sub)
  }
})

local({
  if(FULLTEST) {
    ## test handling of interaction coefficients in multitype case
    set.seed(42)
    XX <- as.solist(replicate(3, rthin(amacrine, 0.8), simplify=FALSE))
    H <- hyperframe(X=XX)
    M <- MultiStrauss(matrix(0.1, 2, 2), levels(marks(amacrine)))
    fit <- mppm(X ~ 1, H, M)
    co <- coef(fit)
    subco <- sapply(subfits(fit), coef)
    if(max(abs(subco - co)) > 0.001)
      stop("Wrong coefficient values in subfits, for multitype interaction")
  }
})

local({
  if(FULLTEST) {
    ## test lurking.mppm
    ## example from 'mppm'
    n <- 7
    H <- hyperframe(V=1:n,
                    U=runif(n, min=-1, max=1))
    H$Z <- setcov(square(1))
    H$U <- with(H, as.im(U, as.rectangle(Z)))
    H$Y <- with(H, rpoispp(eval.im(exp(2+3*Z))))
    fit <- mppm(Y ~ Z + U + V, data=H)

    lurking(fit, expression(Z), type="P")
    lurking(fit, expression(V), type="raw") # design covariate
    lurking(fit, expression(U), type="raw") # image, constant in each row
    lurking(fit, H$Z,           type="P")   # list of images
  }
})

local({
  if(FULLTEST) {
    ## test anova.mppm code blocks and scoping problem
    H <- hyperframe(X=waterstriders)
    mod0 <- mppm(X~1, data=H, Poisson())
    modxy <- mppm(X~x+y, data=H, Poisson())
    mod0S <- mppm(X~1, data=H, Strauss(2))
    modxyS <- mppm(X~x+y, data=H, Strauss(2))
    anova(mod0, modxy, test="Chi")
    anova(mod0S, modxyS, test="Chi")
    anova(modxy, test="Chi")
    anova(modxyS, test="Chi")
    #' models with random effects (example from Marcelino de la Cruz)
    mod0r <- mppm(X~1, data=H, Poisson(), random = ~1|id)
    modxr <- mppm(X~x, data=H, Poisson(), random = ~1|id)
    anova(mod0r, modxr, test="Chi")
  }
})

local({
  if(FULLTEST) {
    ## test multitype stuff
    foo <- flu[1:3,]
    msh <- MultiStraussHard(iradii=matrix(100, 2, 2),
                            hradii=matrix(10,2,2),
                            types=levels(marks(foo$pattern[[1]])))
    msh0 <- MultiStraussHard(iradii=matrix(100, 2, 2),
                             hradii=matrix(10,2,2))
    fit <- mppm(pattern ~ 1, data=foo, interaction=msh0)
    print(fit)
    print(summary(fit))
    v <- vcov(fit)
  }
})

reset.spatstat.options()
#'
#'     tests/msr.R
#'
#'     $Revision: 1.5 $ $Date: 2020/11/30 07:27:44 $
#'
#'     Tests of code for measures
#'

if(FULLTEST) {
local({
    
  ## cases of 'msr'
  Q <- quadscheme(cells)
  nQ <- n.quad(Q)
  nX <- npoints(cells)
  A <- matrix(nX * 3, nX, 3)
  B <- matrix(nQ * 3, nQ, 3)

  m <- msr(Q, A, B)

  M <- msr(Q, A, 1)
  M <- msr(Q, 1, B)
  M <- msr(Q, A, B[,1])
  M <- msr(Q, A[,1], B)
  M <- msr(Q, A, B[,1,drop=FALSE])
  M <- msr(Q, A[,1,drop=FALSE], B)

  ## methods
  a <- summary(m)
  b <- is.marked(m)
  w <- as.owin(m)
  z <- domain(m)
  ss <- scalardilate(m, 2)
  tt <- rescale(m, 2)
  ee <- rotate(m, pi/4)
  aa <- affine(m, mat=diag(c(1,2)), vec=c(0,1))
  ff <- flipxy(m)
  
  am <- augment.msr(m, sigma=0.08)
  ua <- update(am)
  
  rr <- residuals(ppm(cells ~ x))
  mm <- residuals(ppm(amacrine ~ x))
  ss <- residuals(ppm(amacrine ~ x), type="score")
  gg <- rescale(ss, 1/662, c("micron", "microns"))

  plot(mm)
  plot(mm, multiplot=FALSE)
  plot(mm, equal.markscale=TRUE, equal.ribbon=TRUE)
  plot(ss)
  plot(ss, multiplot=FALSE)
})
}
