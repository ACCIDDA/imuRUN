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
