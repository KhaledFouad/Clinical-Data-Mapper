import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../models/domain.dart';

class UnsupportedWorkbookException implements Exception {
  const UnsupportedWorkbookException(this.message);
  final String message;
  @override
  String toString() => message;
}

class XlsxService {
  const XlsxService();

  Future<WorkbookInspection> inspectFile(String path) async {
    _requireXlsx(path);
    final bytes = await File(path).readAsBytes();
    _requireZip(bytes);
    try {
      final payload = await compute(_inspectPayload, bytes);
      return _inspectionFromPayload(payload);
    } catch (error) {
      throw UnsupportedWorkbookException(
        'The workbook is encrypted, corrupted, or unreadable: $error',
      );
    }
  }

  WorkbookInspection inspectBytes(Uint8List bytes) {
    _requireZip(bytes);
    return _inspectionFromPayload(_inspectPayload(bytes));
  }

  WorkbookRegion readRegion(
    Uint8List bytes, {
    required String sheetName,
    required int headerRow,
    required int firstDataRow,
    int? lastDataRow,
  }) {
    _requireZip(bytes);
    if (headerRow < 1 || firstDataRow <= headerRow) {
      throw const FormatException(
        'Header and data rows are 1-based; the first data row must follow the header.',
      );
    }
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables[sheetName];
    if (sheet == null) {
      throw FormatException('Sheet “$sheetName” does not exist.');
    }
    final headerCells = headerRow <= sheet.rows.length
        ? sheet.rows[headerRow - 1]
        : const <Data?>[];
    final width = sheet.maxColumns;
    final headers = List.generate(
      width,
      (i) => i < headerCells.length
          ? headerCells[i]?.value?.toString().trim() ?? ''
          : '',
    );
    final counts = <String, int>{};
    for (final header in headers.where((e) => e.isNotEmpty)) {
      counts[header.toLowerCase()] = (counts[header.toLowerCase()] ?? 0) + 1;
    }
    final columns = List.generate(
      width,
      (i) => SourceColumn(
        index: i,
        letter: _columnLetter(i),
        header: headers[i],
        duplicateHeader:
            headers[i].isNotEmpty &&
            (counts[headers[i].toLowerCase()] ?? 0) > 1,
      ),
    );
    final end = (lastDataRow ?? sheet.maxRows).clamp(
      firstDataRow,
      sheet.maxRows,
    );
    final rows = <SourceRow>[];
    for (var rowNumber = firstDataRow; rowNumber <= end; rowNumber++) {
      final data = rowNumber <= sheet.rows.length
          ? sheet.rows[rowNumber - 1]
          : const <Data?>[];
      final cells = <int, SourceCell>{};
      for (var column = 0; column < width; column++) {
        final value = column < data.length ? data[column]?.value : null;
        cells[column] = _sourceCell(value);
      }
      rows.add(SourceRow(rowNumber: rowNumber, cells: cells));
    }
    return WorkbookRegion(
      workbookFingerprint: sha256.convert(bytes).toString(),
      sheetName: sheetName,
      headerRow: headerRow,
      firstDataRow: firstDataRow,
      lastDataRow: lastDataRow,
      columns: columns,
      rows: rows,
      mergedRanges: List.unmodifiable(sheet.spannedItems),
    );
  }

