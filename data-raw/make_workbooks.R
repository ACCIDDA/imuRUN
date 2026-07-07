# Generates the shipped .xlsx workbooks + test fixtures:
#   * inst/templates/imurun_template.xlsx -- blank, human-readable headers +
#                                            an instructions sheet (first tab)
#   * inst/extdata/imurun_example.xlsx    -- a filled example carved (unsubset)
#                                            from imuGAP's *_sim datasets, with
#                                            the same instructions tab
#   * tests/testthat/fixtures/example*.xlsx
#
# Design (issue #25, addressing @pearsonca's review):
#   - The instructions tab is the FIRST sheet you see when the file opens, and
#     ships in the example too. The tool works with or without it (the loader
#     only reads the named data sheets), so users may delete it.
#   - Columns use human-readable headers ("Location", "Birth cohort", ...). The
#     loader (R/loaders.R canonicalize_headers) maps them back to imuGAP's
#     canonical names, accepting either form.
#   - No populations sheet: each observation carries its own location/cohort/
#     age/dose and imurun derives one weight-1 population per observation (#26).
#   - obs_id is not a user column -- it is irrelevant to the input and is
#     assigned automatically by the loader.
#   - A target sheet drives by-target predictions (#14); target_id is an
#     optional free-text label.
#   - The example uses the FULL *_sim data (not a subset) so the real trends
#     survive (@pearsonca, make_workbooks.R:125).
#
# Run from the package root with:  Rscript data-raw/make_workbooks.R
# Requires the 'writexl' package (a hard imurun dependency).

if (!requireNamespace("writexl", quietly = TRUE)) {
  stop("data-raw/make_workbooks.R needs the 'writexl' package.")
}
suppressMessages({
  library(imuGAP)
  library(data.table)
})

# Canonical -> human-readable header maps. Keep in lock-step with
# R/schema.R::IMURUN_HEADER_ALIASES (which maps the friendly labels back).
obs_headers <- c(
  loc_id = "Location", cohort = "Birth cohort", age = "Age", dose = "Dose",
  positive = "Vaccinated", sample_n = "Sampled", censored = "Censored"
)
loc_headers <- c(loc_id = "Location", parent_id = "Parent location")
tgt_headers <- c(
  loc_id = "Location", cohort = "Birth cohort", age_low = "Youngest age",
  age_high = "Oldest age", dose = "Dose", target_id = "Label"
)

# Rename a frame's canonical columns to friendly headers, keeping map order and
# dropping columns not in the map.
to_friendly <- function(df, map) {
  keep <- names(map)[names(map) %in% names(df)]
  df <- df[, keep, drop = FALSE]
  names(df) <- unname(map[keep])
  df
}

empty_friendly <- function(map) {
  df <- as.data.frame(
    matrix(character(0), ncol = length(map), dimnames = list(NULL, names(map))),
    stringsAsFactors = FALSE
  )
  to_friendly(df, map)
}

out_template <- file.path("inst", "templates", "imurun_template.xlsx")
out_example <- file.path("inst", "extdata", "imurun_example.xlsx")
dir.create(dirname(out_template), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(out_example), recursive = TRUE, showWarnings = FALSE)

# --- Instructions sheet (first tab) ------------------------------------------

instructions <- data.frame(
  instructions = c(
    "imurun input workbook -- a beginner-friendly front-end to the imuGAP coverage model.",
    "",
    "This 'instructions' sheet is optional; imurun reads only the data sheets by",
    "name, so you may delete it. Fill one row per record. You may use these",
    "friendly headers or imuGAP's own (loc_id, cohort, ...). Do not add a",
    "populations sheet or an observation id -- imurun handles both for you.",
    "",
    "observations sheet -- one row per sampled count:",
    "  Location          the location (must match a Location in the locations sheet)",
    "  Birth cohort      positive integer birth-cohort index",
    "  Age               positive integer age",
    "  Dose              integer dose (1 or 2)",
    "  Vaccinated        number found vaccinated",
    "  Sampled           number sampled (Vaccinated must be <= Sampled)",
    "  Censored          optional; blank, or 1 for a right-censored observation",
    "",
    "locations sheet -- the location hierarchy:",
    "  Location          unique location name",
    "  Parent location   the parent's name; leave blank for the single root",
    "",
    "target sheet -- optional; populations to predict coverage for:",
    "  Location          one or more locations, ';'-separated",
    "  Birth cohort      reference cohort index for the oldest age in the span",
    "  Youngest age      youngest age to predict",
    "  Oldest age        oldest age to predict",
    "  Dose              optional; blank defaults to the final dose",
    "  Label             optional; free-text label echoed into the results",
    "  (a Location-only row inherits the cohort/ages/dose from the row above)",
    "",
    "Validate with:  imurun -h yourfile.xlsx",
    "Fit with:       imurun yourfile.xlsx"
  ),
  stringsAsFactors = FALSE
)

