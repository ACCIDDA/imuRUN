#' Canonical imuGAP input schema
#'
#' @description The column schema that imurun targets for each of its two
#' inputs. imurun simplifies imuGAP's inputs: rather than a separate populations
#' sheet, each observation row carries its own `loc_id`/`cohort`/`age`/`dose`,
#' and imurun constructs the imuGAP populations from the observations (one
#' `weight = 1` row per observation). This trades imuGAP's multi-row weighted
#' populations for a simpler one-sheet input; a future version may add an
#' optional populations sheet as a pure expansion. Extra columns are permitted
#' and ignored; only the required columns are enforced.
#'
#' Each element of `IMURUN_SCHEMA` describes one sheet/input:
#' \describe{
#'   \item{observations}{One row per observation. Columns: `obs_id` (a unique
#'     identifier -- the loader assigns one automatically if you omit it, so it
#'     is not a user column), `loc_id` (must exist in locations),
#'     `cohort` (positive integer), `age` (positive integer), `dose` (integer in
#'     `1:max_dose`), `positive` (non-negative integer count of positive
#'     results), `sample_n` (positive integer sample size, with
#'     `positive <= sample_n`). Optional: `censored` (`NA` or `1`).}
#'   \item{locations}{The location hierarchy. Required columns: `loc_id`
#'     (unique identifier), `parent_id` (the parent's `loc_id`, or `NA` for the
#'     single root).}
#' }
#'
#' @format A named list of two character vectors (`observations`, `locations`),
#'   each giving the required column names in schema order.
#'
#' @seealso [validate_inputs()], [read_inputs()], [imurun_template()]
#'
#' @examples
#' IMURUN_SCHEMA$observations
#' IMURUN_SCHEMA$locations
#'
#' @export
IMURUN_SCHEMA <- list(
  observations = c(
    "obs_id", "loc_id", "cohort", "age", "dose", "positive", "sample_n"
  ),
  locations = c("loc_id", "parent_id")
)

#' Optional (recognized but not required) input columns
#'
#' @description Columns that 'imuGAP' understands but does not require. They are
#' included as headers in the shipped template so users know they are
#' available.
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
#' @description Required columns of the optional `target` sheet that drives
#' the by-target predictions. A target-request row names one or more
#' locations (`loc_id`, a `;`-separated list), a reference birth-cohort index
#' (`cohort`), and an inclusive age span (`age_low`..`age_high`). The row is
#' expanded in snapshot mode (via [imuGAP::create_target()]): `cohort` is the
#' cohort of the oldest age in the span, and a cohort is derived for each age so
#' that `age + cohort` stays constant. All columns use the same integer-index
#' representation as the `populations` sheet -- there is no calendar-year
#' translation. Optional columns are `dose` (a blank cell defaults to the final
#' dose) and `target_id` (a free-text label echoed into the results).
#'
#' A row that names only a `loc_id`, leaving `cohort`/`age_low`/`age_high`/`dose`
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
IMURUN_TARGET_SCHEMA <- c("loc_id", "cohort", "age_low", "age_high")

#' Optional (recognized but not required) target-request columns
#'
#' @keywords internal
IMURUN_TARGET_OPTIONAL <- c("dose", "target_id")

#' Name of the optional target-request sheet
#'
#' @keywords internal
IMURUN_TARGET_SHEET <- "target"

#' Human-readable column-header aliases
#'
#' @description Maps friendly, human-readable column headers (as shipped in the
#' template and example workbooks) to imurun's canonical column names. The
#' loader ([read_inputs()]) accepts **either** the friendly header or the
#' canonical name (case-insensitively) and renames friendly headers to canonical
#' before validation, so the rest of imurun only ever sees canonical names.
#'
#' Names are the friendly headers; values are the canonical names. Friendly
#' labels are unambiguous across sheets (e.g. "Location" always means `loc_id`),
#' so a single flat map serves every sheet.
#'
#' @keywords internal
IMURUN_HEADER_ALIASES <- c(
  "Observation ID"  = "obs_id",
  "Location"        = "loc_id",
  "Parent location" = "parent_id",
  "Birth cohort"    = "cohort",
  "Age"             = "age",
  "Dose"            = "dose",
  "Vaccinated"      = "positive",
  "Sampled"         = "sample_n",
  "Censored"        = "censored",
  "Youngest age"    = "age_low",
  "Oldest age"      = "age_high",
  "Label"           = "target_id"
)
