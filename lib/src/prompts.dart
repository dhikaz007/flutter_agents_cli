import 'dart:io';

String? choose(
  String title,
  List<String> options, {
  String? detected,
  bool allowNone = true,
}) {
  stdout.writeln('\n$title');
  final values = <String>[...options, if (allowNone) 'none'];
  for (var i = 0; i < values.length; i++) {
    final marker = values[i] == detected ? ' (current/detected)' : '';
    stdout.writeln('  ${i + 1}. ${values[i]}$marker');
  }
  stdout.write('Choose${detected != null ? ' [Enter = $detected]' : ''}: ');
  final raw = stdin.readLineSync()?.trim() ?? '';
  if (raw.isEmpty && detected != null) return detected;
  final index = int.tryParse(raw);
  if (index == null || index < 1 || index > values.length) return detected;
  return values[index - 1] == 'none' ? null : values[index - 1];
}

String chooseMode(String detected) {
  final result = choose('Project mode', <String>['existing', 'new'], detected: detected, allowNone: false);
  return result ?? detected;
}

bool confirm(String message, {bool defaultYes = true}) {
  stdout.write('$message ${defaultYes ? '[Y/n]' : '[y/N]'} ');
  final raw = stdin.readLineSync()?.trim().toLowerCase() ?? '';
  if (raw.isEmpty) return defaultYes;
  return raw == 'y' || raw == 'yes';
}
