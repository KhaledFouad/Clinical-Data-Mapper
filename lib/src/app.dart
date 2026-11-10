import 'package:flutter/material.dart';

import 'state/workflow_controller.dart';
import 'ui/screens.dart';

class ClinicalMapperApp extends StatelessWidget {
  const ClinicalMapperApp({super.key, this.controller});

  final WorkflowController? controller;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xff18615b));
    return MaterialApp(
      title: 'Clinical Data Mapper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xfff5f7f6),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: Color(0xffdfe7e4)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(Color(0xffedf3f1)),
        ),
      ),
      home: ClinicalMapperHome(controller: controller ?? WorkflowController()),
    );
  }
}

class ClinicalMapperHome extends StatefulWidget {
  const ClinicalMapperHome({super.key, required this.controller});
  final WorkflowController controller;

  @override
  State<ClinicalMapperHome> createState() => _ClinicalMapperHomeState();
}

class _ClinicalMapperHomeState extends State<ClinicalMapperHome> {
  int _section = 0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1180,
              backgroundColor: const Color(0xff123d3a),
              indicatorColor: const Color(0xff2b6661),
              selectedIconTheme: const IconThemeData(color: Colors.white),
              unselectedIconTheme: const IconThemeData(
                color: Color(0xffb8ceca),
              ),
              selectedLabelTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: Color(0xffb8ceca),
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub_outlined, color: Colors.white),
                    if (MediaQuery.sizeOf(context).width >= 1180)
                      const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text(
                          'Clinical Mapper',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon: Icon(Icons.account_tree),
                  label: Text('Workspace'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: Text('Recent jobs'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.business_outlined),
                  selectedIcon: Icon(Icons.business),
                  label: Text('Clients'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.view_list_outlined),
                  selectedIcon: Icon(Icons.view_list),
                  label: Text('Templates'),
                ),
              ],
              selectedIndex: _section,
              onDestinationSelected: (value) =>
                  setState(() => _section = value),
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(controller: controller),
                  if (controller.busy)
                    const LinearProgressIndicator(minHeight: 3),
                  if (controller.errorMessage != null)
                    MaterialBanner(
                      content: Text(controller.errorMessage!),
                      leading: const Icon(Icons.error_outline),
                      actions: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Review'),
                        ),
                      ],
                    ),
                  Expanded(child: _sectionBody(controller)),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _sectionBody(WorkflowController controller) => switch (_section) {
    1 => RecentJobsScreen(controller: controller),
    2 => const ClientProfilesScreen(),
    3 => TemplateLibraryScreen(controller: controller),
    _ => WorkflowWorkspace(controller: controller),
  };
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});
  final WorkflowController controller;

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xffdfe7e4))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                controller.sourcePath?.split(RegExp(r'[/\\]')).last ??
                    'New import job',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                controller.selectedTemplate.displayName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (controller.dirty)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(Icons.circle, size: 9),
              label: Text('Unsaved changes'),
            ),
          ),
        FilledButton.tonalIcon(
          onPressed: controller.hasSource && !controller.busy
              ? controller.saveCurrentJob
              : null,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save job'),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Privacy: all processing stays local',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(
              title: Text('Local processing'),
              content: Text(
                'Workbook values are processed on this computer. Ordinary diagnostic output does not include row values.',
              ),
            ),
          ),
          icon: const Icon(Icons.shield_outlined),
        ),
      ],
    ),
  );
}

class WorkflowWorkspace extends StatelessWidget {
  const WorkflowWorkspace({super.key, required this.controller});
  final WorkflowController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        _WorkflowSteps(controller: controller),
        const SizedBox(height: 18),
        Expanded(
          child: switch (controller.step) {
            WorkflowStep.import => ImportScreen(controller: controller),
            WorkflowStep.template => TemplateSelectionScreen(
              controller: controller,
            ),
            WorkflowStep.mapping => MappingScreen(controller: controller),
            WorkflowStep.review => ReviewScreen(controller: controller),
            WorkflowStep.export => ExportScreen(controller: controller),
          },
        ),
      ],
    ),
  );
}

class _WorkflowSteps extends StatelessWidget {
  const _WorkflowSteps({required this.controller});
  final WorkflowController controller;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: WorkflowStep.values.map((step) {
          final active = controller.step == step;
          final enabled =
              step.index <= controller.step.index || controller.hasSource;
          return Expanded(
            child: InkWell(
              onTap: enabled ? () => controller.moveTo(step) : null,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: active
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xffdce7e4),
                      foregroundColor: active
                          ? Colors.white
                          : const Color(0xff315b57),
                      child: Text(
                        '${step.index + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _label(step),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );

  String _label(WorkflowStep step) => switch (step) {
    WorkflowStep.import => 'Import',
    WorkflowStep.template => 'Template',
    WorkflowStep.mapping => 'Mapping',
    WorkflowStep.review => 'Review',
    WorkflowStep.export => 'Export',
  };
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
