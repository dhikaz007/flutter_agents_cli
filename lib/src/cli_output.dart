import 'dart:io';

import 'models.dart';

void printGenerationReport(GenerationReport report, {bool dryRun = false}) {
  stdout.writeln(dryRun ? '\nDry-run changes:' : '\nApplied changes:');
  for (final item in report.created) stdout.writeln('  + $item');
  for (final item in report.updated) stdout.writeln('  ~ $item');
  for (final item in report.deleted) stdout.writeln('  - $item');
  for (final item in report.preservedModified)
    stdout.writeln('  ! preserved modified: $item');
  for (final item in report.preservedUnmanaged)
    stdout.writeln('  ! preserved unmanaged: $item');
  for (final item in report.missingTemplates)
    stdout.writeln('  ! missing template: $item');
  if (report.created.isEmpty &&
      report.updated.isEmpty &&
      report.deleted.isEmpty &&
      !report.hasWarnings) {
    stdout.writeln('  no file changes');
  }
}

void printDetection(DetectionResult result) {
  final c = result.config;
  stdout.writeln('Detected mode: ${c.mode}');
  stdout.writeln('Architecture: ${c.architecture ?? '-'}');
  stdout.writeln('State: ${c.state ?? '-'}');
  stdout.writeln('Routing: ${c.routing ?? '-'}');
  stdout.writeln('DI: ${c.di ?? '-'}');
  stdout.writeln('Network: ${c.network ?? '-'}');
  stdout.writeln('Storage: ${c.storage ?? '-'}');
  stdout.writeln('Localization: ${c.localization ?? '-'}');
  stdout.writeln('Assets: ${c.assets ?? '-'}');
  stdout.writeln('Model codegen: ${c.modelCodegen ?? '-'}');
  stdout.writeln('Pagination: ${c.pagination ?? '-'}');
  final loading = <String?>[
    c.blockingLoader,
    c.listLoader,
    c.inlineLoader,
  ].whereType<String>().join(', ');
  stdout.writeln('Loading: ${loading.isEmpty ? '-' : loading}');
  if (c.uiComponents.isNotEmpty)
    stdout.writeln('UI components: ${c.uiComponents}');
  for (final note in result.notes) stdout.writeln('i $note');
}

void applyArchitectureDefaults(StackConfig c) {
  switch (c.architecture) {
    case 'feature_first_pragmatic_clean':
      c.featureRoot ??= 'lib/feature';
      c.sharedRoot ??= 'lib/core';
      break;
    case 'feature_first_simple':
    case 'feature_first_clean':
      c.featureRoot ??= 'lib/features';
      c.sharedRoot ??= 'lib/core';
      break;
    case 'modular_feature':
      c.featureRoot ??= 'lib/feature';
      c.sharedRoot ??= 'lib/shared';
      break;
    case 'custom_existing':
      break;
  }
}
