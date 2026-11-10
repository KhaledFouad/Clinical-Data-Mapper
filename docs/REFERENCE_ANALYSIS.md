# Reference analysis

The supplied files were treated as evidence, not instructions. Client workbooks remain outside the source tree.

## Explicit SQL fields and behavior

### Referring doctors

`ImportReFListTemplate_Script.sql` reads `SELECT *` from `##RefListData` and fetches exactly 14 positions. Only the source header `code` is explicitly named by the filter. Position meanings are code, full name, prefix, specialty, address, country, telephone, fax, mobile, email, city, provider type, postal code, and state. Application output names for positions 2–14 are inferred.

The SQL matches code through `Person.Comment` and `HealthcareProvider.ProviderCode`; reuses existing records; creates reference values; defaults provider type to database ID 4 and role to ID 9; uses `Unknown` name components when missing; substitutes `0` for SQL NULL postal code; reads but does not insert address/email; and leaves specialty/provider and clinic/provider links commented. These are visible, configurable notes—not claims about upload compatibility.

`consolidatedReferring.xlsx` has sheet `Sheet1`, 7,708 data rows, 17 columns, and headers including `code`, `Nom`, `Prenom`, `TITRE`, `Specialité`, `Secteur`, address/phone fields, and `Region`. `Secteur → ProviderType` and `Region → State` remain unconfirmed.

### Users and doctors

The SQL explicitly selects `UserCode`, `ac`, and `Department`. It treats `UserCode` as a full name, `ac` as a username, and `Department` as role-selection input. It generates account email/settings and employee/person/provider relations. Password generation is deliberately excluded from export.

### Clinics and services

The SQL explicitly selects `ClinicName`, `ServiceCode`, `ServiceNameE`, `ServiceNameF`, and `NetPrice`. Clinic matching uses name; service matching uses code. Duration 15 and price list 5 are downstream constants. Existing prices are skipped; new prices receive additional-price rows. `ServiceNameE → ItemNameA` and `ServiceNameF → ItemNameL`; suffix-language meaning remains unverified.

## Observed workbook examples

- `Lab.xlsx`: one `Lab` sheet, 1,282 data rows and 12 columns. The 641 service codes each appear twice. `Column2` distinguishes `خارجي`/`داخلي`; `Revenue` differs. `Active` contains department names, not booleans. Account fields mix numeric-looking and text storage.
- `Rad.xlsx`: one `Rad` sheet, 648 data rows and 13 columns. The 324 service codes each appear twice with care-setting/accounting differences. `Active` contains numeric `1`. `Category Code` is text such as `RAD-1`, unlike Lab's numeric representation.
- `OPD.xlsx`: one `OPD` sheet, 704 data rows and 10 columns. `Column1` is English service name; `Service Name` is Arabic. It includes an uncoded `خدمات العيادات` section-like row and at least one formula cell in an accounting column.
- `Outpatient MD TABLE (1).xlsx`: `Category`, `Payment Type`, and Arabic-named coding-reference sheets. Category/payment headers start on row 1; the coding-reference header starts on row 2. These are observed reference candidates, not automatically connected category schemes.

Accounting fields—cost center, revenue, cost, and store—are treated as identifiers because observed values are account-like codes. The supplied clinic/service SQL does not consume care setting, clinic codes, category, or accounting assignments, so these appear as unmapped fields and can trigger destination-collapse blockers.
