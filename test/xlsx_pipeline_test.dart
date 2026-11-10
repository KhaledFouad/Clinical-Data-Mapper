import 'dart:io';

import 'package:clinical_data_mapper/src/models/domain.dart';
import 'package:clinical_data_mapper/src/services/mapping_engine.dart';
import 'package:clinical_data_mapper/src/services/seed_templates.dart';
import 'package:clinical_data_mapper/src/services/xlsx_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  const xlsx = XlsxService();

  test('header selection works on row 2 and preserves duplicate headers', () {
    final bytes = workbookBytes(
      headerRow: 2,
      headers: const ['Code', 'Name', 'Name'],
      rows: const [
        ['001', 'English', 'العربية'],
      ],
    );
    final inspection = xlsx.inspectBytes(bytes);
    expect(inspection.sheets.single.suggestedHeaderRow, 2);
    final region = xlsx.readRegion(
      bytes,
      sheetName: 'Data',
      headerRow: 2,
      firstDataRow: 3,
    );
    expect(region.columns[1].duplicateHeader, isTrue);
    expect(region.columns[2].identity, 'C · Name');
    expect(region.rows.single.cells[0]!.value, '001');
  });

  test('formula cells are flagged while formula-like text stays literal', () {
    final bytes = workbookBytes(
      headers: const ['Code', 'Text'],
      rows: const [
        [FormulaValue('=A1'), "'=A1"],
      ],
    );
    final region = xlsx.readRegion(
      bytes,
      sheetName: 'Data',
      headerRow: 1,
      firstDataRow: 2,
    );
    expect(region.rows.single.cells[0]!.type, SourceCellType.formula);
    expect(region.rows.single.cells[1]!.type, SourceCellType.text);
  });

  test('accounting identifiers and leading zeros survive export readback', () {
    const template = TargetTemplate(
      id: 'accounts',
      version: 1,
      name: 'Accounts',
      description: '',
      verification: TemplateVerification.inferredFromSql,
      fields: [
        TargetField(
          id: 'service',
          header: 'Service',
          type: FieldType.identifier,
        ),
        TargetField(
          id: 'revenue',
          header: 'Revenue',
          type: FieldType.identifier,
        ),
        TargetField(id: 'cost', header: 'Cost', type: FieldType.identifier),
        TargetField(id: 'store', header: 'Store', type: FieldType.identifier),
        TargetField(id: 'phone', header: 'Phone', type: FieldType.phone),
      ],
    );
    final record = PreparedRecord(
      sourceRowNumber: 2,
      values: const {
        'service': '0012',
        'revenue': '4111010002',
        'cost': '03122010002',
        'store': '01131020003',
        'phone': '+00213 0550 001',
      },
      provenance: const {},
    );
    final output = xlsx.exportBytes(template, [record]);
    final decoded = Excel.decodeBytes(output);
    final values = decoded.tables['Import']!.rows[1]
        .map((e) => e!.value)
        .toList();
    expect(values.every((v) => v is TextCellValue), isTrue);
    expect(values.map((v) => v.toString()), record.values.values);
  });

  test('real import-to-export pipeline preserves exact header order', () {
    final input = workbookBytes(
      headers: const ['Price', 'Service Name', 'Code', 'Clinic', 'English'],
      rows: const [
        ['1,250.50', 'خدمة', '0007', 'OPD', 'Consultation'],
      ],
    );
    final region = xlsx.readRegion(
      input,
      sheetName: 'Data',
      headerRow: 1,
      firstDataRow: 2,
    );
    const mappings = [
      FieldMapping(targetFieldId: 'clinic_name', sourceColumnIndexes: [3]),
      FieldMapping(targetFieldId: 'service_code', sourceColumnIndexes: [2]),
      FieldMapping(targetFieldId: 'service_name_e', sourceColumnIndexes: [4]),
      FieldMapping(targetFieldId: 'service_name_f', sourceColumnIndexes: [1]),
      FieldMapping(
        targetFieldId: 'net_price',
        sourceColumnIndexes: [0],
        steps: [
          TransformationStep(TransformationType.decimal, {
            'decimalSeparator': '.',
          }),
        ],
      ),
    ];
    final prepared = const MappingEngine().apply(
      SeedTemplates.clinicsAndServices,
      region,
      mappings,
    );
    final output = xlsx.exportBytes(SeedTemplates.clinicsAndServices, prepared);
    final sheet = Excel.decodeBytes(output).tables['ServicePrice']!;
    expect(sheet.rows.first.map((e) => e!.value.toString()), [
      'ClinicName',
      'ServiceCode',
      'ServiceNameE',
      'ServiceNameF',
      'NetPrice',
    ]);
    expect(sheet.rows[1][1]!.value.toString(), '0007');
    expect(sheet.rows[1][3]!.value.toString(), 'خدمة');
    expect(sheet.rows[1][4]!.value.toString(), '1250.5');
  });

  test(
    'safe export blocks source overwrite and handles cancellation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'clinical-mapper-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/source.xlsx')
        ..writeAsBytesSync([1, 2, 3]);
      await expectLater(
        xlsx.exportSafely(
          destinationPath: source.path,
          sourcePath: source.path,
          bytes: workbookBytes(headers: const ['A'], rows: const []),
        ),
        throwsA(isA<FileSystemException>()),
      );
      final destination = '${directory.path}/output.xlsx';
      await expectLater(
        xlsx.exportSafely(
          destinationPath: destination,
          sourcePath: source.path,
          bytes: workbookBytes(headers: const ['A'], rows: const []),
          isCancelled: () => true,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(destination).existsSync(), isFalse);
    },
  );

  test('synthetic 7700-row workbook completes practical round-trip', () {
    final stopwatch = Stopwatch()..start();
    final input = workbookBytes(
      headers: const ['code', 'FullName'],
      rows: List.generate(
        7700,
        (i) => [
          '${i + 1}'.padLeft(6, '0'),
          i.isEven ? 'Jean Élève $i' : 'طبيب $i',
        ],
      ),
    );
    final region = xlsx.readRegion(
      input,
      sheetName: 'Data',
      headerRow: 1,
      firstDataRow: 2,
    );
    final records = const MappingEngine().apply(
      SeedTemplates.referringDoctors,
      region,
      const [
        FieldMapping(targetFieldId: 'code', sourceColumnIndexes: [0]),
        FieldMapping(targetFieldId: 'full_name', sourceColumnIndexes: [1]),
      ],
    );
    final output = xlsx.exportBytes(SeedTemplates.referringDoctors, records);
    final readback = Excel.decodeBytes(output).tables['ReferringDoctors']!;
    stopwatch.stop();
    expect(region.rows, hasLength(7700));
    expect(readback.maxRows, 7701);
    expect(readback.rows.last[0]!.value.toString(), '007700');
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
  });
}
