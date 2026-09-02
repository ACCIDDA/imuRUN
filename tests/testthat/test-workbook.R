# Tests for the .xlsx reader (read_workbook / read_inputs xlsx mode).
# Fixtures (example_wb, corrupt_wb, skip_if_no_readxl) come from helper-fixtures.R.

# --- read_workbook -----------------------------------------------------------

test_that("read_workbook returns the expected frames (incl. the target sheet)", {
  skip_if_no_readxl()
  inputs <- imuRUN::read_workbook(example_wb())
  expect_named(inputs, c("obs", "locs", "target", "config"))
  expect_s3_class(inputs$obs, "data.frame")
  expect_true(all(
    c(
      "obs_id",
      "loc_id",
      "year",
      "age_min",
      "age_max",
      "dose",
      "positive",
      "sample_n"
    ) %in%
      names(inputs$obs)
  ))
  expect_true(all(c("loc_id", "parent_id") %in% names(inputs$locs)))
  expect_gt(nrow(inputs$obs), 0)
  expect_gt(nrow(inputs$locs), 0)
  expect_identical(
    imuRUN:::parse_sampler_config(inputs$config)$stan_opts,
    list(iter = 2000L, chains = 4L)
  )
})

test_that("workbook configuration is optional for older input files", {
  skip_if_no_readxl()
  wb <- tempfile(fileext = ".xlsx")
  openxlsx2::write_xlsx(
    list(
      observations = data.frame(
        loc_id = "A",
        year = 2020L,
        age = 1L,
        dose = 1L,
        positive = 1L,
        sample_n = 10L
      ),
      locations = data.frame(loc_id = "A", parent_id = NA),
      target = data.frame(
        loc_id = "A",
        year = 2020L,
        age_low = 1L,
        age_high = 1L
      )
    ),
    file = wb
  )
  inputs <- imuRUN::read_workbook(wb)
  expect_null(inputs$config)
  expect_identical(
    imuRUN:::parse_sampler_config(inputs$config)$stan_opts,
    list()
  )
})

test_that("read_inputs dispatches on .xlsx extension", {
  skip_if_no_readxl()
  via_inputs <- imuRUN::read_inputs(example_wb())
  via_workbook <- imuRUN::read_workbook(example_wb())
  expect_equal(via_inputs, via_workbook)
})

test_that("read_workbook reports all missing sheets at once", {
  skip_if_no_readxl()
  path <- tempfile(fileext = ".xlsx")
  on.exit(unlink(path))
  openxlsx2::write_xlsx(
    list(observations = data.frame(obs_id = 1)),
    file = path
  )
  err <- tryCatch(imuRUN::read_workbook(path), error = identity)
  expect_true(inherits(err, "error"))
  missing_clause <- sub(" \\(found:.*", "", err$message)
  expect_match(missing_clause, "locations")
  expect_false(grepl("observations", missing_clause))
})

test_that("read_workbook errors when the file does not exist", {
  skip_if_no_readxl()
  expect_error(
    imuRUN::read_workbook(tempfile(fileext = ".xlsx")),
    "not found"
  )
})

# --- directory mode ----------------------------------------------------------

test_that("read_inputs reads a CSV directory", {
  dir <- tempfile("test_dir_mode_")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  write.csv(
    data.frame(
      obs_id = 1,
      loc_id = 1,
      year = 2020,
      age = 1,
      dose = 1,
      positive = 1,
      sample_n = 10
    ),
    file.path(dir, "observations.csv"),
    row.names = FALSE
  )
  write.csv(
    data.frame(loc_id = 1, parent_id = NA),
    file.path(dir, "locations.csv"),
    row.names = FALSE
  )
  write.csv(
    data.frame(loc_id = 1, year = 2020, age_low = 1, age_high = 1),
    file.path(dir, "target.csv"),
    row.names = FALSE
  )
  inputs <- imuRUN::read_inputs(dir)
  expect_named(inputs, c("obs", "locs", "target"))
})

# --- friendly headers, auto obs_id, instructions-tab tolerance ---------------

