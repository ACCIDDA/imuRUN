# Tests for the fit command's output artifacts (issue #14): the no-clobber
# guard, the results CSV, the amended workbook, and the output-flag parser.
# All toolchain-free: these write files from an already-summarized results
# frame, so none of it needs a fit.

fake_results <- function(n = 2L) {
  data.frame(
    target_id = as.character(seq_len(n)),
    loc_id = rep("A", n),
    cohort = rep(5L, n),
    age = seq.int(5L, length.out = n),
    dose = rep(2L, n),
    n_draws = rep(100L, n),
    est_median = rep(0.8, n),
    est_lower = rep(0.7, n),
    est_upper = rep(0.9, n),
    ci_level = rep(0.95, n),
    stringsAsFactors = FALSE
  )
}

fake_inputs <- function() {
  list(
    obs = data.frame(
      obs_id = 1L, loc_id = "A", cohort = 5L, age = 5L,
      dose = 2L, positive = 3L, sample_n = 10L, stringsAsFactors = FALSE
    ),
    locs = data.frame(loc_id = "A", parent_id = NA, stringsAsFactors = FALSE),
    target = data.frame(
      loc_id = "A", cohort = 5L, age_low = 5L, age_high = 6L,
      stringsAsFactors = FALSE
    )
  )
}

# --- prediction-draws bridge --------------------------------------------------

test_that("as_target_draws renames imuGAP's coverage column to p_obs", {
  # imuGAP::predict.imugap_fit() returns the coverage draws as `coverage`;
  # summarize_targets() consumes `p_obs`. Without this bridge the whole
  # predict -> summarize path fails on the column name alone.
  pred <- data.frame(
    obs_id = c(1L, 1L, 2L, 2L),
    coverage = c(0.7, 0.8, 0.5, 0.6),
    stringsAsFactors = FALSE
  )
  draws <- as_target_draws(pred)
  expect_true("p_obs" %in% names(draws))
  expect_false("coverage" %in% names(draws))
  expect_equal(draws$p_obs, pred$coverage)
  # and the result is directly consumable by summarize_targets
  expect_no_error(summarize_targets(draws))
})

test_that("as_target_draws leaves an already-named p_obs column alone", {
  pred <- data.frame(obs_id = 1L, p_obs = 0.5, stringsAsFactors = FALSE)
  expect_identical(as_target_draws(pred), pred)
})

# --- no-clobber guard ---------------------------------------------------------

test_that("assert_no_clobber allows a new path and refuses an existing one", {
  dir <- withr::local_tempdir()
  fresh <- file.path(dir, "new.xlsx")
  expect_identical(assert_no_clobber(fresh), fresh)

  taken <- file.path(dir, "taken.xlsx")
  file.create(taken)
  expect_error(assert_no_clobber(taken), "already exists")
  expect_error(assert_no_clobber(taken), "--overwrite")
  # ... unless overwrite was requested
  expect_identical(assert_no_clobber(taken, overwrite = TRUE), taken)
})

# --- CSV output ---------------------------------------------------------------

test_that("write_results_csv round-trips the summarized targets", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "results.csv")
  res <- fake_results()

  expect_identical(write_results_csv(res, path), path)
  back <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_identical(nrow(back), nrow(res))
  expect_true(all(
    c("target_id", "loc_id", "est_median", "est_lower", "est_upper") %in%
      names(back)
  ))
  expect_equal(back$est_median, res$est_median)
  # no row-name column leaked into the file
  expect_false("X" %in% names(back))
})

test_that("write_results_csv refuses to clobber unless asked", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "results.csv")
  write_results_csv(fake_results(), path)
  expect_error(write_results_csv(fake_results(), path), "already exists")
  expect_no_error(write_results_csv(fake_results(), path, overwrite = TRUE))
})

# --- amended workbook ---------------------------------------------------------

test_that("write_results_workbook writes the inputs plus a results sheet", {
  skip_if_no_readxl()
  dir <- withr::local_tempdir()
  path <- file.path(dir, "results.xlsx")
  res <- fake_results()

  expect_identical(write_results_workbook(fake_inputs(), res, path), path)
  expect_true(file.exists(path))
  sheets <- readxl::excel_sheets(path)
  expect_identical(sheets, c("observations", "locations", "target", "results"))

  back <- as.data.frame(readxl::read_excel(path, sheet = "results"))
  expect_identical(nrow(back), nrow(res))
  expect_equal(back$est_median, res$est_median)
  expect_true(all(c("target_id", "loc_id", "cohort", "age") %in% names(back)))
})

test_that("write_results_workbook leaves the original input sheets intact", {
  skip_if_no_readxl()
  dir <- withr::local_tempdir()
  path <- file.path(dir, "results.xlsx")
  inputs <- fake_inputs()
  write_results_workbook(inputs, fake_results(), path)

  # the point of the amended workbook is that the request travels with the
  # answer, so the target sheet must survive verbatim
  back <- as.data.frame(readxl::read_excel(path, sheet = "target"))
  expect_identical(as.character(back$loc_id), as.character(inputs$target$loc_id))
  expect_identical(as.integer(back$age_low), as.integer(inputs$target$age_low))
  expect_identical(as.integer(back$age_high), as.integer(inputs$target$age_high))
})

test_that("write_results_workbook refuses to clobber unless asked", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "results.xlsx")
  write_results_workbook(fake_inputs(), fake_results(), path)
  expect_error(
    write_results_workbook(fake_inputs(), fake_results(), path),
    "already exists"
  )
  expect_no_error(
    write_results_workbook(fake_inputs(), fake_results(), path, overwrite = TRUE)
  )
})

# --- output-flag parsing ------------------------------------------------------

test_that("parse_output_options pulls the output flags out of the arguments", {
  p <- parse_output_options(c(
    "data.xlsx", "--results", "out.xlsx", "--csv=res.csv", "--overwrite"
  ))
  expect_identical(p$options$results, "out.xlsx")
  expect_identical(p$options$csv, "res.csv")
  expect_true(p$options$overwrite)
  expect_identical(p$rest, "data.xlsx")
})

test_that("parse_output_options leaves unrelated arguments alone", {
  p <- parse_output_options(c("in.xlsx", "outdir", "--iter", "500"))
  expect_length(p$options, 0L)
  expect_identical(p$rest, c("in.xlsx", "outdir", "--iter", "500"))
})

test_that("parse_output_options errors on a flag with no value", {
  expect_error(parse_output_options(c("in.xlsx", "--csv")), "--csv needs a value")
  expect_error(parse_output_options(c("in.xlsx", "--results")), "needs a value")
  expect_error(parse_output_options(c("in.xlsx", "--csv=")), "needs a value")
})

test_that("the sampler and output parsers compose without eating each other", {
  args <- c("in.xlsx", "--iter", "500", "--csv", "res.csv", "--chains=2")
  s <- parse_sampler_options(args)
  o <- parse_output_options(s$rest)
  expect_identical(s$overrides$iter, 500L)
  expect_identical(s$overrides$chains, 2L)
  expect_identical(o$options$csv, "res.csv")
  expect_identical(o$rest, "in.xlsx")
})
