boot_algo2 <- function(preprocessed_object, boot_iter, point_estimate, impose_null, beta0, sign_level, param, p_val_type, nthreads, type, full_enumeration, small_sample_correction) {
  
  #' Fast wild cluster bootstrap algorithm 
  #' 
  #' function that implements the fast bootstrap algorithm as described in Roodman et al (2019)
  #'
  #' @param preprocessed_object A list: output of the preprocess2 function.
  #' @param boot_iter number of bootstrap iterations
  #' @param point_estimate The point estimate of the test parameter from the regression model.
  #' @param impose_null If TRUE, the null is not imposed on the bootstrap distribution.
  #'        This is what Roodman et al call the "WCU" bootstrap. With impose_null = FALSE, the
  #'        null is imposed ("WCR").
  #' @param beta0 Shifts the null hypothesis.
  #' @param sign_level The significance level.
  #' @param param name of the test parameter.
  #' @param p_val_type type Type of p-value. By default "two-tailed". Other options: "equal-tailed", ">", "<"
  #' @param nthreads The number of threads. Can be: a) an integer lower than, 
  #'                 or equal to, the maximum number of threads; b) 0: meaning 
  #'                 all available threads will be used; c) a number strictly
  #'                 between 0 and 1 which represents the fraction of all threads 
  #'                 to use. The default is to use 50\% of all threads. You can
  #'                 set permanently the number of threads used within this 
  #'                 package using the function ...
  #' @param type character or function. The character string specifies the type
  #'        of boostrap to use: One of "rademacher", "mammen", "norm"
  #'        and "webb". Alternatively, type can be a function(n) for drawing 
  #'        wild bootstrap factors. "rademacher" by default.
  #' @param full_enumeration Is full enumeration employed? Full enum. is used if
  #'        N_G^2 < boot_iter for Mammen and Rademacher weights
  #' @param small_sample_correction The small sample correction to be applied. See ssc().
  #' @return A list of ...
  #' @importFrom Matrix t Diagonal
  #' @importFrom Matrix.utils aggregate.Matrix
  #' @importFrom collapse fsum GRP
  #' @importFrom stats as.formula coef model.matrix model.response model.weights residuals rlnorm rnorm update
  #' @importFrom gtools permutations
  #' @importFrom dqrng dqsample dqset.seed

  

  # 1) preprocess
  # preprocessed_object = preprocess
  
  X <- preprocessed_object$X
  Y <- preprocessed_object$Y
  N <- preprocessed_object$N
  # k <- preprocessed_object$k
  clustid <- preprocessed_object$clustid
  fixed_effect <- preprocessed_object$fixed_effect
  N_G <- preprocessed_object$N_G
  W <- preprocessed_object$W
  # n_fe <- preprocessed_object$n_fe
  bootcluster <- preprocessed_object$bootcluster
  # vcov_sign <- preprocessed_object$vcov_sign
  weights <- preprocessed_object$weights
  R <- t(as.matrix(preprocessed_object$R0))

  N_G_bootcluster <- length(unique(bootcluster[[1]]))
  
  wild_draw_fun <- switch(type,
                          # note: for randemacher, create integer matrix (uses less memory than numeric)                      
                          rademacher = function(n) dqrng::dqsample(x = c(-1L, 1L), size = n, replace = TRUE),
                          mammen = function(n) sample(c(-1, 1) * (sqrt(5) + c(-1, 1))/2, n, replace = TRUE,
                                                      prob = (sqrt(5) + c(1, -1))/(2 * sqrt(5))),
                          norm = function(n) dqrng::dqrnorm(n = n),
                          webb = function(n) dqrng::dqsample(x = c(-sqrt((3:1) / 2), sqrt((1:3) / 2)), size = n, replace = TRUE),
                          wild_draw_fun
  )
  
  # do full enumeration for rademacher weights if bootstrap iterations 
  # B exceed number of possible permutations else random sampling

  if(type %in% c("rademacher") && full_enumeration == TRUE){
      v0 <- gtools::permutations(n = 2, r = N_G_bootcluster, v = c(1, -1), repeats.allowed = TRUE)
      v <- cbind(1, t(v0))
  } else{
    # else: just draw with replacement - by chance, some permutations 
    # might occur more than once
    v <- wild_draw_fun(n = N_G_bootcluster * (boot_iter + 1))
    dim(v) <- c(N_G_bootcluster, boot_iter + 1)
    v[, 1] <- 1
  }
  
  # prepare "key" for use with collapse::fsum()
  g <- collapse::GRP(bootcluster[[1]], call = FALSE)
  
  #weights_mat <- Matrix::Diagonal(N, weights)           # if no weights - N x N identity matrix
  weights_sq <- sqrt(weights)                           # sqrt fine because diagonal matrix
  A <- solve(crossprod(weights_sq * X))                 # k x k
  #XXinv <- solve(crossprod(X))                          # k x k
  WX <- weights * X
  
  XAR <- X %*% (A %*% t(R))
  AWXY <- (A %*% (t(WX) %*% Y))
  
  if(impose_null == TRUE){
    Q <- - XAR %*% solve(R %*% A %*% t(R))        # N x 1
    #P <- Y - X %*% (A %*% (t(WX) %*% Y)) - Q %*% (R %*% A %*% t(WX)) %*% Y
    P <- Y - X %*% AWXY - Q %*% (R %*% AWXY)
  } else if(impose_null == FALSE){
      #P <- Y - X %*% (A %*% (t(WX) %*% Y)) 
      P <- Y - X %*% AWXY
      Q <- matrix(0, nrow(P), 1)
      #R[,1] <- 0
  }

  # pre-compute objects used in for-loop below: 
  WXAR <- weights * as.vector(XAR)             # N x 1
  WXARX <- WXAR * X                                           # N x k
  
  WXARP <- WXAR * as.vector(P)
  WXARQ <- WXAR * as.vector(Q)
  
  P1 <- collapse::fsum(WX * as.vector(P), g)         # P1 as in notes "Implementation details. Formerly called "SuXa". dim = N_G x k
  Q1 <- collapse::fsum(WX * as.vector(Q), g)         # Q1 as in notes "Implementation details. Formerly called "SuXa". dim = N_G x k
  # "crosstab for vectors" via sparse matrices 
  P2_bootcluster <- Matrix::t(                                        
    Matrix.utils::aggregate.Matrix(                           # see notes; formerly diag_XinvXXRuS_a   
      Matrix::Diagonal( 
        N,
        as.vector(WXARP)
      ),
      as.vector(bootcluster[[1]])
    )
  ) # N x c*
  Q2_bootcluster <- Matrix::t(                                            # see notes; formerly diag_XinvXXRuS_b   
    Matrix.utils::aggregate.Matrix(
      Matrix::Diagonal(
        N,
        as.vector(WXARQ)
      ),
      as.vector(bootcluster[[1]])
    )
  ) # N x c*
  
  # preallocate lists
  CC <- vector(mode = "list", length = length(names(clustid)))
  DD <- vector(mode = "list", length = length(names(clustid)))
  CD <- vector(mode = "list", length = length(names(clustid)))
  
  # CC <- matrix(NA, length(names(clustid)), B + 1)
  # CD <- matrix(NA, length(names(clustid)), B + 1)
  # DD <- matrix(NA, length(names(clustid)), B + 1)
  
  
  if(is.null(W)){
    # if there are no fixed effects - term (2) in equ. (62) fast & wild does not arise
    # note - W refers to W_bar in fast & wild, not regression weights. If no fixed effects
    # in the model / bootstrap, W is NULL
    
    for (x in seq_along(names(clustid))) {
      
      SXinvXXRX <- collapse::fsum(WXARX, clustid[x])             # c* x f
      SXinvXXRXA <- SXinvXXRX %*% A                              # part of numerator independent of both bootstrap errors and r   
      
      # P2_bootcluster has been collapsed over "bootcluster", now collapse over cluster c
      P2 <- Matrix.utils::aggregate.Matrix(P2_bootcluster, clustid[x]) # c* x c
      P_all <- P2 - tcrossprod(SXinvXXRXA, P1)                   # formerly _a
      
      Q2 <- Matrix.utils::aggregate.Matrix(Q2_bootcluster, clustid[x])
      Q_all <- Q2 - tcrossprod(SXinvXXRXA, Q1)
      
      C <- eigenMapMatMult(as.matrix(P_all), v, nthreads)             # c* x (B + 1)
      D <- eigenMapMatMult(as.matrix(Q_all), v, nthreads)             # c* x (B + 1)
      
      CC[[x]] <- colSums(C * C)
      DD[[x]] <- colSums(D * D)
      CD[[x]] <- colSums(C * D)
    
    }
  } else if(!is.null(W)){
    
      # project out fe
      Q3_2 <- crosstab(as.matrix(weights * W %*% Q), var1 = bootcluster, var2 = fixed_effect) # f x c*
      P3_2 <- crosstab(as.matrix(weights * W %*% P), var1 = bootcluster, var2 = fixed_effect) # f x c*
      
      for (x in seq_along(names(clustid))) {
        
        SXinvXXRX <- collapse::fsum(WXARX, clustid[x])             # c* x f
        SXinvXXRXA <- SXinvXXRX %*% A                              # part of numerator independent of both bootstrap errors and r   
        
        CT_cfe <- crosstab(WXAR, var1 = clustid[x], var2 = fixed_effect) # c x f, formerly S_XinvXXR_F
        
        # a
        P3 <- t(tcrossprod(P3_2, CT_cfe))                       # formerly prod_a
        P2 <- Matrix.utils::aggregate.Matrix(P2_bootcluster, clustid[x]) # c* x c
        P_all <- P2 - tcrossprod(SXinvXXRXA, P1) - P3
        
        # b: note that from here, if impose_null = TRUE, _b suffix objects and D, DD, CD need not be computed, they are always objects of 0's only
        Q3 <- t(tcrossprod(Q3_2, CT_cfe))
        Q2 <- Matrix.utils::aggregate.Matrix(Q2_bootcluster, clustid[x])
        Q_all <- Q2 - tcrossprod(SXinvXXRXA, Q1) - Q3
        C <- eigenMapMatMult(as.matrix(P_all), v, nthreads)
        D <- eigenMapMatMult(as.matrix(Q_all), v, nthreads)
          
        CC[[x]] <- colSums(C * C)
        DD[[x]] <- colSums(D * D)
        CD[[x]] <- colSums(C * D)
      }
      
    }
      
  # calculate numerator:
  numer_a <- collapse::fsum(as.vector(WXARP), g)
  numer_b <- collapse::fsum(as.vector(WXARQ), g)
  # calculate A, B
  A <- crossprod(as.matrix(numer_a), v)                        # q x (B+1) -> q = 1
  B <- crossprod(numer_b, v)                                   # q x (B+1) -> q = 1
    
  p_val_res <- p_val_null2(beta0 = beta0, A = A, B = B, CC = CC, CD = CD, DD = DD, clustid = clustid, boot_iter = boot_iter, small_sample_correction = small_sample_correction, impose_null = impose_null, point_estimate = point_estimate, p_val_type = p_val_type)
  # collect results from P-val_null2
  p_val <- p_val_res$p_val
  t_stat <- p_val_res$t_stat
  t_boot <- p_val_res$t_boot
  invalid_t <- p_val_res$delete_invalid_t_total
  # collect pre-computed A, B, CC, CD, DD - will be needed for p-value inversion
  ABCD <- list(A = A, B = B, CC = CC, CD = CD, DD = DD)
 
  res <- list(
    p_val = p_val,
    t_stat = t_stat,
    t_boot = t_boot,
    B = B,
    R0 = R,
    param = param,
    clustid = clustid,
    v = v,
    invalid_t = invalid_t,
    ABCD = ABCD, 
    small_sample_correction = small_sample_correction
  )
  
  class(res) <- "boot_algo"
  
  invisible(res)
  
}