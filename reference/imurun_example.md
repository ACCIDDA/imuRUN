# Locate the bundled filled example workbook

Resolves the path to the small, realistic example `.xlsx` workbook
shipped with imurun (derived from 'imuGAP”s `*_sim` datasets), via
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
#> [1] "/tmp/RtmppRI8X2/temp_libpath1acc2afb35d5/imurun/extdata/imurun_example.xlsx"
```
