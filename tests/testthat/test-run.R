# Tests for run_fit() and cli_run_fit() argument parsing and early error paths.

test_that("cli_run_fit returns 0 and prints usage for no args or --help", {
  out <- capture.output(result <- imuRUN::cli_run_fit(character(0)))
  expect_equal(result, 0L)
  expect_true(any(grepl("imurun", out)))

  out2 <- capture.output(result2 <- imuRUN::cli_run_fit(c("--help")))
  expect_equal(result2, 0L)
  expect_true(any(grepl("imurun", out2)))

  out3 <- capture.output(result3 <- imuRUN::cli_run_fit(c("-h")))
  expect_equal(result3, 0L)
})

test_that("cli_run_fit returns 3 for non-existent input directory", {
  result <- suppressMessages(imuRUN::cli_run_fit(c("/nonexistent/path/xyz")))
  expect_equal(result, 3L)
})

test_that("cli_run_fit returns 3 when input files are missing", {
  dir <- tempfile("test_run_missing_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  result <- suppressMessages(imuRUN::cli_run_fit(c(dir)))
  expect_equal(result, 3L)
})

test_that("cli_run_fit strips sampler flags before the positional parsing", {
  out <- capture.output(res <- imuRUN::cli_run_fit(c("--iter", "4000")))
  expect_equal(res, 0L)
  expect_true(any(grepl("imurun", out)))
})

test_that("cli_run_fit returns 1 for a malformed sampler flag", {
  result <- suppressMessages(
    imuRUN::cli_run_fit(c("/nonexistent/path/xyz", "--iter", "abc"))
  )
  expect_equal(result, 1L)
})

test_that("run_fit validates workbook configuration before fitting in dryrun mode", {
  wb <- tempfile(fileext = ".xlsx")
  openxlsx2::write_xlsx(
    list(
      configuration = data.frame(Setting = "iter", Value = "not a number"),
      observations = data.frame(
        loc_id = "A",
        year = 2020L,
        age_min = 1L,
        age_max = 1L,
        dose = 1L,
        positive = 1L,
        sample_n = 10L
      ),
      locations = data.frame(loc_id = "A", parent_id = NA),
      target = data.frame(
        loc_id = "A",
        year = 2020L,
        age_low = 1L,
        age_high = 1L
      )
    ),
    file = wb
  )
  expect_error(
    suppressMessages(imuRUN::run_fit(wb, dryrun = TRUE)),
    "whole number"
  )
})

test_that("cli_run_fit rejects an unknown/mistyped option", {
  result <- suppressMessages(
    imuRUN::cli_run_fit(c("/nonexistent/xyz", "--iters", "4000"))
  )
  expect_equal(result, 1L)
})

test_that("run_fit accepts direct R arguments and dryrun = TRUE", {
  skip_if(!nzchar(imuRUN::imurun_example()), "example not installed")
  expect_no_error(
    suppressMessages(imuRUN::run_fit(imuRUN::imurun_example(), dryrun = TRUE))
  )
})

# --- dryrun checks the settings and the dose schedule ------------------------

dryrun_example <- function(edit) {
  inputs <- imuRUN::read_inputs(imuRUN::imurun_example())
  inputs <- edit(inputs)
  tryCatch(
    suppressMessages(imuRUN::run_fit(inputs, dryrun = TRUE)),
    error = identity
  )
}

test_that("dryrun reads a text dose_schedule and allows its extra doses", {
  skip_if(!nzchar(imuRUN::imurun_example()), "example not installed")
  res <- dryrun_example(function(x) {
    x$config <- data.frame(Setting = "dose_schedule", Value = "1, 4, 6")
    # dose 3 is given at age 6, so it can only be counted at older ages
    x$obs$dose[which(x$obs$age_min > 6)[1]] <- 3
    x
  })
  expect_identical(res, 0L)
})

test_that("dryrun reports a setting the options builders reject", {
  skip_if(!nzchar(imuRUN::imurun_example()), "example not installed")
  err <- dryrun_example(function(x) {
    x$config <- data.frame(Setting = "backend", Value = "nope")
    x
  })
  expect_s3_class(err, "error")
  expect_match(err$message, "Input validation failed.*\\[configuration\\]")
})

test_that("the bundled CLI script loads the imuRUN package", {
  script <- system.file("scripts", "imurun.R", package = "imuRUN")
  skip_if(!nzchar(script), "CLI script not installed")
  src <- readLines(script)
  expect_true(any(grepl('requireNamespace("imuRUN"', src, fixed = TRUE)))
  expect_false(any(grepl("imurun::", src, fixed = TRUE)))
})
