# Tests for install_cli(), ported from imugap-map's test-imugap-cli.R.
# Skipped on Windows, as upstream, since symlinks are unsupported there.

test_that("install_cli creates symlink to correct script", {
  skip_on_os("windows")
  dir <- tempfile("test_install_cli_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  result <- imurun::install_cli(path = dir)
  link <- file.path(dir, "imurun")
  expect_true(result)
  expect_true(file.exists(link))
  target <- Sys.readlink(link)
  expected <- system.file("scripts", "imurun.R", package = "imurun")
  expect_equal(normalizePath(target), normalizePath(expected))
})

test_that("install_cli errors for non-existent directory", {
  skip_on_os("windows")
  expect_error(
    imurun::install_cli(path = "/nonexistent/path/xyz"),
    "does not exist"
  )
})

test_that("install_cli replaces existing file at target", {
  skip_on_os("windows")
  dir <- tempfile("test_install_replace_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  writeLines("old", file.path(dir, "imurun"))
  imurun::install_cli(path = dir)
  expect_true(nzchar(Sys.readlink(file.path(dir, "imurun"))))
})
