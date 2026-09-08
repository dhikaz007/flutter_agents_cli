import 'dart:io';

import 'package:flutter_agents_cli/src/detector.dart';
import 'package:test/test.dart';

void main() {
  test('detects common Flutter stack from pubspec', () {
    final root = Directory.systemTemp.createTempSync('flutter_agents_test_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: demo
dependencies:
  flutter_bloc: any
  go_router: any
  dio: any
  hive_ce: any
  easy_localization: any
  skeletonizer: any
dev_dependencies:
  freezed: any
''');
    Directory('${root.path}/lib/core').createSync(recursive: true);
    Directory('${root.path}/lib/feature/auth/data/datasources')
        .createSync(recursive: true);
    Directory('${root.path}/lib/feature/auth/presentation/widgets')
        .createSync(recursive: true);

    final result = ProjectDetector().detect(root);
    expect(result.config.mode, 'existing');
    expect(result.config.state, 'flutter_bloc');
    expect(result.config.routing, 'go_router');
    expect(result.config.network, 'dio');
    expect(result.config.storage, 'hive_ce');
    expect(result.config.localization, 'easy_localization');
    expect(result.config.listLoader, 'skeletonizer');
    expect(result.config.architecture, 'custom_existing');
    expect(result.config.observedStructure, contains('lib/feature/auth/data'));
  });

  test(
      'classifies reusable widgets from their implementation and flexible names',
      () {
    final root = Directory.systemTemp.createTempSync('flutter_agents_widgets_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/lib/widgets/atoms/widgets.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
class AppButtonPrimary extends StatelessWidget { Widget build(context) => ElevatedButton(onPressed: () {}, child: const Text('Save')); }
class AppInputField extends StatelessWidget { Widget build(context) => TextFormField(); }
class AppAppBar extends StatelessWidget { Widget build(context) => AppBar(); }
class AppDefaultLoading extends StatelessWidget { Widget build(context) => CircularProgressIndicator(); }
class AppSvg extends StatelessWidget { Widget build(context) => SvgPicture.asset('logo.svg'); }
''');

    final components = ProjectDetector().detectUiComponents(root);

    expect(components['Button'], 'AppButtonPrimary');
    expect(components['Input'], 'AppInputField');
    expect(components['AppBar'], 'AppAppBar');
    expect(components['Loading'], 'AppDefaultLoading');
    expect(components['Svg'], 'AppSvg');
  });
}
