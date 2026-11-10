import 'dart:convert';

enum TemplateVerification { inferredFromSql, verified }

enum FieldType {
  text,
  identifier,
  integer,
  decimal,
  date,
  email,
  phone,
  boolean,
}

enum ValidationSeverity { information, warning, error }

enum SourceCellType {
  empty,
  text,
  integer,
  decimal,
  date,
  dateTime,
  boolean,
  formula,
  error,
}

enum TransformationType {
  trim,
  normalizeWhitespace,
  upperCase,
  lowerCase,
  combine,
  split,
  replace,
  decimal,
  date,
  referenceLookup,
}

enum NullExportBehavior { blank, omitRow, literal }

class FieldConstraint {
  const FieldConstraint({
    this.maxLength,
    this.minValue,
    this.maxValue,
    this.allowedValues = const [],
    this.nullMarkers = const ['', 'NULL', 'N/A'],
  });

  final int? maxLength;
  final num? minValue;
  final num? maxValue;
  final List<String> allowedValues;
  final List<String> nullMarkers;

  Map<String, Object?> toJson() => {
    'maxLength': maxLength,
    'minValue': minValue,
    'maxValue': maxValue,
    'allowedValues': allowedValues,
    'nullMarkers': nullMarkers,
  };

  factory FieldConstraint.fromJson(Map<String, Object?> json) =>
      FieldConstraint(
        maxLength: json['maxLength'] as int?,
        minValue: json['minValue'] as num?,
        maxValue: json['maxValue'] as num?,
        allowedValues: (json['allowedValues'] as List? ?? const [])
            .cast<String>(),
        nullMarkers: (json['nullMarkers'] as List? ?? const ['', 'NULL', 'N/A'])
            .cast<String>(),
      );
}

class TargetField {
  const TargetField({
    required this.id,
    required this.header,
    required this.type,
    this.description = '',
    this.required = false,
    this.defaultValue,
    this.constraint = const FieldConstraint(),
    this.severity = ValidationSeverity.error,
    this.nullExportBehavior = NullExportBehavior.blank,
    this.aliases = const [],
  });

  final String id;
  final String header;
  final String description;
  final FieldType type;
  final bool required;
  final Object? defaultValue;
  final FieldConstraint constraint;
  final ValidationSeverity severity;
  final NullExportBehavior nullExportBehavior;
  final List<String> aliases;

  TargetField copyWith({
    String? header,
    String? description,
    FieldType? type,
    bool? required,
    Object? defaultValue,
    FieldConstraint? constraint,
    ValidationSeverity? severity,
    NullExportBehavior? nullExportBehavior,
    List<String>? aliases,
  }) => TargetField(
    id: id,
    header: header ?? this.header,
    description: description ?? this.description,
    type: type ?? this.type,
    required: required ?? this.required,
    defaultValue: defaultValue ?? this.defaultValue,
    constraint: constraint ?? this.constraint,
    severity: severity ?? this.severity,
    nullExportBehavior: nullExportBehavior ?? this.nullExportBehavior,
    aliases: aliases ?? this.aliases,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'header': header,
    'description': description,
    'type': type.name,
    'required': required,
    'defaultValue': defaultValue,
    'constraint': constraint.toJson(),
    'severity': severity.name,
    'nullExportBehavior': nullExportBehavior.name,
    'aliases': aliases,
  };

  factory TargetField.fromJson(Map<String, Object?> json) => TargetField(
    id: json['id']! as String,
    header: json['header']! as String,
    description: json['description'] as String? ?? '',
    type: FieldType.values.byName(json['type']! as String),
    required: json['required'] as bool? ?? false,
    defaultValue: json['defaultValue'],
    constraint: FieldConstraint.fromJson(
      (json['constraint'] as Map? ?? const {}).cast<String, Object?>(),
    ),
    severity: ValidationSeverity.values.byName(
      json['severity'] as String? ?? 'error',
    ),
    nullExportBehavior: NullExportBehavior.values.byName(
      json['nullExportBehavior'] as String? ?? 'blank',
    ),
    aliases: (json['aliases'] as List? ?? const []).cast<String>(),
  );
}

class TargetTemplate {
  const TargetTemplate({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.verification,
    required this.fields,
    this.outputSheetName = 'Import',
    this.headerRow = 1,
    this.uniqueKeys = const [],
    this.businessRules = const [],
    this.schemaVersion = 1,
  });

  final String id;
  final int version;
  final int schemaVersion;
  final String name;
  final String description;
  final TemplateVerification verification;
  final String outputSheetName;
  final int headerRow;
  final List<TargetField> fields;
  final List<List<String>> uniqueKeys;
  final List<String> businessRules;

  String get displayName =>
      '$name v$version · ${verification == TemplateVerification.verified ? 'Verified' : 'Inferred from SQL'}';

