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

# --- silent fit-failure detection (no Stan toolchain required) ---------------
# imuGAP::sampling() returns an imugap_fit even when the Stan sampler fails to
# initialize: a stanfit in mode 2 with an empty @sim. run_fit() must treat that
# as a model failure (exit 2), not silently write an empty fit.rds. A real fit
# is exercised in the gated integration suite (#19); here we unit-test the
# discriminator with a minimal stand-in for a stanfit.

test_that("stanfit_drew_samples distinguishes a real fit from a silent failure", {
  methods::setClass(
    "fake_stanfit",
    representation(mode = "integer", sim = "list")
  )
  on.exit(methods::removeClass("fake_stanfit"), add = TRUE)

  # imuGAP's silent init-failure shape: mode 2, no draws.
  failed <- methods::new("fake_stanfit", mode = 2L, sim = list())
  expect_false(imurun:::stanfit_drew_samples(failed))

  # a completed fit: mode 0 with stored draws.
  ok <- methods::new("fake_stanfit", mode = 0L, sim = list(samples = 1))
  expect_true(imurun:::stanfit_drew_samples(ok))

  # a malformed / missing stanfit must report FALSE, not error.
  expect_false(imurun:::stanfit_drew_samples(NULL))
})
