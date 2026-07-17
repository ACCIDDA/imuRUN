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
  canonical <- imurun::validate_inputs(imurun::read_inputs(example_wb()))
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
})
