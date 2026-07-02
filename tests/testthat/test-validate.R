# Tests for the friendly validation layer (validate_inputs).

example_wb <- function() {
  testthat::test_path("fixtures", "example.xlsx")
}

corrupt_wb <- function() {
  testthat::test_path("fixtures", "example_corrupt.xlsx")
}

# --- clean input passes ------------------------------------------------------

test_that("validate_inputs accepts the clean example workbook", {
  skip_if_not_installed("readxl")
  expect_no_error(imurun::validate_inputs(imurun::read_inputs(example_wb())))
})

test_that("validate_inputs accepts a path directly", {
  skip_if_not_installed("readxl")
  expect_no_error(imurun::validate_inputs(example_wb()))
})

# --- corrupted input fails with friendly messages ----------------------------

test_that("validate_inputs reports the corrupted workbook problems", {
  skip_if_not_installed("readxl")
  err <- tryCatch(
    imurun::validate_inputs(imurun::read_inputs(corrupt_wb())),
    error = identity
  )
  expect_true(inherits(err, "error"))
  # renamed sample_n -> missing required column, named in spreadsheet terms
  expect_match(err$message, "observations")
  expect_match(err$message, "sample_n")
  # non-numeric cohort
  expect_match(err$message, "cohort")
})

test_that("validate_inputs names a missing column and its sheet", {
  # sample_n missing from the (merged) observations sheet
  obs <- data.frame(
    obs_id = 1, loc_id = "A", cohort = 1, age = 1, dose = 1, positive = 1
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  err <- tryCatch(
    imurun::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "\\[observations\\]")
  expect_match(err$message, "sample_n")
})

test_that("validate_inputs catches a loc_id referenced but not defined", {
  obs <- data.frame(
    obs_id = 1, loc_id = "Ghost", cohort = 1, age = 1, dose = 1,
    positive = 1, sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  err <- tryCatch(
    imurun::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  # populations are derived from observations, so the problem is attributed there
  expect_match(err$message, "observations")
})

test_that("validate_inputs catches out-of-range dose", {
  obs <- data.frame(
    obs_id = 1, loc_id = "A", cohort = 1, age = 1, dose = 9,
    positive = 1, sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  err <- tryCatch(
    imurun::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "dose")
})

test_that("validate_inputs collects multiple problems at once", {
  obs <- data.frame(obs_id = 1)            # missing loc/cohort/age/dose/counts
  locs <- data.frame(loc_id = "A")         # missing parent_id
  err <- tryCatch(
    imurun::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "problem")
  expect_match(err$message, "observations")
  expect_match(err$message, "locations")
})
