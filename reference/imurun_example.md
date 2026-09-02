# Locate the bundled filled example workbook

Resolves the path to the small, realistic example `.xlsx` workbook
shipped with imuRUN (derived from 'imuGAP”s `*_sim` datasets), via
[`base::system.file()`](https://rdrr.io/r/base/system.file.html).

## Usage

``` r
imurun_example()
```

## Value

character; absolute path to `imurun_example.xlsx`, or `""` if the
package is not installed.

## Examples

``` r
imurun_example()
#> [1] "/tmp/Rtmp8UWNbc/temp_libpath1fda5d1b7cb7/imuRUN/extdata/imurun_example.xlsx"
```
