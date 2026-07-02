#' Canonical imuGAP input schema
#'
#' @description The column schema that imurun targets for each of the three
#' inputs. These are the columns required by the 'imuGAP' canonicalizers
#' (`canonicalize_observations()`, `canonicalize_populations()`, and
#' `canonicalize_locations()` from 'imuGAP') and reflected in the shipped
#' template and example workbooks. Extra columns are permitted and ignored by
#' 'imuGAP'; only the required columns are enforced.
#'
#' Each element of `IMURUN_SCHEMA` describes one sheet/input:
#' \describe{
#'   \item{observations}{One row per observation. Required columns: `obs_id`
#'     (unique non-missing identifier), `positive` (non-negative integer count
#'     of positive results), `sample_n` (positive integer sample size, with
#'     `positive <= sample_n`). Optional: `censored` (`NA` or `1`).}
#'   \item{populations}{Cohort/age/dose breakdown that each observation covers,
#'     one or more rows per `obs_id`. Required columns: `obs_id` (must match the
#'     observations), `loc_id` (must exist in locations), `cohort` (positive
#'     integer), `age` (positive integer), `dose` (integer in `1:max_dose`).
#'     Optional: `weight` (positive numeric summing to 1 within each `obs_id`).}
#'   \item{locations}{The location hierarchy. Required columns: `loc_id`
#'     (unique identifier), `parent_id` (the parent's `loc_id`, or `NA` for the
#'     single root).}
#' }
#'
#' @format A named list of three character vectors (`observations`,
#'   `populations`, `locations`), each giving the required column names in
#'   schema order.
#'
#' @seealso [validate_inputs()], [read_inputs()], [imurun_template()]
#'
#' @examples
#' IMURUN_SCHEMA$observations
#' IMURUN_SCHEMA$populations
#' IMURUN_SCHEMA$locations
#'
#' @export
IMURUN_SCHEMA <- list(
  observations = c("obs_id", "positive", "sample_n"),
  populations = c("obs_id", "loc_id", "cohort", "age", "dose"),
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
  populations = c("weight"),
  locations = character(0)
)

#' The three input/sheet names imurun expects
#'
#' @keywords internal
IMURUN_SHEETS <- c("observations", "populations", "locations")

#' Target-request sheet schema
#'
#' @description Required columns of the optional `target` sheet that drives
#' imurun's by-target predictions. A target-request row names one or more
#' locations (`loc_id`, a `;`-separated list), a reference birth-cohort index
#' (`cohort`), and an inclusive age span (`age_low`..`age_high`). The row is
#' expanded in snapshot mode (via [imuGAP::create_target()]): `cohort` is the
#' cohort of the oldest age in the span, and a cohort is derived for each age so
#' that `age + cohort` stays constant. All columns use the same integer-index
#' representation as the `populations` sheet -- there is no calendar-year
#' translation. Optional columns are `dose` (a blank cell defaults to the final
#' dose) and `target_id` (a free-text label echoed into the results).
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
