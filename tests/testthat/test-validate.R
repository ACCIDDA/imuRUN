# Tests for the friendly validation layer (validate_inputs).
# Fixtures (example_wb, corrupt_wb) come from helper-fixtures.R.

# --- clean input passes ------------------------------------------------------

test_that("validate_inputs accepts the clean example workbook and returns TRUE", {
  res <- imuRUN::validate_inputs(imuRUN::read_inputs(example_wb()))
  expect_true(isTRUE(res))
})

test_that("validate_inputs accepts a path directly", {
  expect_true(isTRUE(imuRUN::validate_inputs(example_wb())))
})

# --- corrupted input fails with friendly messages ----------------------------

test_that("validate_inputs reports the corrupted workbook problems", {
  err <- tryCatch(
    imuRUN::validate_inputs(imuRUN::read_inputs(corrupt_wb())),
    error = identity
  )
  expect_true(inherits(err, "error"))
  # renamed sample_n -> missing required column, named in spreadsheet terms
  expect_match(err$message, "observations")
  expect_match(err$message, "sample_n")
  # non-numeric year
  expect_match(err$message, "year")
})

test_that("validate_inputs names a missing column and its sheet", {
  # sample_n missing from the observations sheet
  obs <- data.frame(
    obs_id = 1,
    loc_id = "A",
    year = 2020,
    age = 1,
    dose = 1,
    positive = 1
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  err <- tryCatch(
    imuRUN::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "\\[observations\\]")
  expect_match(err$message, "sample_n")
})

test_that("validate_inputs catches a loc_id referenced but not defined", {
  obs <- data.frame(
    obs_id = 1,
    loc_id = "Ghost",
    year = 2020,
    age = 1,
    dose = 1,
    positive = 1,
    sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  err <- tryCatch(
    imuRUN::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "observations")
})

test_that("validate_inputs catches out-of-range dose", {
  obs <- data.frame(
    obs_id = 1,
    loc_id = "A",
    year = 2020,
    age = 1,
    dose = 9,
    positive = 1,
    sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  err <- tryCatch(
    imuRUN::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "dose")
})

test_that("validate_inputs collects multiple problems at once", {
  obs <- data.frame(obs_id = 1) # missing loc/year/age/dose/counts
  locs <- data.frame(loc_id = "A") # missing parent_id
  err <- tryCatch(
    imuRUN::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "problem")
  expect_match(err$message, "observations")
  expect_match(err$message, "locations")
})

# --- observation age spans ---------------------------------------------------

test_that("a single-age observation expands to one weight-1 population row", {
  obs <- data.frame(
    obs_id = 1,
    loc_id = "A",
    year = 12,
    age_min = 7,
    age_max = 7,
    dose = 2
  )
  pops <- imuRUN:::build_populations(obs)
  expect_equal(nrow(pops), 1L)
  expect_equal(pops$age, 7L)
  expect_equal(pops$cohort, 5L) # cohort is year minus age (12 - 7 = 5)
  expect_equal(pops$weight, 1)
})

test_that("a multi-age observation expands to an equally weighted mixture", {
  obs <- data.frame(
    obs_id = 1,
    loc_id = "A",
    year = 10,
    age_min = 5,
    age_max = 7,
    dose = 2
  )
  pops <- imuRUN:::build_populations(obs)

  expect_equal(nrow(pops), 3L)
  expect_equal(pops$age, 5:7)
  # Equal weights, and imuGAP requires them to sum to 1 within an obs_id.
  expect_equal(pops$weight, rep(1 / 3, 3))
  expect_equal(sum(pops$weight), 1)
  # The rows all belong to the one observation, which carries the counts.
  expect_equal(unique(pops$obs_id), 1)
})

test_that("the expansion holds age + cohort constant (= year)", {
  obs <- data.frame(
    obs_id = 1,
    loc_id = "A",
    year = 10,
    age_min = 5,
    age_max = 7,
    dose = 2
  )
  pops <- imuRUN:::build_populations(obs)
  expect_equal(pops$cohort[pops$age == 7L], 3L)
  expect_true(all(pops$age + pops$cohort == 10L))
})

test_that("build_populations reproduces imuGAP's own simulated populations", {
  skip_if_not_installed("imuGAP")
  pop <- as.data.frame(imuGAP::populations_sim)
  spans <- do.call(
    rbind,
    lapply(split(pop, pop$obs_id), function(d) {
      data.frame(
        obs_id = d$obs_id[1L],
        loc_id = d$loc_id[1L],
        year = d$cohort[1L] + d$age[1L],
        age_min = min(d$age),
        age_max = max(d$age),
        dose = d$dose[1L],
        stringsAsFactors = FALSE
      )
    })
  )
  rebuilt <- imuRUN:::build_populations(spans)

  key <- function(d) order(d$obs_id, d$age)
  rebuilt <- rebuilt[
    key(rebuilt),
    c("obs_id", "loc_id", "cohort", "age", "dose", "weight")
  ]
  original <- pop[
    key(pop),
    c("obs_id", "loc_id", "cohort", "age", "dose", "weight")
  ]
  expect_equal(nrow(rebuilt), nrow(original))
  expect_equal(as.numeric(rebuilt$age), as.numeric(original$age))
  expect_equal(as.numeric(rebuilt$cohort), as.numeric(original$cohort))
  expect_equal(as.numeric(rebuilt$weight), as.numeric(original$weight))
})

test_that("validate_inputs rejects an inverted age span, naming the row", {
  obs <- data.frame(
    obs_id = 1:2,
    loc_id = "A",
    year = 2020,
    age_min = c(1, 9),
    age_max = c(1, 4),
    dose = 1,
    positive = 1,
    sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  err <- tryCatch(
    imuRUN::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "age_min must be <= age_max")
  expect_match(err$message, "row\\(s\\): 2")
})

test_that("validate_inputs rejects fractional age endpoints before coercion", {
  obs <- data.frame(
    obs_id = 1,
    loc_id = "A",
    year = 2020,
    age_min = 5.9,
    age_max = 7.9,
    dose = 1,
    positive = 1,
    sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)

  err <- tryCatch(
    imuRUN::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "age_min.*whole numbers")
  expect_match(err$message, "age_max.*whole numbers")
})

test_that("validate_inputs bounds age spans before allocating populations", {
  obs <- data.frame(
    obs_id = 1,
    loc_id = "A",
    year = 2020,
    age_min = 1,
    age_max = 1000000000,
    dose = 1,
    positive = 1,
    sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)

  expect_error(
    imuRUN::validate_inputs(list(obs = obs, locs = locs), max_age = 100),
    "age span out of range"
  )
  expect_error(
    imuRUN::validate_inputs(list(obs = obs, locs = locs)),
    "more than 1000000 population rows"
  )
})

test_that("validate_inputs accepts the single-age `age` shorthand", {
  obs <- data.frame(
    obs_id = 1,
    loc_id = "A",
    year = 2020,
    age = 1,
    dose = 1,
    positive = 1,
    sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  expect_true(isTRUE(imuRUN::validate_inputs(list(obs = obs, locs = locs))))
})

test_that("validation checks derived cohort is positive", {
  obs <- data.frame(
    obs_id = 1,
    loc_id = "A",
    year = 5,
    age_min = 6,
    age_max = 8,
    dose = 1,
    positive = 1,
    sample_n = 10
  )
  locs <- data.frame(loc_id = "A", parent_id = NA)
  err <- tryCatch(
    imuRUN::validate_inputs(list(obs = obs, locs = locs)),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "greater than oldest age")
})