  Uint8List exportBytes(
    TargetTemplate template,
    Iterable<PreparedRecord> records, {
    bool eligibleOnly = false,
    Set<int> blockedRows = const {},
  }) {
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != template.outputSheetName) {
      workbook.rename(defaultSheet, template.outputSheetName);
    }
    final sheet = workbook[template.outputSheetName];
    for (var column = 0; column < template.fields.length; column++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: column,
              rowIndex: template.headerRow - 1,
            ),
          )
          .value = TextCellValue(
        template.fields[column].header,
      );
    }
    var outputRow = template.headerRow;
    for (final record in records) {
      if (record.excluded ||
          (eligibleOnly && blockedRows.contains(record.sourceRowNumber))) {
        continue;
      }
      for (var column = 0; column < template.fields.length; column++) {
        final field = template.fields[column];
        final value = record.values[field.id];
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: outputRow,
              ),
            )
            .value = _excelValue(
          value,
          field.type,
        );
      }
      outputRow++;
    }
    final result = workbook.save();
    if (result == null) {
      throw const FileSystemException('Could not encode workbook.');
    }
    return Uint8List.fromList(result);
  }

  Future<void> exportSafely({
    required String destinationPath,
    required String sourcePath,
    required Uint8List bytes,
    bool Function()? isCancelled,
  }) async {
    _requireXlsx(destinationPath);
    final source = File(sourcePath).absolute.path.toLowerCase();
    final destination = File(destinationPath).absolute.path.toLowerCase();
    if (source == destination) {
      throw const FileSystemException(
        'The export destination cannot overwrite the source workbook.',
      );
    }
    if (isCancelled?.call() ?? false) {
      throw const FileSystemException('Export cancelled before writing.');
    }
    final target = File(destinationPath);
    final temporary = File('$destinationPath.clinical-mapper.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (isCancelled?.call() ?? false) {
        await temporary.delete();
        throw const FileSystemException(
          'Export cancelled; the incomplete temporary file was removed.',
        );
      }
      if (await target.exists()) await target.delete();
      await temporary.rename(destinationPath);
    } on FileSystemException {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Uint8List issueReportBytes(List<DataIssue> issues, List<AuditEntry> audit) {
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null) workbook.rename(defaultSheet, 'Issues');
    final issuesSheet = workbook['Issues'];
    issuesSheet.appendRow(
      [
        'Severity',
        'Code',
        'Sheet',
        'Row',
        'Column',
        'Target field',
        'Message',
      ].map(TextCellValue.new).toList(),
    );
    for (final issue in issues) {
      issuesSheet.appendRow([
        TextCellValue(issue.severity.name),
        TextCellValue(issue.code),
        TextCellValue(issue.sheet),
        issue.sourceRow == null ? null : IntCellValue(issue.sourceRow!),
        issue.sourceColumn == null
            ? null
            : TextCellValue(_columnLetter(issue.sourceColumn!)),
        TextCellValue(issue.targetFieldId ?? ''),
        TextCellValue(issue.message),
      ]);
    }
    final auditSheet = workbook['Audit'];
    auditSheet.appendRow(
      [
        'Time',
        'Action',
        'Source row',
        'Target field',
        'Original',
        'Result',
        'Detail',
      ].map(TextCellValue.new).toList(),
    );
    for (final entry in audit) {
      auditSheet.appendRow([
        TextCellValue(entry.at.toIso8601String()),
        TextCellValue(entry.action),
        IntCellValue(entry.sourceRow),
        TextCellValue(entry.targetFieldId ?? ''),
        TextCellValue(entry.originalValue?.toString() ?? ''),
        TextCellValue(entry.resultingValue?.toString() ?? ''),
        TextCellValue(entry.detail),
      ]);
    }
    return Uint8List.fromList(workbook.save()!);
  }

  static void _requireXlsx(String path) {
    if (!path.toLowerCase().endsWith('.xlsx')) {
      throw const UnsupportedWorkbookException(
        'Only .xlsx workbooks are supported.',
      );
    }
  }

  static void _requireZip(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
      throw const UnsupportedWorkbookException(
        'The selected file is not a valid XLSX ZIP container.',
      );
    }
  }
}

Map<String, Object?> _inspectPayload(Uint8List bytes) {
  final workbook = Excel.decodeBytes(bytes);
  return {
    'fingerprint': sha256.convert(bytes).toString(),
    'sheets': workbook.tables.entries.map((entry) {
      final sheet = entry.value;
      final preview = sheet.rows
          .take(12)
          .map(
            (row) => List.generate(
              sheet.maxColumns,
              (i) => i < row.length ? row[i]?.value?.toString() ?? '' : '',
            ),
          )
          .toList();
      return <String, Object?>{
        'name': entry.key,
        'rowCount': sheet.maxRows,
        'columnCount': sheet.maxColumns,
        'suggestedHeaderRow': _suggestHeader(preview),
        'preview': preview,
        'mergedRanges': List<String>.from(sheet.spannedItems),
      };
    }).toList(),
  };
}

