import 'dart:convert';

import 'package:clinical_data_mapper/src/models/domain.dart';
import 'package:clinical_data_mapper/src/services/seed_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ships three editable SQL-inferred templates', () {
    expect(SeedTemplates.all, hasLength(3));
    expect(
      SeedTemplates.all.every(
        (template) =>
            template.verification == TemplateVerification.inferredFromSql,
      ),
      isTrue,
    );
    expect(SeedTemplates.referringDoctors.fields.map((field) => field.header), [
      'code',
      'FullName',
      'Prefix',
      'Specialty',
      'Address',
      'Country',
      'Telephone',
      'Fax',
      'Mobile',
      'Email',
      'City',
      'ProviderType',
      'ZipCode',
      'State',
    ]);
  });

  test('template editing creates a new unverified version', () {
    final original = SeedTemplates.clinicsAndServices;
    final edited = original.nextVersion(
      fields: [
        ...original.fields,
        const TargetField(
          id: 'branch',
          header: 'Branch',
          type: FieldType.identifier,
        ),
      ],
    );
    expect(edited.id, original.id);
    expect(edited.version, original.version + 1);
    expect(edited.verification, TemplateVerification.inferredFromSql);
    expect(original.fields, hasLength(5));
  });

  test('serialized template schema round-trips and rejects future schemas', () {
    final source = SeedTemplates.usersAndDoctors;
    final restored = TargetTemplate.decode(jsonEncode(source.toJson()));
    expect(restored.id, source.id);
    expect(restored.fields.map((e) => e.id), source.fields.map((e) => e.id));
    final bad = source.toJson()..['schemaVersion'] = 99;
    expect(() => TargetTemplate.fromJson(bad), throwsA(isA<FormatException>()));
  });
}
