import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class UserRuleStore {
  Directory get root {
    final override = Platform.environment['FLUTTER_AGENTS_HOME'];
    if (override != null && override.trim().isNotEmpty) return Directory(override);
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
    return Directory(p.join(home, '.flutter-agents'));
  }

  File get defaultsFile => File(p.join(root.path, 'rule-defaults.json'));
  Directory rulesDir(String layer) => Directory(p.join(root.path, 'rules', layer));

  List<String> layers() {
    final base = Directory(p.join(root.path, 'rules'));
    if (!base.existsSync()) return <String>[];
    final out = base.listSync().whereType<Directory>().map((d) => p.basename(d.path)).toList()..sort();
    return out;
  }

  List<String> list(String layer) {
    final dir = rulesDir(layer);
    if (!dir.existsSync()) return <String>[];
    final out = dir.listSync().whereType<File>().where((f) => p.extension(f.path) == '.md').map((f) => p.basenameWithoutExtension(f.path)).toList()..sort();
    return out;
  }

  File? resolve(String layer, String name) {
    final file = File(p.join(rulesDir(layer).path, '$name.md'));
    return file.existsSync() ? file : null;
  }

  String add(String layer, File source, {String? name}) {
    if (!source.existsSync()) throw ArgumentError('Rule file not found: ${source.path}');
    final ruleName = _safe(name ?? p.basenameWithoutExtension(source.path));
    final target = File(p.join(rulesDir(layer).path, '$ruleName.md'));
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(source.readAsBytesSync());
    return ruleName;
  }

  void remove(String layer, String name) {
    final file = resolve(layer, name);
    if (file == null) throw ArgumentError('Rule not found: $layer/$name');
    file.deleteSync();
    final defaults = readDefaults();
    if (defaults[layer] == name) {
      defaults.remove(layer);
      writeDefaults(defaults);
    }
  }

  Map<String, String> readDefaults() {
    if (!defaultsFile.existsSync()) return <String, String>{};
    try {
      final raw = jsonDecode(defaultsFile.readAsStringSync());
      if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {}
    return <String, String>{};
  }

  void writeDefaults(Map<String, String> value) {
    defaultsFile.parent.createSync(recursive: true);
    defaultsFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));
  }

  void setDefault(String layer, String? name) {
    final defaults = readDefaults();
    if (name == null || name == 'default') {
      defaults.remove(layer);
    } else {
      if (resolve(layer, name) == null) throw ArgumentError('Rule not found: $layer/$name');
      defaults[layer] = name;
    }
    writeDefaults(defaults);
  }

  String? defaultFor(String layer) => readDefaults()[layer];

  String _safe(String value) {
    final safe = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    if (safe.isEmpty) throw ArgumentError('Invalid rule name.');
    return safe;
  }
}
