
<!-- README.md is generated from README.Rmd. Please edit that file -->

# fwildclusterboot

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/fwildclusterboot)](https://CRAN.R-project.org/package=fwildclusterboot)
<!-- badges: end -->

The fwildclusterboot package implements the fast wild cluster bootstrap
algorithm for regression objects in R following Stata’s boottest
package. It works with regression objects of type lm, lm\_robust, felm
and fixest from the base R and the estimatr, lfe and fixest packages.

## Installation

You can install the released version of fwildclusterboot from github…

# The boottest function

In a first step, simulate a data set with 10000 individual observations
that are grouped in 20 clusters and with a small intra-cluster
correlation of 0.01. The small intra-cluster correlation implies that,
in theory, inference based on cluster-robust covariance estimates should
lead to results that are very similar to the bootstrap.

``` r


library(fwildclusterboot)
#> 
#> Attaching package: 'fwildclusterboot'
#> The following object is masked _by_ '.GlobalEnv':
#> 
#>     boottest
B <- 10000
seed <- 13456
set.seed(seed)

voters <- create_data(N = 10000, N_G = 200, icc = 0.1)
head(voters)
#>       ID group_id    ideology ideological_label     income       Q1_immigration
#> 1: 00001        1  0.40393432           Liberal   3714.889 Don't Know / Neutral
#> 2: 00002        2  0.20515319           Liberal  24098.174 Don't Know / Neutral
#> 3: 00003        3 -0.06154031      Conservative 118037.533 Don't Know / Neutral
#> 4: 00004        4 -0.07549291      Conservative  73420.230 Don't Know / Neutral
#> 5: 00005        5  0.80690455           Liberal  12240.079           Lean Agree
#> 6: 00006        6 -0.06811706      Conservative 762239.189 Don't Know / Neutral
#>    treatment proposition_vote log_income
#> 1:         1                1   8.220104
#> 2:         1                0  10.089891
#> 3:         0                1  11.678758
#> 4:         0                1  11.203955
#> 5:         0                1   9.412471
#> 6:         1                1  13.544016
```

The fwildclusterboot package supports estimation of linear models based
on base R’s lm() function, estimatr’s lm\_robust function, lfe’s felm()
function and fixest’s feols() function.

``` r
library(estimatr)
library(lfe)
#> Loading required package: Matrix
#> 
#> Attaching package: 'Matrix'
#> The following objects are masked from 'package:pracma':
#> 
#>     expm, lu, tril, triu
#> 
#> Attaching package: 'lfe'
#> The following object is masked from 'package:lmtest':
#> 
#>     waldtest
library(fixest)

# lm_fit <- lm(proposition_vote ~ treatment + ideology + log_income +Q1_immigration, weights = NULL, data = voters)
# lm_robust_fit <- lm_robust(proposition_vote ~ treatment + ideology + log_income, fixed_effects = ~ Q1_immigration , weights = NULL, data = voters)
# lm_robust_fit1 <- lm_robust(proposition_vote ~ treatment + ideology + log_income + Q1_immigration , weights = NULL, data = voters )
feols_fit <- feols(proposition_vote ~ treatment + ideology + log_income, fixef = c("Q1_immigration"), weights = NULL, data = voters)
feols_fit1 <- feols(proposition_vote ~ treatment + ideology + log_income + Q1_immigration , weights = NULL, data = voters)
felm_fit <- felm(proposition_vote ~ treatment + ideology + log_income | Q1_immigration, weights = NULL, data = voters)
```

The boottest command offers two functions. First, it calculates p-values
for a given null hypothesis of the form HO: \(\beta = 0\) vs H1:
\(\beta \neq 1\). In order to work, an object from a regression model of
class lm, lm\_robust, felm or feols needs to be passed to the boottest
function. Currently, the user is still required to pass a vector with
information on clusters to the function. As of now, the function only
supports one-dimensional clustering. By default, the boottest function
calculates confidence intervals by inversion. The user can considerably
speed up the inference procedure by setting the argument conf\_int to
FALSE, in which case no confidence intervals are computed.

``` r
# lm = boottest(lm_fit, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = FALSE)
# estimatr_fe = boottest(lm_robust_fit, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = FALSE)
# estimatr = boottest(lm_robust_fit1, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = FALSE)
# felm = boottest(felm_fit, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = FALSE)
fixest = boottest(feols_fit, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = FALSE)
fixest1 = boottest(feols_fit1, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = FALSE)
```

Secondly, the user may specify to obtain confidence intervals.

``` r
#res_lm = boottest(lm_fit, clustid = voters$group_id, B = B, seed = seed, param = "treatment", #conf_int = TRUE)
#res_estimatr_fe = boottest(lm_robust_fit, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = #TRUE)
#res_estimatr = boottest(lm_robust_fit1, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = #TRUE)
#res_felm = boottest(felm_fit, clustid = voters$group_id, B = B, seed = seed, param = "treatment", #conf_int = TRUE)
#tic()
# res_fixest = boottest(feols_fit, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = TRUE)
# res_fixest1 = boottest(feols_fit1, clustid = voters$group_id, B = B, seed = seed, param = "treatment", conf_int = TRUE)
#toc()
```

A summary method collects the results.

``` r
#summary(res_lm)
#summary(res_estimatr_fe)
#summary(res_estimatr)
#summary(res_felm)
# summary(fixest)
# summary(fixest1)
fixest$p_val
#> [1] 0.2062
fixest1$p_val
#> [1] 0.2062
```

These estimates are very close to estimates using sandwich cluster
robust estimators:

``` r
summary(feols_fit, se = "cluster", cluster = "group_id")
#> OLS estimation, Dep. Var.: proposition_vote
#> Observations: 10,000 
#> Fixed-effects: Q1_immigration: 7
#> Standard-errors: Clustered (group_id) 
#>             Estimate Std. Error   t value  Pr(>|t|)    
#> treatment   0.009637   0.008070  1.194100  0.232457    
#> ideology    0.283317   0.015469 18.316000 < 2.2e-16 ***
#> log_income -0.000419   0.002921 -0.143592  0.885825    
#> ---
#> Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
#> Log-likelihood: -5,107.25   Adj. R2: 0.34897 
#>                           R2-Within: 0.0375
```

Currently they are probably not exactly equal as I might not adjust
correctly for degrees of freedom in the fixed effects estimations.

Boottest comes with a tidy method which, in analogy with the
broom-package, returns the estimation results as a data.frame.

``` r
#tidy(res_lm)
#summary(res_estimatr_fe)
#summary(res_estimatr)
#tidy(res_felm)
# tidy(res_fixest)
# tidy(res_fixest1)
```

## Benchmarks

``` r

# seed <- 1
# set.seed(seed)
# N <- 5000
# N_G <- 10
# B <- 1000
# 
# data <- create_data(N = N, N_G = N_G)
# 
# lapply(c(100, 1000, 5000, 1000), function(B){
#       lm_fit <- lm(proposition_vote ~ treatment + ideology + log_income +Q1_immigration + Q2_defence, weights = NULL, data = data)
#       bench <- benchmark(
#           boot =  multiwayvcov::cluster.boot(lm_fit, 
#                                              as.factor(data$group_id), 
#                                              R = B, 
#                                              boot_type = "residual", 
#                                              wild_type = "rademacher", 
#                                              parallel = FALSE), 
#           fast_boot_1 = boottest(lm_fit, clustid = data$group_id, B = B, seed = seed, param = "treatment", conf_int = FALSE),
#           fast_boot_1_2 = boottest(lm_fit, clustid = data$group_id, B = B, seed = seed, param = "treatment", conf_int = TRUE), 
#           replications = 10)
#       c(N, N_G, bench$elapsed)
# })
# 
# 
# res <- data.frame()
# 
# data <- create_data(N = N, N_G = 20)
# i <- 0
# 
# res <- 
# lapply(c(1000, 5000, 10000, 20000), function(N){
#   lapply(c(10, 20, 50, 100, 200), function(N_G){
#     data <- create_data(N = N, N_G = N_G)
#     lapply(c(100, 1000, 5000, 1000), function(B){
#       lm_fit <- lm(proposition_vote ~ treatment + ideology + log_income +Q1_immigration + Q2_defence, weights = NULL, data = data)
#       bench <- benchmark(
#         boot =  multiwayvcov::cluster.boot(lm_fit, 
#                                                        as.factor(data$group_id), 
#                                                        R = B, 
#                                                        boot_type = "residual", 
#                                                        wild_type = "rademacher", 
#                                                        parallel = FALSE), 
#         fast_boot_1 = boottest(lm_fit, clustid = data$group_id, B = B, seed = seed, param = "treatment", conf_int = FALSE),
#         fast_boot_1_2 = boottest(lm_fit, clustid = data$group_id, B = B, seed = seed, param = "treatment", conf_int = TRUE), 
#         replications = 10, 
#         columns = c("bootstrap", "fast bootstrap 1", "fast bootstrap 2")#,
#         #relative = c("bootstrap")
#       )
#       c(N, N_G, bench$elapsed)
#     })
#   })
# })
```
