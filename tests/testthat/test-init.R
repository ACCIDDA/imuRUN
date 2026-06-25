# Tests for imurun_init / imurun_copy_example and the bundled-path helpers.

test_that("imurun_template resolves to a bundled file", {
  path <- imurun::imurun_template()
  expect_true(nzchar(path))
  expect_true(file.exists(path))
})

test_that("imurun_init copies the template into a target dir", {
  dir <- tempfile("test_init_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- suppressMessages(imurun::imurun_init(dir))
  expect_true(file.exists(dest))
  expect_equal(basename(dest), "imurun_template.xlsx")
})

test_that("imurun_init does not clobber without overwrite", {
  dir <- tempfile("test_init_clobber_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  suppressMessages(imurun::imurun_init(dir))
  expect_error(
    suppressMessages(imurun::imurun_init(dir)),
    "already exists"
  )
})

test_that("imurun_init overwrites when asked", {
  dir <- tempfile("test_init_overwrite_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  suppressMessages(imurun::imurun_init(dir))
  expect_no_error(
    suppressMessages(imurun::imurun_init(dir, overwrite = TRUE))
  )
})

test_that("imurun_copy_example copies the bundled example", {
  skip_if(!nzchar(imurun::imurun_example()), "example not installed")
  dir <- tempfile("test_example_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- suppressMessages(imurun::imurun_copy_example(dir))
  expect_true(file.exists(dest))
  expect_equal(basename(dest), "imurun_example.xlsx")
})
