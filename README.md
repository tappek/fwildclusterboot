
<!-- README.md is generated from README.Rmd. Please edit that file -->

# fwildclusterboot

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/fwildclusterboot)](https://CRAN.R-project.org/package=fwildclusterboot)
[![R-CMD-check](https://github.com/s3alfisc/fwildclusterboot/workflows/R-CMD-check/badge.svg)](https://github.com/s3alfisc/fwildclusterboot/actions)
<!-- badges: end -->

The `fwildclusterboot` package is an R port of Stata’s `boottest`
package.

It implements the fast wild cluster bootstrap algorithm developed in
Roodman et al (2019) for regression objects in R. It currently works for
regression objects of type `lm`, `felm` and `fixest` from base R and the
`lfe` and `fixest` packages.

The package’s central function is `boottest()`. It allows the user to
test two-sided, univariate hypotheses using a wild cluster bootstrap.
Importantly, it uses the “fast” algorithm developed in Roodman et al,
which makes it feasible to calculate test statistics based on a large
number of bootstrap draws even for large samples–as long as the number
of bootstrapping clusters is not too large.

The `fwildclusterboot` package currently supports one- and
two-dimensional clustering and one-dimensional hypotheses.

The package is highly experimental and only includes few unit tests.

The following features will be added in the future:

  - support for multivariate hypotheses
  - bootstrap distributions beyond the rademacher distribution

## The `boottest()` function

The `fwildclusterboot` package supports wild cluster bootstrap inference
for linear models based on

  - `lm()` from `base` R
  - `felm()` from `lfe`
  - `feols()` from `fixest`

<!-- end list -->

``` r
library(fwildclusterboot)

B <- 10000
seed <- 942413
set.seed(seed)
voters <- create_data_2(N = 10000, N_G1 = 20, icc1 = 0.01, N_G2 = 10, icc2 = 0.01, numb_fe1 = 10, numb_fe2 = 10, seed = seed)

lm_fit <- lm(proposition_vote ~ treatment + ideology1 + log_income + Q1_immigration , weights = NULL, data = voters)
```

The `boottest` function always calculates p-values for a given
univariate hypothesis test. Second and by default, the boottest function
calculates confidence intervals by inversion of the p-value. The user
can considerably speed up the inference procedure by setting the
argument `conf_int = FALSE`, in which case no confidence intervals are
computed.

``` r
# 1) boottest based on object of class lm
boot_lm = boottest(lm_fit, clustid = "group_id1", B = B, seed = seed, param = "treatment", conf_int = TRUE)
#>   |                                                                              |                                                                      |   0%  |                                                                              |------                                                                |   8%  |                                                                              |---------                                                             |  12%  |                                                                              |------------                                                          |  17%  |                                                                              |---------------                                                       |  21%  |                                                                              |------------------                                                    |  25%  |                                                                              |--------------------                                                  |  29%  |                                                                              |-----------------------                                               |  33%  |                                                                              |--------------------------                                            |  38%  |                                                                              |-----------------------------                                         |  42%  |                                                                              |--------------------------------                                      |  46%  |                                                                              |-----------------------------------                                   |  50%  |                                                                              |--------------------------------------                                |  54%  |                                                                              |-----------------------------------------                             |  58%  |                                                                              |--------------------------------------------                          |  62%  |                                                                              |-----------------------------------------------                       |  67%  |                                                                              |--------------------------------------------------                    |  71%  |                                                                              |----------------------------------------------------                  |  75%  |                                                                              |-------------------------------------------------------               |  79%  |                                                                              |----------------------------------------------------------            |  83%  |                                                                              |-------------------------------------------------------------         |  88%  |                                                                              |----------------------------------------------------------------      |  92%  |                                                                              |-------------------------------------------------------------------   |  96%  |                                                                              |----------------------------------------------------------------------| 100%
```

The function `summary` collects the results. Boottest further comes with
a `tidy` method, which, in analogy with the `broom` package, returns the
estimation results as a data.frame.

``` r
summary(boot_lm)
#> boottest.lm(object = lm_fit, clustid = "group_id1", param = "treatment", 
#>     B = B, conf_int = TRUE, seed = seed)
#>  
#>  Observations: 10000
#>  Bootstr. Iter: 10000
#>  Clustering: oneway
#>  Confidence Sets: 95%
#>  Number of Clusters: 20
#> 
#>           Estimate t value Pr(>|t|) CI Lower CI Upper
#> treatment    0.011    1.09    0.292    -0.01    0.032
tidy(boot_lm)
#>             Estimate  t value Pr(>|t|)     CI Lower   CI Upper
#> treatment 0.01080738 1.089841   0.2918 -0.009933565 0.03186458
```

## Installation

You can install the released version of `fwildclusterboot` from github
by running

``` r
devtools::install_github("s3alfisc/fwildclusterboot")
```

## Benchmarks

Results of timing benchmarks of `fwildclusterboot` with
`sandwich::vcovBS`.

  - Benchmark 1: N = 10000, one cluster with \(N_G = 40\)
  - Benchmark 2: N = 10000, two closters with \(N_G1= 40\) and
    \(N_G2 = 20\), \(N_G12 = 800\)

<img src="man/figures/README-unnamed-chunk-11-1.png" width="100%" />
