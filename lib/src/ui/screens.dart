import 'package:flutter/material.dart';

import '../app.dart';
import '../models/domain.dart';
import '../state/workflow_controller.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key, required this.controller});
  final WorkflowController controller;

  @override
  Widget build(BuildContext context) {
    final inspection = controller.inspection;
    if (inspection == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(42),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 58,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Inspect a client workbook',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Choose an XLSX file. The original remains unchanged and values stay on this computer.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    key: const Key('import-file'),
                    onPressed: controller.busy ? null : controller.pickWorkbook,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choose XLSX workbook'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Unsupported, encrypted, corrupted, or unreadable files are reported explicitly.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final sheet = inspection.sheets[controller.selectedSheetIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Workbook structure',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.busy ? null : controller.pickWorkbook,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Change file'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: controller.busy
                  ? null
                  : controller.selectPrimaryRegion,
              icon: const Icon(Icons.check),
              label: const Text('Use this region'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 14,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<int>(
                    initialValue: controller.selectedSheetIndex,
                    decoration: const InputDecoration(labelText: 'Worksheet'),
                    items: [
                      for (var i = 0; i < inspection.sheets.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(inspection.sheets[i].name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      controller.setSheetSelection(value);
                    },
                  ),
                ),
                _RowNumberField(
                  label: 'Header row',
                  value: controller.headerRow,
                  onChanged: (v) => controller.setRegionRows(
                    header: v,
                    lastData: controller.lastDataRow,
                  ),
                ),
                _RowNumberField(
                  label: 'First data row',
                  value: controller.firstDataRow,
                  onChanged: (v) => controller.setRegionRows(
                    firstData: v,
                    lastData: controller.lastDataRow,
                  ),
                ),
                _RowNumberField(
                  label: 'Final row (optional)',
                  value: controller.lastDataRow,
                  onChanged: (v) => controller.setRegionRows(lastData: v),
                ),
                StatusPill(
                  '${sheet.rowCount} rows · ${sheet.columnCount} columns',
                  color: Colors.teal,
                  icon: Icons.table_rows_outlined,
                ),
                if (sheet.mergedRanges.isNotEmpty)
                  StatusPill(
                    '${sheet.mergedRanges.length} merged ranges',
                    color: Colors.orange,
                    icon: Icons.call_merge,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Raw preview · source row numbers and cell values are preserved',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('Row')),
                          for (var i = 0; i < sheet.columnCount; i++)
                            DataColumn(label: Text(_letter(i))),
                        ],
                        rows: [
                          for (var r = 0; r < sheet.preview.length; r++)
                            DataRow(
                              color: r + 1 == controller.headerRow
                                  ? const WidgetStatePropertyAll(
                                      Color(0xffdff1ed),
                                    )
                                  : null,
                              cells: [
                                DataCell(Text('${r + 1}')),
                                for (var c = 0; c < sheet.columnCount; c++)
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 210,
                                      ),
                                      child: Text(
                                        c < sheet.preview[r].length
                                            ? sheet.preview[r][c]
                                            : '',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RowNumberField extends StatelessWidget {
  const _RowNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: TextFormField(
      key: ValueKey('$label:$value'),
      initialValue: value?.toString() ?? '',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (text) => onChanged(int.tryParse(text)),
    ),
  );
}

class TemplateSelectionScreen extends StatelessWidget {
  const TemplateSelectionScreen({super.key, required this.controller});
  final WorkflowController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose a target template',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Text(
                  'These seeded profiles are editable and remain unverified until an external import succeeds.',
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: controller.region == null
                ? null
                : () => controller.moveTo(WorkflowStep.mapping),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue to mapping'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Expanded(
        child: ListView.separated(
          itemCount: controller.templates.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final template = controller.templates[index];
            final selected =
                template.id == controller.selectedTemplate.id &&
                template.version == controller.selectedTemplate.version;
            return Card(
              child: InkWell(
                onTap: () => controller.selectTemplate(template),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black45,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${template.name} · v${template.version}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const StatusPill(
                                  'Inferred from SQL',
                                  color: Colors.orange,
                                  icon: Icons.science_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(template.description),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final field in template.fields)
                                  Chip(
                                    label: Text(field.header),
                                    avatar: field.required
                                        ? const Icon(Icons.star, size: 14)
                                        : null,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                '${template.businessRules.length} SQL-derived notes and unverified assumptions',
                              ),
                              children: [
                                for (final rule in template.businessRules)
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.info_outline,
                                      size: 18,
                                    ),
                                    title: Text(rule),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class MappingScreen extends StatelessWidget {
  const MappingScreen({super.key, required this.controller});
  final WorkflowController controller;

  @override
  Widget build(BuildContext context) {
    final region = controller.region;
    if (region == null) {
      return const Center(
        child: Text('Select a primary workbook region first.'),
      );
    }
    return Column(
      key: const Key('mapping-screen'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map source columns',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Suggestions use header aliases and observed values. Every proposal requires your confirmation.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              key: const Key('validate-mapping'),
              onPressed: controller.busy ? null : controller.prepareAndValidate,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Prepare and validate'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: ListView.separated(
              itemCount: controller.selectedTemplate.fields.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == controller.selectedTemplate.fields.length) {
                  return _UnmappedDisposition(controller: controller);
                }
                final field = controller.selectedTemplate.fields[index];
                final mapping = controller.mappings
                    .where((m) => m.targetFieldId == field.id)
                    .firstOrNull;
                final best = controller.suggestions
                    .where((s) => s.field.id == field.id)
                    .firstOrNull;
                final selectedColumn = mapping?.sourceColumnIndexes.firstOrNull;
                final samples = selectedColumn == null
                    ? const <String>[]
                    : region.rows
                          .map(
                            (r) => r.cells[selectedColumn]?.displayValue ?? '',
                          )
                          .where((e) => e.isNotEmpty)
                          .take(3)
                          .toList();
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 210,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    field.header,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (field.required)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              field.type.name,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (field.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  field.description,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<int?>(
                          isExpanded: true,
                          key: ValueKey('mapping-${field.id}-$selectedColumn'),
                          initialValue: selectedColumn,
                          decoration: const InputDecoration(
                            labelText: 'Source column',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Not mapped'),
                            ),
                            ...region.columns.map(
                              (c) => DropdownMenuItem<int?>(
                                value: c.index,
                                child: Text(
                                  c.identity,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) => controller.setMapping(
                            FieldMapping(
                              targetFieldId: field.id,
                              sourceColumnIndexes: value == null
                                  ? const []
                                  : [value],
                              steps: const [
                                TransformationStep(TransformationType.trim),
                              ],
                              confirmed: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              samples.isEmpty
                                  ? 'No transformed preview'
                                  : samples.join('  ·  '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (best != null && mapping == null)
                              Row(
                                children: [
                                  Icon(
                                    best.typeConflict
                                        ? Icons.warning_amber
                                        : Icons.auto_awesome,
                                    size: 17,
                                    color: best.typeConflict
                                        ? Colors.orange
                                        : Colors.teal,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Suggestion: ${best.column.identity} · ${best.reasons.join(' ')}',
                                      style: TextStyle(
                                        color: best.typeConflict
                                            ? Colors.deepOrange
                                            : Colors.teal.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (mapping != null)
                              const StatusPill(
                                'Confirmed mapping',
                                color: Colors.teal,
                                icon: Icons.check_circle_outline,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UnmappedDisposition extends StatelessWidget {
  const _UnmappedDisposition({required this.controller});
  final WorkflowController controller;
  @override
  Widget build(BuildContext context) {
    final region = controller.region!;
    final used = controller.mappings
        .expand((e) => e.sourceColumnIndexes)
        .toSet();
    final remaining = region.columns
        .where((c) => !used.contains(c.index))
        .toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unmapped source fields',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const Text(
            'Every extra source field needs an explicit disposition. Ignored fields remain visible in the audit preview but are not exported.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: remaining
                .map(
                  (column) => FilterChip(
                    label: Text(column.identity),
                    selected: controller.explicitlyIgnoredColumns.contains(
                      column.index,
                    ),
                    onSelected: (value) =>
                        controller.ignoreSourceColumn(column.index, value),
                    avatar: const Icon(Icons.visibility_off_outlined, size: 16),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.controller});
  final WorkflowController controller;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String filter = 'All';
  String search = '';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final blocked = controller.blockedRows;
    var records = controller.records.where((r) {
      if (search.isNotEmpty &&
          !r.values.values.any(
            (v) =>
                v?.toString().toLowerCase().contains(search.toLowerCase()) ??
                false,
          )) {
        return false;
      }
      return switch (filter) {
        'Errors' => blocked.contains(r.sourceRowNumber),
        'Excluded' => r.excluded,
        'Valid' => !r.excluded && !blocked.contains(r.sourceRowNumber),
        _ => true,
      };
    }).toList();
    return Column(
      key: const Key('issue-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Review prepared data',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.undoLastCorrection,
              icon: const Icon(Icons.undo),
              label: const Text('Undo correction'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => controller.moveTo(WorkflowStep.export),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Export summary'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final name in const ['All', 'Errors', 'Excluded', 'Valid'])
              FilterChip(
                label: Text(name),
                selected: filter == name,
                onSelected: (_) => setState(() => filter = name),
              ),
            StatusPill(
              '${controller.errors.length} errors',
              color: Colors.red,
              icon: Icons.error_outline,
            ),
            StatusPill(
              '${controller.warnings.length} warnings',
              color: Colors.orange,
              icon: Icons.warning_amber,
            ),
            StatusPill(
              '${controller.duplicateGroups.length} duplicate groups',
              color: Colors.purple,
              icon: Icons.content_copy,
            ),
            SizedBox(
              width: 260,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search records',
                ),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Card(
                  child: records.isEmpty
                      ? const Center(
                          child: Text('No records match this filter.'),
                        )
                      : SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                const DataColumn(label: Text('Status')),
                                const DataColumn(label: Text('Source row')),
                                ...controller.selectedTemplate.fields
                                    .take(6)
                                    .map(
                                      (f) => DataColumn(label: Text(f.header)),
                                    ),
                              ],
                              rows: records
                                  .take(200)
                                  .map(
                                    (record) => DataRow(
                                      cells: [
                                        DataCell(
                                          Icon(
                                            record.excluded
                                                ? Icons.remove_circle_outline
                                                : blocked.contains(
                                                    record.sourceRowNumber,
                                                  )
                                                ? Icons.error_outline
                                                : Icons.check_circle_outline,
                                            color: record.excluded
                                                ? Colors.grey
                                                : blocked.contains(
                                                    record.sourceRowNumber,
                                                  )
                                                ? Colors.red
                                                : Colors.teal,
                                          ),
                                        ),
                                        DataCell(
                                          Text('${record.sourceRowNumber}'),
                                        ),
                                        ...controller.selectedTemplate.fields
                                            .take(6)
                                            .map(
                                              (field) => DataCell(
                                                InkWell(
                                                  onDoubleTap: () => _edit(
                                                    context,
                                                    record,
                                                    field,
                                                  ),
                                                  child: ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                          maxWidth: 180,
                                                        ),
                                                    child: Text(
                                                      record.values[field.id]
                                                              ?.toString() ??
                                                          '',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Card(
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      Text(
                        'Issues',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (controller.issues.isEmpty)
                        const ListTile(
                          leading: Icon(Icons.check_circle, color: Colors.teal),
                          title: Text('No validation issues'),
                        ),
                      for (final issue in controller.issues.take(80))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            issue.severity == ValidationSeverity.error
                                ? Icons.error_outline
                                : issue.severity == ValidationSeverity.warning
                                ? Icons.warning_amber
                                : Icons.info_outline,
                            color: issue.severity == ValidationSeverity.error
                                ? Colors.red
                                : issue.severity == ValidationSeverity.warning
                                ? Colors.orange
                                : Colors.blue,
                          ),
                          title: Text(issue.message),
                          subtitle: Text(
                            '${issue.code} · ${issue.sheet}${issue.sourceRow == null ? '' : ' row ${issue.sourceRow}'}',
                          ),
                        ),
                      if (controller.duplicateGroups.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          'Duplicate comparisons',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        for (final group in controller.duplicateGroups.take(20))
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              '${group.kind} · ${group.records.length} rows',
                            ),
                            subtitle: Text(
                              'Conflicts: ${group.conflictingFields.join(', ')}',
                            ),
                            children: [
                              for (final record in group.records)
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    'Source row ${record.sourceRowNumber}',
                                  ),
                                  subtitle: Text(
                                    group.conflictingFields
                                        .map((f) => '$f: ${record.values[f]}')
                                        .join(' · '),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => controller.setExcluded(
                                      record.sourceRowNumber,
                                      true,
                                      'Duplicate decision',
                                    ),
                                    child: const Text('Exclude'),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    PreparedRecord record,
    TargetField field,
  ) async {
    final text = TextEditingController(
      text: record.values[field.id]?.toString() ?? '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Correct ${field.header} · source row ${record.sourceRowNumber}',
        ),
        content: TextField(controller: text, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value != null) {
      widget.controller.correctValue(record.sourceRowNumber, field.id, value);
    }
  }
}

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key, required this.controller});
  final WorkflowController controller;
  @override
  Widget build(BuildContext context) {
    final summary = controller.exportSummary;
    return ListView(
      key: const Key('export-ready'),
      children: [
        Text(
          'Export readiness',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          '${controller.selectedTemplate.displayName} · sheet “${controller.selectedTemplate.outputSheetName}”',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              'Source rows',
              summary.sourceCount,
              Icons.table_rows_outlined,
              Colors.blue,
            ),
            _Metric(
              'Eligible included',
              summary.includedCount,
              Icons.check_circle_outline,
              Colors.teal,
            ),
            _Metric(
              'Excluded',
              summary.excludedCount,
              Icons.remove_circle_outline,
              Colors.grey,
            ),
            _Metric(
              'Blocked by errors',
              summary.blockedCount,
              Icons.error_outline,
              Colors.red,
            ),
            _Metric(
              'Warnings',
              summary.warningCount,
              Icons.warning_amber,
              Colors.orange,
            ),
            _Metric(
              'Duplicate groups',
              summary.unresolvedDuplicateGroups,
              Icons.content_copy,
              Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      summary.canExportAll
                          ? Icons.verified_outlined
                          : Icons.block,
                      color: summary.canExportAll ? Colors.teal : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      summary.canExportAll
                          ? 'All included rows are export-ready'
                          : 'Blocking issues remain',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The upload workbook contains only configured headers and data. Audit and issue reports are separate so strict importers do not see extra sheets.',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const Key('export-all'),
                      onPressed: summary.canExportAll && !controller.busy
                          ? () => controller.export(eligibleOnly: false)
                          : null,
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Export all included records'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('export-eligible'),
                      onPressed: summary.includedCount > 0 && !controller.busy
                          ? () => controller.export(eligibleOnly: true)
                          : null,
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: Text(
                        'Export ${summary.includedCount} eligible records only',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('Compatibility remains unverified'),
              subtitle: Text(
                'A successfully generated XLSX file is not proof that the hospital website will accept it. Mark a template verified only after an external import test.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 175,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class TemplateLibraryScreen extends StatelessWidget {
  const TemplateLibraryScreen({super.key, required this.controller});
  final WorkflowController controller;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Template management',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add),
              label: const Text('Create template'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: controller.importTemplate,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import JSON'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: controller.templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final t = controller.templates[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.view_list_outlined),
                  title: Text(t.displayName),
                  subtitle: Text(
                    '${t.fields.length} ordered fields · ${t.outputSheetName} · editing creates v${t.version + 1}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Duplicate',
                        onPressed: () => controller.duplicateTemplate(t),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                      IconButton(
                        tooltip: 'Edit as new version',
                        onPressed: () => _version(context, t),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Export JSON',
                        onPressed: () => controller.exportTemplate(t),
                        icon: const Icon(Icons.file_download_outlined),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _create(BuildContext context) async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create target template'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      controller.createTemplate(name);
    }
  }

  Future<void> _version(BuildContext context, TargetTemplate template) async {
    final input = TextEditingController(text: template.description);
    final description = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create ${template.name} v${template.version + 1}'),
        content: TextField(
          controller: input,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Version description'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Create version'),
          ),
        ],
      ),
    );
    if (description != null) {
      controller.createTemplateVersion(template, description: description);
    }
  }
}

class RecentJobsScreen extends StatefulWidget {
  const RecentJobsScreen({super.key, required this.controller});
  final WorkflowController controller;

  @override
  State<RecentJobsScreen> createState() => _RecentJobsScreenState();
}

class _RecentJobsScreenState extends State<RecentJobsScreen> {
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: widget.controller.recentJobs(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final jobs = snapshot.data ?? const [];
      if (jobs.isEmpty) {
        return const _EmptySection(
          icon: Icons.history,
          title: 'Recent jobs',
          message: 'Saved jobs appear here with their client, template version, source fingerprint, decisions, and export history.',
        );
      }
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent jobs',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: jobs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const Icon(Icons.description_outlined),
                      title: Text(job.templateName),
                      subtitle: Text(
                        '${job.clientId} · ${job.updatedAt.toLocal()}\n${job.sourcePath}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          FilledButton.tonal(
                            onPressed: () async {
                              await widget.controller.reopenJob(job.id);
                              if (mounted) setState(() {});
                            },
                            child: const Text('Open'),
                          ),
                          IconButton(
                            tooltip: 'Delete saved job metadata',
                            onPressed: () async {
                              await widget.controller.repository.deleteJob(
                                job.id,
                              );
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class ClientProfilesScreen extends StatelessWidget {
  const ClientProfilesScreen({super.key});
  @override
  Widget build(BuildContext context) => _EmptySection(
    icon: Icons.business_outlined,
    title: 'Client mapping profiles',
    message: 'Reusable profiles are matched by stable headers and column identities. Missing, renamed, ambiguous, moved, and additional columns require review.',
  );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 580),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 50,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Create new'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _letter(int zeroBased) {
  var value = zeroBased + 1;
  var result = '';
  while (value > 0) {
    value--;
    result = String.fromCharCode(65 + value % 26) + result;
    value ~/= 26;
  }
  return result;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
