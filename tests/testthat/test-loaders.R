# Tests for the input-loading helpers, ported from imugap-map's
# test-imugap-cli.R. These call the exported imurun functions directly rather
# than slicing them out of the CLI script.

# --- find_input_file ---------------------------------------------------------

test_that("find_input_file reads CSV from directory", {
  dir <- tempfile("test_csv_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  write.csv(
    data.frame(positive = 1:3, sample_n = 10:12),
    file.path(dir, "observations.csv"),
    row.names = FALSE
  )
  result <- imurun::find_input_file(dir, "observations")
  expect_equal(result$positive, 1:3)
  expect_equal(result$sample_n, 10:12)
})

test_that("find_input_file reads RDS from directory", {
  dir <- tempfile("test_rds_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  expected <- data.frame(id = 1:5, parent_id = c(NA, 1, 1, 2, 2))
  saveRDS(expected, file.path(dir, "locations.rds"))
  result <- imurun::find_input_file(dir, "locations")
  expect_equal(result, expected)
})

test_that("find_input_file errors with clear message when file missing", {
  dir <- tempfile("test_missing_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  expect_error(
    imurun::find_input_file(dir, "nonexistent"),
    "Expected 'nonexistent\\.csv' or 'nonexistent\\.rds'"
  )
})

# --- check_all_inputs --------------------------------------------------------

test_that("check_all_inputs reports all missing files at once", {
  dir <- tempfile("test_all_missing_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  expect_error(
    imurun::check_all_inputs(dir),
    "observations.*populations.*locations"
  )
})

test_that("check_all_inputs reports only the actually missing files", {
  dir <- tempfile("test_partial_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  write.csv(
    data.frame(a = 1),
    file.path(dir, "observations.csv"),
    row.names = FALSE
  )
  err <- tryCatch(imurun::check_all_inputs(dir), error = identity)
  expect_true(inherits(err, "error"))
  expect_false(grepl("observations", err$message))
  expect_true(grepl("populations", err$message))
  expect_true(grepl("locations", err$message))
})

test_that("check_all_inputs passes when all files present", {
  dir <- tempfile("test_all_present_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  write.csv(
    data.frame(a = 1),
    file.path(dir, "observations.csv"),
    row.names = FALSE
  )
  write.csv(
    data.frame(a = 1),
    file.path(dir, "populations.csv"),
    row.names = FALSE
  )
  write.csv(
    data.frame(a = 1),
    file.path(dir, "locations.csv"),
    row.names = FALSE
  )
  expect_no_error(imurun::check_all_inputs(dir))
})

# --- load_by_ext -------------------------------------------------------------

test_that("load_by_ext reads CSV correctly", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  write.csv(data.frame(x = 1:3), path, row.names = FALSE)
  result <- imurun::load_by_ext(path)
  expect_equal(result$x, 1:3)
})

test_that("load_by_ext reads RDS correctly", {
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path))
  expected <- data.frame(x = 1:3)
  saveRDS(expected, path)
  expect_equal(imurun::load_by_ext(path), expected)
})

test_that("load_by_ext rejects unsupported extensions", {
  path <- tempfile(fileext = ".json")
  writeLines("{}", path)
  on.exit(unlink(path))
  expect_error(imurun::load_by_ext(path), "Unsupported extension")
})

test_that("load_by_ext includes filename in error for corrupt files", {
  path <- tempfile(fileext = ".rds")
  writeLines("not a valid rds file", path)
  on.exit(unlink(path))
  expect_error(imurun::load_by_ext(path), "Failed to read")
})

# --- read_inputs -------------------------------------------------------------

test_that("read_inputs returns all three inputs", {
  dir <- tempfile("test_read_inputs_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  write.csv(
    data.frame(positive = 1:2, sample_n = 3:4),
    file.path(dir, "observations.csv"),
    row.names = FALSE
  )
  write.csv(
    data.frame(a = 1:2),
    file.path(dir, "populations.csv"),
    row.names = FALSE
  )
  saveRDS(
    data.frame(loc_id = 1, parent_id = NA),
    file.path(dir, "locations.rds")
  )

  inputs <- imurun::read_inputs(dir)
  expect_named(inputs, c("obs", "pops", "locs"))
  expect_equal(inputs$obs$positive, 1:2)
})

test_that("read_inputs errors when an input is missing", {
  dir <- tempfile("test_read_inputs_missing_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  write.csv(
    data.frame(a = 1),
    file.path(dir, "observations.csv"),
    row.names = FALSE
  )
  expect_error(imurun::read_inputs(dir), "Missing input files")
})