  TargetTemplate nextVersion({
    List<TargetField>? fields,
    String? description,
  }) => TargetTemplate(
    id: id,
    version: version + 1,
    name: name,
    description: description ?? this.description,
    verification: TemplateVerification.inferredFromSql,
    fields: fields ?? this.fields,
    outputSheetName: outputSheetName,
    headerRow: headerRow,
    uniqueKeys: uniqueKeys,
    businessRules: businessRules,
    schemaVersion: schemaVersion,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'version': version,
    'name': name,
    'description': description,
    'verification': verification.name,
    'outputSheetName': outputSheetName,
    'headerRow': headerRow,
    'fields': fields.map((e) => e.toJson()).toList(),
    'uniqueKeys': uniqueKeys,
    'businessRules': businessRules,
  };

  factory TargetTemplate.fromJson(Map<String, Object?> json) {
    final schema = json['schemaVersion'] as int? ?? 1;
    if (schema != 1) {
      throw const FormatException('Unsupported template schema version.');
    }
    return TargetTemplate(
      id: json['id']! as String,
      version: json['version']! as int,
      name: json['name']! as String,
      description: json['description'] as String? ?? '',
      verification: TemplateVerification.values.byName(
        json['verification'] as String? ?? 'inferredFromSql',
      ),
      outputSheetName: json['outputSheetName'] as String? ?? 'Import',
      headerRow: json['headerRow'] as int? ?? 1,
      fields: (json['fields']! as List)
          .map((e) => TargetField.fromJson((e as Map).cast<String, Object?>()))
          .toList(),
      uniqueKeys: (json['uniqueKeys'] as List? ?? const [])
          .map((e) => (e as List).cast<String>())
          .toList(),
      businessRules: (json['businessRules'] as List? ?? const [])
          .cast<String>(),
      schemaVersion: schema,
    );
  }

  static TargetTemplate decode(String source) => TargetTemplate.fromJson(
    (jsonDecode(source) as Map).cast<String, Object?>(),
  );
}

class SourceCell {
  const SourceCell({required this.type, this.value, this.formula});

  final SourceCellType type;
  final Object? value;
  final String? formula;
  String get displayValue => value?.toString() ?? '';
}

class SourceColumn {
  const SourceColumn({
    required this.index,
    required this.letter,
    required this.header,
    this.duplicateHeader = false,
  });

  final int index;
  final String letter;
  final String header;
  final bool duplicateHeader;
  String get identity => '$letter · ${header.isEmpty ? '(empty)' : header}';
}

class SourceRow {
  SourceRow({
    required this.rowNumber,
    required this.cells,
    this.excluded = false,
    this.exclusionReason,
  });

  final int rowNumber;
  final Map<int, SourceCell> cells;
  bool excluded;
  String? exclusionReason;
}

class WorkbookRegion {
  const WorkbookRegion({
    required this.workbookFingerprint,
    required this.sheetName,
    required this.headerRow,
    required this.firstDataRow,
    required this.columns,
    required this.rows,
    this.lastDataRow,
    this.mergedRanges = const [],
  });

  final String workbookFingerprint;
  final String sheetName;
  final int headerRow;
  final int firstDataRow;
  final int? lastDataRow;
  final List<SourceColumn> columns;
  final List<SourceRow> rows;
  final List<String> mergedRanges;
}

class WorkbookInspection {
  const WorkbookInspection({required this.fingerprint, required this.sheets});

  final String fingerprint;
  final List<SheetInspection> sheets;
}

class SheetInspection {
  const SheetInspection({
    required this.name,
    required this.rowCount,
    required this.columnCount,
    required this.suggestedHeaderRow,
    required this.preview,
    required this.mergedRanges,
  });

  final String name;
  final int rowCount;
  final int columnCount;
  final int suggestedHeaderRow;
  final List<List<String>> preview;
  final List<String> mergedRanges;
}

class TransformationStep {
  const TransformationStep(this.type, [this.options = const {}]);

  final TransformationType type;
  final Map<String, Object?> options;

  Map<String, Object?> toJson() => {'type': type.name, 'options': options};

  factory TransformationStep.fromJson(Map<String, Object?> json) =>
      TransformationStep(
        TransformationType.values.byName(json['type']! as String),
        (json['options'] as Map? ?? const {}).cast<String, Object?>(),
      );
}

class FieldMapping {
  const FieldMapping({
    required this.targetFieldId,
    this.sourceColumnIndexes = const [],
    this.steps = const [],
    this.constantValue,
    this.fallbackValue,
    this.confirmed = false,
  });

  final String targetFieldId;
  final List<int> sourceColumnIndexes;
  final List<TransformationStep> steps;
  final Object? constantValue;
  final Object? fallbackValue;
  final bool confirmed;

