# Tests for the read_inputs() entry point: it reads a .xlsx workbook or
# normalizes an in-memory inputs list, and rejects anything else.

# --- read_inputs -------------------------------------------------------------

test_that("read_inputs normalizes an in-memory inputs list", {
  inputs <- imuRUN::read_inputs(list(
    obs = data.frame(positive = 1:2, sample_n = 3:4),
    locs = data.frame(loc_id = 1, parent_id = NA)
  ))
  expect_true(all(c("obs", "locs") %in% names(inputs)))
  expect_equal(inputs$obs$positive, 1:2)
})

test_that("read_inputs rejects a directory", {
  dir <- tempfile("test_read_inputs_dir_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  expect_error(imuRUN::read_inputs(dir), "not a .xlsx workbook")
})

test_that("read_inputs rejects a non-.xlsx file", {
  path <- tempfile(fileext = ".csv")
  write.csv(data.frame(a = 1), path, row.names = FALSE)
  on.exit(unlink(path))
  expect_error(imuRUN::read_inputs(path), "not a .xlsx workbook")
})

test_that("read_inputs requires a single path string", {
  expect_error(imuRUN::read_inputs(c("a.xlsx", "b.xlsx")), "single string")
})