test_that("read_inputs accepts human-readable headers and auto-assigns obs_id", {
  skip_if_no_readxl()
  wb <- tempfile(fileext = ".xlsx")
  openxlsx2::write_xlsx(
    list(
      observations = data.frame(
        Location = c("A", "A"),
        "Observation Year" = c(2020L, 2021L),
        Age = c(5L, 6L),
        Dose = c(2L, 2L),
        Vaccinated = c(3L, 4L),
        Sampled = c(10L, 10L),
        check.names = FALSE
      ),
      locations = data.frame(
        Location = "A",
        "Parent location" = NA,
        check.names = FALSE
      ),
      target = data.frame(
        Location = "A",
        "Target Year" = 2020L,
        "Youngest age" = 1L,
        "Oldest age" = 1L,
        check.names = FALSE
      )
    ),
    file = wb
  )
  inp <- imuRUN::read_inputs(wb)
  expect_true(all(
    c(
      "obs_id",
      "loc_id",
      "year",
      "age_min",
      "age_max",
      "dose",
      "positive",
      "sample_n"
    ) %in%
      names(inp$obs)
  ))
  expect_true(all(c("loc_id", "parent_id") %in% names(inp$locs)))
  expect_identical(inp$obs$obs_id, seq_len(nrow(inp$obs)))
  expect_equal(inp$obs$age_min, c(5L, 6L))
  expect_equal(inp$obs$age_max, c(5L, 6L))
})

test_that("'Youngest age'/'Oldest age' mean the age span on observations", {
  skip_if_no_readxl()
  wb <- tempfile(fileext = ".xlsx")
  openxlsx2::write_xlsx(
    list(
      observations = data.frame(
        Location = "A",
        "Observation Year" = 2020L,
        "Youngest age" = 5L,
        "Oldest age" = 7L,
        Dose = 2L,
        Vaccinated = 3L,
        Sampled = 10L,
        check.names = FALSE
      ),
      locations = data.frame(
        Location = "A",
        "Parent location" = NA,
        check.names = FALSE
      ),
      target = data.frame(
        Location = "A",
        "Target Year" = 2020L,
        "Youngest age" = 1L,
        "Oldest age" = 1L,
        check.names = FALSE
      )
    ),
    file = wb
  )
  inp <- imuRUN::read_inputs(wb)
  expect_equal(inp$obs$age_min, 5L)
  expect_equal(inp$obs$age_max, 7L)
  expect_false("age_low" %in% names(inp$obs))
  expect_equal(inp$target$age_low, 1L)
  expect_equal(inp$target$age_high, 1L)
  expect_false("age_min" %in% names(inp$target))
  expect_equal(inp$obs$year, 2020L)
})

test_that("an instructions sheet is tolerated whether present or absent", {
  skip_if_no_readxl()
  sheets <- list(
    observations = data.frame(
      Location = "A",
      "Observation Year" = 2020L,
      Age = 5L,
      Dose = 2L,
      Vaccinated = 3L,
      Sampled = 10L,
      check.names = FALSE
    ),
    locations = data.frame(
      Location = "A",
      "Parent location" = NA,
      check.names = FALSE
    ),
    target = data.frame(
      Location = "A",
      "Target Year" = 2020L,
      "Youngest age" = 1L,
      "Oldest age" = 1L,
      check.names = FALSE
    )
  )
  with_wb <- tempfile(fileext = ".xlsx")
  without_wb <- tempfile(fileext = ".xlsx")
  openxlsx2::write_xlsx(
    c(list(instructions = data.frame(instructions = "read me")), sheets),
    file = with_wb
  )
  openxlsx2::write_xlsx(sheets, file = without_wb)
  a <- imuRUN::read_inputs(with_wb)
  b <- imuRUN::read_inputs(without_wb)
  expect_identical(names(a$obs), names(b$obs))
  expect_equal(a$obs, b$obs)
})

test_that("write_workbook round-trips through read_workbook", {
  skip_if_no_readxl()
  inputs <- list(
    obs = data.frame(
      obs_id = 1:2,
      loc_id = "A",
      year = 2020L,
      age = 5:6,
      dose = 2L,
      positive = 3:4,
      sample_n = 10L
    ),
    locs = data.frame(loc_id = "A", parent_id = NA),
    target = data.frame(loc_id = "A", year = 2020L, age_low = 1L, age_high = 1L)
  )
  out <- tempfile(fileext = ".xlsx")
  imuRUN::write_workbook(inputs, out)
  back <- imuRUN::read_workbook(out)
  expect_equal(back$obs$loc_id, inputs$obs$loc_id)
  expect_equal(back$locs$loc_id, inputs$locs$loc_id)
  expect_equal(back$target$loc_id, inputs$target$loc_id)
})
