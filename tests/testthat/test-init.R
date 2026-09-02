# Tests for imurun_init / imurun_copy_example and the bundled-path helpers.

test_that("imurun_template resolves to a bundled file", {
  path <- imuRUN::imurun_template()
  expect_true(nzchar(path))
  expect_true(file.exists(path))
})

test_that("imurun_init copies the template into a target dir", {
  dir <- tempfile("test_init_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- suppressMessages(imuRUN::imurun_init(dir))
  expect_true(file.exists(dest))
  expect_equal(basename(dest), "imurun_template.xlsx")
})

test_that("imurun_init does not clobber without overwrite", {
  dir <- tempfile("test_init_clobber_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  suppressMessages(imuRUN::imurun_init(dir))
  expect_error(
    suppressMessages(imuRUN::imurun_init(dir)),
    "already exists"
  )
})

test_that("imurun_init overwrites when asked", {
  dir <- tempfile("test_init_overwrite_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  suppressMessages(imuRUN::imurun_init(dir))
  expect_no_error(
    suppressMessages(imuRUN::imurun_init(dir, overwrite = TRUE))
  )
})

test_that("imurun_init supports custom name with or without .xlsx", {
  dir <- tempfile("test_init_custom_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest1 <- suppressMessages(imuRUN::imurun_init(dir, name = "my_template"))
  expect_true(file.exists(dest1))
  expect_equal(basename(dest1), "my_template.xlsx")

  dest2 <- suppressMessages(imuRUN::imurun_init(dir, name = "custom_tmpl.xlsx"))
  expect_true(file.exists(dest2))
  expect_equal(basename(dest2), "custom_tmpl.xlsx")
})

test_that("imurun_copy_example copies the bundled example and supports custom name", {
  skip_if(!nzchar(imuRUN::imurun_example()), "example not installed")
  dir <- tempfile("test_example_")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- suppressMessages(imuRUN::imurun_copy_example(dir))
  expect_true(file.exists(dest))
  expect_equal(basename(dest), "imurun_example.xlsx")

  dest_custom <- suppressMessages(imuRUN::imurun_copy_example(
    dir,
    name = "sample"
  ))
  expect_true(file.exists(dest_custom))
  expect_equal(basename(dest_custom), "sample.xlsx")
})