WorkbookInspection _inspectionFromPayload(Map<String, Object?> payload) =>
    WorkbookInspection(
      fingerprint: payload['fingerprint']! as String,
      sheets: (payload['sheets']! as List).map((raw) {
        final map = (raw as Map).cast<String, Object?>();
        return SheetInspection(
          name: map['name']! as String,
          rowCount: map['rowCount']! as int,
          columnCount: map['columnCount']! as int,
          suggestedHeaderRow: map['suggestedHeaderRow']! as int,
          preview: (map['preview']! as List)
              .map((row) => (row as List).cast<String>())
              .toList(),
          mergedRanges: (map['mergedRanges']! as List).cast<String>(),
        );
      }).toList(),
    );

int _suggestHeader(List<List<String>> preview) {
  if (preview.isEmpty) return 1;
  var bestRow = 0;
  var bestScore = -1.0;
  for (var i = 0; i < preview.length; i++) {
    final values = preview[i]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (values.isEmpty) continue;
    final strings = values.where((e) => num.tryParse(e) == null).length;
    final uniqueness = values.toSet().length / values.length;
    final score = strings + uniqueness - (i * .01);
    if (score > bestScore) {
      bestScore = score;
      bestRow = i;
    }
  }
  return bestRow + 1;
}

SourceCell _sourceCell(CellValue? value) {
  if (value == null) return const SourceCell(type: SourceCellType.empty);
  return switch (value) {
    TextCellValue() => _textCell(value.toString()),
    FormulaCellValue() => SourceCell(
      type: SourceCellType.formula,
      value: value.formula,
      formula: value.formula,
    ),
    IntCellValue() => SourceCell(
      type: SourceCellType.integer,
      value: value.value,
    ),
    DoubleCellValue() => SourceCell(
      type: SourceCellType.decimal,
      value: value.value,
    ),
    DateCellValue() => SourceCell(
      type: SourceCellType.date,
      value: value.asDateTimeLocal(),
    ),
    DateTimeCellValue() => SourceCell(
      type: SourceCellType.dateTime,
      value: value.asDateTimeLocal(),
    ),
    TimeCellValue() => SourceCell(
      type: SourceCellType.text,
      value: value.toString(),
    ),
    BoolCellValue() => SourceCell(
      type: SourceCellType.boolean,
      value: value.value,
    ),
  };
}

SourceCell _textCell(String value) {
  if (RegExp(r'^#(REF|VALUE|DIV/0|NAME|N/A|NUM|NULL)!?$')
      .hasMatch(value.toUpperCase())) {
    return SourceCell(type: SourceCellType.error, value: value);
  }
  return SourceCell(type: SourceCellType.text, value: value);
}

CellValue? _excelValue(Object? value, FieldType type) {
  if (value == null) return null;
  if (type == FieldType.identifier ||
      type == FieldType.phone ||
      type == FieldType.text ||
      type == FieldType.email) {
    return TextCellValue(value.toString());
  }
  if (type == FieldType.integer && value is int) return IntCellValue(value);
  if (type == FieldType.decimal && value is int) return IntCellValue(value);
  if (type == FieldType.decimal && value is num) {
    return DoubleCellValue(value.toDouble());
  }
  if (type == FieldType.boolean && value is bool) return BoolCellValue(value);
  if (type == FieldType.date && value is DateTime) {
    return DateCellValue.fromDateTime(value);
  }
  return TextCellValue(value.toString());
}

String _columnLetter(int zeroBased) {
  var value = zeroBased + 1;
  var result = '';
  while (value > 0) {
    value--;
    result = String.fromCharCode(65 + value % 26) + result;
    value ~/= 26;
  }
  return result;
}
