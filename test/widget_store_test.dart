import 'dart:io';

import 'package:flutter_agents_cli/src/models.dart';
import 'package:flutter_agents_cli/src/widget_store.dart';
import 'package:test/test.dart';

void main() {
  group('WidgetStore', () {
    test('knows the built-in widget names', () {
      expect(WidgetStore.names, containsAll(<String>['text', 'spacing']));
      expect(WidgetStore.supports('text'), isTrue);
      expect(WidgetStore.supports('spacing'), isTrue);
      expect(WidgetStore.supports('button'), isFalse);
    });

    test('resolves a spec only for an exact role and class pair', () {
      expect(
        WidgetStore.byRole('Text', 'CustomText')?.file,
        'text/custom_text.dart',
      );
      expect(
        WidgetStore.byRole('Spacing', 'AppSpacing')?.file,
        'spacing/app_spacing.dart',
      );
      expect(WidgetStore.byRole('Text', 'AppText'), isNull);
      expect(WidgetStore.byRole('Body', 'CustomText'), isNull);
    });

    test('add writes the file and records the role mapping', () async {
      final project = Directory.systemTemp.createTempSync('agents-widget-');
      try {
        final config = StackConfig(mode: 'new', sharedRoot: 'lib/core');

        final rel = await WidgetStore().add(project, config, 'text');

        expect(rel, 'lib/core/widgets/custom_text.dart');
        expect(
          File('${project.path}/lib/core/widgets/custom_text.dart')
              .existsSync(),
          isTrue,
        );
        expect(config.uiComponents['Text'], 'CustomText');
      } finally {
        project.deleteSync(recursive: true);
      }
    });

    test('add falls back to lib/shared without a shared root', () async {
      final project = Directory.systemTemp.createTempSync('agents-widget-');
      try {
        final config = StackConfig(mode: 'new');

        final rel = await WidgetStore().add(project, config, 'spacing');

        expect(rel, 'lib/shared/widgets/app_spacing.dart');
        expect(config.uiComponents['Spacing'], 'AppSpacing');
      } finally {
        project.deleteSync(recursive: true);
      }
    });
  });
}
