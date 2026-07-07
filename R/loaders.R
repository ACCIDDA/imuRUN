#' Supported input file extensions
#'
#' @description The file extensions imurun knows how to read, in precedence
#' order. CSV takes precedence over RDS when both exist for the same input.
#'
#' @keywords internal
SUPPORTED_EXT <- c("csv", "rds")

#' Does an input exist under any supported extension?
#'
#' @description Tests whether a named input (e.g. `"observations"`) exists in a
#' directory under any of the [SUPPORTED_EXT] extensions.
#'
#' @param dir character; directory to look in.
#' @param name character; the input base name, without extension.
#'
#' @return Logical scalar; `TRUE` if a matching file exists.
#'
#' @keywords internal
file_exists_any_ext <- function(dir, name) {
  any(file.exists(file.path(dir, paste0(name, ".", SUPPORTED_EXT))))
}

#' Read a data file by its extension
#'
#' @description Reads a single input file, dispatching on its extension. CSV is
#' read with [utils::read.csv()] (strings as character); RDS with
#' [base::readRDS()]. Unsupported extensions and unreadable files raise an
#' error that names the offending file.
#'
#' @param path character; path to the file to read.
#'
#' @return The object stored in the file (typically a `data.frame`).
#'
#' @examples
#' path <- tempfile(fileext = ".csv")
#' write.csv(data.frame(x = 1:3), path, row.names = FALSE)
#' load_by_ext(path)
#'
#' @export
load_by_ext <- function(path) {
  ext <- tolower(tools::file_ext(path))
  tryCatch(
    switch(
      ext,
      csv = utils::read.csv(path, stringsAsFactors = FALSE),
      rds = readRDS(path),
      stop("Unsupported extension '.", ext, "'", call. = FALSE)
    ),
    error = function(e) {
      stop("Failed to read '", basename(path), "': ", e$message, call. = FALSE)
    }
  )
}

#' Find and read a named input from a directory
#'
#' @description Looks for a named input (e.g. `"observations"`) in a directory,
#' trying each supported extension in precedence order (CSV before RDS), and
#' reads the first match with [load_by_ext()]. Errors with a clear message if
#' no matching file is found.
#'
#' @param dir character; directory to look in.
#' @param name character; the input base name, without extension.
#'
#' @return The object read from the matching file.
#'
#' @examples
#' dir <- tempfile("imurun_find_")
#' dir.create(dir)
#' write.csv(data.frame(positive = 1:3, sample_n = 10:12),
#'           file.path(dir, "observations.csv"), row.names = FALSE)
#' find_input_file(dir, "observations")
#'
#' @export
find_input_file <- function(dir, name) {
  for (ext in SUPPORTED_EXT) {
    path <- file.path(dir, paste0(name, ".", ext))
    if (file.exists(path)) return(load_by_ext(path))
  }
  stop(
    "Expected '",
    name,
    ".csv' or '",
    name,
    ".rds' in ",
    dir,
    "/",
    call. = FALSE
  )
}

