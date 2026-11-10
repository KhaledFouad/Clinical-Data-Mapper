import 'package:clinical_data_mapper/src/models/domain.dart';
import 'package:clinical_data_mapper/src/services/mapping_engine.dart';
import 'package:clinical_data_mapper/src/services/quality_engine.dart';
import 'package:clinical_data_mapper/src/services/seed_templates.dart';
import 'package:clinical_data_mapper/src/services/xlsx_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  const xlsx = XlsxService();
  const mapper = MappingEngine();
  const validator = ValidationEngine();

  test('same service code with care-setting variants remains separate', () {
    final bytes = workbookBytes(
      headers: const [
        'ClinicName',
        'Service Code',
        'Column1',
        'Service Name',
        'Price',
        'Column2',
        'Revenue',
      ],
      rows: const [
        ['Lab', 'LAB-001', 'CBC', 'فحص الدم', 100, 'خارجي', '4111010002'],
        ['Lab', 'LAB-001', 'CBC', 'فحص الدم', 100, 'داخلي', '4111010009'],
      ],
    );
    final region = xlsx.readRegion(
      bytes,
      sheetName: 'Data',
      headerRow: 1,
      firstDataRow: 2,
    );
    final mappings = const [
      FieldMapping(targetFieldId: 'clinic_name', sourceColumnIndexes: [0]),
      FieldMapping(targetFieldId: 'service_code', sourceColumnIndexes: [1]),
      FieldMapping(targetFieldId: 'service_name_e', sourceColumnIndexes: [2]),
      FieldMapping(targetFieldId: 'service_name_f', sourceColumnIndexes: [3]),
      FieldMapping(targetFieldId: 'net_price', sourceColumnIndexes: [4]),
    ];
    final prepared = mapper.apply(
      SeedTemplates.clinicsAndServices,
      region,
      mappings,
    );
    expect(prepared, hasLength(2));
    expect(region.rows.map((r) => r.cells[5]!.value), ['خارجي', 'داخلي']);
    expect(region.rows.map((r) => r.cells[6]!.value), [
      '4111010002',
      '4111010009',
    ]);
    final issues = validator.detectLossyServiceCollapse(region, mappings);
    expect(issues.map((e) => e.code), contains('DESTINATION_COLLAPSE_RISK'));
    expect(issues.single.message, contains('Column2'));
    expect(issues.single.message, contains('Revenue'));
  });

  test('department names under Active cause a type conflict warning', () {
    final bytes = workbookBytes(
      headers: const ['Active'],
      rows: const [
        ['HEMATOLOGY'],
        ['SEROLOGY & IMMUNOLOGY'],
      ],
    );
    final region = xlsx.readRegion(
      bytes,
      sheetName: 'Data',
      headerRow: 1,
      firstDataRow: 2,
    );
    const template = TargetTemplate(
      id: 'active',
      version: 1,
      name: 'Active',
      description: '',
      verification: TemplateVerification.inferredFromSql,
      fields: [
        TargetField(
          id: 'active',
          header: 'Active',
          type: FieldType.boolean,
          aliases: ['active'],
        ),
      ],
    );
    final suggestion = mapper.suggest(template, region).single;
    expect(suggestion.typeConflict, isTrue);
    expect(suggestion.reasons.join(' '), contains('confirmation required'));
  });

  test('English and Arabic service names map independently', () {
    final bytes = workbookBytes(
      headers: const ['Column1', 'Service Name'],
      rows: const [
        ['MEDICAL CONSULTATION', 'معاينة طبية'],
      ],
    );
    final region = xlsx.readRegion(
      bytes,
      sheetName: 'Data',
      headerRow: 1,
      firstDataRow: 2,
    );
    final records = mapper.apply(
      SeedTemplates.clinicsAndServices,
      region,
      const [
        FieldMapping(targetFieldId: 'service_name_e', sourceColumnIndexes: [0]),
        FieldMapping(targetFieldId: 'service_name_f', sourceColumnIndexes: [1]),
      ],
    );
    expect(records.single.values['service_name_e'], 'MEDICAL CONSULTATION');
    expect(records.single.values['service_name_f'], 'معاينة طبية');
  });

  test('reference lookups report unmatched and ambiguous keys', () {
    const region = ReferenceRegion(
      id: 'categories',
      workbookFingerprint: 'abc',
      sheetName: 'Category',
      headerRow: 1,
      keyColumnIndex: 0,
      labelColumnIndex: 1,
      entries: [
        ReferenceEntry(key: '1', label: 'Examination', sourceRow: 2),
        ReferenceEntry(key: '2', label: 'Follow up', sourceRow: 3),
        ReferenceEntry(key: '3', label: 'Follow up', sourceRow: 4),
      ],
    );
    final result = const ReferenceLookupEngine().match(const [
      'Examination',
      'Follow up',
      'Unknown',
    ], region);
    expect(result.matches['Examination']!.key, '1');
    expect(result.ambiguous, contains('Follow up'));
    expect(result.unmatched, contains('Unknown'));
  });

  test('profile drift never silently applies stale positions', () {
    final bytes = workbookBytes(
      headers: const ['Name', 'New field', 'Code'],
      rows: const [
        ['A', 'x', '01'],
      ],
    );
    final region = xlsx.readRegion(
      bytes,
      sheetName: 'Data',
      headerRow: 1,
      firstDataRow: 2,
    );
    const profile = MappingProfile(
      id: 'p',
      clientId: 'c',
      templateId: 't',
      templateVersion: 1,
      expectedHeaders: ['Code', 'Name'],
      mappings: [],
    );
    final issues = mapper.profileCompatibility(profile, region);
    expect(issues.map((e) => e.code), contains('PROFILE_COLUMN_MOVED'));
    expect(issues.map((e) => e.code), contains('PROFILE_ADDITIONAL_COLUMN'));
  });

  test('section row is reviewable and exclusion is not implicit', () {
    final bytes = workbookBytes(
      headers: const ['Clinic Code', 'Service Code', 'Name', 'Revenue'],
      rows: const [
        ['خدمات العيادات', null, null, '4111010001'],
        ['OPD', 'OPD-1', 'Consultation', '4111010001'],
      ],
    );
    final region = xlsx.readRegion(
      bytes,
      sheetName: 'Data',
      headerRow: 1,
      firstDataRow: 2,
    );
    final issues = validator.detectSectionRows(region);
    expect(issues.map((e) => e.code), contains('POSSIBLE_SECTION_ROW'));
    expect(region.rows.first.excluded, isFalse);
    region.rows.first
      ..excluded = true
      ..exclusionReason = 'Confirmed section row';
    expect(region.rows.first.exclusionReason, 'Confirmed section row');
  });

  test('different category schemes require explicit disposition', () {
    final bytes = workbookBytes(
      headers: const ['Service Code', 'Category Code'],
      rows: const [
        ['LAB-1', 1],
        ['RAD-1', 'RAD-1'],
      ],
    );
    final region = xlsx.readRegion(
      bytes,
      sheetName: 'Data',
      headerRow: 1,
      firstDataRow: 2,
    );
    final issues = validator.validateConfiguration(
      SeedTemplates.clinicsAndServices,
      const [
        FieldMapping(targetFieldId: 'service_code', sourceColumnIndexes: [0]),
      ],
      region,
    );
    expect(
      issues.where((e) => e.sourceColumn == 1).single.code,
      'UNMAPPED_SOURCE_COLUMN',
    );
  });
}
