# Initialize an imurun input workbook

Copies the bundled blank template workbook into a target directory so
users can fill in their own data. The template has one sheet per input
(`observations`, `locations`) with the exact required headers, plus an
`instructions` sheet.

## Usage

``` r
imurun_init(path = ".", overwrite = FALSE)
```

## Arguments

- path:

  character; destination directory (created if needed). Defaults to the
  current working directory.

- overwrite:

  logical; if `FALSE` (the default) an existing `imurun_template.xlsx`
  is not clobbered.

## Value

Invisibly, the path to the copied workbook.

## Examples

``` r
dir <- tempfile("imurun_init_")
imurun_init(dir)
#> Created: /tmp/RtmpVwJXPn/imurun_init_1beb11c1169e/imurun_template.xlsx
#> Next steps:
#>   1. Open the workbook and fill the observations and locations
#>      sheets (see the instructions sheet).
#>   2. Validate it:  imurun -h /tmp/RtmpVwJXPn/imurun_init_1beb11c1169e/imurun_template.xlsx
#>   3. Fit it:       imurun /tmp/RtmpVwJXPn/imurun_init_1beb11c1169e/imurun_template.xlsx
```
