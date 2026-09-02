# Cross-cutting read -> validate -> fit suite (issue #19). The cheap,
# deterministic golden tests always run against the shared example fixture; the
# full Stan fit is gated behind skip_on_cran() + IMURUN_RUN_INTEGRATION so normal
# CI stays fast. This is the only home for the end-to-end pipeline test -- the
# per-function tests (test-loaders/-workbook/-validate/-targets) do not restate
# it.

# --- Golden: read the shared example (workbook and CSV directory) -------------

test_that("the example workbook reads data and sampler configuration", {
  skip_if_no_readxl()
  inputs <- imuRUN::read_inputs(example_wb())
  expect_named(inputs, c("obs", "locs", "target", "config"))
  expect_gt(nrow(inputs$obs), 0)
  expect_gt(nrow(inputs$locs), 0)
  expect_gt(nrow(inputs$target), 0)
})

test_that("the example CSV directory reads into the same frames", {
  inputs <- imuRUN::read_inputs(example_dir())
  expect_named(inputs, c("obs", "locs", "target"))
  expect_true("obs_id" %in% names(inputs$obs)) # auto-assigned (no id column)
  expect_gt(nrow(inputs$obs), 0)
})

# --- Golden: validation passes clean, fails on the corrupt copy ---------------

test_that("the clean example validates and the corrupt copy is rejected", {
  skip_if_no_readxl()
  expect_no_error(imuRUN::validate_inputs(imuRUN::read_inputs(example_wb())))
  expect_no_error(imuRUN::validate_inputs(imuRUN::read_inputs(example_dir())))
  expect_error(
    imuRUN::validate_inputs(imuRUN::read_inputs(corrupt_wb())),
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
  inputs <- imuRUN::read_inputs(example_wb())
  obs <- imuGAP::canonicalize_observations(inputs$obs)
  locs <- imuGAP::canonicalize_locations(inputs$locs)
  pops_raw <- imuRUN:::build_populations(inputs$obs)
  max_cohort <- max(as.integer(pops_raw$cohort))
  max_age <- max(as.integer(pops_raw$age))
  pops <- imuGAP::canonicalize_populations(
    pops_raw,
    obs,
    locs,
    max_cohort = max_cohort,
    max_age = max_age
  )
  fit <- imuGAP::sampling(
    observations = obs,
    populations = pops,
    locations = locs,
    imugap_opts = imuGAP::imugap_options(df = 5L, dose_schedule = c(1L, 4L)),
    stan_opts = imuGAP::stan_options(
      iter = 100L,
      chains = 1L,
      refresh = 0L,
      seed = 1L
    )
  )
  expect_true(inherits(fit$stanfit, "stanfit"))

  n_cohort <- fit$data$n_cohort
  expect_no_error(
    imuRUN::validate_targets(
      inputs$target,
      loc_ids = as.character(inputs$locs$loc_id),
      max_cohort = n_cohort,
      max_age = fit$data$n_yr
    )
  )
  exp <- imuRUN::expand_targets(inputs$target, default_dose = fit$data$n_doses)
  expect_true(all(exp$cohort >= 1L & exp$cohort <= n_cohort))

  pred <- stats::predict(fit, target = exp)
  draws <- imuRUN:::as_target_draws(pred)
  expect_true("p_obs" %in% names(draws))
  smry <- imuRUN::summarize_targets(draws)
  expect_equal(nrow(smry), nrow(exp))
  expect_true(all(c("est_median", "est_lower", "est_upper") %in% names(smry)))
  expect_true(all(smry$est_median >= 0 & smry$est_median <= 1))
  lower_ok <- all(smry$est_lower <= smry$est_median)
  upper_ok <- all(smry$est_median <= smry$est_upper)
  expect_true(lower_ok && upper_ok)
})

test_that("run_fit writes fit.rds and amends the input workbook (gated)", {
  skip_on_cran()
  if (!nzchar(Sys.getenv("IMURUN_RUN_INTEGRATION"))) {
    skip("set IMURUN_RUN_INTEGRATION=1 to run the end-to-end fit")
  }
  skip_if_no_readxl()
  out <- withr::local_tempdir()
  input <- file.path(out, "imurun_example.xlsx")
  expect_true(file.copy(example_wb(), input))

  wb <- openxlsx2::wb_load(input)
  wb$add_data(
    "configuration",
    data.frame(Value = c(100L, 1L, 1L, NA_integer_)),
    start_col = 2,
    start_row = 2,
    col_names = FALSE
  )
  openxlsx2::wb_save(wb, input, overwrite = TRUE)
  csv <- file.path(out, "results.csv")
  fit_path <- file.path(out, "imurun_example.rds")

  code <- imuRUN::run_fit(
    input,
    output_dir = out,
    result = c("xlsx", csv, "rds")
  )
  expect_identical(code, 0L)

  wb_path <- input
  expect_true(file.exists(fit_path))
  expect_true(file.exists(wb_path))
  expect_true(file.exists(csv))

  # The workbook carries the request alongside the answer.
  expect_identical(
    openxlsx2::wb_load(wb_path)$get_sheet_names(),
    c(
      "instructions",
      "configuration",
      "observations",
      "locations",
      "target",
      "results"
    )
  )
  res <- as.data.frame(openxlsx2::read_xlsx(wb_path, sheet = "results"))
  expect_gt(nrow(res), 0L)
  expect_true(all(
    c(
      "target_id",
      "loc_id",
      "cohort",
      "age",
      "dose",
      "est_median",
      "est_lower",
      "est_upper",
      "ci_level"
    ) %in%
      names(res)
  ))
  expect_true(all(res$est_median >= 0 & res$est_median <= 1))
  expect_true(all(res$est_lower <= res$est_median))
  expect_true(all(res$est_median <= res$est_upper))

  # The CSV holds the same estimates as the workbook's results sheet.
  from_csv <- utils::read.csv(csv, stringsAsFactors = FALSE)
  expect_identical(nrow(from_csv), nrow(res))
  expect_equal(from_csv$est_median, res$est_median, tolerance = 1e-8)

  # A second run with overwrite = FALSE refuses when files exist
  expect_error(
    imuRUN::run_fit(
      input,
      output_dir = out,
      result = c("xlsx", csv, "rds"),
      overwrite = FALSE
    ),
    "already exists"
  )
  # ... and overwrite = TRUE succeeds.
  forced <- imuRUN::run_fit(
    input,
    output_dir = out,
    result = c("xlsx", csv, "rds"),
    overwrite = TRUE
  )
  expect_identical(forced, 0L)
})
