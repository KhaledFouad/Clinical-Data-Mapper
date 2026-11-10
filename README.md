# Clinical Data Mapper

Offline-first Flutter desktop application for inspecting client XLSX workbooks, mapping them into versioned target templates, reviewing data-quality and duplicate issues, and exporting a clean XLSX upload file.

The three bundled templates are labelled **Inferred from SQL**. Generating a workbook does not establish compatibility with any hospital website. A template should be marked verified only after a successful external import test.

## Implemented path

- Native XLSX picker, sheet preview, suggested/editable header row, first/final data rows, stable column indexes/letters, duplicate and empty headers, merged-range visibility, cell types, and source row provenance.
- Versioned templates with ordered stable field IDs, output headers, types, required fields, constraints, aliases, defaults, null behavior, unique keys, JSON import/export model, and three SQL-derived seeds.
- Mapping proposals based on multilingual aliases and observed value types; one/multiple source support in the engine; constants, fallback, combine, split, replacement dictionaries, whitespace/case, decimal/date, and reference-lookup transformations.
- One primary region plus saved reference-region snapshots, key/label matching, and unmatched/ambiguous result reporting.
- Validation for required mappings/values, null markers, type/length/dictionary/email/phone/date/decimal/formula/error conditions, explicit section-row review, and unmapped-source disposition.
- Client-scoped exact/key/conflict duplicates, deterministic possible-person candidate grouping, side-by-side conflict UI, explicit exclusions, corrections, bulk correction API, undo, revalidation, and audit entries.
- Service-variant collapse detection when care setting, revenue, cost center, branch, or price-list distinctions are not present in the selected destination.
- Separate clean upload workbook and audit/issue workbook generation; identifiers remain text, formula-like text remains literal, imported formulas are never evaluated, and safe temporary writes prevent source overwrite.
- Local template/job persistence with schema versions, source fingerprints, exact template snapshots, mappings, corrections, exclusions, reference snapshots, reopen verification, recent jobs, and deletion.
- Parsing, validation, duplicate checks, preparation, and encoding are dispatched to background isolates in the interactive workflow.

See [User guide](docs/USER_GUIDE.md), [reference analysis](docs/REFERENCE_ANALYSIS.md), and [limitations](docs/LIMITATIONS.md).

## Architecture

The project uses Flutter's built-in `ChangeNotifier` consistently for workflow state. It is small, dependency-free, and sufficient for a single desktop job workspace. UI, state, domain models, XLSX I/O, mapping, quality rules, duplicate/reference engines, and persistence are separate under `lib/src/`.

```text
lib/src/
  models/       Versioned templates, mappings, source/provenance, issues
  services/     XLSX, transformation, validation, duplicates, references, storage
  state/        Workflow controller and invalidation rules
  ui/           Desktop workflow and management screens
assets/templates/  Editable SQL-inferred JSON seeds
test/              Synthetic unit, pipeline, persistence, performance, widget tests
```

## Dependencies

Checked against current package metadata on 10 November 2026:

| Package | Version | Purpose | Windows | License |
|---|---:|---|---|---|
| `excel` | 4.0.6 | Pure-Dart XLSX read/write | Yes | MIT |
| `file_picker` | 13.3.3 | Native open/folder dialogs | Yes | MIT |
| `path_provider` | 2.1.6 | Per-user application-support path | Yes (official Flutter package) | BSD-3-Clause |
| `crypto` | 3.0.8 | SHA-256 source fingerprints | Pure Dart | BSD-3-Clause |

No commercial dependency is used. Versions are constrained by compatible major versions in `pubspec.yaml`; `pubspec.lock` provides reproducible application builds.

## Setup and test

Install Flutter 3.47.9 stable or a compatible stable SDK with Dart 3.13.7, then:

```powershell
flutter config --enable-windows-desktop
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

On Linux/macOS the pure-Dart engine and widget tests run normally, but the Windows executable cannot be compiled there.

## Run and build on Windows

Prerequisites: Windows 10/11, Git, Flutter, and Visual Studio 2022 with **Desktop development with C++**, MSVC, CMake tools, and a Windows 10/11 SDK.

```powershell
flutter doctor -v
flutter pub get
flutter run -d windows
flutter build windows --release
```

The release bundle is produced under `build\windows\x64\runner\Release\`. Distribute the entire folder, not only the `.exe`.

Windows runner files are included. This Linux environment ran formatting, static analysis, and Flutter tests, but did **not** compile or launch the Windows runner; no Windows executable is claimed as tested.

## Local data and privacy

Normal processing is local and works offline after installation. `path_provider` selects the current user's application-support directory; the app stores its JSON under a `ClinicalDataMapper` subfolder. Recent Jobs lets users delete saved job metadata. Source workbooks remain in their original locations and are never committed by this repository. Ordinary errors identify file structure and source coordinates without logging row values.

Synthetic fixtures are generated in tests. The supplied client workbooks and SQL files were inspected only as external references and are not included in this project.
