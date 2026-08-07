# Output artifacts for the fit command (issue #14). imurun's raison d'etre is
# that its user is not an R user, so `fit.rds` alone is not a result: the
# human-readable companion is. Per the design settled on #14, the primary output
# is an amended copy of the input workbook carrying the by-target estimates, with
# a results-only CSV as an option. Everything here is plain file writing, so it
# is unit-testable without a Stan toolchain.

#' Normalize imuGAP prediction draws before summarizing them
#'
#' @description Bridges the one naming difference between the two halves of the
#' by-target path: [imuGAP::predict.imugap_fit()] returns the predicted coverage
#' column as `coverage`, while [summarize_targets()] consumes `p_obs`. Kept as a
#' named function rather than an inline rename so the coupling is visible and
#' has a test of its own; if imuGAP ever renames the column, this is the single
#' place that changes.
#'
#' @param pred the object returned by `predict()` on an imuGAP fit.
#'
#' @return A data.frame with a `p_obs` column, ready for [summarize_targets()].
#'
#' @keywords internal
as_target_draws <- function(pred) {
  draws <- as.data.frame(pred, stringsAsFactors = FALSE)
  if (!"p_obs" %in% names(draws) && "coverage" %in% names(draws)) {
    names(draws)[names(draws) == "coverage"] <- "p_obs"
  }
  draws
}

#' Refuse to overwrite an existing output file
#'
#' @description imurun writes next to a user's own inputs, so a second run must
#' not silently replace results they have not looked at yet. Errors when `path`
#' already exists unless `overwrite` is `TRUE`.
#'
#' @param path character; the file about to be written.
#' @param overwrite logical; `TRUE` to allow replacing an existing file.
#'
#' @return Invisibly, `path`.
#'
#' @keywords internal
assert_no_clobber <- function(path, overwrite = FALSE) {
  if (!isTRUE(overwrite) && file.exists(path)) {
    stop(
      sprintf("%s already exists; pass --overwrite to replace it.", path),
      call. = FALSE
    )
  }
  invisible(path)
}

#' Write the by-target results to a CSV
#'
#' @description The results-only output: one row per target with its posterior
#' median and credible interval, without the input sheets. For a user who wants
#' to load the estimates into something other than a spreadsheet.
#'
#' @param results data.frame of summarized targets, as returned by
#'   [summarize_targets()].
#' @param path character; destination `.csv` path.
#' @param overwrite logical; `TRUE` to replace an existing file.
#'
#' @return Invisibly, `path`.
#'
#' @seealso [write_results_workbook()], [summarize_targets()]
#'
#' @examples
#' res <- data.frame(
#'   target_id = "1", loc_id = "A", cohort = 5L, age = 5L, dose = 2L,
#'   n_draws = 100L, est_median = 0.8, est_lower = 0.7, est_upper = 0.9,
#'   ci_level = 0.95
#' )
#' out <- file.path(tempdir(), "results.csv")
#' write_results_csv(res, out, overwrite = TRUE)
#'
#' @export
write_results_csv <- function(results, path, overwrite = FALSE) {
  assert_no_clobber(path, overwrite)
  utils::write.csv(
    as.data.frame(results, stringsAsFactors = FALSE),
    file = path,
    row.names = FALSE
  )
  invisible(path)
}

