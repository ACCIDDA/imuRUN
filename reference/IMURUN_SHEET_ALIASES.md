# Sheet-specific column-header aliases

Friendly headers whose canonical name depends on which sheet they appear
on, overriding
[IMURUN_HEADER_ALIASES](https://accidda.github.io/imurun/reference/IMURUN_HEADER_ALIASES.md)
for that sheet.

The `observations` and `target` sheets both express an inclusive age
span and so both want the labels "Youngest age" / "Oldest age", but they
canonicalize to different names (`age_min`/`age_max` for a sampled
count, `age_low`/`age_high` for a prediction request). Keeping the
user-facing labels identical while the canonical names stay distinct is
the reason this second map exists.

## Usage

``` r
IMURUN_SHEET_ALIASES
```
