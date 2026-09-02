# Copy the bundled example workbook into a target directory

Copies the small filled example workbook (derived from 'imuGAP”s `*_sim`
data) into a target directory, so users have a complete, runnable input
to learn from.

## Usage

``` r
imurun_copy_example(
  path = ".",
  name = "imurun_example.xlsx",
  overwrite = FALSE
)
```

## Arguments

- path:

  character; destination directory (created if needed). Defaults to the
  current working directory (`"."`).

- name:

  character; destination file name (default `"imurun_example.xlsx"`).
  The `.xlsx` extension is optional and will be appended if omitted.

- overwrite:

  logical; if `FALSE` (the default) an existing workbook is not
  clobbered.

## Value

Invisibly, the resolved path to the copied workbook.

## Examples

``` r
dir <- tempfile("imurun_example_")
if (nzchar(imurun_example())) {
  imurun_copy_example(dir)
}
#> Created: /tmp/Rtmp8UWNbc/imurun_example_1fda2a8769de/imurun_example.xlsx
#> Validate it with:  imuRUN::run_fit("/tmp/Rtmp8UWNbc/imurun_example_1fda2a8769de/imurun_example.xlsx", dryrun = TRUE)
```
