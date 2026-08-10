# Tests for the friendly validation layer (validate_inputs).
# Fixtures (example_wb, corrupt_wb) come from helper-fixtures.R.

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

# --- observation age spans (issue #36) ---------------------------------------

test_that("a single-age observation expands to one weight-1 population row", {
  obs <- data.frame(
    obs_id = 1, loc_id = "A", cohort = 5, age_min = 7, age_max = 7, dose = 2
  )
  pops <- imurun:::build_populations(obs)
  expect_equal(nrow(pops), 1L)
  expect_equal(pops$age, 7L)
  expect_equal(pops$cohort, 5L)
  expect_equal(pops$weight, 1)
})

test_that("a multi-age observation expands to an equally weighted mixture", {
  obs <- data.frame(
    obs_id = 1, loc_id = "A", cohort = 3, age_min = 5, age_max = 7, dose = 2
  )
  pops <- imurun:::build_populations(obs)

  expect_equal(nrow(pops), 3L)
  expect_equal(pops$age, 5:7)
  # Equal weights, and imuGAP requires them to sum to 1 within an obs_id.
  expect_equal(pops$weight, rep(1 / 3, 3))
  expect_equal(sum(pops$weight), 1)
  # The rows all belong to the one observation, which carries the counts.
  expect_equal(unique(pops$obs_id), 1)
})

test_that("the expansion holds age + cohort constant off the oldest age", {
  obs <- data.frame(
    obs_id = 1, loc_id = "A", cohort = 3, age_min = 5, age_max = 7, dose = 2
  )
  pops <- imurun:::build_populations(obs)
  # `cohort` is the reference cohort, that of age_max; younger ages step up so
  # the row describes one moment in time (the same relation create_target()
  # applies in snapshot mode).
  expect_equal(pops$cohort[pops$age == 7L], 3L)
  expect_true(all(pops$age + pops$cohort == 10L))
})

test_that("build_populations reproduces imuGAP's own simulated populations", {
  skip_if_not_installed("imuGAP")
  pop <- as.data.frame(imuGAP::populations_sim)
  # Collapse each observation to the span an imurun sheet carries, then expand
  # it again: imuGAP's simulated populations are exactly the shape this feature
  # describes, so the round trip must be lossless.
  spans <- do.call(rbind, lapply(split(pop, pop$obs_id), function(d) {
    data.frame(
      obs_id = d$obs_id[1L], loc_id = d$loc_id[1L],
      cohort = d$cohort[which.max(d$age)],
      age_min = min(d$age), age_max = max(d$age),
      dose = d$dose[1L], stringsAsFactors = FALSE
    )
  }))
  rebuilt <- imurun:::build_populations(spans)

  key <- function(d) order(d$obs_id, d$age)
  rebuilt <- rebuilt[key(rebuilt), c("obs_id", "loc_id", "cohort", "age",
                                     "dose", "weight")]
  original <- pop[key(pop), c("obs_id", "loc_id", "cohort", "age",
                              "dose", "weight")]
  expect_equal(nrow(rebuilt), nrow(original))
  expect_equal(as.numeric(rebuilt$age), as.numeric(original$age))
  expect_equal(as.numeric(rebuilt$cohort), as.numeric(original$cohort))
  expect_equal(as.numeric(rebuilt$weight), as.numeric(original$weight))
})

test_that("validate_inputs rejects an inverted age span, naming the row", {
  obs <- data.frame(
    obs_id = 1:2, loc_id = "A", cohort = 1, age_min = c(1, 9),
    age_max = c(1, 4), dose = 1, positive = 1, sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  err <- tryCatch(
    imurun::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "age_min must be <= age_max")
  expect_match(err$message, "row\\(s\\): 2")
})

test_that("validate_inputs accepts the single-age `age` shorthand", {
  obs <- data.frame(
    obs_id = 1, loc_id = "A", cohort = 1, age = 1, dose = 1,
    positive = 1, sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  expect_no_error(imurun::validate_inputs(list(obs = obs, locs = locs)))
})

test_that("validation bounds cover the cohorts the expansion derives", {
  # The span reaches cohort 3 + (7 - 5) = 5, above the sheet's own `cohort`
  # column. Bounding by the sheet would reject rows the expansion just made.
  obs <- data.frame(
    obs_id = 1, loc_id = "A", cohort = 3, age_min = 5, age_max = 7,
    dose = 1, positive = 1, sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  expect_no_error(imurun::validate_inputs(list(obs = obs, locs = locs)))
})
