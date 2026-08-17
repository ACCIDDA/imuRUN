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
#   - No populations sheet: each observation carries its own location/reference
#     cohort/age span/dose and imurun derives the populations from it (#26, #36)
#     -- one equally-weighted row per age in the span.
#   - obs_id is not a user column -- it is irrelevant to the input and is
#     assigned automatically by the loader.
#   - A target sheet drives by-target predictions (#14); target_id is an
#     optional free-text label.
#   - A configuration sheet carries the sampler settings a user is likely to
#     change, so they do not need to translate workbook choices into shell flags.
#   - The example uses the FULL *_sim data (not a subset) so the real trends
#     survive (@pearsonca, make_workbooks.R:125).
#
# Structure (openxlsx2): each data sheet gets an AutoFilter, a frozen header
# row, auto-fit column widths, and a Dose dropdown (1/2). These are cosmetic --
# the loader reads values with readxl and is blind to filters/freeze/validation
# -- so they never affect parsing, only human usability. The runtime results
# writer also uses openxlsx2 to preserve these workbook features when adding the
# results sheet.
#
# Run from the package root with:  Rscript data-raw/make_workbooks.R
# Requires the runtime 'openxlsx2' package (see DESCRIPTION Imports).

if (!requireNamespace("openxlsx2", quietly = TRUE)) {
  stop("data-raw/make_workbooks.R needs the 'openxlsx2' package.")
}
suppressMessages({
  library(imuGAP)
  library(data.table)
})

