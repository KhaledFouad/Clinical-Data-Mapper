# Known limitations and unverified assumptions

- No verified website upload template or importer contract was supplied. All seeded output headers and workbook compatibility remain unverified.
- Only `.xlsx` is supported. Encrypted XLSX, legacy `.xls`, CSV, macros, and automatic formula evaluation are unsupported.
- One primary tabular region is prepared per job. Supporting reference regions are supported, but multiple primary tables and relational multi-sheet output are future work.
- The engine supports bounded combine/split/dictionary/locale/reference transforms; the current desktop mapping table exposes the most common single-column mapping directly. Advanced transform editing uses the model/API and needs a richer visual editor.
- Phone/postal checks are structural until an approved country rule/dictionary is configured. Country is never inferred from a name or language.
- Possible-person matching is deliberately conservative and deterministic. It does not perform unrestricted all-pairs fuzzy matching or automatic merges.
- Template management persistence/version models are complete; the current template library presents create/duplicate/edit/export affordances, while a full field-by-field visual designer remains limited.
- The Windows runner is generated but was not compiled in this Linux environment.
