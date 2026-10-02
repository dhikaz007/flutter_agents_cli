import 'dart:io';

import 'package:path/path.dart' as p;

import 'generator.dart';
import 'models.dart';

/// Built-in shared widgets the CLI can scaffold into a project.
class WidgetStore {
  static const Map<String, _WidgetSpec> widgets = <String, _WidgetSpec>{
    'text': _WidgetSpec(
      file: 'text/custom_text.dart',
      role: 'Text',
      className: 'CustomText',
      package: null,
    ),
    'spacing': _WidgetSpec(
      file: 'spacing/app_spacing.dart',
      role: 'Spacing',
      className: 'AppSpacing',
      package: 'gap',
    ),
  };

  static List<String> get names => widgets.keys.toList()..sort();

  static bool supports(String name) => widgets.containsKey(name);

  static _WidgetSpec? byRole(String role, String className) {
    for (final spec in widgets.values) {
      if (spec.role == role && spec.className == className) return spec;
    }
    return null;
  }

  /// Copies the widget template into the project shared folder and records
  /// the role mapping, returning the project-relative path written.
  Future<String> add(
    Directory project,
    StackConfig config,
    String name,
  ) async {
    final spec = widgets[name]!;
    final templates = await RuleGenerator().templateRoot();
    final source = File(p.join(templates.path, 'widgets', spec.file));
    if (!source.existsSync()) {
      throw StateError('Widget template missing: widgets/${spec.file}');
    }
    final shared = config.sharedRoot ?? 'lib/shared';
    final rel = p.join(shared, 'widgets', p.basename(spec.file));
    final target = File(p.join(project.path, rel));
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(source.readAsBytesSync());
    config.uiComponents = Map<String, String>.of(config.uiComponents)
      ..[spec.role] = spec.className;
    return rel;
  }
}

class _WidgetSpec {
  const _WidgetSpec({
    required this.file,
    required this.role,
    required this.className,
    required this.package,
  });

  final String file;
  final String role;
  final String className;
  final String? package;
}
