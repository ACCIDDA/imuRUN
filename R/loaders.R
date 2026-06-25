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
#' @description Verifies that all three required imuGAP inputs
#' (`observations`, `populations`, `locations`) exist in a directory under some
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
#' for (n in c("observations", "populations", "locations")) {
#'   write.csv(data.frame(a = 1), file.path(dir, paste0(n, ".csv")),
#'             row.names = FALSE)
#' }
#' check_all_inputs(dir)
#'
#' @export
check_all_inputs <- function(dir) {
  required <- c("observations", "populations", "locations")
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

#' Read all required sheets from an .xlsx workbook
#'
#' @description Reads the `observations`, `populations`, and `locations` sheets
#' from a single Excel workbook into data frames. Reports every missing sheet at
#' once (mirroring [check_all_inputs()] semantics) rather than failing on the
#' first.
#'
#' Sheet names are matched case-insensitively against the required
#' [IMURUN_SHEETS]. The reader package ('readxl') is only needed at call time;
#' an informative error is raised if it is not installed.
#'
#' @param path character; path to a `.xlsx` workbook.
#'
#' @return A named list with elements `obs`, `pops`, and `locs`, each a
#'   `data.frame`.
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
        "Failed to open workbook '", basename(path), "': ", e$message,
        call. = FALSE
      )
    }
  )
  matched <- match(tolower(IMURUN_SHEETS), tolower(present))
  missing <- IMURUN_SHEETS[is.na(matched)]
  if (length(missing) > 0) {
    stop(
      "Workbook '", basename(path), "' is missing required sheet(s): ",
      paste(missing, collapse = ", "),
      " (found: ", paste(present, collapse = ", "), ")",
      call. = FALSE
    )
  }

  read_one <- function(sheet_name) {
    actual <- present[matched[match(sheet_name, IMURUN_SHEETS)]]
    df <- tryCatch(
      readxl::read_excel(path, sheet = actual),
      error = function(e) {
        stop(
          "Failed to read sheet '", actual, "' from '", basename(path),
          "': ", e$message,
          call. = FALSE
        )
      }
    )
    as.data.frame(df, stringsAsFactors = FALSE)
  }

  list(
    obs = read_one("observations"),
    pops = read_one("populations"),
    locs = read_one("locations")
  )
}

#' Read all imuGAP inputs from a directory or workbook
#'
#' @description Convenience entry point that loads the raw (un-canonicalized)
#' `observations`, `populations`, and `locations` data, ready to be passed to
#' [validate_inputs()] or [run_fit()].
#'
#' `read_inputs()` accepts either:
#' \describe{
#'   \item{a directory}{containing `observations`, `populations`, and
#'     `locations` files as CSV or RDS (the original behavior); or}
#'   \item{a single `.xlsx` workbook}{with one sheet per input, read via
#'     [read_workbook()].}
#' }
#'
#' Missing inputs (files or sheets) are all reported at once.
#'
#' @param path character; a directory of CSV/RDS files, or the path to a single
#'   `.xlsx` workbook.
#'
#' @return A named list with elements `obs`, `pops`, and `locs`.
#'
#' @examples
#' dir <- tempfile("imurun_read_")
#' dir.create(dir)
#' write.csv(data.frame(obs_id = 1, positive = 1, sample_n = 10),
#'           file.path(dir, "observations.csv"), row.names = FALSE)
#' write.csv(data.frame(obs_id = 1, loc_id = 1, cohort = 2000, age = 1,
#'                      dose = 1, weight = 1),
#'           file.path(dir, "populations.csv"), row.names = FALSE)
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
  list(
    obs = find_input_file(path, "observations"),
    pops = find_input_file(path, "populations"),
    locs = find_input_file(path, "locations")
  )
}
