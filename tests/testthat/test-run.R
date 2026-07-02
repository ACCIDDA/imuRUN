# Tests for run_fit() argument parsing and early error paths, ported from
# imugap-map's test-imugap-cli.R (formerly main()). These exercise only the
# fast, no-Stan code paths; a real model-fit test is deferred to a later issue.

test_that("run_fit returns 0 and prints usage for no args", {
  out <- capture.output(result <- imurun::run_fit(character(0)))
  expect_equal(result, 0L)
  expect_true(any(grepl("imurun", out)))
})

test_that("run_fit returns 0 and prints usage for --help", {
  out <- capture.output(result <- imurun::run_fit(c("--help")))
  expect_equal(result, 0L)
  expect_true(any(grepl("imurun", out)))
})

test_that("run_fit returns 0 and prints usage for -h alone", {
  out <- capture.output(result <- imurun::run_fit(c("-h")))
  expect_equal(result, 0L)
})

test_that("run_fit returns 3 for non-existent input directory", {
  result <- suppressMessages(imurun::run_fit(c("/nonexistent/path/xyz")))
  expect_equal(result, 3L)
})

test_that("run_fit returns 3 when input files are missing", {
  dir <- tempfile("test_run_missing_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  result <- suppressMessages(imurun::run_fit(c(dir)))
  expect_equal(result, 3L)
})

# --- fit-failure handling (no Stan toolchain required) -----------------------
# imuGAP::sampling() raises a typed `imugap_no_draws` error when the sampler
# fails to initialize (no draws), rather than returning an empty fit. run_fit()
# must surface that as a model failure (exit 2), not write an empty fit.rds.
# Mock sampling so the failure path runs without a Stan toolchain; the real
# fit is exercised in the gated integration suite (#19).

test_that("run_fit reports exit 2 when sampling produces no draws", {
  skip_if_not_installed("readxl")
  wb <- testthat::test_path("fixtures", "example.xlsx")
  out <- tempfile("run_no_draws_")
  dir.create(out)
  on.exit(unlink(out, recursive = TRUE), add = TRUE)

  res <- testthat::with_mocked_bindings(
    suppressMessages(imurun::run_fit(c(wb, out))),
    sampling = function(...) {
      stop(errorCondition(
        "the Stan sampler produced no draws",
        class = "imugap_no_draws"
      ))
    },
    .package = "imuGAP"
  )
  expect_equal(res, 2L)
  expect_false(file.exists(file.path(out, "fit.rds")))
})
