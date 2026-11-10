import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/domain.dart';
import '../services/mapping_engine.dart';
import '../services/local_repository.dart';
import '../services/quality_engine.dart';
import '../services/seed_templates.dart';
import '../services/xlsx_service.dart';

enum WorkflowStep { import, template, mapping, review, export }

class WorkflowController extends ChangeNotifier {
  WorkflowController({
    this._xlsx = const XlsxService(),
    LocalRepository? repository,
  }) : repository = repository ?? LocalRepository();

  final XlsxService _xlsx;
  final LocalRepository repository;
  final MappingEngine _mappingEngine = const MappingEngine();
  final ValidationEngine _validationEngine = const ValidationEngine();
  final DuplicateDetector _duplicateDetector = const DuplicateDetector();

  final List<TargetTemplate> templates = [...SeedTemplates.all];
  TargetTemplate selectedTemplate = SeedTemplates.referringDoctors;
  WorkflowStep step = WorkflowStep.import;
  WorkbookInspection? inspection;
  WorkbookRegion? region;
  String? sourcePath;
  String clientId = 'default-client';
  int selectedSheetIndex = 0;
  int headerRow = 1;
  int firstDataRow = 2;
  int? lastDataRow;
  bool busy = false;
  bool dirty = false;
  String? errorMessage;
  List<FieldMapping> mappings = [];
  List<MappingSuggestion> suggestions = [];
  List<PreparedRecord> records = [];
  List<DataIssue> issues = [];
  List<DuplicateGroup> duplicateGroups = [];
  List<AuditEntry> audit = [];
  final Set<int> explicitlyIgnoredColumns = {};
  final List<ReferenceRegion> references = [];
  String? currentJobId;

  bool get hasSource => inspection != null && sourcePath != null;
  bool get canPrepare => region != null;
  List<DataIssue> get errors =>
      issues.where((e) => e.severity == ValidationSeverity.error).toList();
  List<DataIssue> get warnings =>
      issues.where((e) => e.severity == ValidationSeverity.warning).toList();
  Set<int> get blockedRows =>
      errors.map((e) => e.sourceRow).whereType<int>().toSet();

  ExportSummary get exportSummary => ExportSummary(
    sourceCount: records.length,
    includedCount: records
        .where((r) => !r.excluded && !blockedRows.contains(r.sourceRowNumber))
        .length,
    excludedCount: records.where((r) => r.excluded).length,
    blockedCount: records
        .where((r) => !r.excluded && blockedRows.contains(r.sourceRowNumber))
        .length,
    warningCount: warnings.length,
    unresolvedDuplicateGroups: duplicateGroups.length,
  );

