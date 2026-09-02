# Initialize an imurun input workbook

Copies the bundled blank template workbook into a target directory so
users can fill in their own data. The template has one sheet per input
(`observations`, `locations`) with the exact required headers, plus an
`instructions` sheet.

## Usage

``` r
imurun_init(path = ".", name = "imurun_template.xlsx", overwrite = FALSE)
```

## Arguments

- path:

  character; destination directory (created if needed). Defaults to the
  current working directory (`"."`).

- name:

  character; destination file name (default `"imurun_template.xlsx"`).
  The `.xlsx` extension is optional and will be appended if omitted.

- overwrite:

  logical; if `FALSE` (the default) an existing workbook is not
  clobbered.

## Value

Invisibly, the resolved path to the copied workbook.

## Examples

``` r
dir <- tempfile("imurun_init_")
imurun_init(dir)
#> Created: /tmp/Rtmp8UWNbc/imurun_init_1fda796c5c8/imurun_template.xlsx
#> Next steps:
#>   1. Open the workbook and fill the observations and locations
#>      sheets (see the instructions sheet).
#>   2. Validate it:  imuRUN::run_fit("/tmp/Rtmp8UWNbc/imurun_init_1fda796c5c8/imurun_template.xlsx", dryrun = TRUE)
#>   3. Fit it:       imuRUN::run_fit("/tmp/Rtmp8UWNbc/imurun_init_1fda796c5c8/imurun_template.xlsx")
```
