import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/domain.dart';

class SavedJobSummary {
  const SavedJobSummary({
    required this.id,
    required this.clientId,
    required this.updatedAt,
    required this.templateName,
    required this.sourceFingerprint,
    required this.sourcePath,
  });

  final String id;
  final String clientId;
  final DateTime updatedAt;
  final String templateName;
  final String sourceFingerprint;
  final String sourcePath;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'clientId': clientId,
    'updatedAt': updatedAt.toIso8601String(),
    'templateName': templateName,
    'sourceFingerprint': sourceFingerprint,
    'sourcePath': sourcePath,
  };

  factory SavedJobSummary.fromJson(Map<String, Object?> json) {
    if ((json['schemaVersion'] as int? ?? 1) != 1) {
      throw const FormatException('Unsupported job schema version.');
    }
    return SavedJobSummary(
      id: json['id']! as String,
      clientId: json['clientId']! as String,
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      templateName: json['templateName']! as String,
      sourceFingerprint: json['sourceFingerprint']! as String,
      sourcePath: json['sourcePath']! as String,
    );
  }
}

class SavedJobDocument {
  const SavedJobDocument({
    required this.id,
    required this.clientId,
    required this.updatedAt,
    required this.sourcePath,
    required this.sourceFingerprint,
    required this.sheetName,
    required this.headerRow,
    required this.firstDataRow,
    required this.templateSnapshot,
    required this.mappings,
    this.lastDataRow,
    this.corrections = const [],
    this.exclusions = const {},
    this.references = const [],
    this.schemaVersion = 1,
  });

