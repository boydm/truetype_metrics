# Changelist

## v0.6.1
  * One of the Font Awesome fonts has extra data at the end of the type 12 CMAP table. This update extracts the character groups, then ignores the extra data.

## v0.6.0
  * Add support and tests for type 12 cmap tables.

## v0.5.2
  * Add :crypto to the list of required applications.

## v0.5.1
  * fix off-by-one error pulling metrics from the hmtx file.

## v0.5.0
  * Sync with FontMetrics v0.5.0
  * Pass line_gap from font into metrics

## v0.4.1
  * Fixed error parsing the hmtx table for monospaced fonts, or any font that ends the hmtx with the optional array of left-side-bearings data. Now only reads the num_h_metrics worth of values as defined in the hhea table.

## v0.4.0
  * signature of metrics sources is now in binary
  * deprecate the mix tasks.