# Tests for the .xlsx reader (read_workbook / read_inputs xlsx mode).

skip_if_no_readxl <- function() {
  testthat::skip_if_not_installed("readxl")
}

example_wb <- function() {
  testthat::test_path("fixtures", "example.xlsx")
}

corrupt_wb <- function() {
  testthat::test_path("fixtures", "example_corrupt.xlsx")
}

# --- read_workbook -----------------------------------------------------------

test_that("read_workbook returns the three expected frames", {
  skip_if_no_readxl()
  inputs <- imurun::read_workbook(example_wb())
  expect_named(inputs, c("obs", "pops", "locs"))
  expect_s3_class(inputs$obs, "data.frame")
  expect_true(all(c("obs_id", "positive", "sample_n") %in% names(inputs$obs)))
  expect_true(all(
    c("obs_id", "loc_id", "cohort", "age", "dose") %in% names(inputs$pops)
  ))
  expect_true(all(c("loc_id", "parent_id") %in% names(inputs$locs)))
  expect_gt(nrow(inputs$obs), 0)
  expect_gt(nrow(inputs$pops), 0)
  expect_gt(nrow(inputs$locs), 0)
})

test_that("read_inputs dispatches on .xlsx extension", {
  skip_if_no_readxl()
  via_inputs <- imurun::read_inputs(example_wb())
  via_workbook <- imurun::read_workbook(example_wb())
  expect_equal(via_inputs, via_workbook)
})

test_that("read_workbook reports all missing sheets at once", {
  skip_if_no_readxl()
  skip_if_not_installed("writexl")
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path))
  writexl::write_xlsx(list(observations = data.frame(obs_id = 1)), path)
  err <- tryCatch(imurun::read_workbook(path), error = identity)
  expect_true(inherits(err, "error"))
  # both genuinely-missing sheets are listed in the "missing" clause
  missing_clause <- sub(" \\(found:.*", "", err$message)
  expect_match(missing_clause, "populations")
  expect_match(missing_clause, "locations")
  # the present sheet is NOT listed as missing
  expect_false(grepl("observations", missing_clause))
})

test_that("read_workbook errors when the file does not exist", {
  skip_if_no_readxl()
  expect_error(
    imurun::read_workbook(tempfile(fileext = ".xlsx")),
    "not found"
  )
})

# --- directory mode unchanged ------------------------------------------------

test_that("read_inputs still reads a CSV/RDS directory", {
  dir <- tempfile("test_dir_mode_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  write.csv(
    data.frame(obs_id = 1, positive = 1, sample_n = 10),
    file.path(dir, "observations.csv"), row.names = FALSE
  )
  write.csv(
    data.frame(obs_id = 1, loc_id = 1, cohort = 1, age = 1, dose = 1),
    file.path(dir, "populations.csv"), row.names = FALSE
  )
  write.csv(
    data.frame(loc_id = 1, parent_id = NA),
    file.path(dir, "locations.csv"), row.names = FALSE
  )
  inputs <- imurun::read_inputs(dir)
  expect_named(inputs, c("obs", "pops", "locs"))
})
