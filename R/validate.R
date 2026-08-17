#' Check required columns and report them in spreadsheet terms
#'
#' @description Compares the columns present on one input frame against the
#' required [IMURUN_SCHEMA] columns for that sheet, returning a character vector
#' of human-readable problem messages (empty if none). Used by
#' [validate_inputs()].
#'
#' @param df data.frame; the sheet contents.
#' @param sheet character; one of `"observations"`, `"populations"`,
#'   `"locations"` (or any sheet name used in the message).
#' @param required character; the required column names. Defaults to the
#'   [IMURUN_SCHEMA] entry for `sheet`; pass an explicit vector to check a sheet
#'   not in `IMURUN_SCHEMA` (e.g. the `target` sheet).
#'
#' @return character vector of problem messages (possibly length zero).
#'
#' @keywords internal
check_sheet_columns <- function(df, sheet, required = IMURUN_SCHEMA[[sheet]]) {
  missing <- setdiff(required, names(df))
  if (length(missing) == 0) {
    return(character(0))
  }
  sprintf(
    "[%s] missing required column(s): %s (found: %s)",
    sheet,
    paste(missing, collapse = ", "),
    if (length(names(df))) paste(names(df), collapse = ", ") else "<none>"
  )
}

#' Check that a count-like column is numeric, in spreadsheet terms
#'
#' @param df data.frame; sheet contents.
#' @param sheet character; sheet name (for messages).
#' @param col character; column to check.
#'
#' @return character vector of problem messages (possibly length zero).
#'
#' @keywords internal
check_numeric_column <- function(df, sheet, col) {
  if (!col %in% names(df)) {
    return(character(0))
  }
  values <- df[[col]]
  if (is.numeric(values)) {
    return(character(0))
  }
  coerced <- suppressWarnings(as.numeric(as.character(values)))
  bad_rows <- which(
    is.na(coerced) & !is.na(values) & nzchar(trimws(as.character(values)))
  )
  if (length(bad_rows) == 0) {
    return(character(0))
  }
  sprintf(
    "[%s] column '%s' must be numeric; non-numeric value(s) at row(s): %s",
    sheet,
    col,
    paste(utils::head(bad_rows, 20L), collapse = ", ")
  )
}

#' Check that a numeric column contains only whole numbers
#'
#' @param df data.frame; sheet contents.
#' @param sheet character; sheet name (for messages).
#' @param col character; column to check.
#'
#' @return character vector of problem messages (possibly length zero).
#'
#' @keywords internal
check_whole_number_column <- function(df, sheet, col) {
  if (!col %in% names(df)) {
    return(character(0))
  }
  values <- suppressWarnings(as.numeric(as.character(df[[col]])))
  bad_rows <- which(is.finite(values) & values != trunc(values))
  if (length(bad_rows) == 0) {
    return(character(0))
  }
  sprintf(
    "[%s] column '%s' must contain whole numbers; fractional value(s) at row(s): %s",
    sheet,
    col,
    paste(utils::head(bad_rows, 20L), collapse = ", ")
  )
}

# Expanding a malformed workbook must not be able to exhaust the R process
# before validation can report the problem. A million derived population rows
# is already far beyond a practical interactive imurun fit; keep the guard
# separate from model age bounds because callers may intentionally derive those
# bounds from otherwise-valid input.
MAX_EXPANDED_POPULATION_ROWS <- 1000000

#' Translate an 'imuGAP' canonicalizer error into a friendly message
#'
#' @param sheet character; which sheet the canonicalizer was checking.
#' @param e the captured condition.
#'
#' @return character scalar problem message.
#'
#' @keywords internal
friendly_canonical_error <- function(sheet, e) {
  sprintf("[%s] %s", sheet, conditionMessage(e))
}

