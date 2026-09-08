import 'dart:io';

import 'package:path/path.dart' as p;

class StyleFinding {
  const StyleFinding(this.path, this.line, this.message);

  final String path;
  final int line;
  final String message;
}

class StyleAuditor {
  List<StyleFinding> audit(Directory root) {
    final lib = Directory(p.join(root.path, 'lib'));
    if (!lib.existsSync()) return <StyleFinding>[];
    final findings = <StyleFinding>[];
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (p.extension(file.path) != '.dart' ||
          file.path.endsWith('.g.dart') ||
          file.path.endsWith('.freezed.dart')) continue;
      final relative = p.relative(file.path, from: root.path);
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (RegExp(r'Widget\s+_build\w+\s*\(').hasMatch(line))
          findings.add(StyleFinding(relative, index + 1,
              'Widget-returning _buildXxx() method; keep page UI inline or extract a public XxxWidget.'));
        if (RegExp(
                r'class\s+_\w+\s+extends\s+(?:StatelessWidget|StatefulWidget)')
            .hasMatch(line))
          findings.add(StyleFinding(relative, index + 1,
              'Private widget class; use a public XxxWidget when extraction is justified.'));
        if (RegExp(r'class\s+\w+(?:Content|Loading|Error)Component\s+extends')
            .hasMatch(line))
          findings.add(StyleFinding(relative, index + 1,
              'Page-state component; keep state branches inline unless reuse, independent state, or size requires extraction.'));
        if (RegExp(
                r'^(?:BoxDecoration|TextStyle|EdgeInsets|BorderRadius)\s+\w+\s*\(')
            .hasMatch(line.trim()))
          findings.add(StyleFinding(relative, index + 1,
              'Small visual configuration helper; keep one-off visual configuration inline.'));
        if (line.contains('PagedListView<') && !line.contains('.separated'))
          findings.add(StyleFinding(
              relative, index + 1, 'PagedListView must use .separated.'));
      }
      final content = lines.join('\n');
      if (content.contains('PagedListView') ||
          content.contains('PagedAlignedGridView')) {
        for (final required in <String>[
          'newPageProgressIndicatorBuilder',
          'firstPageProgressIndicatorBuilder',
          'firstPageErrorIndicatorBuilder',
          'noItemsFoundIndicatorBuilder'
        ]) {
          if (!content.contains(required))
            findings.add(
                StyleFinding(relative, 1, 'Pagination is missing $required.'));
        }
      }
      if (content.contains('ScrollController(') &&
          !content.contains('_scrollController.dispose()'))
        findings.add(StyleFinding(relative, 1,
            'ScrollController may not be disposed; verify screen lifecycle.'));
    }
    return findings;
  }
}
