# Cross-cutting read -> validate -> fit suite (issue #19). The cheap,
# deterministic golden tests always run against the shared example fixture; the
# full Stan fit is gated behind skip_on_cran() + IMURUN_RUN_INTEGRATION so normal
# CI stays fast. This is the only home for the end-to-end pipeline test -- the
# per-function tests (test-loaders/-workbook/-validate/-targets) do not restate
# it.

# --- Golden: read the shared example (workbook and CSV directory) -------------

test_that("the example workbook reads into the three expected frames", {
  skip_if_no_readxl()
  inputs <- imurun::read_inputs(example_wb())
  expect_named(inputs, c("obs", "locs", "target"))
  expect_gt(nrow(inputs$obs), 0)
  expect_gt(nrow(inputs$locs), 0)
  expect_gt(nrow(inputs$target), 0)
})

test_that("the example CSV directory reads into the same frames", {
  inputs <- imurun::read_inputs(example_dir())
  expect_named(inputs, c("obs", "locs", "target"))
  expect_true("obs_id" %in% names(inputs$obs)) # auto-assigned (no id column)
  expect_gt(nrow(inputs$obs), 0)
})

# --- Golden: validation passes clean, fails on the corrupt copy ---------------

test_that("the clean example validates and the corrupt copy is rejected", {
  skip_if_no_readxl()
  expect_no_error(imurun::validate_inputs(imurun::read_inputs(example_wb())))
  expect_no_error(imurun::validate_inputs(imurun::read_inputs(example_dir())))
  expect_error(
    imurun::validate_inputs(imurun::read_inputs(corrupt_wb())),
    "sample_n"
  )
})

# --- Integration: a real (tiny) fit, gated ------------------------------------

test_that("the example fits end-to-end (gated)", {
  skip_on_cran()
  if (!nzchar(Sys.getenv("IMURUN_RUN_INTEGRATION"))) {
    skip("set IMURUN_RUN_INTEGRATION=1 to run the end-to-end fit")
  }
  skip_if_no_readxl()
  inputs <- imurun::read_inputs(example_wb())
  canonical <- imurun::validate_inputs(inputs)
  fit <- imuGAP::sampling(
    observations = canonical$obs,
    populations = canonical$pops,
    locations = canonical$locs,
    imugap_opts = imuGAP::imugap_options(df = 5L, dose_schedule = c(1L, 4L)),
    stan_opts = imuGAP::stan_options(
      iter = 100L, chains = 1L, refresh = 0L, seed = 1L
    )
  )
  expect_true(inherits(fit$stanfit, "stanfit"))

  # The example's target must survive the whole by-target path: validate ->
  # expand -> predict -> summarize. This is the regression guard for #38 -- the
  # snapshot expansion must not reach a cohort the model was never fit for, or
  # predict() errors deep inside imuGAP. (The cheap validate_targets guard is
  # unit-tested in test-targets; here we prove predict itself succeeds.)
  n_cohort <- fit$data$n_cohort
  expect_no_error(
    imurun::validate_targets(
      inputs$target,
      loc_ids = canonical$locs$loc_id,
      max_cohort = n_cohort,
      max_age = fit$data$n_yr
    )
  )
  exp <- imurun::expand_targets(inputs$target, default_dose = fit$data$n_doses)
  expect_true(all(exp$cohort >= 1L & exp$cohort <= n_cohort))

  pred <- stats::predict(fit, target = exp)
  draws <- as.data.frame(pred)
  # predict() names the coverage draws `coverage`; summarize_targets consumes
  # `p_obs` (the #14 writer bridges this). Rename inline to exercise the path.
  names(draws)[names(draws) == "coverage"] <- "p_obs"
  smry <- imurun::summarize_targets(draws)
  expect_equal(nrow(smry), nrow(exp)) # one summary row per expanded target
  expect_true(all(c("est_median", "est_lower", "est_upper") %in% names(smry)))
  expect_true(all(smry$est_median >= 0 & smry$est_median <= 1))
  lower_ok <- all(smry$est_lower <= smry$est_median)
  upper_ok <- all(smry$est_median <= smry$est_upper)
  expect_true(lower_ok && upper_ok)
})