  Map<String, Object?> toJson() => {
    'targetFieldId': targetFieldId,
    'sourceColumnIndexes': sourceColumnIndexes,
    'steps': steps.map((step) => step.toJson()).toList(),
    'constantValue': constantValue,
    'fallbackValue': fallbackValue,
    'confirmed': confirmed,
  };

  factory FieldMapping.fromJson(Map<String, Object?> json) => FieldMapping(
    targetFieldId: json['targetFieldId']! as String,
    sourceColumnIndexes: (json['sourceColumnIndexes'] as List? ?? const [])
        .cast<int>(),
    steps: (json['steps'] as List? ?? const [])
        .map(
          (step) => TransformationStep.fromJson(
            (step as Map).cast<String, Object?>(),
          ),
        )
        .toList(),
    constantValue: json['constantValue'],
    fallbackValue: json['fallbackValue'],
    confirmed: json['confirmed'] as bool? ?? false,
  );
}

class MappingProfile {
  const MappingProfile({
    required this.id,
    required this.clientId,
    required this.templateId,
    required this.templateVersion,
    required this.expectedHeaders,
    required this.mappings,
    this.locale = 'en',
    this.country,
    this.referenceMappings = const [],
    this.schemaVersion = 1,
  });

  final String id;
  final int schemaVersion;
  final String clientId;
  final String templateId;
  final int templateVersion;
  final List<String> expectedHeaders;
  final List<FieldMapping> mappings;
  final String locale;
  final String? country;
  final List<ReferenceMapping> referenceMappings;
}

class ReferenceRegion {
  const ReferenceRegion({
    required this.id,
    required this.workbookFingerprint,
    required this.sheetName,
    required this.headerRow,
    required this.keyColumnIndex,
    required this.labelColumnIndex,
    required this.entries,
  });

  final String id;
  final String workbookFingerprint;
  final String sheetName;
  final int headerRow;
  final int keyColumnIndex;
  final int labelColumnIndex;
  final List<ReferenceEntry> entries;
}

class ReferenceEntry {
  const ReferenceEntry({
    required this.key,
    required this.label,
    required this.sourceRow,
  });

  final String key;
  final String label;
  final int sourceRow;
}

class ReferenceMapping {
  const ReferenceMapping({
    required this.referenceRegionId,
    required this.sourceFieldId,
    required this.targetFieldId,
  });

  final String referenceRegionId;
  final String sourceFieldId;
  final String targetFieldId;
}

class CellProvenance {
  const CellProvenance({
    required this.sheet,
    required this.row,
    required this.columns,
    required this.originalValues,
  });

  final String sheet;
  final int row;
  final List<int> columns;
  final List<Object?> originalValues;
}

class PreparedRecord {
  PreparedRecord({
    required this.sourceRowNumber,
    required this.values,
    required this.provenance,
    this.excluded = false,
    this.exclusionReason,
  });

  final int sourceRowNumber;
  final Map<String, Object?> values;
  final Map<String, CellProvenance> provenance;
  bool excluded;
  String? exclusionReason;
}

class DataIssue {
  const DataIssue({
    required this.code,
    required this.severity,
    required this.message,
    required this.sheet,
    this.sourceRow,
    this.sourceColumn,
    this.targetFieldId,
    this.acknowledged = false,
  });

  final String code;
  final ValidationSeverity severity;
  final String message;
  final String sheet;
  final int? sourceRow;
  final int? sourceColumn;
  final String? targetFieldId;
  final bool acknowledged;
}

class DuplicateGroup {
  const DuplicateGroup({
    required this.id,
    required this.kind,
    required this.key,
    required this.records,
    required this.conflictingFields,
  });

  final String id;
  final String kind;
  final String key;
  final List<PreparedRecord> records;
  final List<String> conflictingFields;
}

class ReferenceLookupResult {
  const ReferenceLookupResult({
    required this.matches,
    required this.unmatched,
    required this.ambiguous,
  });

  final Map<String, ReferenceEntry> matches;
  final Set<String> unmatched;
  final Map<String, List<ReferenceEntry>> ambiguous;
}

class AuditEntry {
  const AuditEntry({
    required this.action,
    required this.at,
    required this.sourceRow,
    this.targetFieldId,
    this.originalValue,
    this.resultingValue,
    this.detail = '',
  });

  final String action;
  final DateTime at;
  final int sourceRow;
  final String? targetFieldId;
  final Object? originalValue;
  final Object? resultingValue;
  final String detail;
}

class ExportSummary {
  const ExportSummary({
    required this.sourceCount,
    required this.includedCount,
    required this.excludedCount,
    required this.blockedCount,
    required this.warningCount,
    required this.unresolvedDuplicateGroups,
  });

  final int sourceCount;
  final int includedCount;
  final int excludedCount;
  final int blockedCount;
  final int warningCount;
  final int unresolvedDuplicateGroups;
  bool get canExportAll => blockedCount == 0 && unresolvedDuplicateGroups == 0;
}
