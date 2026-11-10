import '../models/domain.dart';

class ValidationEngine {
  const ValidationEngine();

  List<DataIssue> validateConfiguration(
    TargetTemplate template,
    List<FieldMapping> mappings,
    WorkbookRegion region, {
    Set<int> explicitlyIgnoredColumns = const {},
  }) {
    final issues = <DataIssue>[];
    final byField = {for (final m in mappings) m.targetFieldId: m};
    for (final field in template.fields.where((f) => f.required)) {
      final mapping = byField[field.id];
      if (mapping == null ||
          (mapping.sourceColumnIndexes.isEmpty &&
              mapping.constantValue == null &&
              field.defaultValue == null)) {
        issues.add(
          DataIssue(
            code: 'MISSING_REQUIRED_MAPPING',
            severity: ValidationSeverity.error,
            message:
                'Required target field “${field.header}” has no source, constant, or approved default.',
            sheet: region.sheetName,
            targetFieldId: field.id,
          ),
        );
      }
    }
    final used = mappings.expand((m) => m.sourceColumnIndexes).toSet();
    for (final column in region.columns.where(
      (c) =>
          !used.contains(c.index) &&
          !explicitlyIgnoredColumns.contains(c.index),
    )) {
      issues.add(
        DataIssue(
          code: 'UNMAPPED_SOURCE_COLUMN',
          severity: ValidationSeverity.warning,
          message:
              'Source column “${column.header}” has no destination. Choose ignore, audit-only, or map.',
          sheet: region.sheetName,
          sourceColumn: column.index,
        ),
      );
    }
    return issues;
  }