# Canonical -> human-readable header maps. Keep in lock-step with
# R/schema.R::IMURUN_HEADER_ALIASES (which maps the friendly labels back).
obs_headers <- c(
  loc_id = "Location", cohort = "Reference cohort", age_min = "Youngest age",
  age_max = "Oldest age", dose = "Dose", positive = "Vaccinated",
  sample_n = "Sampled", censored = "Censored"
)
loc_headers <- c(loc_id = "Location", parent_id = "Parent location")
tgt_headers <- c(
  loc_id = "Location", cohort = "Reference cohort", age_low = "Youngest age",
  age_high = "Oldest age", dose = "Dose", target_id = "Label"
)
sampler_config <- data.frame(
  Setting = c("iter", "chains", "seed", "warmup"),
  Value = c("2000", "4", "", ""),
  Description = c(
    "Total iterations per chain",
    "Number of chains",
    "Optional random seed for reproducibility",
    "Optional warmup iterations per chain"
  ),
  stringsAsFactors = FALSE,
  check.names = FALSE
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

instructions_lines <- c(
  "imurun input workbook -- a beginner-friendly front-end to the imuGAP coverage model.",
  "",
  "HOW TO USE THIS FILE",
  "  1. Fill in the data sheets below (the tabs at the bottom): one row per record.",
  "  2. Keep the header row on each sheet. You may use these friendly headers or",
  "     imuGAP's own names (loc_id, cohort, ...); either works.",
  "  3. Review the configuration sheet, then save the file.",
  "  4. From R, check it: imurun::run_fit(c('-h', 'yourfile.xlsx'))",
  "  5. Fix anything it flags, then fit: imurun::run_fit('yourfile.xlsx')",
  "  A bad edit fails the check with a clear message -- it cannot silently produce a wrong result.",
  "",
  "This 'instructions' sheet is optional: imurun reads only the data sheets by name, so you may",
  "delete it. Do not add a populations sheet or an observation-id column -- imurun handles both",
  "for you. Extra columns you add for your own notes are ignored.",
  "",
  "configuration sheet -- sampler settings used for the fit:",
  "  iter              total iterations per chain (default 2000)",
  "  chains            number of chains (default 4)",
  "  seed              optional random seed for reproducibility",
  "  warmup            optional warmup iterations per chain",
  "  Leave seed/warmup blank to use the model defaults.",
  "",
  "observations sheet -- one row per sampled count:",
  "  Location          the location of this count (must match a Location in the locations sheet)",
  "  Reference cohort  positive whole-number cohort index, for the OLDEST age in the row",
  "  Youngest age      youngest age this count covers",
  "  Oldest age        oldest age this count covers (put the same age in both for a single age)",
  "  Dose              which dose this count is for: 1 or 2",
  "  Vaccinated        how many were found vaccinated",
  "  Sampled           how many were sampled (Vaccinated must be <= Sampled)",
  "  Censored          optional; leave blank, or put 1 for a right-censored observation",
  "  A count covering several ages is split evenly across them, and the cohort of each younger",
  "  age is stepped up so that age + cohort stays constant (a snapshot in time). If you prefer,",
  "  you may use a single 'Age' column instead of the two age columns.",
  "",
  "locations sheet -- your location hierarchy, written as a tree:",
  "  Location          a unique name for the location (you choose the names)",
  "  Parent location   the name of this location's parent (must be another Location in this sheet)",
  "  IMPORTANT: there must be exactly ONE root -- the single top location whose Parent location",
  "  is left BLANK. Every other location must name its parent, and the parents must chain up to",
  "  that one root (no loops, no second root). This is the most common thing to get wrong.",
  "",
  "target sheet -- the populations to predict coverage for (required):",
  "  Location          one or more locations to predict, ';'-separated",
  "  Reference cohort  cohort index for the oldest age in the span",
  "  Youngest age      youngest age to predict",
  "  Oldest age        oldest age to predict",
  "  Dose              optional; leave blank to default to the final dose",
  "  Label             optional; free-text label echoed into the results",
  "  A Location-only row (cohort/ages/dose left blank) inherits those from the row above it.",
  "",
  "Check from R: imurun::run_fit(c('-h', 'yourfile.xlsx'))",
  "Fit from R:   imurun::run_fit('yourfile.xlsx')",
  "If you installed the optional command wrapper, 'imurun yourfile.xlsx' also works."
)

# --- openxlsx2 workbook assembly ---------------------------------------------

# Add the instructions as the first tab: a single wide, wrapped column with a
# bold title row. The loader ignores this sheet entirely.
add_instructions_sheet <- function(wb) {
  n <- length(instructions_lines)
  wb$add_worksheet("instructions")
  wb$add_data("instructions", instructions_lines, col_names = FALSE)
  wb$set_col_widths("instructions", cols = 1, widths = 100)
  wb$add_font("instructions", dims = "A1", bold = TRUE, size = 13)
  wb$add_cell_style(
    "instructions",
    dims = paste0("A1:A", n),
    wrap_text = TRUE,
    vertical = "top"
  )
  invisible(wb)
}

# Add a data sheet with an AutoFilter, a frozen header row, auto-fit widths, and
# (where the sheet has a Dose column) a 1/2 dropdown over `valid_rows` data rows.
add_data_sheet <- function(wb, sheet, df, valid_rows) {
  ncol_df <- ncol(df)
  wb$add_worksheet(sheet)
  wb$add_data(sheet, df)
  wb$add_filter(sheet, rows = 1, cols = seq_len(ncol_df))
  wb$freeze_pane(sheet, first_active_row = 2)
  wb$set_col_widths(sheet, cols = seq_len(ncol_df), widths = "auto")

  dose_col <- match("Dose", names(df))
  if (!is.na(dose_col) && valid_rows > 0L) {
    letter <- openxlsx2::int2col(dose_col)
    wb$add_data_validation(
      sheet,
      dims = paste0(letter, 2, ":", letter, valid_rows + 1L),
      type = "list",
      value = '"1,2"'
    )
  }
  invisible(wb)
}

# Build a whole workbook: instructions, configuration, and the three data
# sheets. `valid_rows` is how many data rows the Dose dropdown should cover (a
# generous span for the blank template, the actual row count for filled files).
build_workbook <- function(observations, locations, target, valid_rows) {
  wb <- openxlsx2::wb_workbook()
  add_instructions_sheet(wb)
  add_data_sheet(wb, "configuration", sampler_config, valid_rows = 0L)
  add_data_sheet(wb, "observations", observations, valid_rows)
  add_data_sheet(wb, "locations", locations, valid_rows)
  add_data_sheet(wb, "target", target, valid_rows)
  wb
}

# --- Blank template ----------------------------------------------------------

# The template ships empty, so pre-apply the Dose dropdown to a generous span of
# rows the user is likely to fill.
TEMPLATE_ROWS <- 1000L
wb_template <- build_workbook(
  empty_friendly(obs_headers),
  empty_friendly(loc_headers),
  empty_friendly(tgt_headers),
  valid_rows = TEMPLATE_ROWS
)
openxlsx2::wb_save(wb_template, out_template, overwrite = TRUE)
message("Wrote ", out_template)

# --- Filled example (full *_sim data, not subset) ----------------------------

data(observations_sim, package = "imuGAP")
data(populations_sim, package = "imuGAP")
data(locations_sim, package = "imuGAP")

obs_sim <- as.data.table(observations_sim)
pop_sim <- as.data.table(populations_sim)
loc_sim <- as.data.table(locations_sim)

# Collapse each observation's population rows to the age span imurun's
# observations sheet carries (#36): the reference cohort is the cohort of the
# OLDEST age, and the span runs age_min..age_max. imuGAP's simulated populations
# are exactly this shape already -- every obs_id spans a contiguous age range at
# one location and dose, with equal weights and `age + cohort` held constant --
# so this is lossless, and build_populations() reconstructs populations_sim from
# it row for row (asserted below). Earlier revisions had to drop the multi-age
# observations (`.SD[1L]`) because the sheet could only express a single age.
# Use ALL observations and ALL locations -- do not subset (keep the real trends).
pop_span <- pop_sim[, .(
  loc_id = loc_id[1L],
  cohort = cohort[which.max(age)],
  age_min = min(age),
  age_max = max(age),
  dose = dose[1L]
), by = obs_id]
ex_obs <- merge(
  obs_sim[, .(obs_id, positive, sample_n)],
  pop_span,
  by = "obs_id"
)
setorder(ex_obs, obs_id)
ex_obs <- as.data.frame(ex_obs, stringsAsFactors = FALSE)
ex_loc <- as.data.frame(loc_sim[, .(loc_id, parent_id)], stringsAsFactors = FALSE)

# Sanity check: the example must pass canonicalization the way imurun runs it
# (obs_id auto-assigned here mirrors the loader's ensure_obs_id()). Use imurun's
# own build_populations() rather than a local copy of the expansion, so the
# shipped example is verified by the exact code that will later read it.
source(file.path("R", "schema.R"))
source(file.path("R", "loaders.R"))
source(file.path("R", "validate.R"))

ex_pops <- build_populations(ex_obs)
stopifnot(
  "expansion must round-trip imuGAP's simulated populations" = isTRUE(
    all.equal(
      as.data.frame(setorder(as.data.table(ex_pops), obs_id, age)),
      as.data.frame(
        setorder(copy(pop_sim), obs_id, age)[, .(
          obs_id = as.numeric(obs_id), loc_id = as.character(loc_id),
          cohort = as.numeric(cohort), age = as.numeric(age),
          dose = as.numeric(dose), weight = as.numeric(weight)
        )]
      ),
      check.attributes = FALSE
    )
  )
)

loc_c <- imuGAP::canonicalize_locations(ex_loc)
obs_c <- imuGAP::canonicalize_observations(ex_obs)
imuGAP::canonicalize_populations(
  ex_pops, obs_c, loc_c,
  max_cohort = max(ex_pops$cohort), max_age = max(ex_pops$age)
)

# A small target example: a multi-location request plus a location-only row
# that inherits the request above it (demonstrates the LOCF fill).
# The snapshot expansion holds `age + cohort` constant, so a span [age_low,
# age_high] reaches reference_cohort + (age_high - age_low) at its youngest age.
# Pick the reference cohort so the whole span stays within the observed cohort
# range, otherwise predict() fails on cohorts the model was never fit for (#38).
# Bound against the EXPANDED populations, which is what sizes the model: a
# multi-age observation derives cohorts above its own reference cohort.
some_locs <- unique(ex_loc$loc_id[!is.na(ex_loc$parent_id)])
tgt_age_low <- 1L
tgt_age_high <- min(5L, max(ex_pops$age))
tgt_ref_cohort <- max(ex_pops$cohort) - (tgt_age_high - tgt_age_low)
ex_target <- data.frame(
  loc_id = c(paste(utils::head(some_locs, 2L), collapse = "; "), some_locs[3L]),
  cohort = c(tgt_ref_cohort, NA),
  age_low = c(tgt_age_low, NA),
  age_high = c(tgt_age_high, NA),
  dose = c(2L, NA),
  target_id = c("schools, ages 1-5", ""),
  stringsAsFactors = FALSE
)

ex_obs_friendly <- to_friendly(ex_obs, obs_headers)
ex_loc_friendly <- to_friendly(ex_loc, loc_headers)
ex_tgt_friendly <- to_friendly(ex_target, tgt_headers)

wb_example <- build_workbook(
  ex_obs_friendly, ex_loc_friendly, ex_tgt_friendly,
  valid_rows = nrow(ex_obs_friendly)
)
openxlsx2::wb_save(wb_example, out_example, overwrite = TRUE)
message("Wrote ", out_example,
        " (", nrow(ex_obs), " obs, ", nrow(ex_loc), " loc)")

# --- CSV directory fixture (same example, directory read path) ---------------
# Canonical headers here: read.csv() mangles headers with spaces, and this
# fixture's job is to exercise the directory/CSV path (the friendly-header alias
# path is covered by the .xlsx fixtures). obs_id is omitted (auto-assigned).
csv_dir <- file.path("tests", "testthat", "fixtures", "example_dir")
dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
  ex_obs[, c(
    "loc_id", "cohort", "age_min", "age_max", "dose", "positive", "sample_n"
  )],
  file.path(csv_dir, "observations.csv"), row.names = FALSE
)
utils::write.csv(
  ex_loc[, c("loc_id", "parent_id")],
  file.path(csv_dir, "locations.csv"), row.names = FALSE
)
utils::write.csv(ex_target, file.path(csv_dir, "target.csv"), row.names = FALSE)
message("Wrote CSV directory fixture to ", csv_dir)

