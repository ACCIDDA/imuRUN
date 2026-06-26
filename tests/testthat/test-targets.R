# Tests for the Stan-free core of the by-target prediction feature (#14):
# parse_loc_list, expand_targets, validate_targets, summarize_targets. None of
# these need a Stan toolchain; the real predict/gqs path is gated under #19.

# --- parse_loc_list ----------------------------------------------------------

test_that("parse_loc_list splits on ; and ,, trims, and drops empties", {
  expect_equal(imurun:::parse_loc_list("A"), "A")
  expect_equal(imurun:::parse_loc_list("A; B ,C"), c("A", "B", "C"))
  expect_equal(imurun:::parse_loc_list("A;;B"), c("A", "B"))
  expect_equal(imurun:::parse_loc_list(""), character(0))
  expect_equal(imurun:::parse_loc_list(NA), character(0))
})

# --- expand_targets ----------------------------------------------------------

test_that("expand_targets fans out locations x age span, defaulting a blank dose", {
  tg <- data.frame(
    loc_id = "A;B",
    cohort = 5,
    age_low = 5,
    age_high = 7,
    stringsAsFactors = FALSE
  )
  ex <- expand_targets(tg, default_dose = 2L)

  expect_equal(nrow(ex), 6L) # 2 locations x 3 ages
  expect_equal(sort(unique(ex$loc_id)), c("A", "B"))
  expect_equal(sort(unique(ex$age)), 5:7)
  expect_true(all(ex$cohort == 5L))
  expect_true(all(ex$dose == 2L)) # blank dose -> default_dose
  expect_true(all(ex$weight == 1))
  expect_equal(ex$obs_id, 1:6) # unique key for grouping draws
  expect_equal(
    names(ex),
    c("obs_id", "target_id", "loc_id", "cohort", "age", "dose", "weight")
  )
})

test_that("expand_targets honours an explicit dose and a target_id label", {
  tg <- data.frame(
    loc_id = "A",
    cohort = 5,
    age_low = 5,
    age_high = 5,
    dose = 1,
    target_id = "demo",
    stringsAsFactors = FALSE
  )
  ex <- expand_targets(tg, default_dose = 2L)
  expect_equal(nrow(ex), 1L)
  expect_equal(ex$dose, 1L)
  expect_equal(ex$target_id, "demo")
})

test_that("expand_targets de-duplicates identical target identities across rows", {
  tg <- data.frame(
    loc_id = c("A", "A"),
    cohort = c(5, 5),
    age_low = c(5, 5),
    age_high = c(5, 5),
    stringsAsFactors = FALSE
  )
  ex <- expand_targets(tg, default_dose = 2L)
  expect_equal(nrow(ex), 1L)
  expect_equal(ex$obs_id, 1L)
})

# --- validate_targets --------------------------------------------------------

test_that("validate_targets accepts a clean sheet", {
  ok <- data.frame(
    loc_id = "A;B",
    cohort = 5,
    age_low = 5,
    age_high = 7,
    dose = 2,
    target_id = "demo",
    stringsAsFactors = FALSE
  )
  expect_no_error(
    validate_targets(ok, loc_ids = c("A", "B"), max_cohort = 15, max_age = 8)
  )
})

test_that("validate_targets reports a missing column and a non-numeric cohort", {
  bad <- data.frame(
    loc_id = "A",
    cohort = "x",
    age_low = 1, # age_high missing, cohort non-numeric
    stringsAsFactors = FALSE
  )
  err <- tryCatch(
    validate_targets(bad, loc_ids = "A", max_cohort = 15, max_age = 8),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "\\[target\\]")
  expect_match(err$message, "age_high")
  expect_match(err$message, "cohort")
})

test_that("validate_targets collects unknown loc, bad span, and out-of-range values", {
  bad <- data.frame(
    loc_id = "A;Nowhere",
    cohort = 99,
    age_low = 3,
    age_high = 2,
    dose = 9,
    stringsAsFactors = FALSE
  )
  err <- tryCatch(
    validate_targets(bad, loc_ids = c("A", "B"), max_cohort = 15, max_age = 8),
    error = identity
  )
  expect_true(inherits(err, "error"))
  expect_match(err$message, "Nowhere") # unknown location
  expect_match(err$message, "cohort") # cohort above its max
  expect_match(err$message, "age_low must be <= age_high") # inverted span
  expect_match(err$message, "dose") # dose above its max
})

# --- summarize_targets -------------------------------------------------------

test_that("summarize_targets reduces draws to median + CI per target", {
  d1 <- data.frame(
    obs_id = 1L,
    target_id = "t1",
    loc_id = "A",
    cohort = 5L,
    age = 5L,
    dose = 2L,
    p_obs = seq(0, 1, length.out = 201)
  )
  d2 <- data.frame(
    obs_id = 2L,
    target_id = "t2",
    loc_id = "B",
    cohort = 5L,
    age = 6L,
    dose = 2L,
    p_obs = seq(0.2, 0.4, length.out = 201)
  )
  s <- summarize_targets(rbind(d1, d2), ci_level = 0.95)

  expect_equal(nrow(s), 2L)
  expect_equal(
    names(s),
    c(
      "target_id",
      "loc_id",
      "cohort",
      "age",
      "dose",
      "n_draws",
      "est_median",
      "est_lower",
      "est_upper",
      "ci_level"
    )
  )
  expect_equal(s$n_draws, c(201L, 201L))
  expect_equal(s$est_median[1], stats::median(d1$p_obs))
  expect_equal(s$est_lower[1], unname(stats::quantile(d1$p_obs, 0.025)))
  expect_equal(s$est_upper[1], unname(stats::quantile(d1$p_obs, 0.975)))
  expect_equal(s$ci_level, c(0.95, 0.95))
  expect_true(all(s$est_lower <= s$est_median & s$est_median <= s$est_upper))
})

test_that("summarize_targets respects a non-default ci_level and validates input", {
  d <- data.frame(
    obs_id = 1L,
    loc_id = "A",
    p_obs = seq(0, 1, length.out = 101)
  )
  s50 <- summarize_targets(d, ci_level = 0.5)
  expect_equal(s50$est_lower, unname(stats::quantile(d$p_obs, 0.25)))
  expect_equal(s50$est_upper, unname(stats::quantile(d$p_obs, 0.75)))

  expect_error(summarize_targets(data.frame(x = 1), ci_level = 0.95), "obs_id")
  expect_error(summarize_targets(d, ci_level = 1.5), "ci_level")
})