#' Write an amended workbook: the inputs plus a results sheet
#'
#' @description The primary human-readable output. Writes a copy of the input
#' workbook (`observations`, `locations`, `target`) with a `results` sheet added,
#' so the estimates travel alongside the request that produced them and the
#' original input file is left untouched.
#'
#' @details Each results row carries the `target_id` label and the resolved
#' `loc_id`/`cohort`/`age`/`dose` identity, so a reader can trace it back to the
#' `target` sheet row it came from. A single target-request row expands to one
#' results row per location and per age in its span (see [expand_targets()]),
#' which is why the estimates land on their own sheet rather than being appended
#' to the request rows.
#'
#' @param inputs a list with `obs`, `locs`, and optionally `target` data frames,
#'   e.g. the result of [read_inputs()].
#' @param results data.frame of summarized targets, as returned by
#'   [summarize_targets()].
#' @param path character; destination `.xlsx` path.
#' @param overwrite logical; `TRUE` to replace an existing file.
#'
#' @return Invisibly, `path`.
#'
#' @seealso [write_results_csv()], [write_workbook()], [summarize_targets()]
#'
#' @examples
#' inputs <- list(
#'   obs = data.frame(
#'     obs_id = 1, loc_id = "A", cohort = 5, age = 5,
#'     dose = 2, positive = 3, sample_n = 10
#'   ),
#'   locs = data.frame(loc_id = "A", parent_id = NA)
#' )
#' res <- data.frame(
#'   target_id = "1", loc_id = "A", cohort = 5L, age = 5L, dose = 2L,
#'   n_draws = 100L, est_median = 0.8, est_lower = 0.7, est_upper = 0.9,
#'   ci_level = 0.95
#' )
#' out <- file.path(tempdir(), "results.xlsx")
#' write_results_workbook(inputs, res, out, overwrite = TRUE)
#'
#' @export
write_results_workbook <- function(inputs, results, path, overwrite = FALSE) {
  assert_no_clobber(path, overwrite)
  sheets <- list()
  if (!is.null(inputs$obs)) sheets$observations <- inputs$obs
  if (!is.null(inputs$locs)) sheets$locations <- inputs$locs
  if (!is.null(inputs$target)) sheets$target <- inputs$target
  sheets$results <- as.data.frame(results, stringsAsFactors = FALSE)
  writexl::write_xlsx(sheets, path = path)
  invisible(path)
}

#' Pull output-path options out of the command-line arguments
#'
#' @description The counterpart to [parse_sampler_options()] for the output
#' flags: `--results PATH` (where the amended workbook goes), `--csv PATH` (also
#' write a results-only CSV), and `--overwrite` (allow replacing existing
#' outputs). Each path flag may be written `--csv PATH` or `--csv=PATH`.
#' Unrecognized arguments are left in `rest` for the caller.
#'
#' @param args character vector of command-line style arguments.
#'
#' @return A list with `options` (a named list holding any of `results`, `csv`,
#'   and `overwrite`) and `rest` (the arguments with the recognized output flags
#'   and their values removed).
#'
#' @seealso [parse_sampler_options()]
#'
#' @examples
#' parse_output_options(c("data.xlsx", "--csv", "out.csv", "--overwrite"))
#'
#' @export
parse_output_options <- function(args) {
  path_spec <- c(results = "--results", csv = "--csv")
  options <- list()
  keep <- rep(TRUE, length(args))
  i <- 1L
  n <- length(args)
  while (i <= n) {
    a <- args[[i]]
    if (is.na(a)) {
      i <- i + 1L
      next
    }
    if (identical(a, "--overwrite")) {
      options$overwrite <- TRUE
      keep[i] <- FALSE
      i <- i + 1L
      next
    }
    matched <- FALSE
    for (nm in names(path_spec)) {
      flag <- path_spec[[nm]]
      if (identical(a, flag)) {
        if (i == n) {
          stop(sprintf("%s needs a value.", flag), call. = FALSE)
        }
        options[[nm]] <- as.character(args[[i + 1L]])
        keep[i] <- FALSE
        keep[i + 1L] <- FALSE
        i <- i + 2L
        matched <- TRUE
        break
      }
      if (startsWith(a, paste0(flag, "="))) {
        val <- sub(paste0(flag, "="), "", a, fixed = TRUE)
        if (!nzchar(val)) {
          stop(sprintf("%s needs a value.", flag), call. = FALSE)
        }
        options[[nm]] <- val
        keep[i] <- FALSE
        i <- i + 1L
        matched <- TRUE
        break
      }
    }
    if (!matched) {
      i <- i + 1L
    }
  }
  list(options = options, rest = args[keep])
}
