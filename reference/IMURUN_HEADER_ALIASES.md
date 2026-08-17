# Human-readable column-header aliases

Maps friendly, human-readable column headers (as shipped in the template
and example workbooks) to imurun's canonical column names. The loader
([`read_inputs()`](https://accidda.github.io/imurun/reference/read_inputs.md))
accepts **either** the friendly header or the canonical name
(case-insensitively) and renames friendly headers to canonical before
validation, so the rest of imurun only ever sees canonical names.

Names are the friendly headers; values are the canonical names. Most
friendly labels are unambiguous across sheets (e.g. "Location" always
means `loc_id`), so this flat map serves every sheet; the few that are
sheet-specific live in
[IMURUN_SHEET_ALIASES](https://accidda.github.io/imurun/reference/IMURUN_SHEET_ALIASES.md)
and take precedence over this map.

"Birth cohort" is the former label for what is now "Reference cohort";
both are accepted so workbooks written against the earlier template keep
loading.

## Usage

``` r
IMURUN_HEADER_ALIASES
```