  List<DataIssue> validateRecords(
    TargetTemplate template,
    WorkbookRegion region,
    List<PreparedRecord> records,
  ) {
    final issues = <DataIssue>[];
    final fields = {for (final f in template.fields) f.id: f};
    for (final record in records.where((r) => !r.excluded)) {
      for (final entry in record.values.entries) {
        final field = fields[entry.key];
        if (field == null) continue;
        final value = entry.value;
        final text = value?.toString() ?? '';
        final provenance = record.provenance[field.id];
        void add(String code, ValidationSeverity severity, String message) =>
            issues.add(
              DataIssue(
                code: code,
                severity: severity,
                message: message,
                sheet: region.sheetName,
                sourceRow: record.sourceRowNumber,
                sourceColumn: provenance?.columns.firstOrNull,
                targetFieldId: field.id,
              ),
            );
        final isNull =
            value == null ||
            text.trim().isEmpty ||
            field.constraint.nullMarkers.any(
              (e) => e.toLowerCase() == text.trim().toLowerCase(),
            );
        if (field.required && isNull) {
          add(
            'REQUIRED_VALUE_MISSING',
            ValidationSeverity.error,
            '“${field.header}” is required.',
          );
          continue;
        }
        if (isNull) continue;
        if (value is String && value.isNotEmpty && value.trim().isEmpty) {
          add(
            'WHITESPACE_ONLY',
            field.severity,
            'Value contains whitespace only.',
          );
        }
        if (field.constraint.maxLength case final max? when text.length > max) {
          add(
            'MAX_LENGTH',
            field.severity,
            'Value length ${text.length} exceeds $max.',
          );
        }
        if (field.constraint.allowedValues.isNotEmpty &&
            !field.constraint.allowedValues.contains(text)) {
          add(
            'INVALID_ALLOWED_VALUE',
            field.severity,
            'Value is not in the approved dictionary.',
          );
        }
        switch (field.type) {
          case FieldType.integer:
            if (value is! int && int.tryParse(text) == null) {
              add(
                'INVALID_INTEGER',
                field.severity,
                'Expected a whole number.',
              );
            }
          case FieldType.decimal:
            if (value is! num && num.tryParse(text) == null) {
              final ambiguous = text.contains(',') || text.contains('.');
              add(
                ambiguous ? 'AMBIGUOUS_DECIMAL' : 'INVALID_DECIMAL',
                field.severity,
                ambiguous
                    ? 'Decimal/grouping separators require an explicit locale.'
                    : 'Expected a number.',
              );
            }
          case FieldType.date:
            if (value is! DateTime) {
              final ambiguous = RegExp(r'^\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}$')
                  .hasMatch(text);
              add(
                ambiguous ? 'AMBIGUOUS_DATE' : 'INVALID_DATE',
                field.severity,
                ambiguous
                    ? 'Date order is ambiguous; select DMY, MDY, or YMD.'
                    : 'Expected a configured date.',
              );
            }
          case FieldType.email:
            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
              add(
                'INVALID_EMAIL',
                field.severity,
                'Email structure is invalid.',
              );
            }
          case FieldType.phone:
            if (!RegExp(r'^\+?[0-9 ()\-]{5,}$').hasMatch(text)) {
              add(
                'INVALID_PHONE',
                ValidationSeverity.warning,
                'Phone format is suspicious; country-specific validation requires country context.',
              );
            }
          case FieldType.boolean:
            if (value is! bool &&
                !const [
                  '0',
                  '1',
                  'true',
                  'false',
                ].contains(text.toLowerCase())) {
              add(
                'INVALID_BOOLEAN',
                field.severity,
                'Expected a boolean value.',
              );
            }
          case FieldType.text || FieldType.identifier:
            break;
        }
      }
    }
    for (final row in region.rows) {
      for (final cellEntry in row.cells.entries) {
        final cell = cellEntry.value;
        if (cell.type == SourceCellType.formula) {
          issues.add(
            DataIssue(
              code: 'FORMULA_REQUIRES_RESOLUTION',
              severity: ValidationSeverity.error,
              message: 'Formula cells are not evaluated. Provide values-only input or resolve manually.',
              sheet: region.sheetName,
              sourceRow: row.rowNumber,
              sourceColumn: cellEntry.key,
            ),
          );
        } else if (cell.type == SourceCellType.error) {
          issues.add(
            DataIssue(
              code: 'EXCEL_ERROR_CELL',
              severity: ValidationSeverity.error,
              message: 'Excel error cell requires manual resolution.',
              sheet: region.sheetName,
              sourceRow: row.rowNumber,
              sourceColumn: cellEntry.key,
            ),
          );
        }
      }
    }
    return issues;
  }

  List<DataIssue> detectSectionRows(WorkbookRegion region) {
    final issues = <DataIssue>[];
    final codeColumns = region.columns
        .where((column) => column.header.toLowerCase().contains('code'))
        .map((column) => column.index)
        .toList();
    for (final row in region.rows) {
      final nonEmpty = row.cells.values
          .where((c) => c.displayValue.trim().isNotEmpty)
          .toList();
      final populatedCodeColumns = codeColumns
          .where((index) => row.cells[index]!.displayValue.trim().isNotEmpty)
          .length;
      final hasIncompleteIdentity =
          codeColumns.isNotEmpty && populatedCodeColumns < codeColumns.length;
      if (nonEmpty.isNotEmpty &&
          hasIncompleteIdentity &&
          nonEmpty.length <= (region.columns.length / 2).ceil()) {
        issues.add(
          DataIssue(
            code: 'POSSIBLE_SECTION_ROW',
            severity: ValidationSeverity.warning,
            message: 'Partly populated uncoded row may be a section heading. Review and record an explicit exclusion decision.',
            sheet: region.sheetName,
            sourceRow: row.rowNumber,
          ),
        );
      }
    }
    return issues;
  }

  List<DataIssue> detectLossyServiceCollapse(
    WorkbookRegion region,
    List<FieldMapping> mappings,
  ) {
    final issues = <DataIssue>[];
    int? serviceColumn;
    final mappedColumns = mappings.expand((m) => m.sourceColumnIndexes).toSet();
    for (final m in mappings.where((m) => m.targetFieldId == 'service_code')) {
      serviceColumn = m.sourceColumnIndexes.firstOrNull;
    }
    if (serviceColumn == null) return issues;
    final contextColumns = region.columns.where((c) {
      final h = c.header.toLowerCase().trim();
      return !mappedColumns.contains(c.index) &&
          (h == 'column2' ||
              h.contains('revenue') ||
              h.contains('cost center') ||
              h.contains('branch') ||
              h.contains('price list'));
    }).toList();
    final groups = <String, List<SourceRow>>{};
    for (final row in region.rows) {
      final code = row.cells[serviceColumn]?.displayValue.trim() ?? '';
      if (code.isNotEmpty) groups.putIfAbsent(code, () => []).add(row);
    }
    for (final entry in groups.entries.where((e) => e.value.length > 1)) {
      final differing = contextColumns
          .where(
            (c) =>
                entry.value
                    .map((r) => r.cells[c.index]?.displayValue ?? '')
                    .toSet()
                    .length >
                1,
          )
          .toList();
      if (differing.isNotEmpty) {
        issues.add(
          DataIssue(
            code: 'DESTINATION_COLLAPSE_RISK',
            severity: ValidationSeverity.error,
            message:
                'Service ${entry.key} has variants in ${differing.map((e) => e.header).join(', ')} that the selected SQL-derived destination does not preserve.',
            sheet: region.sheetName,
            sourceRow: entry.value.first.rowNumber,
            targetFieldId: 'service_code',
          ),
        );
      }
    }
    return issues;
  }
}

class DuplicateDetector {
  const DuplicateDetector();

