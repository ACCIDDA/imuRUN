# Tests for install_cli(). Runs on all platforms: Unix installs a symlink,
# Windows writes an imurun.cmd shim (issue #16).

test_that("install_cli installs a launcher pointing at the bundled script", {
  dir <- tempfile("test_install_cli_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  result <- install_cli(path = dir)
  expect_true(result)

  script <- system.file("scripts", "imurun.R", package = "imuRUN")
  if (.Platform$OS.type == "windows") {
    shim <- file.path(dir, "imurun.cmd")
    expect_true(file.exists(shim))
    lines <- readLines(shim)
    # the shim runs the bundled script through Rscript
    expect_true(any(grepl("Rscript", lines, fixed = TRUE)))
    expect_true(any(grepl(basename(script), lines, fixed = TRUE)))
  } else {
    link <- file.path(dir, "imurun")
    expect_true(file.exists(link))
    expect_equal(normalizePath(Sys.readlink(link)), normalizePath(script))
  }
})

test_that("install_cli errors for non-existent directory", {
  expect_error(
    imuRUN::install_cli(path = file.path(tempdir(), "nonexistent_xyz_123")),
    "does not exist"
  )
})

test_that("install_cli replaces an existing launcher at the target", {
  dir <- tempfile("test_install_replace_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  is_windows <- .Platform$OS.type == "windows"
  target <- file.path(dir, if (is_windows) "imurun.cmd" else "imurun")
  writeLines("old", target)

  imuRUN::install_cli(path = dir)

  if (is_windows) {
    # the stale contents are replaced by the shim
    expect_true(any(grepl("Rscript", readLines(target), fixed = TRUE)))
  } else {
    expect_true(nzchar(Sys.readlink(target)))
  }
})
