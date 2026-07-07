# Split a location-list cell into individual location identifiers

Parses one `loc_id` cell from the `target` sheet, which may name a
single location or a `;`- or `,`-separated list. Tokens are trimmed and
empty tokens dropped, so `"A; B ,C"` and `"A;;B"` yield
`c("A", "B", "C")` and `c("A", "B")` respectively.

## Usage

``` r
parse_loc_list(x)
```

## Arguments

- x:

  a single cell value (coerced to character).

## Value

character vector of location identifiers (possibly length zero).