# --- Blank template ----------------------------------------------------------

writexl::write_xlsx(
  list(
    instructions = instructions,
    observations = empty_friendly(obs_headers),
    locations = empty_friendly(loc_headers),
    target = empty_friendly(tgt_headers)
  ),
  path = out_template
)
message("Wrote ", out_template)

# --- Filled example (full *_sim data, not subset) ----------------------------

data(observations_sim, package = "imuGAP")
data(populations_sim, package = "imuGAP")
data(locations_sim, package = "imuGAP")

obs_sim <- as.data.table(observations_sim)
pop_sim <- as.data.table(populations_sim)
loc_sim <- as.data.table(locations_sim)

# imurun's limited model is one population row per observation: take the first
# population row per obs_id and merge its loc/cohort/age/dose onto the counts.
# Use ALL observations and ALL locations -- do not subset (keep the real trends).
pop_one <- pop_sim[, .SD[1L], by = obs_id]
ex_obs <- merge(
  obs_sim[, .(obs_id, positive, sample_n)],
  pop_one[, .(obs_id, loc_id, cohort, age, dose)],
  by = "obs_id"
)
setorder(ex_obs, obs_id)
ex_obs <- as.data.frame(ex_obs, stringsAsFactors = FALSE)
ex_loc <- as.data.frame(loc_sim[, .(loc_id, parent_id)], stringsAsFactors = FALSE)

# Sanity check: the example must pass canonicalization the way imurun runs it
# (obs_id auto-assigned here mirrors the loader's ensure_obs_id()).
loc_c <- imuGAP::canonicalize_locations(ex_loc)
obs_c <- imuGAP::canonicalize_observations(ex_obs)
imuGAP::canonicalize_populations(
  data.frame(
    ex_obs[, c("obs_id", "loc_id", "cohort", "age", "dose")],
    weight = 1, stringsAsFactors = FALSE
  ),
  obs_c, loc_c,
  max_cohort = max(ex_obs$cohort), max_age = max(ex_obs$age)
)

# A small target example: a multi-location request plus a location-only row
# that inherits the request above it (demonstrates the LOCF fill).
some_locs <- unique(ex_loc$loc_id[!is.na(ex_loc$parent_id)])
ex_target <- data.frame(
  loc_id = c(paste(utils::head(some_locs, 2L), collapse = "; "), some_locs[3L]),
  cohort = c(max(ex_obs$cohort), NA),
  age_low = c(1L, NA),
  age_high = c(min(5L, max(ex_obs$age)), NA),
  dose = c(2L, NA),
  target_id = c("schools, ages 1-5", ""),
  stringsAsFactors = FALSE
)

write_example <- function(path, obs, loc, tgt) {
  writexl::write_xlsx(
    list(
      instructions = instructions,
      observations = to_friendly(obs, obs_headers),
      locations = to_friendly(loc, loc_headers),
      target = to_friendly(tgt, tgt_headers)
    ),
    path = path
  )
}

write_example(out_example, ex_obs, ex_loc, ex_target)
message("Wrote ", out_example,
        " (", nrow(ex_obs), " obs, ", nrow(ex_loc), " loc)")

# --- Test fixtures -----------------------------------------------------------
fixture_dir <- file.path("tests", "testthat", "fixtures")
dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)
file.copy(out_example, file.path(fixture_dir, "example.xlsx"), overwrite = TRUE)

# Corrupted copy: give a required column an unrecognized header (so it is neither
# friendly nor canonical -> missing) and blank a numeric with a string --
# exercises the structural and numeric validation branches at once.
bad_obs <- to_friendly(ex_obs, obs_headers)
names(bad_obs)[names(bad_obs) == "Sampled"] <- "Sampl3d"  # unrecognized header
bad_obs[["Birth cohort"]][1] <- "abc"                     # non-numeric
writexl::write_xlsx(
  list(
    instructions = instructions,
    observations = bad_obs,
    locations = to_friendly(ex_loc, loc_headers)
  ),
  path = file.path(fixture_dir, "example_corrupt.xlsx")
)
message("Wrote test fixtures to ", fixture_dir)