  Future<void> pickWorkbook() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    final path = result?.path;
    if (path != null) await inspectPath(path);
  }

  void setSheetSelection(int value) {
    final currentInspection = inspection;
    if (currentInspection == null) return;
    selectedSheetIndex = value;
    headerRow = currentInspection.sheets[value].suggestedHeaderRow;
    firstDataRow = headerRow + 1;
    notifyListeners();
  }

  void setRegionRows({int? header, int? firstData, int? lastData}) {
    if (header != null) headerRow = header;
    if (firstData != null) firstDataRow = firstData;
    lastDataRow = lastData;
    notifyListeners();
  }

  Future<void> inspectPath(String path) async {
    await _run(() async {
      inspection = await _xlsx.inspectFile(path);
      sourcePath = path;
      selectedSheetIndex = 0;
      headerRow = inspection!.sheets.first.suggestedHeaderRow;
      firstDataRow = headerRow + 1;
      region = null;
      records = [];
      issues = [];
      duplicateGroups = [];
      mappings = [];
      dirty = true;
    });
  }

  Future<void> selectPrimaryRegion() async {
    final currentInspection = inspection;
    final path = sourcePath;
    if (currentInspection == null || path == null) return;
    await _run(() async {
      final bytes = await File(path).readAsBytes();
      region = await Isolate.run(
        () => _xlsx.readRegion(
          bytes,
          sheetName: currentInspection.sheets[selectedSheetIndex].name,
          headerRow: headerRow,
          firstDataRow: firstDataRow,
          lastDataRow: lastDataRow,
        ),
      );
      suggestions = _mappingEngine.suggest(selectedTemplate, region!);
      mappings = [];
      records = [];
      issues = [];
      duplicateGroups = [];
      step = WorkflowStep.template;
      dirty = true;
    });
  }

  Future<void> addReferenceRegion({
    required String path,
    required String sheetName,
    required int headerRow,
    required int keyColumnIndex,
    required int labelColumnIndex,
  }) async {
    await _run(() async {
      final bytes = await File(path).readAsBytes();
      final selected = _xlsx.readRegion(
        bytes,
        sheetName: sheetName,
        headerRow: headerRow,
        firstDataRow: headerRow + 1,
      );
      references.add(
        ReferenceRegion(
          id: '${selected.workbookFingerprint}:$sheetName:$headerRow:$keyColumnIndex:$labelColumnIndex',
          workbookFingerprint: selected.workbookFingerprint,
          sheetName: sheetName,
          headerRow: headerRow,
          keyColumnIndex: keyColumnIndex,
          labelColumnIndex: labelColumnIndex,
          entries: selected.rows
              .where(
                (row) => (row.cells[keyColumnIndex]?.displayValue ?? '')
                    .trim()
                    .isNotEmpty,
              )
              .map(
                (row) => ReferenceEntry(
                  key: row.cells[keyColumnIndex]!.displayValue,
                  label: row.cells[labelColumnIndex]?.displayValue ?? '',
                  sourceRow: row.rowNumber,
                ),
              )
              .toList(),
        ),
      );
      dirty = true;
    });
  }

  Future<void> saveCurrentJob() async {
    final currentRegion = region;
    final path = sourcePath;
    if (currentRegion == null || path == null) {
      errorMessage = 'Select a primary workbook region before saving the job.';
      notifyListeners();
      return;
    }
    await _run(() async {
      currentJobId ??= 'job-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      final corrections = audit
          .where(
            (entry) =>
                entry.action == 'correction' ||
                entry.action == 'bulk-correction',
          )
          .toList();
      final exclusions = <int, String>{
        for (final record in records.where((record) => record.excluded))
          record.sourceRowNumber: record.exclusionReason ?? 'Excluded',
      };
      await repository.saveJob(
        SavedJobDocument(
          id: currentJobId!,
          clientId: clientId,
          updatedAt: DateTime.now().toUtc(),
          sourcePath: path,
          sourceFingerprint: currentRegion.workbookFingerprint,
          sheetName: currentRegion.sheetName,
          headerRow: currentRegion.headerRow,
          firstDataRow: currentRegion.firstDataRow,
          lastDataRow: currentRegion.lastDataRow,
          templateSnapshot: selectedTemplate,
          mappings: mappings,
          corrections: corrections,
          exclusions: exclusions,
          references: references,
        ),
      );
      dirty = false;
    });
  }

  Future<List<SavedJobSummary>> recentJobs() => repository.loadJobSummaries();

  Future<void> reopenJob(String id) async {
    await _run(() async {
      final saved = await repository.loadJob(id);
      final file = File(saved.sourcePath);
      if (!await file.exists()) {
        throw const FileSystemException(
          'The saved source workbook is unavailable. Select the original file to reopen this job.',
        );
      }
      final currentInspection = await _xlsx.inspectFile(saved.sourcePath);
      if (currentInspection.fingerprint != saved.sourceFingerprint) {
        throw const FormatException(
          'The source workbook fingerprint changed. The saved mapping was not applied.',
        );
      }
      inspection = currentInspection;
      sourcePath = saved.sourcePath;
      selectedSheetIndex = currentInspection.sheets.indexWhere(
        (sheet) => sheet.name == saved.sheetName,
      );
      if (selectedSheetIndex < 0) {
        throw FormatException(
          'Saved sheet “${saved.sheetName}” no longer exists.',
        );
      }
      headerRow = saved.headerRow;
      firstDataRow = saved.firstDataRow;
      lastDataRow = saved.lastDataRow;
      selectedTemplate = saved.templateSnapshot;
      if (!templates.any(
        (template) =>
            template.id == selectedTemplate.id &&
            template.version == selectedTemplate.version,
      )) {
        templates.add(selectedTemplate);
      }
      mappings = saved.mappings;
      final bytes = await file.readAsBytes();
      region = _xlsx.readRegion(
        bytes,
        sheetName: saved.sheetName,
        headerRow: saved.headerRow,
        firstDataRow: saved.firstDataRow,
        lastDataRow: saved.lastDataRow,
      );
      records = _mappingEngine.apply(selectedTemplate, region!, mappings);
      for (final correction in saved.corrections) {
        final matching = records.where(
          (record) => record.sourceRowNumber == correction.sourceRow,
        );
        if (matching.isNotEmpty && correction.targetFieldId != null) {
          matching.first.values[correction.targetFieldId!] =
              correction.resultingValue;
        }
      }
      for (final exclusion in saved.exclusions.entries) {
        final matching = records.where(
          (record) => record.sourceRowNumber == exclusion.key,
        );
        if (matching.isNotEmpty) {
          matching.first
            ..excluded = true
            ..exclusionReason = exclusion.value;
        }
      }
      references
        ..clear()
        ..addAll(saved.references);
      audit = [...saved.corrections];
      issues = _validationEngine.validateRecords(
        selectedTemplate,
        region!,
        records,
      );
      duplicateGroups = _duplicateDetector.detect(
        selectedTemplate,
        records,
        clientId: clientId,
      );
      currentJobId = saved.id;
      step = WorkflowStep.review;
      dirty = false;
    });
  }

  void selectTemplate(TargetTemplate template) {
    if (selectedTemplate.id == template.id &&
        selectedTemplate.version == template.version) {
      return;
    }
    selectedTemplate = template;
    mappings = [];
    records = [];
    issues = [];
    duplicateGroups = [];
    if (region != null) {
      suggestions = _mappingEngine.suggest(selectedTemplate, region!);
    }
    dirty = true;
    notifyListeners();
  }

  void createTemplate(String name) {
    final id = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final template = TargetTemplate(
      id: id.isEmpty
          ? 'template-${DateTime.now().microsecondsSinceEpoch}'
          : '$id-${DateTime.now().microsecondsSinceEpoch}',
      version: 1,
      name: name.trim(),
      description: 'User-created target template.',
      verification: TemplateVerification.inferredFromSql,
      fields: const [],
    );
    templates.add(template);
    selectedTemplate = template;
    dirty = true;
    notifyListeners();
  }

  void duplicateTemplate(TargetTemplate source) {
    final copy = TargetTemplate(
      id: '${source.id}-copy-${DateTime.now().microsecondsSinceEpoch}',
      version: 1,
      name: '${source.name} copy',
      description: source.description,
      verification: TemplateVerification.inferredFromSql,
      outputSheetName: source.outputSheetName,
      headerRow: source.headerRow,
      fields: [...source.fields],
      uniqueKeys: source.uniqueKeys.map((key) => [...key]).toList(),
      businessRules: [...source.businessRules],
    );
    templates.add(copy);
    selectedTemplate = copy;
    dirty = true;
    notifyListeners();
  }

  void createTemplateVersion(
    TargetTemplate source, {
    required String description,
  }) {
    final version = source.nextVersion(description: description.trim());
    templates.add(version);
    selectedTemplate = version;
    mappings = [];
    _invalidatePreparedState();
  }

  Future<void> importTemplate() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import target template',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file?.path == null) return;
    await _run(() async {
      final template = TargetTemplate.decode(
        await File(file!.path!).readAsString(),
      );
      if (templates.any(
        (existing) =>
            existing.id == template.id && existing.version == template.version,
      )) {
        throw const FormatException(
          'A template with that ID and version already exists.',
        );
      }
      templates.add(template);
      selectedTemplate = template;
      await repository.saveTemplate(template);
      dirty = true;
    });
  }

  Future<void> exportTemplate(TargetTemplate template) async {
    await FilePicker.saveFile(
      dialogTitle: 'Export target template',
      fileName: '${template.id}-v${template.version}.json',
      bytes: Uint8List.fromList(
        utf8.encode(
          const JsonEncoder.withIndent('  ').convert(template.toJson()),
        ),
      ),
      mimeType: 'application/json',
    );
  }

  void setMapping(FieldMapping mapping) {
    mappings = [
      ...mappings.where((m) => m.targetFieldId != mapping.targetFieldId),
      mapping,
    ];
    _invalidatePreparedState();
  }

  void ignoreSourceColumn(int index, bool ignored) {
    ignored
        ? explicitlyIgnoredColumns.add(index)
        : explicitlyIgnoredColumns.remove(index);
    _invalidatePreparedState();
  }

  Future<void> prepareAndValidate() async {
    final selectedRegion = region;
    if (selectedRegion == null) return;
    await _run(() async {
      final result = await Isolate.run(() {
        final prepared = _mappingEngine.apply(
          selectedTemplate,
          selectedRegion,
          mappings,
        );
        final foundIssues = <DataIssue>[
          ..._validationEngine.validateConfiguration(
            selectedTemplate,
            mappings,
            selectedRegion,
            explicitlyIgnoredColumns: explicitlyIgnoredColumns,
          ),
          ..._validationEngine.validateRecords(
            selectedTemplate,
            selectedRegion,
            prepared,
          ),
          ..._validationEngine.detectSectionRows(selectedRegion),
          ..._validationEngine.detectLossyServiceCollapse(
            selectedRegion,
            mappings,
          ),
        ];
        final duplicates = _duplicateDetector.detect(
          selectedTemplate,
          prepared,
          clientId: clientId,
        );
        return (prepared, foundIssues, duplicates);
      });
      records = result.$1;
      issues = result.$2;
      duplicateGroups = result.$3;
      step = WorkflowStep.review;
      dirty = true;
    });
  }

  void correctValue(int sourceRow, String fieldId, Object? value) {
    final record = records.firstWhere((r) => r.sourceRowNumber == sourceRow);
    final before = record.values[fieldId];
    record.values[fieldId] = value;
    audit.add(
      AuditEntry(
        action: 'correction',
        at: DateTime.now().toUtc(),
        sourceRow: sourceRow,
        targetFieldId: fieldId,
        originalValue: before,
        resultingValue: value,
      ),
    );
    _revalidateAfterDecision();
  }

  void applyCorrectionToMatching(
    String fieldId,
    Object? originalValue,
    Object? replacement,
  ) {
    for (final record in records.where(
      (r) => r.values[fieldId] == originalValue,
    )) {
      record.values[fieldId] = replacement;
      audit.add(
        AuditEntry(
          action: 'bulk-correction',
          at: DateTime.now().toUtc(),
          sourceRow: record.sourceRowNumber,
          targetFieldId: fieldId,
          originalValue: originalValue,
          resultingValue: replacement,
        ),
      );
    }
    _revalidateAfterDecision();
  }

  void undoLastCorrection() {
    for (var i = audit.length - 1; i >= 0; i--) {
      final entry = audit[i];
      if (entry.action == 'correction' || entry.action == 'bulk-correction') {
        records
                .firstWhere((r) => r.sourceRowNumber == entry.sourceRow)
                .values[entry.targetFieldId!] =
            entry.originalValue;
        audit.removeAt(i);
        _revalidateAfterDecision();
        return;
      }
    }
  }

  void setExcluded(int sourceRow, bool excluded, String reason) {
    final record = records.firstWhere((r) => r.sourceRowNumber == sourceRow);
    record.excluded = excluded;
    record.exclusionReason = excluded ? reason : null;
    audit.add(
      AuditEntry(
        action: excluded ? 'exclude' : 'restore',
        at: DateTime.now().toUtc(),
        sourceRow: sourceRow,
        detail: reason,
      ),
    );
    _revalidateAfterDecision();
  }

  Future<String?> export({required bool eligibleOnly}) async {
    if (!eligibleOnly && !exportSummary.canExportAll) {
      errorMessage = 'Resolve blocking issues and duplicate groups, or choose eligible records only.';
      notifyListeners();
      return null;
    }
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose export folder',
    );
    if (directory == null || sourcePath == null) return null;
    final path =
        '$directory${Platform.pathSeparator}${selectedTemplate.id}-prepared.xlsx';
    await _run(() async {
      final bytes = await Isolate.run(
        () => _xlsx.exportBytes(
          selectedTemplate,
          records,
          eligibleOnly: eligibleOnly,
          blockedRows: blockedRows,
        ),
      );
      await _xlsx.exportSafely(
        destinationPath: path,
        sourcePath: sourcePath!,
        bytes: bytes,
      );
      audit.add(
        AuditEntry(
          action: 'export',
          at: DateTime.now().toUtc(),
          sourceRow: 0,
          detail:
              'Eligible only: $eligibleOnly; rows: ${exportSummary.includedCount}',
        ),
      );
      dirty = false;
    });
    return errorMessage == null ? path : null;
  }

  void moveTo(WorkflowStep value) {
    step = value;
    notifyListeners();
  }

  void _invalidatePreparedState() {
    records = [];
    issues = [];
    duplicateGroups = [];
    dirty = true;
    notifyListeners();
  }

  void _revalidateAfterDecision() {
    if (region == null) return;
    issues = [
      ..._validationEngine.validateConfiguration(
        selectedTemplate,
        mappings,
        region!,
        explicitlyIgnoredColumns: explicitlyIgnoredColumns,
      ),
      ..._validationEngine.validateRecords(selectedTemplate, region!, records),
      ..._validationEngine.detectLossyServiceCollapse(region!, mappings),
    ];
    duplicateGroups = _duplicateDetector.detect(
      selectedTemplate,
      records,
      clientId: clientId,
    );
    dirty = true;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
    } on Object catch (error) {
      errorMessage = error.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
