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

test_that("read_workbook returns the expected frames (incl. the target sheet)", {
  skip_if_no_readxl()
  inputs <- imurun::read_workbook(example_wb())
  expect_named(inputs, c("obs", "locs", "target"))
  expect_s3_class(inputs$obs, "data.frame")
  expect_true(all(
    c("obs_id", "loc_id", "cohort", "age", "dose", "positive", "sample_n")
    %in% names(inputs$obs)
  ))
  expect_true(all(c("loc_id", "parent_id") %in% names(inputs$locs)))
  expect_gt(nrow(inputs$obs), 0)
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
  # the genuinely-missing required sheet is listed in the "missing" clause
  missing_clause <- sub(" \\(found:.*", "", err$message)
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
    data.frame(
      obs_id = 1, loc_id = 1, cohort = 1, age = 1, dose = 1,
      positive = 1, sample_n = 10
    ),
    file.path(dir, "observations.csv"), row.names = FALSE
  )
  write.csv(
    data.frame(loc_id = 1, parent_id = NA),
    file.path(dir, "locations.csv"), row.names = FALSE
  )
  inputs <- imurun::read_inputs(dir)
  expect_named(inputs, c("obs", "locs"))
})

# --- friendly headers, auto obs_id, instructions-tab tolerance (issue #25) ----

test_that("read_inputs accepts human-readable headers and auto-assigns obs_id", {
  skip_if_no_readxl()
  skip_if_not_installed("writexl")
  wb <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(
    list(
      observations = data.frame(
        Location = c("A", "A"), "Birth cohort" = c(5L, 6L), Age = c(5L, 6L),
        Dose = c(2L, 2L), Vaccinated = c(3L, 4L), Sampled = c(10L, 10L),
        check.names = FALSE
      ),
      locations = data.frame(
        Location = "A", "Parent location" = NA, check.names = FALSE
      )
    ),
    wb
  )
  inp <- imurun::read_inputs(wb)
  expect_true(all(
    c("obs_id", "loc_id", "cohort", "age", "dose", "positive", "sample_n") %in%
      names(inp$obs)
  ))
  expect_true(all(c("loc_id", "parent_id") %in% names(inp$locs)))
  expect_identical(inp$obs$obs_id, seq_len(nrow(inp$obs)))
})

test_that("an instructions sheet is tolerated whether present or absent", {
  skip_if_no_readxl()
  skip_if_not_installed("writexl")
  sheets <- list(
    observations = data.frame(
      Location = "A", "Birth cohort" = 5L, Age = 5L, Dose = 2L,
      Vaccinated = 3L, Sampled = 10L, check.names = FALSE
    ),
    locations = data.frame(
      Location = "A", "Parent location" = NA, check.names = FALSE
    )
  )
  with_wb <- tempfile(fileext = ".xlsx")
  without_wb <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(
    c(list(instructions = data.frame(instructions = "read me")), sheets), with_wb
  )
  writexl::write_xlsx(sheets, without_wb)
  a <- imurun::read_inputs(with_wb)
  b <- imurun::read_inputs(without_wb)
  expect_identical(names(a$obs), names(b$obs))
  expect_equal(a$obs, b$obs)
})

test_that("write_workbook round-trips through read_workbook", {
  skip_if_no_readxl()
  skip_if_not_installed("writexl")
  inputs <- list(
    obs = data.frame(obs_id = 1:2, loc_id = "A", cohort = 5L, age = 5:6,
                     dose = 2L, positive = 3:4, sample_n = 10L),
    locs = data.frame(loc_id = "A", parent_id = NA)
  )
  out <- tempfile(fileext = ".xlsx")
  imurun::write_workbook(inputs, out)
  back <- imurun::read_workbook(out)
  expect_equal(back$obs$loc_id, inputs$obs$loc_id)
  expect_equal(back$locs$loc_id, inputs$locs$loc_id)
})
