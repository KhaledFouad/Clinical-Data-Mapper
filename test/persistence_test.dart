import 'dart:io';

import 'package:clinical_data_mapper/src/models/domain.dart';
import 'package:clinical_data_mapper/src/services/local_repository.dart';
import 'package:clinical_data_mapper/src/state/workflow_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  test(
    'saved job round-trips mapping, decisions, references, and template',
    () async {
      final directory = await Directory.systemTemp.createTemp('mapper-store-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = LocalRepository(root: directory);
      const template = TargetTemplate(
        id: 't',
        version: 4,
        name: 'Versioned',
        description: '',
        verification: TemplateVerification.inferredFromSql,
        fields: [
          TargetField(id: 'code', header: 'Code', type: FieldType.identifier),
        ],
      );
      final document = SavedJobDocument(
        id: 'job-1',
        clientId: 'client-a',
        updatedAt: DateTime.utc(2026, 11, 10),
        sourcePath: 'C:\\input.xlsx',
        sourceFingerprint: 'fingerprint',
        sheetName: 'Data',
        headerRow: 2,
        firstDataRow: 3,
        templateSnapshot: template,
        mappings: const [
          FieldMapping(
            targetFieldId: 'code',
            sourceColumnIndexes: [2],
            steps: [TransformationStep(TransformationType.trim)],
            confirmed: true,
          ),
        ],
        corrections: [
          AuditEntry(
            action: 'correction',
            at: DateTime.utc(2026, 11, 10),
            sourceRow: 7,
            targetFieldId: 'code',
            originalValue: ' 01 ',
            resultingValue: '01',
          ),
        ],
        exclusions: const {9: 'Confirmed section row'},
        references: const [
          ReferenceRegion(
            id: 'ref',
            workbookFingerprint: 'ref-fingerprint',
            sheetName: 'Category',
            headerRow: 1,
            keyColumnIndex: 0,
            labelColumnIndex: 1,
            entries: [
              ReferenceEntry(key: '1', label: 'Examination', sourceRow: 2),
            ],
          ),
        ],
      );

      await repository.saveJob(document);
      final restored = await repository.loadJob('job-1');
      expect(restored.templateSnapshot.version, 4);
      expect(restored.mappings.single.sourceColumnIndexes, [2]);
      expect(restored.corrections.single.resultingValue, '01');
      expect(restored.exclusions[9], 'Confirmed section row');
      expect(restored.references.single.entries.single.label, 'Examination');
      expect(
        (await repository.loadJobSummaries()).single.templateName,
        'Versioned v4',
      );
    },
  );

  test(
    'reopening verifies fingerprint and restores corrections and exclusions',
    () async {
      final directory = await Directory.systemTemp.createTemp('mapper-reopen-');
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/source.xlsx');
      await source.writeAsBytes(
        workbookBytes(
          headers: const ['code', 'FullName'],
          rows: const [
            ['001', 'Original'],
            ['002', 'Section'],
          ],
        ),
      );
      final repository = LocalRepository(
        root: Directory('${directory.path}/store'),
      );
      final controller = WorkflowController(repository: repository);
      await controller.inspectPath(source.path);
      await controller.selectPrimaryRegion();
      controller
        ..setMapping(
          const FieldMapping(targetFieldId: 'code', sourceColumnIndexes: [0]),
        )
        ..setMapping(
          const FieldMapping(
            targetFieldId: 'full_name',
            sourceColumnIndexes: [1],
          ),
        );
      await controller.prepareAndValidate();
      controller
        ..correctValue(2, 'full_name', 'Corrected')
        ..setExcluded(3, true, 'Confirmed non-record');
      await controller.saveCurrentJob();

      final reopened = WorkflowController(repository: repository);
      await reopened.reopenJob(controller.currentJobId!);
      expect(
        reopened.selectedTemplate.version,
        controller.selectedTemplate.version,
      );
      expect(reopened.records.first.values['full_name'], 'Corrected');
      expect(reopened.records.last.excluded, isTrue);
      expect(reopened.records.last.exclusionReason, 'Confirmed non-record');
      expect(reopened.dirty, isFalse);
    },
  );
}