# --- Test fixtures -----------------------------------------------------------
fixture_dir <- file.path("tests", "testthat", "fixtures")
dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)
file.copy(out_example, file.path(fixture_dir, "example.xlsx"), overwrite = TRUE)

# Corrupted copy: give a required column an unrecognized header (so it is neither
# friendly nor canonical -> missing) and blank a numeric with a string --
# exercises the structural and numeric validation branches at once.
bad_obs <- to_friendly(ex_obs, obs_headers)
names(bad_obs)[names(bad_obs) == "Sampled"] <- "Sampl3d"  # unrecognized header
bad_obs[["Reference cohort"]][1] <- "abc"                 # non-numeric
wb_corrupt <- openxlsx2::wb_workbook()
add_instructions_sheet(wb_corrupt)
add_data_sheet(wb_corrupt, "configuration", sampler_config, valid_rows = 0L)
add_data_sheet(wb_corrupt, "observations", bad_obs, valid_rows = nrow(bad_obs))
add_data_sheet(wb_corrupt, "locations", ex_loc_friendly, valid_rows = nrow(ex_loc_friendly))
# target is required, so include a valid one -- the corruption is in the
# observations sheet, which is what validation should catch.
add_data_sheet(wb_corrupt, "target", ex_tgt_friendly, valid_rows = nrow(ex_tgt_friendly))
openxlsx2::wb_save(wb_corrupt, file.path(fixture_dir, "example_corrupt.xlsx"), overwrite = TRUE)
message("Wrote test fixtures to ", fixture_dir)