#' Construct an imuGAP populations frame from an observations frame
#'
#' @description imurun has no populations sheet: each observation carries its own
#' `loc_id`/`cohort`/`age_min`/`age_max`/`dose`, and the imuGAP populations are
#' derived from it. An observation spanning ages `age_min`..`age_max` becomes one
#' population row per age in the span, all sharing its `obs_id`.
#'
#' @details An observation carries *counts* (`positive`/`sample_n`) for the whole
#' span, so the span's rows are a mixture rather than separate observations:
#' 'imuGAP' requires a population's weights to sum to 1 within an `obs_id`, and
#' the Stan model reads them as the mixing proportions of that observation's
#' modeled probability. Two conventions follow:
#'
#' \describe{
#'   \item{Weights}{Each age in the span gets `1 / (age_max - age_min + 1)`.
#'     The sheet carries no age-specific denominators, so a population-
#'     proportional split is not derivable from the input; equal weights are the
#'     documented default, and explicit per-age weights are possible future
#'     functionality.}
#'   \item{Cohorts}{`cohort` is the **reference** cohort, that of `age_max`, and
#'     the cohort of each younger age is derived so that `age + cohort` is held
#'     constant: `cohort_at_age = cohort + age_max - age`. This is a snapshot in
#'     time, and is the same relation [imuGAP::create_target()] applies in
#'     `"snapshot"` mode, so an observation and a target written over the same
#'     span describe the same populations.}
#' }
#'
#' A single-age observation (`age_min == age_max`) reduces to exactly the former
#' behavior: one row, `weight = 1`, `cohort` unchanged.
#'
#' A row whose span is missing or inverted is emitted as a single row at
#' `age_max` rather than expanded, so that the downstream canonicalizer reports
#' the offending value instead of this function failing on it or silently
#' producing a backwards span.
#'
#' @param obs a data.frame of observations with `obs_id`, `loc_id`, `cohort`,
#'   `dose`, and either `age_min`/`age_max` or a single `age` column.
#'
#' @return a data.frame with `obs_id`, `loc_id`, `cohort`, `age`, `dose`, and
#'   `weight`, with one row per (observation x age in its span).
#'
#' @keywords internal
build_populations <- function(obs) {
  obs <- expand_obs_age(as.data.frame(obs, stringsAsFactors = FALSE))
  n <- nrow(obs)
  if (n == 0L) {
    return(data.frame(
      obs_id = obs$obs_id,
      loc_id = obs$loc_id,
      cohort = integer(0),
      age = integer(0),
      dose = integer(0),
      weight = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  # A column the caller never supplied is carried as NA rather than a
  # zero-length vector, so a missing span degrades to the unusable branch below
  # (and a named validation problem) instead of a recycling error here.
  int_col <- function(name) {
    if (is.null(obs[[name]])) {
      rep(NA_integer_, n)
    } else {
      suppressWarnings(as.integer(obs[[name]]))
    }
  }
  age_min <- int_col("age_min")
  age_max <- int_col("age_max")
  cohort <- int_col("cohort")

  # An unusable span is passed through as a single row so the canonicalizer can
  # name the bad value; expanding it here would either error or invent rows.
  span <- age_max - age_min + 1L
  usable <- !is.na(span) & span >= 1L
  n_ages <- as.integer(ifelse(usable, span, 1L))

  idx <- rep(seq_len(n), times = n_ages)
  # sequence() restarts at 1 for each observation, giving the offset into its
  # span; unusable rows get their single row placed at age_max.
  offset <- sequence(n_ages) - 1L
  age <- ifelse(usable[idx], age_min[idx] + offset, age_max[idx])

  data.frame(
    obs_id = obs$obs_id[idx],
    loc_id = obs$loc_id[idx],
    cohort = cohort[idx] + age_max[idx] - age,
    age = age,
    dose = suppressWarnings(as.integer(obs$dose))[idx],
    weight = 1 / n_ages[idx],
    stringsAsFactors = FALSE
  )
}

#' Validate imurun inputs and report all problems at once
#'
#' @description A friendly validation layer over the 'imuGAP' canonicalizers
#' (`canonicalize_observations()`, `canonicalize_populations()`, and
#' `canonicalize_locations()`). It reports problems in spreadsheet
#' terms -- naming the offending sheet and, where 'imuGAP' provides it, the
#' offending column or row -- and collects *all* problems it can find rather
#' than stopping at the first.
#'
#' Problems detected include:
#' \itemize{
#'   \item missing or renamed required columns (per [IMURUN_SCHEMA]);
#'   \item non-numeric count columns (`positive`, `sample_n`, `cohort`,
#'     `age_min`, `age_max`, `dose`);
#'   \item fractional age-span endpoints;
#'   \item an inverted age span (`age_min > age_max`);
#'   \item age spans outside an explicit `max_age` or too large to expand
#'     safely;
#'   \item `loc_id` values in `observations` but absent from `locations`;
#'   \item `dose`, `cohort`, and `age` values out of range;
#'   \item structural location problems (duplicate or missing root, cycles).
#' }
#'
#' The imuGAP populations are constructed from the observations
#' ([build_populations()]); there is no populations sheet.
#'
#' On success the canonicalized frames are returned invisibly. On failure a
#' single error is raised whose message lists every problem found.
#'
#' @param inputs a named list with `obs` and `locs` (as returned by
#'   [read_inputs()]), or a path passed straight to [read_inputs()].
#' @param max_cohort,max_age integer upper bounds for the derived `cohort` and
#'   `age` values. Default to the largest value present in the populations built
#'   from `observations` -- which, for a multi-age observation, reaches past its
#'   own reference cohort -- so that validation does not impose a model
#'   configuration; supply explicit bounds to enforce a particular schedule.
#' @param max_dose integer; the maximum allowed `dose` (default `2`).
#'
#' @return Invisibly, a named list of the canonicalized `obs`, `pops`, and
#'   `locs` frames (`pops` derived from `obs`).
#'
#' @examples
#' wb <- system.file("extdata", "imurun_example.xlsx", package = "imurun")
#' if (nzchar(wb) && requireNamespace("readxl", quietly = TRUE)) {
#'   validate_inputs(read_inputs(wb))
#' }
#'
#' @export
validate_inputs <- function(
  inputs,
  max_cohort = NULL,
  max_age = NULL,
  max_dose = 2L
) {
  if (is.character(inputs)) {
    inputs <- read_inputs(inputs)
  }
  if (!is.list(inputs) || !all(c("obs", "locs") %in% names(inputs))) {
    stop(
      "'inputs' must be a list with elements obs, locs ",
      "(or a path to read_inputs()).",
      call. = FALSE
    )
  }

  # A lone `age` column is the single-age shorthand for the age span; expand it
  # here as well as in the loader so a hand-built frame validates the same way
  # one read from a sheet does.
  obs <- expand_obs_age(as.data.frame(inputs$obs, stringsAsFactors = FALSE))
  locs <- as.data.frame(inputs$locs, stringsAsFactors = FALSE)

  problems <- character(0)

  # 1. Structural column checks first (report all missing columns at once).
  problems <- c(problems, check_sheet_columns(obs, "observations"))
  problems <- c(problems, check_sheet_columns(locs, "locations"))

  # 2. Numeric-type checks for count columns that are present. loc/cohort/age/
  #    dose now live on the observations sheet (populations is derived from it).
  for (col in c(
    "cohort",
    "age_min",
    "age_max",
    "dose",
    "positive",
    "sample_n"
  )) {
    problems <- c(problems, check_numeric_column(obs, "observations", col))
  }

  # 3. Age-span checks must all happen before build_populations(). In
  #    particular, coercing fractional endpoints would silently change the
  #    requested mixture, while expanding an unbounded typo could exhaust
  #    memory before the canonicalizer sees it.
  if (all(c("age_min", "age_max") %in% names(obs))) {
    problems <- c(
      problems,
      check_whole_number_column(obs, "observations", "age_min"),
      check_whole_number_column(obs, "observations", "age_max")
    )

    age_min <- suppressWarnings(as.numeric(as.character(obs$age_min)))
    age_max <- suppressWarnings(as.numeric(as.character(obs$age_max)))
    whole <- is.finite(age_min) & is.finite(age_max) &
      age_min == trunc(age_min) & age_max == trunc(age_max)

    inverted <- which(whole & age_min > age_max)
    if (length(inverted) > 0) {
      problems <- c(
        problems,
        sprintf(
          "[observations] age_min must be <= age_max at row(s): %s",
          paste(utils::head(inverted, 20L), collapse = ", ")
        )
      )
    }

    bounded <- whole & age_min <= age_max
    if (!is.null(max_age) && length(max_age) == 1L &&
          is.numeric(max_age) && is.finite(max_age)) {
      outside <- which(bounded & (age_min < 1 | age_max > max_age))
      if (length(outside) > 0) {
        problems <- c(
          problems,
          sprintf(
            "[observations] age span out of range [1, %d] at row(s): %s",
            as.integer(max_age),
            paste(utils::head(outside, 20L), collapse = ", ")
          )
        )
      }
      bounded[outside] <- FALSE
    } else {
      nonpositive <- which(bounded & age_min < 1)
      if (length(nonpositive) > 0) {
        problems <- c(
          problems,
          sprintf(
            "[observations] age span must start at 1 or greater at row(s): %s",
            paste(utils::head(nonpositive, 20L), collapse = ", ")
          )
        )
      }
      bounded[nonpositive] <- FALSE
    }

    spans <- age_max[bounded] - age_min[bounded] + 1
    if (length(spans) > 0 &&
          (any(spans > MAX_EXPANDED_POPULATION_ROWS) ||
             sum(spans) > MAX_EXPANDED_POPULATION_ROWS)) {
      problems <- c(
        problems,
        sprintf(
          paste0(
            "[observations] age spans expand to more than %d population rows; ",
            "check age_min and age_max"
          ),
          MAX_EXPANDED_POPULATION_ROWS
        )
      )
    }
  }

  # If columns or types are wrong, stop here: the canonicalizers below would
  # raise confusing low-level errors on top of what we already know.
  if (length(problems) > 0) {
    stop(format_validation_error(problems), call. = FALSE)
  }

  # 4. Hand off to the imuGAP canonicalizers, capturing each error in turn so
  #    we can attribute it to a sheet and keep going.
  c_locs <- tryCatch(
    imuGAP::canonicalize_locations(locs),
    error = function(e) {
      problems <<- c(problems, friendly_canonical_error("locations", e))
      NULL
    }
  )
  c_obs <- tryCatch(
    imuGAP::canonicalize_observations(obs),
    error = function(e) {
      problems <<- c(problems, friendly_canonical_error("observations", e))
      NULL
    }
  )

  # The bounds are taken from the *expanded* populations, not the sheet: an
  # observation's span derives cohorts above its own reference cohort
  # (`cohort + age_max - age`), so bounding by the sheet's `cohort` column would
  # reject the very rows the expansion just created. run_fit() sizes the model
  # from the same frame, so the two agree by construction.
  pops_raw <- build_populations(obs)
  if (is.null(max_cohort)) {
    max_cohort <- suppressWarnings(max(pops_raw$cohort, na.rm = TRUE))
  }
  if (is.null(max_age)) {
    max_age <- suppressWarnings(max(pops_raw$age, na.rm = TRUE))
  }

  # populations are derived from the observations. Canonicalizing them needs
  # valid obs + locs; only attempt it when those succeeded, otherwise its
  # set-equivalence checks are meaningless. Attribute failures to observations,
  # since that is the sheet the user actually provides.
  c_pops <- NULL
  if (!is.null(c_obs) && !is.null(c_locs)) {
    c_pops <- tryCatch(
      imuGAP::canonicalize_populations(
        pops_raw,
        c_obs,
        c_locs,
        max_cohort = as.integer(max_cohort),
        max_age = as.integer(max_age),
        max_dose = as.integer(max_dose)
      ),
      error = function(e) {
        problems <<- c(problems, friendly_canonical_error("observations", e))
        NULL
      }
    )
  }

  if (length(problems) > 0) {
    stop(format_validation_error(problems), call. = FALSE)
  }

  invisible(list(obs = c_obs, pops = c_pops, locs = c_locs))
}

#' Assemble a multi-problem validation error message
#'
#' @param problems character vector of problem messages.
#'
#' @return character scalar suitable for [base::stop()].
#'
#' @keywords internal
format_validation_error <- function(problems) {
  problems <- unique(problems)
  header <- sprintf(
    "Input validation failed with %d problem(s):",
    length(problems)
  )
  paste(c(header, paste0("  - ", problems)), collapse = "\n")
}
