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
#' `loc_id`/`cohort`/`age`/`dose`, so the imuGAP populations are one `weight = 1`
#' row per observation. This is the limited (single-row-per-observation) flavor
#' of imuGAP's populations flexibility.
#'
#' @param obs a data.frame of observations with `obs_id`, `loc_id`, `cohort`,
#'   `age`, and `dose` columns.
#'
#' @return a data.frame with `obs_id`, `loc_id`, `cohort`, `age`, `dose`, and
#'   `weight` (all `1`).
#'
#' @keywords internal
build_populations <- function(obs) {
  data.frame(
    obs_id = obs$obs_id,
    loc_id = obs$loc_id,
    cohort = suppressWarnings(as.integer(obs$cohort)),
    age = suppressWarnings(as.integer(obs$age)),
    dose = suppressWarnings(as.integer(obs$dose)),
    weight = 1,
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
#'   \item non-numeric count columns (`positive`, `sample_n`, `cohort`, `age`,
#'     `dose`);
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
#' @param max_cohort,max_age integer upper bounds for the `cohort` and `age`
#'   columns. Default to the largest value present in `observations` so that
#'   validation does not impose a model configuration; supply explicit bounds to
#'   enforce a particular schedule.
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

  obs <- as.data.frame(inputs$obs, stringsAsFactors = FALSE)
  locs <- as.data.frame(inputs$locs, stringsAsFactors = FALSE)

  problems <- character(0)

  # 1. Structural column checks first (report all missing columns at once).
  problems <- c(problems, check_sheet_columns(obs, "observations"))
  problems <- c(problems, check_sheet_columns(locs, "locations"))

  # 2. Numeric-type checks for count columns that are present. loc/cohort/age/
  #    dose now live on the observations sheet (populations is derived from it).
  for (col in c("cohort", "age", "dose", "positive", "sample_n")) {
    problems <- c(problems, check_numeric_column(obs, "observations", col))
  }

  # If columns or types are wrong, stop here: the canonicalizers below would
  # raise confusing low-level errors on top of what we already know.
  if (length(problems) > 0) {
    stop(format_validation_error(problems), call. = FALSE)
  }

  # 3. Hand off to the imuGAP canonicalizers, capturing each error in turn so
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

  if (is.null(max_cohort)) {
    max_cohort <- suppressWarnings(max(as.numeric(obs$cohort), na.rm = TRUE))
  }
  if (is.null(max_age)) {
    max_age <- suppressWarnings(max(as.numeric(obs$age), na.rm = TRUE))
  }

  # populations are derived from the observations. Canonicalizing them needs
  # valid obs + locs; only attempt it when those succeeded, otherwise its
  # set-equivalence checks are meaningless. Attribute failures to observations,
  # since that is the sheet the user actually provides.
  c_pops <- NULL
  if (!is.null(c_obs) && !is.null(c_locs)) {
    c_pops <- tryCatch(
      imuGAP::canonicalize_populations(
        build_populations(obs),
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