  List<DuplicateGroup> detect(
    TargetTemplate template,
    List<PreparedRecord> records, {
    String clientId = '',
  }) {
    final result = <DuplicateGroup>[];
    final included = records.where((r) => !r.excluded).toList();
    for (final keyFields in template.uniqueKeys) {
      final groups = <String, List<PreparedRecord>>{};
      for (final record in included) {
        final key = [
          clientId,
          ...keyFields.map((f) => _normalize(record.values[f])),
        ].join('|');
        if (keyFields.any((f) => _normalize(record.values[f]).isEmpty)) {
          continue;
        }
        groups.putIfAbsent(key, () => []).add(record);
      }
      for (final entry in groups.entries.where((e) => e.value.length > 1)) {
        final conflicts = template.fields
            .where(
              (f) =>
                  entry.value
                      .map((r) => _normalize(r.values[f.id]))
                      .toSet()
                      .length >
                  1,
            )
            .map((f) => f.id)
            .toList();
        result.add(
          DuplicateGroup(
            id: 'key:${entry.key}',
            kind: conflicts.isEmpty ? 'duplicate-key' : 'conflicting-key',
            key: entry.key,
            records: entry.value
              ..sort((a, b) => a.sourceRowNumber.compareTo(b.sourceRowNumber)),
            conflictingFields: conflicts,
          ),
        );
      }
    }
    final exact = <String, List<PreparedRecord>>{};
    for (final record in included) {
      final key = template.fields
          .map((f) => _normalize(record.values[f.id]))
          .join('\u001f');
      exact.putIfAbsent(key, () => []).add(record);
    }
    for (final entry in exact.entries.where((e) => e.value.length > 1)) {
      if (result.any(
        (g) => g.records
            .map((r) => r.sourceRowNumber)
            .toSet()
            .containsAll(entry.value.map((r) => r.sourceRowNumber)),
      )) {
        continue;
      }
      result.add(
        DuplicateGroup(
          id: 'row:${entry.key.hashCode}',
          kind: 'exact-row',
          key: entry.key,
          records: entry.value,
          conflictingFields: const [],
        ),
      );
    }
    result.sort(
      (a, b) => a.records.first.sourceRowNumber.compareTo(
        b.records.first.sourceRowNumber,
      ),
    );
    return result;
  }

  List<DuplicateGroup> possiblePeople(
    List<PreparedRecord> records, {
    String nameField = 'full_name',
    String? supportingField,
  }) {
    final buckets = <String, List<PreparedRecord>>{};
    for (final record in records.where((r) => !r.excluded)) {
      final name = _normalizeName(record.values[nameField]);
      if (name.isEmpty) continue;
      final prefix = name.length > 3 ? name.substring(0, 3) : name;
      buckets.putIfAbsent(prefix, () => []).add(record);
    }
    final groups = <DuplicateGroup>[];
    for (final bucket in buckets.values) {
      final byName = <String, List<PreparedRecord>>{};
      for (final record in bucket) {
        final name = _normalizeName(record.values[nameField]);
        byName.putIfAbsent(name, () => []).add(record);
      }
      for (final entry in byName.entries.where((e) => e.value.length > 1)) {
        final supporting = supportingField == null
            ? const <String>{}
            : entry.value
                  .map((r) => _normalize(r.values[supportingField]))
                  .toSet();
        groups.add(
          DuplicateGroup(
            id: 'person:${entry.key}',
            kind: 'possible-person',
            key: entry.key,
            records: entry.value,
            conflictingFields: supporting.length > 1
                ? [supportingField!]
                : const [],
          ),
        );
      }
    }
    return groups;
  }

  static String _normalize(Object? value) =>
      value?.toString().trim().toLowerCase() ?? '';
  static String _normalizeName(Object? value) =>
      _normalize(value)
          .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
}

class ReferenceLookupEngine {
  const ReferenceLookupEngine();

  ReferenceLookupResult match(
    Iterable<Object?> sourceValues,
    ReferenceRegion region, {
    bool caseSensitive = false,
  }) {
    String normalize(Object? value) {
      final text = value?.toString().trim() ?? '';
      return caseSensitive ? text : text.toLowerCase();
    }

    final index = <String, List<ReferenceEntry>>{};
    for (final entry in region.entries) {
      index.putIfAbsent(normalize(entry.key), () => []).add(entry);
      index.putIfAbsent(normalize(entry.label), () => []).add(entry);
    }
    final matches = <String, ReferenceEntry>{};
    final unmatched = <String>{};
    final ambiguous = <String, List<ReferenceEntry>>{};
    for (final raw in sourceValues) {
      final value = raw?.toString() ?? '';
      final candidates = index[normalize(value)] ?? const [];
      if (candidates.isEmpty) {
        unmatched.add(value);
      } else if (candidates.map((e) => e.key).toSet().length > 1 ||
          candidates.length > 1) {
        ambiguous[value] = candidates;
      } else {
        matches[value] = candidates.single;
      }
    }
    return ReferenceLookupResult(
      matches: matches,
      unmatched: unmatched,
      ambiguous: ambiguous,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
