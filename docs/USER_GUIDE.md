# Short user guide

## 1. Import

Choose an `.xlsx` workbook. Select a worksheet, confirm the suggested header row, and set the first and optional final data rows. Introductory rows remain visible. Empty/duplicate headers, merged ranges, source row numbers, and column letters help identify the actual table. The first release prepares one primary region; add reference regions from the same or another workbook as supporting lookups.

Imported formulas are not evaluated. Resolve formula issues manually or obtain a values-only workbook. Text beginning with `=` is exported as literal text. Merged cells are never forward-filled implicitly.

## 2. Template

Choose one exact template version. All bundled versions are **Inferred from SQL**. Editing produces a new version; saved jobs retain their original version. Review every SQL-derived rule because database constants are not automatically converted into source text.

## 3. Mapping

Confirm each proposed source column. Proposals use the header and observed values; orange warnings indicate a type conflict. Configure transformations and explicitly mark extra source columns as ignored/audit-only or map them. Column positions are never reused silently when a saved profile's structure changes.

For supporting references, select the reference sheet/header plus key and label columns. Review matched, unmatched, and ambiguous values and save the snapshot with the job. Similar category names do not connect schemes automatically.

## 4. Review

Filter/search prepared records and compare original provenance with transformed values. Double-click a prepared value to correct it. Corrections and exclusions are audited and can be undone/restored. Same-name people are candidates only—never automatic merges.

For services, check care setting, revenue, cost center, branch, and price-list differences. When variants would collapse into the five-column SQL destination, export remains blocked until the loss is explicitly resolved by the chosen template/rules.

## 5. Export

The summary reconciles source, eligible, excluded, blocked, warning, and duplicate counts. Choose:

- **Export all included records** only after every blocker is resolved.
- **Export eligible records only** after reviewing exactly which rows remain blocked.

The upload workbook contains only the configured sheet, headers, columns, and data. Export the audit/issue report separately. Never choose the source file as the destination.

## Saving and reopening

Use **Save job**. The local record contains the source fingerprint/path, primary region, template snapshot, mappings, approved corrections, exclusions, and reference snapshots. Reopening verifies the source fingerprint before applying decisions. Delete saved metadata from **Recent jobs**.
