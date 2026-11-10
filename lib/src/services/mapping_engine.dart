import '../models/domain.dart';

class MappingSuggestion {
  const MappingSuggestion({
    required this.field,
    required this.column,
    required this.score,
    required this.reasons,
    this.typeConflict = false,
  });

  final TargetField field;
  final SourceColumn column;
  final double score;
  final List<String> reasons;
  final bool typeConflict;
}

class MappingEngine {
  const MappingEngine();

  List<MappingSuggestion> suggest(
    TargetTemplate template,
    WorkbookRegion region,
  ) {
    final result = <MappingSuggestion>[];
    for (final field in template.fields) {
      for (final column in region.columns) {
        final header = _normalize(column.header);
        final candidates = [field.header, ...field.aliases].map(_normalize);
        var score = 0.0;
        final reasons = <String>[];
        if (candidates.contains(header) && header.isNotEmpty) {
          score = 1;
          reasons.add('Header matches a configured alias.');
        } else if (header.isNotEmpty &&
            candidates.any((e) => e.contains(header) || header.contains(e))) {
          score = .7;
          reasons.add('Header partially matches a configured alias.');
        }
        final conflict = _hasTypeConflict(
          field.type,
          region.rows.map((r) => r.cells[column.index]).whereType<SourceCell>(),
        );
        if (conflict) {
          score -= .25;
          reasons.add(
            'Observed values conflict with target type ${field.type.name}; confirmation required.',
          );
        } else if (score > 0) {
          reasons.add('Sample values are compatible with the proposed type.');
        }
        if (score >= .45) {
          result.add(
            MappingSuggestion(
              field: field,
              column: column,
              score: score,
              reasons: reasons,
              typeConflict: conflict,
            ),
          );
        }
      }
    }
    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  List<DataIssue> profileCompatibility(
    MappingProfile profile,
    WorkbookRegion region,
  ) {
    final current = region.columns.map((e) => e.header).toList();
    final issues = <DataIssue>[];
    for (var i = 0; i < profile.expectedHeaders.length; i++) {
      final expected = profile.expectedHeaders[i];
      if (i >= current.length) {
        issues.add(
          DataIssue(
            code: 'PROFILE_COLUMN_MISSING',
            severity: ValidationSeverity.error,
            message: 'Expected column $i “$expected” is missing.',
            sheet: region.sheetName,
            sourceColumn: i,
          ),
        );
      } else if (current[i] != expected) {
        final renamedAt = current.indexOf(expected);
        issues.add(
          DataIssue(
            code: renamedAt >= 0
                ? 'PROFILE_COLUMN_MOVED'
                : 'PROFILE_COLUMN_RENAMED',
            severity: ValidationSeverity.warning,
            message: renamedAt >= 0
                ? '“$expected” moved from column ${i + 1} to ${renamedAt + 1}; stale positions were not applied.'
                : 'Column ${i + 1} was “$expected” and is now “${current[i]}”; review the mapping.',
            sheet: region.sheetName,
            sourceColumn: i,
          ),
        );
      }
    }
    if (current.length > profile.expectedHeaders.length) {
      for (var i = profile.expectedHeaders.length; i < current.length; i++) {
        issues.add(
          DataIssue(
            code: 'PROFILE_ADDITIONAL_COLUMN',
            severity: ValidationSeverity.information,
            message:
                'Additional source column “${current[i]}” requires a disposition.',
            sheet: region.sheetName,
            sourceColumn: i,
          ),
        );
      }
    }
    return issues;
  }

  List<PreparedRecord> apply(
    TargetTemplate template,
    WorkbookRegion region,
    List<FieldMapping> mappings,
  ) {
    final byField = {for (final m in mappings) m.targetFieldId: m};
    return region.rows.map((row) {
      final values = <String, Object?>{};
      final provenance = <String, CellProvenance>{};
      for (final field in template.fields) {
        final mapping = byField[field.id];
        if (mapping == null) {
          values[field.id] = field.defaultValue;
          continue;
        }
        final sourceCells = mapping.sourceColumnIndexes
            .map(
              (i) =>
                  row.cells[i] ?? const SourceCell(type: SourceCellType.empty),
            )
            .toList();
        Object? value = mapping.constantValue;
        if (value == null && sourceCells.isNotEmpty) {
          value = sourceCells.length == 1
              ? sourceCells.first.value
              : sourceCells.map((e) => e.value).toList();
        }
        for (final step in mapping.steps) {
          value = _transform(value, step);
        }
        if (_isEmpty(value)) {
          value = mapping.fallbackValue ?? field.defaultValue;
        }
        values[field.id] = value;
        if (mapping.sourceColumnIndexes.isNotEmpty) {
          provenance[field.id] = CellProvenance(
            sheet: region.sheetName,
            row: row.rowNumber,
            columns: mapping.sourceColumnIndexes,
            originalValues: sourceCells.map((e) => e.value).toList(),
          );
        }
      }
      return PreparedRecord(
        sourceRowNumber: row.rowNumber,
        values: values,
        provenance: provenance,
        excluded: row.excluded,
        exclusionReason: row.exclusionReason,
      );
    }).toList();
  }

  Object? _transform(Object? value, TransformationStep step) {
    switch (step.type) {
      case TransformationType.trim:
        return value?.toString().trim();
      case TransformationType.normalizeWhitespace:
        return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
      case TransformationType.upperCase:
        return value?.toString().toUpperCase();
      case TransformationType.lowerCase:
        return value?.toString().toLowerCase();
      case TransformationType.combine:
        final separator = step.options['separator'] as String? ?? ' ';
        if (value is List) {
          return value
              .where((e) => !_isEmpty(e))
              .map((e) => e.toString())
              .join(separator);
        }
        return value;
      case TransformationType.split:
        final separator = step.options['separator'] as String? ?? ' ';
        final index = step.options['index'] as int? ?? 0;
        final parts = value?.toString().split(separator) ?? const <String>[];
        return index >= 0 && index < parts.length ? parts[index] : null;
      case TransformationType.replace:
        final replacements = (step.options['values'] as Map? ?? const {})
            .cast<String, Object?>();
        return replacements[value?.toString()] ?? value;
      case TransformationType.decimal:
        return _parseDecimal(
          value,
          step.options['decimalSeparator'] as String? ?? '.',
        );
      case TransformationType.date:
        return _parseDate(value, step.options['order'] as String? ?? 'YMD');
      case TransformationType.referenceLookup:
        final values = (step.options['values'] as Map? ?? const {})
            .cast<String, Object?>();
        return values[value?.toString()];
    }
  }

  static num? _parseDecimal(Object? value, String decimalSeparator) {
    if (value is num) return value;
    var text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final grouping = decimalSeparator == ',' ? '.' : ',';
    text = text.replaceAll(grouping, '').replaceAll(decimalSeparator, '.');
    return num.tryParse(text);
  }

  static DateTime? _parseDate(Object? value, String order) {
    if (value is DateTime) return value;
    final parts =
        value?.toString().trim().split(RegExp(r'[-/.]')) ?? const <String>[];
    if (parts.length != 3 || parts.any((e) => int.tryParse(e) == null)) {
      return null;
    }
    final n = parts.map(int.parse).toList();
    try {
      return switch (order) {
        'DMY' => DateTime(n[2], n[1], n[0]),
        'MDY' => DateTime(n[2], n[0], n[1]),
        _ => DateTime(n[0], n[1], n[2]),
      };
    } on ArgumentError {
      return null;
    }
  }

  static bool _hasTypeConflict(FieldType type, Iterable<SourceCell> cells) {
    final nonEmpty = cells
        .where((e) => e.type != SourceCellType.empty)
        .take(50)
        .toList();
    if (nonEmpty.isEmpty) return false;
    final compatible = nonEmpty.where((cell) {
      return switch (type) {
        FieldType.text ||
        FieldType.identifier ||
        FieldType.email ||
        FieldType.phone => true,
        FieldType.integer =>
          cell.type == SourceCellType.integer ||
              int.tryParse(cell.displayValue) != null,
        FieldType.decimal =>
          cell.type == SourceCellType.integer ||
              cell.type == SourceCellType.decimal ||
              num.tryParse(cell.displayValue) != null,
        FieldType.date =>
          cell.type == SourceCellType.date ||
              cell.type == SourceCellType.dateTime,
        FieldType.boolean =>
          cell.type == SourceCellType.boolean ||
              const [
                '0',
                '1',
                'true',
                'false',
              ].contains(cell.displayValue.toLowerCase()),
      };
    }).length;
    return compatible / nonEmpty.length < .8;
  }

  static bool _isEmpty(Object? value) =>
      value == null || (value is String && value.trim().isEmpty);

  static String _normalize(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
