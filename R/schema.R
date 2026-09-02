#' Canonical imuGAP input schema
#'
#' The column schema that imurun targets for each of its two inputs.
#'
#' @details
#' imurun simplifies imuGAP's inputs: rather than a separate populations
#' sheet, each observation row carries its own
#' `loc_id`/`year`/`age_min`/`age_max`/`dose`, and imurun constructs the
#' imuGAP populations from the observations (see [build_populations()]). This
#' list gives the column names that are expected once header aliases
#' (see [IMURUN_HEADER_ALIASES]) have been applied and before types and values
#' are enforced.
#'
#' Each element of `IMURUN_SCHEMA` describes one sheet/input:
#' * `observations`: One row per observation. Columns: `obs_id` (a unique
#'   identifier -- the loader assigns one automatically if you omit it, so it
#'   is not a user column), `loc_id` (must exist in locations),
#'   `year` (positive integer observation year), `age_min` and `age_max`
#'   (positive integers giving the inclusive age span the count was drawn
#'   over, with `age_min <= age_max`), `dose` (integer in `1:max_dose`),
#'   `positive` (non-negative integer count of positive results), `sample_n`
#'   (positive integer sample size, with `positive <= sample_n`). Optional:
#'   `censored` (`NA` or `1`).
#'
#'   A single-age observation may be written with one `age` column instead of
#'   `age_min`/`age_max`; the loader expands it to `age_min = age_max = age`
#'   (see [expand_obs_age()]).
#' * `locations`: The location hierarchy. Required columns: `loc_id`
#'   (unique identifier), `parent_id` (the parent's `loc_id`, or `NA` for the
#'   single root).
#'
#' @format A named list of two character vectors (`observations`, `locations`),
#'   each giving the required column names in schema order.
#'
#' @seealso [validate_inputs()], [read_inputs()], [IMURUN_TARGET_SCHEMA]
#'
#' @examples
#' IMURUN_SCHEMA$observations
#' IMURUN_SCHEMA$locations
#'
#' @export
IMURUN_SCHEMA <- list(
  observations = c(
    "obs_id",
    "loc_id",
    "year",
    "age_min",
    "age_max",
    "dose",
    "positive",
    "sample_n"
  ),
  locations = c("loc_id", "parent_id")
)

#' Optional (recognized but not required) input columns
#'
#' @keywords internal
IMURUN_OPTIONAL <- list(
  observations = c("censored"),
  locations = character(0)
)

#' The input/sheet names imurun expects
#'
#' @keywords internal
IMURUN_SHEETS <- c("observations", "locations")

#' Target-request sheet schema
#'
#' @description Required columns of the (required) `target` sheet that drives
#' the by-target predictions. A target-request row names one or more
#' locations (`loc_id`, a `;`-separated list), a target year (`year`), and an
#' inclusive age span (`age_low`..`age_high`).
#'
#' A row that names only a `loc_id`, leaving `year`/`age_low`/`age_high`/`dose`
#' blank, inherits those values from the row above (last-observation-carried-
#' forward), so a run of locations sharing one request need not repeat them.
#'
#' @format A character vector of the required target columns, in sheet order.
#'
#' @seealso [expand_targets()], [validate_targets()], [summarize_targets()]
#'
#' @examples
#' IMURUN_TARGET_SCHEMA
#'
#' @export
IMURUN_TARGET_SCHEMA <- c("loc_id", "year", "age_low", "age_high")

#' Optional (recognized but not required) target-request columns
#'
#' @keywords internal
IMURUN_TARGET_OPTIONAL <- c("dose", "target_id")

#' Name of the (required) target-request sheet
#'
#' @keywords internal
IMURUN_TARGET_SHEET <- "target"

#' Name and columns of the workbook configuration sheet
#'
#' @description Generated workbooks include this sheet so calculation settings can
#' be edited in the same place as the data.
#'
#' @keywords internal
IMURUN_CONFIG_SHEET <- "configuration"
IMURUN_CONFIG_FIELDS <- c("setting", "value")

#' Human-readable column-header aliases
#'
#' @description Maps friendly, human-readable column headers (as shipped in the
#' template and example workbooks) to imurun's canonical column names. The
#' loader ([read_inputs()]) accepts **either** the friendly header or the
#' canonical name (case-insensitively) and renames friendly headers to canonical
#' before validation, so the rest of imurun only ever sees canonical names.
#'
#' @keywords internal
IMURUN_HEADER_ALIASES <- c(
  "Observation ID" = "obs_id",
  "Location" = "loc_id",
  "Parent location" = "parent_id",
  "Observation Year" = "year",
  "Target Year" = "year",
  "Year" = "year",
  "Age" = "age",
  "Dose" = "dose",
  "Vaccinated" = "positive",
  "Sampled" = "sample_n",
  "Censored" = "censored",
  "Youngest age" = "age_low",
  "Oldest age" = "age_high",
  "Label" = "target_id"
)

#' Sheet-specific column-header aliases
#'
#' @description Friendly headers whose canonical name depends on which sheet
#' they appear on, overriding [IMURUN_HEADER_ALIASES] for that sheet.
#'
#' @keywords internal
IMURUN_SHEET_ALIASES <- list(
  observations = c(
    "Observation Year" = "year",
    "Year" = "year",
    "Youngest age" = "age_min",
    "Oldest age" = "age_max"
  ),
  target = c(
    "Target Year" = "year",
    "Year" = "year",
    "Youngest age" = "age_low",
    "Oldest age" = "age_high"
  )
)