#' Check that all required inputs are present
#'
#' @description Verifies that both required imuGAP inputs
#' (`observations`, `locations`) exist in a directory under some
#' supported extension. Reports every missing input at once rather than failing
#' on the first.
#'
#' @param dir character; directory to check.
#'
#' @return Invisibly `NULL` on success; errors listing the missing inputs
#'   otherwise.
#'
#' @examples
#' dir <- tempfile("imurun_check_")
#' dir.create(dir)
#' for (n in c("observations", "locations")) {
#'   write.csv(data.frame(a = 1), file.path(dir, paste0(n, ".csv")),
#'             row.names = FALSE)
#' }
#' check_all_inputs(dir)
#'
#' @export
check_all_inputs <- function(dir) {
  required <- c("observations", "locations")
  missing <- required[
    !vapply(required, function(n) file_exists_any_ext(dir, n), logical(1))
  ]
  if (length(missing) > 0) {
    stop(
      "Missing input files in ",
      dir,
      "/: ",
      paste(missing, collapse = ", "),
      " (expected .csv or .rds)",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Rename friendly column headers to imurun's canonical names
#'
#' @description Renames any human-readable header present in
#' [IMURUN_HEADER_ALIASES] to its canonical name (case-insensitively). Columns
#' already using a canonical name, and any unrecognized columns, pass through
#' unchanged. This lets the shipped template and example workbooks use
#' human-readable headers while the rest of imurun sees only canonical names.
#'
#' @param df a data.frame.
#'
#' @return `df` with friendly headers renamed to canonical.
#'
#' @keywords internal
canonicalize_headers <- function(df) {
  nm <- names(df)
  hit <- match(tolower(nm), tolower(names(IMURUN_HEADER_ALIASES)))
  ok <- !is.na(hit)
  nm[ok] <- unname(IMURUN_HEADER_ALIASES[hit[ok]])
  names(df) <- nm
  df
}

#' Assign a row-number obs_id when the observations sheet omits one
#'
#' @description `obs_id` is not something a user should have to invent: if the
#' observations frame carries no `obs_id` column, assign one (`1:n`) so the
#' downstream imuGAP canonicalization has the unique key it needs.
#'
#' @param obs a data.frame of observations.
#'
#' @return `obs` with an `obs_id` column guaranteed present.
#'
#' @keywords internal
ensure_obs_id <- function(obs) {
  if (!"obs_id" %in% names(obs) && nrow(obs) > 0L) {
    obs <- cbind(obs_id = seq_len(nrow(obs)), obs)
  }
  obs
}

#' Normalize read inputs: friendly headers -> canonical, and auto obs_id
#'
#' @param result a list with `obs`/`locs` and optionally `target`.
#'
#' @return the normalized list.
#'
#' @keywords internal
normalize_inputs <- function(result) {
  if (!is.null(result$obs)) {
    result$obs <- ensure_obs_id(canonicalize_headers(result$obs))
  }
  if (!is.null(result$locs)) {
    result$locs <- canonicalize_headers(result$locs)
  }
  if (!is.null(result$target)) {
    result$target <- canonicalize_headers(result$target)
  }
  result
}

#' Read all required sheets from an .xlsx workbook
#'
#' @description Reads the `observations` and `locations` sheets
#' from a single Excel workbook into data frames. Reports every missing sheet at
#' once (mirroring [check_all_inputs()] semantics) rather than failing on the
#' first.
#'
#' Sheet names are matched case-insensitively against the required
#' [IMURUN_SHEETS]. The reader package ('readxl') is only needed at call time;
#' an informative error is raised if it is not installed.
#'
#' An optional fourth sheet named `target` ([IMURUN_TARGET_SHEET]) is read when
#' present and returned as a `target` element; it is never required, so its
#' absence is not an error.
#'
#' @param path character; path to a `.xlsx` workbook.
#'
#' @return A named list with elements `obs` and `locs` (each a
#'   `data.frame`), plus `target` when the optional `target` sheet is present.
#'
#' @examples
#' wb <- system.file("extdata", "imurun_example.xlsx", package = "imurun")
#' if (nzchar(wb) && requireNamespace("readxl", quietly = TRUE)) {
#'   inputs <- read_workbook(wb)
#'   names(inputs)
#' }
#'
#' @export
read_workbook <- function(path) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop(
      "Reading .xlsx input requires the 'readxl' package. ",
      "Install it with install.packages(\"readxl\").",
      call. = FALSE
    )
  }
  if (!file.exists(path)) {
    stop("Workbook not found: ", path, call. = FALSE)
  }

  present <- tryCatch(
    readxl::excel_sheets(path),
    error = function(e) {
      stop(
        "Failed to open workbook '",
        basename(path),
        "': ",
        e$message,
        call. = FALSE
      )
    }
  )
  matched <- match(tolower(IMURUN_SHEETS), tolower(present))
  missing <- IMURUN_SHEETS[is.na(matched)]
  if (length(missing) > 0) {
    stop(
      "Workbook '",
      basename(path),
      "' is missing required sheet(s): ",
      paste(missing, collapse = ", "),
      " (found: ",
      paste(present, collapse = ", "),
      ")",
      call. = FALSE
    )
  }

  read_one <- function(sheet_name) {
    actual <- present[matched[match(sheet_name, IMURUN_SHEETS)]]
    df <- tryCatch(
      readxl::read_excel(path, sheet = actual),
      error = function(e) {
        stop(
          "Failed to read sheet '",
          actual,
          "' from '",
          basename(path),
          "': ",
          e$message,
          call. = FALSE
        )
      }
    )
    as.data.frame(df, stringsAsFactors = FALSE)
  }

  result <- list(
    obs = read_one("observations"),
    locs = read_one("locations")
  )

  # Optional target-request sheet (issue #14): read it when present, else leave
  # it out (callers treat a missing/NULL `target` as "no targets requested").
  tgt_idx <- match(tolower(IMURUN_TARGET_SHEET), tolower(present))
  if (!is.na(tgt_idx)) {
    result$target <- tryCatch(
      as.data.frame(
        readxl::read_excel(path, sheet = present[tgt_idx]),
        stringsAsFactors = FALSE
      ),
      error = function(e) {
        stop(
          "Failed to read sheet '",
          present[tgt_idx],
          "' from '",
          basename(path),
          "': ",
          e$message,
          call. = FALSE
        )
      }
    )
  }
  normalize_inputs(result)
}

#' Read all imuGAP inputs from a directory or workbook
#'
#' @description Convenience entry point that loads the raw (un-canonicalized)
#' `observations` and `locations` data, ready to be passed to
#' [validate_inputs()] or [run_fit()].
#'
#' `read_inputs()` accepts either:
#' \describe{
#'   \item{a directory}{containing `observations` and
#'     `locations` files as CSV or RDS (the original behavior); or}
#'   \item{a single `.xlsx` workbook}{with one sheet per input, read via
#'     [read_workbook()].}
#' }
#'
#' Missing inputs (files or sheets) are all reported at once. An optional
#' `target` sheet (in a workbook) or `target.csv`/`target.rds` (in a directory)
#' is read when present and returned as a `target` element (issue #14).
#'
#' @param path character; a directory of CSV/RDS files, or the path to a single
#'   `.xlsx` workbook.
#'
#' @return A named list with elements `obs` and `locs`, plus `target`
#'   when an optional target input is present.
#'
#' @examples
#' dir <- tempfile("imurun_read_")
#' dir.create(dir)
#' write.csv(data.frame(obs_id = 1, loc_id = 1, cohort = 2000, age = 1,
#'                      dose = 1, positive = 1, sample_n = 10),
#'           file.path(dir, "observations.csv"), row.names = FALSE)
#' write.csv(data.frame(loc_id = 1, parent_id = NA),
#'           file.path(dir, "locations.csv"), row.names = FALSE)
#' inputs <- read_inputs(dir)
#' names(inputs)
#'
#' @export
read_inputs <- function(path) {
  if (!is.character(path) || length(path) != 1L) {
    stop("'path' must be a single directory or .xlsx file path.", call. = FALSE)
  }
  if (tolower(tools::file_ext(path)) == "xlsx") {
    return(read_workbook(path))
  }
  check_all_inputs(path)
  result <- list(
    obs = find_input_file(path, "observations"),
    locs = find_input_file(path, "locations")
  )
  # Optional target input (issue #14): target.csv / target.rds if present.
  if (file_exists_any_ext(path, IMURUN_TARGET_SHEET)) {
    result$target <- find_input_file(path, IMURUN_TARGET_SHEET)
  }
  normalize_inputs(result)
}

#' Write imurun inputs to an .xlsx workbook
#'
#' @description The inverse of [read_workbook()]: writes an inputs list (as
#' returned by [read_inputs()]) back to a single `.xlsx` workbook, one sheet per
#' element (`observations`, `locations`, and `target` when present). Uses the
#' 'writexl' package.
#'
#' @param inputs a list with `obs` and `locs` (and optionally `target`) data
#'   frames, e.g. the result of [read_inputs()].
#' @param path character; destination `.xlsx` path.
#'
#' @return Invisibly, `path`.
#'
#' @examples
#' inputs <- list(
#'   obs = data.frame(obs_id = 1, loc_id = "A", cohort = 5, age = 5,
#'                    dose = 2, positive = 3, sample_n = 10),
#'   locs = data.frame(loc_id = "A", parent_id = NA)
#' )
#' out <- file.path(tempdir(), "inputs.xlsx")
#' write_workbook(inputs, out)
#'
#' @export
write_workbook <- function(inputs, path) {
  sheets <- list()
  if (!is.null(inputs$obs)) sheets$observations <- inputs$obs
  if (!is.null(inputs$locs)) sheets$locations <- inputs$locs
  if (!is.null(inputs$target)) sheets$target <- inputs$target
  if (length(sheets) == 0L) {
    stop("'inputs' has no observations/locations/target to write.", call. = FALSE)
  }
  writexl::write_xlsx(sheets, path = path)
  invisible(path)
}
