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
    "'Sampled'"
  )
})

test_that("calendar-year targets validate before fitting", {
  inputs <- imuRUN::read_inputs(example_wb())
  inputs$obs$year <- as.integer(inputs$obs$year) + 2000L
  inputs$target$year <- as.integer(inputs$target$year) + 2000L

  expect_identical(imuRUN::run_fit(inputs, dryrun = TRUE), 0L)

  latest <- max(imuRUN:::build_populations(inputs$obs)$cohort)
  inputs$target$year[1L] <- latest + 2L
  inputs$target$age_low[1L] <- 1L
  inputs$target$age_high[1L] <- 1L
  expect_error(
    imuRUN::run_fit(inputs, dryrun = TRUE),
    sprintf(
      "birth cohort %d, after the latest birth cohort %d",
      latest + 1L,
      latest
    )
  )
})

test_that("birth cohorts are rebased and restored by target identity", {
  populations <- data.frame(cohort = c(2010L, 2014L, 2024L))
  targets <- data.frame(
    obs_id = c(11L, 22L),
    cohort = c(2010L, 2024L),
    abs_cohort = c(2010L, 2024L)
  )

  expect_equal(imuRUN:::rebase_cohorts(populations, 2010L)$cohort, c(1, 5, 15))
  targets <- imuRUN:::rebase_cohorts(targets, 2010L)
  expect_equal(targets$cohort, c(1, 15))

  draws <- data.frame(obs_id = c(22L, 11L, 22L), age = c(1L, 15L, 1L))
  restored <- imuRUN:::reattach_birth_cohorts(draws, targets)
  expect_equal(restored$cohort, c(2024, 2010, 2024))
  expect_true(all(restored$cohort + restored$age == 2025L))
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
  # imuGAP numbers cohorts from 1, as run_fit() does.
  earliest <- min(as.integer(pops_raw$cohort))
  pops_raw$cohort <- pops_raw$cohort - earliest + 1L
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
      max_age = fit$data$n_yr,
      earliest = earliest
    )
  )
  exp <- imuRUN::expand_targets(inputs$target, default_dose = fit$data$n_doses)
  exp$cohort <- exp$cohort - earliest + 1L
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
    data.frame(Setting = c("iter", "chains", "seed"), Value = c(100L, 1L, 1L)),
    start_col = 1L,
    start_row = 2L,
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

  fit <- readRDS(fit_path)
  input_data <- imuRUN::read_inputs(input)
  birth_cohorts <- imuRUN:::build_populations(input_data$obs)$cohort
  expect_identical(
    attr(fit, "imurun_cohort_origin"),
    as.integer(min(birth_cohorts))
  )

  # The workbook carries the request alongside the answer.
  expect_identical(
    unname(openxlsx2::wb_load(wb_path)$get_sheet_names()),
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
  expect_false("n_draws" %in% names(res))
  expect_true(all(res$est_median >= 0 & res$est_median <= 1))
  expect_true(all(res$est_lower <= res$est_median))
  expect_true(all(res$est_median <= res$est_upper))
  expect_true(all(res$cohort + res$age == input_data$target$year[1L]))

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
