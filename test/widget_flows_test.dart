import 'package:clinical_data_mapper/src/app.dart';
import 'package:clinical_data_mapper/src/models/domain.dart';
import 'package:clinical_data_mapper/src/state/workflow_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkflowController controller;

  setUp(() {
    controller = WorkflowController();
  });

  testWidgets('mapping flow shows proposals and stable source identities', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    controller
      ..region = _region()
      ..step = WorkflowStep.mapping;
    await tester.pumpWidget(ClinicalMapperApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mapping-screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mapping-code-null')));
    await tester.pumpAndSettle();
    expect(find.text('A · code'), findsWidgets);
    expect(find.text('B · Full name'), findsWidgets);
    expect(
      find.textContaining('Every proposal requires your confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets('issue review supports correction and undo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    controller
      ..region = _region()
      ..records = [
        PreparedRecord(
          sourceRowNumber: 2,
          values: {'code': '001', 'full_name': 'Doceur Test'},
          provenance: const {},
        ),
      ]
      ..issues = const [
        DataIssue(
          code: 'UNKNOWN_TITLE',
          severity: ValidationSeverity.warning,
          message: 'Unknown value requires approved correction.',
          sheet: 'Data',
          sourceRow: 2,
          targetFieldId: 'full_name',
        ),
      ]
      ..step = WorkflowStep.review;
    await tester.pumpWidget(ClinicalMapperApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('issue-review')), findsOneWidget);
    expect(
      find.text('Unknown value requires approved correction.'),
      findsOneWidget,
    );

    controller.correctValue(2, 'full_name', 'Docteur Test');
    await tester.pump();
    expect(controller.records.single.values['full_name'], 'Docteur Test');
    controller.undoLastCorrection();
    await tester.pump();
    expect(controller.records.single.values['full_name'], 'Doceur Test');
  });

  testWidgets('long errors stay bounded and open in a scrollable dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longMessage = List.generate(
      80,
      (index) => 'Diagnostic line ${index + 1}',
    ).join('\n');
    controller.errorMessage = longMessage;

    await tester.pumpWidget(ClinicalMapperApp(controller: controller));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final summary = tester.widget<Text>(find.text(longMessage));
    expect(summary.maxLines, 2);
    expect(summary.overflow, TextOverflow.ellipsis);

    await tester.tap(find.widgetWithText(TextButton, 'Review'));
    await tester.pumpAndSettle();

    expect(find.text('Error details'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'export readiness blocks all-row export but allows eligible rows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      controller
        ..region = _region()
        ..records = [
          PreparedRecord(
            sourceRowNumber: 2,
            values: {'code': '001', 'full_name': 'Valid'},
            provenance: const {},
          ),
          PreparedRecord(
            sourceRowNumber: 3,
            values: {'code': '', 'full_name': 'Blocked'},
            provenance: const {},
          ),
        ]
        ..issues = const [
          DataIssue(
            code: 'REQUIRED_VALUE_MISSING',
            severity: ValidationSeverity.error,
            message: 'Code is required.',
            sheet: 'Data',
            sourceRow: 3,
            targetFieldId: 'code',
          ),
        ]
        ..step = WorkflowStep.export;
      await tester.pumpWidget(ClinicalMapperApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export-ready')), findsOneWidget);
      final all = tester.widget<FilledButton>(
        find.byKey(const Key('export-all')),
      );
      final eligible = tester.widget<OutlinedButton>(
        find.byKey(const Key('export-eligible')),
      );
      expect(all.onPressed, isNull);
      expect(eligible.onPressed, isNotNull);
      expect(find.text('Export 1 eligible records only'), findsOneWidget);
    },
  );
}

WorkbookRegion _region() => WorkbookRegion(
  workbookFingerprint: 'fixture',
  sheetName: 'Data',
  headerRow: 1,
  firstDataRow: 2,
  columns: const [
    SourceColumn(index: 0, letter: 'A', header: 'code'),
    SourceColumn(index: 1, letter: 'B', header: 'Full name'),
  ],
  rows: [
    SourceRow(
      rowNumber: 2,
      cells: const {
        0: SourceCell(type: SourceCellType.text, value: '001'),
        1: SourceCell(type: SourceCellType.text, value: 'Jean Élève'),
      },
    ),
  ],
);