  final int schemaVersion;
  final String id;
  final String clientId;
  final DateTime updatedAt;
  final String sourcePath;
  final String sourceFingerprint;
  final String sheetName;
  final int headerRow;
  final int firstDataRow;
  final int? lastDataRow;
  final TargetTemplate templateSnapshot;
  final List<FieldMapping> mappings;
  final List<AuditEntry> corrections;
  final Map<int, String> exclusions;
  final List<ReferenceRegion> references;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'clientId': clientId,
    'updatedAt': updatedAt.toIso8601String(),
    'sourcePath': sourcePath,
    'sourceFingerprint': sourceFingerprint,
    'sheetName': sheetName,
    'headerRow': headerRow,
    'firstDataRow': firstDataRow,
    'lastDataRow': lastDataRow,
    'templateSnapshot': templateSnapshot.toJson(),
    'mappings': mappings.map((mapping) => mapping.toJson()).toList(),
    'corrections': corrections
        .map(
          (entry) => {
            'action': entry.action,
            'at': entry.at.toIso8601String(),
            'sourceRow': entry.sourceRow,
            'targetFieldId': entry.targetFieldId,
            'originalValue': entry.originalValue,
            'resultingValue': entry.resultingValue,
            'detail': entry.detail,
          },
        )
        .toList(),
    'exclusions': exclusions.map((key, value) => MapEntry('$key', value)),
    'references': references
        .map(
          (region) => {
            'id': region.id,
            'workbookFingerprint': region.workbookFingerprint,
            'sheetName': region.sheetName,
            'headerRow': region.headerRow,
            'keyColumnIndex': region.keyColumnIndex,
            'labelColumnIndex': region.labelColumnIndex,
            'entries': region.entries
                .map(
                  (entry) => {
                    'key': entry.key,
                    'label': entry.label,
                    'sourceRow': entry.sourceRow,
                  },
                )
                .toList(),
          },
        )
        .toList(),
  };

  factory SavedJobDocument.fromJson(Map<String, Object?> json) {
    final schema = json['schemaVersion'] as int? ?? 1;
    if (schema != 1) {
      throw const FormatException('Unsupported saved-job schema version.');
    }
    return SavedJobDocument(
      schemaVersion: schema,
      id: json['id']! as String,
      clientId: json['clientId']! as String,
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      sourcePath: json['sourcePath']! as String,
      sourceFingerprint: json['sourceFingerprint']! as String,
      sheetName: json['sheetName']! as String,
      headerRow: json['headerRow']! as int,
      firstDataRow: json['firstDataRow']! as int,
      lastDataRow: json['lastDataRow'] as int?,
      templateSnapshot: TargetTemplate.fromJson(
        (json['templateSnapshot']! as Map).cast<String, Object?>(),
      ),
      mappings: (json['mappings']! as List)
          .map(
            (mapping) =>
                FieldMapping.fromJson((mapping as Map).cast<String, Object?>()),
          )
          .toList(),
      corrections: (json['corrections'] as List? ?? const []).map((raw) {
        final entry = (raw as Map).cast<String, Object?>();
        return AuditEntry(
          action: entry['action']! as String,
          at: DateTime.parse(entry['at']! as String),
          sourceRow: entry['sourceRow']! as int,
          targetFieldId: entry['targetFieldId'] as String?,
          originalValue: entry['originalValue'],
          resultingValue: entry['resultingValue'],
          detail: entry['detail'] as String? ?? '',
        );
      }).toList(),
      exclusions: (json['exclusions'] as Map? ?? const {}).map(
        (key, value) => MapEntry(int.parse(key as String), value as String),
      ),
      references: (json['references'] as List? ?? const []).map((raw) {
        final region = (raw as Map).cast<String, Object?>();
        return ReferenceRegion(
          id: region['id']! as String,
          workbookFingerprint: region['workbookFingerprint']! as String,
          sheetName: region['sheetName']! as String,
          headerRow: region['headerRow']! as int,
          keyColumnIndex: region['keyColumnIndex']! as int,
          labelColumnIndex: region['labelColumnIndex']! as int,
          entries: (region['entries']! as List).map((rawEntry) {
            final entry = (rawEntry as Map).cast<String, Object?>();
            return ReferenceEntry(
              key: entry['key']! as String,
              label: entry['label']! as String,
              sourceRow: entry['sourceRow']! as int,
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class LocalRepository {
  LocalRepository({this._root});

  Directory? _root;

  Future<Directory> get root async {
    if (_root != null) return _root!;
    final support = await getApplicationSupportDirectory();
    _root = Directory(
      '${support.path}${Platform.pathSeparator}ClinicalDataMapper',
    );
    return _root!;
  }

  Future<String> get location async => (await root).path;

  Future<void> saveTemplate(TargetTemplate template) async {
    final folder = await _folder('templates');
    await _atomicJson(
      File(
        '${folder.path}${Platform.pathSeparator}${_safe(template.id)}-v${template.version}.json',
      ),
      template.toJson(),
    );
  }

  Future<List<TargetTemplate>> loadTemplates() async {
    final folder = await _folder('templates');
    final result = <TargetTemplate>[];
    await for (final entity in folder.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        result.add(
          TargetTemplate.fromJson(
            (jsonDecode(await entity.readAsString()) as Map)
                .cast<String, Object?>(),
          ),
        );
      }
    }
    result.sort(
      (a, b) => a.name == b.name
          ? b.version.compareTo(a.version)
          : a.name.compareTo(b.name),
    );
    return result;
  }

  Future<void> saveJobSummary(SavedJobSummary summary) async {
    final folder = await _folder('jobs');
    await _atomicJson(
      File('${folder.path}${Platform.pathSeparator}${_safe(summary.id)}.json'),
      summary.toJson(),
    );
  }

  Future<void> saveJob(SavedJobDocument job) async {
    final folder = await _folder('jobs');
    await _atomicJson(
      File('${folder.path}${Platform.pathSeparator}${_safe(job.id)}.json'),
      job.toJson(),
    );
  }

  Future<SavedJobDocument> loadJob(String id) async {
    final folder = await _folder('jobs');
    final file = File(
      '${folder.path}${Platform.pathSeparator}${_safe(id)}.json',
    );
    return SavedJobDocument.fromJson(
      (jsonDecode(await file.readAsString()) as Map).cast<String, Object?>(),
    );
  }

  Future<List<SavedJobSummary>> loadJobSummaries() async {
    final folder = await _folder('jobs');
    final result = <SavedJobSummary>[];
    await for (final entity in folder.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final json = (jsonDecode(await entity.readAsString()) as Map)
            .cast<String, Object?>();
        if (json.containsKey('templateSnapshot')) {
          final template = (json['templateSnapshot']! as Map)
              .cast<String, Object?>();
          result.add(
            SavedJobSummary(
              id: json['id']! as String,
              clientId: json['clientId']! as String,
              updatedAt: DateTime.parse(json['updatedAt']! as String),
              templateName: '${template['name']} v${template['version']}',
              sourceFingerprint: json['sourceFingerprint']! as String,
              sourcePath: json['sourcePath']! as String,
            ),
          );
        } else {
          result.add(SavedJobSummary.fromJson(json));
        }
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<void> deleteJob(String id) async {
    final folder = await _folder('jobs');
    final file = File(
      '${folder.path}${Platform.pathSeparator}${_safe(id)}.json',
    );
    if (await file.exists()) await file.delete();
  }

  Future<bool> fingerprintMatches(
    SavedJobSummary job,
    String currentFingerprint,
  ) async => job.sourceFingerprint == currentFingerprint;

  Future<Directory> _folder(String name) async {
    final directory = Directory(
      '${(await root).path}${Platform.pathSeparator}$name',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _atomicJson(File destination, Map<String, Object?> value) async {
    await destination.parent.create(recursive: true);
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(value),
      flush: true,
    );
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  }

  static String _safe(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}
