# Tests for sampler-option configuration (issue #15): workbook settings are the
# primary user surface, while CLI flags remain an automation/compatibility
# override. All toolchain-free (no real fit).

# --- workbook configuration --------------------------------------------------

test_that("parse_sampler_config reads populated settings and skips blanks", {
  config <- data.frame(
    Setting = c("iter", "chains", "seed", "warmup"),
    Value = c("1500", "2", "", NA),
    stringsAsFactors = FALSE
  )
  expect_identical(
    parse_sampler_config(config),
    list(iter = 1500L, chains = 2L)
  )
})

test_that("parse_sampler_config validates the sheet structure and values", {
  expect_error(
    parse_sampler_config(data.frame(option = "iter", value = 10)),
    "Setting.*Value"
  )
  expect_error(
    parse_sampler_config(data.frame(Setting = "iters", Value = 10)),
    "unknown setting"
  )
  expect_error(
    parse_sampler_config(data.frame(Setting = "iter", Value = "2.5")),
    "whole number"
  )
  expect_error(
    parse_sampler_config(data.frame(
      Setting = c("iter", "iter"), Value = c(10, 20)
    )),
    "repeated"
  )
})

test_that("CLI settings override the workbook and both override defaults", {
  config <- data.frame(
    Setting = c("iter", "chains"), Value = c(1000, 2)
  )
  from_workbook <- parse_sampler_config(config)
  from_cli <- parse_sampler_options(c("--iter", "500"))$overrides
  combined <- utils::modifyList(from_workbook, from_cli)
  actual <- utils::modifyList(IMURUN_SAMPLER_DEFAULTS, combined)
  expect_identical(actual, list(iter = 500L, chains = 2L))
})

# --- parse_sampler_options: extraction ---------------------------------------

test_that("parse_sampler_options pulls flags out and leaves the positionals", {
  p <- parse_sampler_options(c("data.xlsx", "--iter", "4000", "--chains=2"))
  expect_identical(p$overrides, list(iter = 4000L, chains = 2L))
  expect_identical(p$rest, "data.xlsx")
})

test_that("parse_sampler_options accepts flags anywhere and both forms", {
  p <- parse_sampler_options(c("--seed", "7", "dir", "out", "--warmup=500"))
  expect_identical(p$overrides, list(seed = 7L, warmup = 500L))
  expect_identical(p$rest, c("dir", "out"))
})

test_that("parse_sampler_options with no flags returns empty overrides", {
  p <- parse_sampler_options(c("dir", "out"))
  expect_identical(p$overrides, list())
  expect_identical(p$rest, c("dir", "out"))
})

test_that("parse_sampler_options handles empty args", {
  p <- parse_sampler_options(character(0))
  expect_identical(p$overrides, list())
  expect_identical(p$rest, character(0))
})

# --- validation (friendly, like the schema errors) ---------------------------

test_that("parse_sampler_options rejects invalid flag values", {
  expect_error(parse_sampler_options(c("--iter", "abc")), "whole number")
  expect_error(parse_sampler_options(c("--iter", "-1")), "whole number")
  expect_error(parse_sampler_options(c("--chains", "2.5")), "whole number")
  expect_error(parse_sampler_options(c("--iter=x")), "whole number")
  expect_error(parse_sampler_options(c("--iter=")), "whole number") # empty value
  # a value that looks like another flag is consumed and rejected
  expect_error(parse_sampler_options(c("--iter", "--chains")), "whole number")
  expect_error(parse_sampler_options(c("--iter", "0")), "at least 1") # count minimum
  expect_error(parse_sampler_options(c("--iter", "99999999999")), "too large")
})

test_that("parse_sampler_options errors when a flag has no value", {
  expect_error(parse_sampler_options(c("data.xlsx", "--iter")), "needs a value")
})

test_that("--seed accepts 0 (a valid, conventional seed)", {
  expect_identical(
    parse_sampler_options(c("--seed", "0"))$overrides, list(seed = 0L)
  )
})

test_that("a repeated flag takes the last value", {
  expect_identical(
    parse_sampler_options(c("--iter", "1", "--iter", "2"))$overrides,
    list(iter = 2L)
  )
})

# --- merge with defaults: overrides win, unset options fall back --------------

test_that("overrides merge over the imurun sampler defaults", {
  merged <- function(args) {
    utils::modifyList(
      IMURUN_SAMPLER_DEFAULTS, parse_sampler_options(args)$overrides
    )
  }
  expect_identical(merged(character(0)), list(iter = 2000L, chains = 4L))
  expect_identical(merged(c("--iter", "500")), list(iter = 500L, chains = 4L))
  expect_identical(
    merged(c("--chains", "2", "--seed", "9")),
    list(iter = 2000L, chains = 2L, seed = 9L)
  )
})

# --- overrides reach the constructed stan_options (issue #15) -----------------

test_that("overrides flow through to imuGAP::stan_options()", {
  skip_if_not_installed("imuGAP")
  build <- function(args) {
    ov <- parse_sampler_options(args)$overrides
    do.call(imuGAP::stan_options, utils::modifyList(IMURUN_SAMPLER_DEFAULTS, ov))
  }
  base <- build(character(0))
  expect_equal(base$iter, 2000L)
  expect_equal(base$chains, 4L)

  o <- build(c("data.xlsx", "--iter", "4000", "--chains", "2", "--seed", "7"))
  expect_equal(o$iter, 4000L)
  expect_equal(o$chains, 2L)
  expect_equal(o$seed, 7L)
})
