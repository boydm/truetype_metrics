# Changelist


## v0.5.0
  * Sync with FontMetrics v0.5.0
  * Pass line_gap from font into metrics

## v0.4.1
  * Fixed error parsing the hmtx table for monospaced fonts, or any font that ends the hmtx with the optional array of left-side-bearings data. Now only reads the num_h_metrics worth of values as defined in the hhea table.

## v0.4.0
  * signature of metrics sources is now in binary
  * deprecate the mix tasks.