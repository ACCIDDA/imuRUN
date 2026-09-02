# Locate the bundled blank template workbook

Resolves the path to the blank `.xlsx` template shipped with imurun (one
sheet per input plus an instructions sheet), via
[`base::system.file()`](https://rdrr.io/r/base/system.file.html).

## Usage

``` r
imurun_template()
```

## Value

character; absolute path to `imurun_template.xlsx`, or `""` if the
package is not installed.

## Examples

``` r
imurun_template()
#> [1] "/tmp/Rtmp8UWNbc/temp_libpath1fda5d1b7cb7/imuRUN/templates/imurun_template.xlsx"
```
