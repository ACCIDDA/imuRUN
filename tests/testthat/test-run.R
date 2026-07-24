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

test_that("run_fit strips sampler flags before the positional parsing", {
  # With ONLY a sampler flag and no input, stripping leaves no positional args,
  # so usage prints and it returns 0. If the flag were NOT stripped it would be
  # taken as the input path and fail (exit 3), so this discriminates.
  out <- capture.output(res <- imurun::run_fit(c("--iter", "4000")))
  expect_equal(res, 0L)
  expect_true(any(grepl("imurun", out)))
})

test_that("run_fit returns 1 for a malformed sampler flag", {
  # A bad flag value is caught before anything else and reported as a validation
  # (exit 1) failure, not an I/O one.
  result <- suppressMessages(
    imurun::run_fit(c("/nonexistent/path/xyz", "--iter", "abc"))
  )
  expect_equal(result, 1L)
})

test_that("run_fit rejects an unknown/mistyped option instead of pathifying it", {
  # `--iters` is a typo (not `--iter`); it must error (exit 1) rather than
  # silently becoming the output directory with the override dropped.
  result <- suppressMessages(
    imurun::run_fit(c("/nonexistent/xyz", "--iters", "4000"))
  )
  expect_equal(result, 1L)
})
