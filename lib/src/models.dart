class StackConfig {
  StackConfig({
    required this.mode,
    this.architecture,
    this.featureRoot,
    this.sharedRoot,
    this.state,
    this.routing,
    this.di,
    this.network,
    this.storage,
    this.localization,
    this.assets,
    this.modelCodegen,
    this.jsonCodegen,
    this.blockingLoader,
    this.listLoader,
    this.inlineLoader,
    this.pagination,
    this.observedStructure = const <String>[],
    this.uiComponents = const <String, String>{},
    this.rules = const <String, String>{},
    this.ruleset,
    this.rulesetProfile,
    this.ruleMappings = const <String, String>{},
    this.dynamicRules = const <String>[],
  }) {
    // The generator and init mutate these collections in place, so a config
    // owns mutable copies. Copying also stops a caller's map from being
    // aliased and changed behind the config's back.
    this.observedStructure = List<String>.of(observedStructure);
    this.uiComponents = Map<String, String>.of(uiComponents);
    this.rules = Map<String, String>.of(rules);
    this.ruleMappings = Map<String, String>.of(ruleMappings);
    this.dynamicRules = List<String>.of(dynamicRules);
  }

  String mode;
  String? architecture;
  String? featureRoot;
  String? sharedRoot;
  String? state;
  String? routing;
  String? di;
  String? network;
  String? storage;
  String? localization;
  String? assets;
  String? modelCodegen;
  String? jsonCodegen;
  String? blockingLoader;
  String? listLoader;
  String? inlineLoader;
  String? pagination;
  List<String> observedStructure;
  Map<String, String> uiComponents;
  Map<String, String>
      rules; // layer -> custom rule name; absent means CLI default
  String? ruleset;
  String? rulesetProfile;

  /// concern -> `project:<relative path>` or `dynamic:<relative path>`.
  Map<String, String> ruleMappings;
  List<String> dynamicRules;

  StackConfig copy() => StackConfig.fromJson(toJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode,
        'architecture': architecture,
        'featureRoot': featureRoot,
        'sharedRoot': sharedRoot,
        'state': state,
        'routing': routing,
        'di': di,
        'network': network,
        'storage': storage,
        'localization': localization,
        'assets': assets,
        'modelCodegen': modelCodegen,
        'jsonCodegen': jsonCodegen,
        'blockingLoader': blockingLoader,
        'listLoader': listLoader,
        'inlineLoader': inlineLoader,
        'pagination': pagination,
        'observedStructure': observedStructure,
        'uiComponents': uiComponents,
        'rules': rules,
        'ruleset': ruleset,
        'rulesetProfile': rulesetProfile,
        'ruleMappings': ruleMappings,
        'dynamicRules': dynamicRules,
      };

  factory StackConfig.fromJson(Map<String, dynamic> json) {
    final rawUi = json['uiComponents'];
    final rawRules = json['rules'];
    final rawStructure = json['observedStructure'];
    final rawMappings = json['ruleMappings'];
    final rawDynamicRules = json['dynamicRules'];
    return StackConfig(
      mode: json['mode']?.toString() ?? 'existing',
      architecture: _nullable(json['architecture']),
      featureRoot: _nullable(json['featureRoot']),
      sharedRoot: _nullable(json['sharedRoot']),
      state: _nullable(json['state']),
      routing: _nullable(json['routing']),
      di: _nullable(json['di']),
      network: _nullable(json['network']),
      storage: _nullable(json['storage']),
      localization: _nullable(json['localization']),
      assets: _nullable(json['assets']),
      modelCodegen: _nullable(json['modelCodegen']),
      jsonCodegen: _nullable(json['jsonCodegen']),
      blockingLoader: _nullable(json['blockingLoader']),
      listLoader: _nullable(json['listLoader']),
      inlineLoader: _nullable(json['inlineLoader']),
      pagination: _nullable(json['pagination']),
      observedStructure: rawStructure is List
          ? rawStructure.map((item) => item.toString()).toList()
          : <String>[],
      uiComponents: rawUi is Map
          ? rawUi.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : <String, String>{},
      rules: rawRules is Map
          ? rawRules.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : <String, String>{},
      ruleset: _nullable(json['ruleset']),
      rulesetProfile: _nullable(json['rulesetProfile']),
      ruleMappings: rawMappings is Map
          ? rawMappings
              .map((key, value) => MapEntry(key.toString(), value.toString()))
          : <String, String>{},
      dynamicRules: rawDynamicRules is List
          ? rawDynamicRules.map((item) => item.toString()).toList()
          : <String>[],
    );
  }

  static String? _nullable(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'none' || text == 'null') return null;
    return text;
  }

  List<String> get profileKeys => <String>[
        if (architecture != null) 'architecture:$architecture',
        if (state != null) 'state:$state',
        if (routing != null) 'routing:$routing',
        if (di != null) 'di:$di',
        if (network != null) 'network:$network',
        if (storage != null) 'storage:$storage',
        if (localization != null) 'localization:$localization',
        if (assets != null) 'assets:$assets',
        if (modelCodegen != null) 'codegen:$modelCodegen',
        if (blockingLoader != null) 'loading:$blockingLoader',
        if (listLoader != null) 'loading:$listLoader',
        if (inlineLoader != null) 'loading:$inlineLoader',
        if (pagination != null) 'pagination:$pagination',
      ];

  String? valueForKind(String kind) {
    final field = kindFields[kind];
    return field == null ? null : fields[field]!.read(this);
  }

  void setKind(String kind, String? value) {
    final field = kindFields[kind];
    if (field == null) throw ArgumentError('Unknown profile kind: $kind');
    fields[field]!.write(this, value);
  }

  /// Profile kind -> the config field that stores it. Kinds are the CLI-facing
  /// names (`codegen`, `loading-list`); fields are the Dart field names
  /// (`modelCodegen`, `listLoader`).
  static const Map<String, String> kindFields = <String, String>{
    'architecture': 'architecture',
    'state': 'state',
    'routing': 'routing',
    'di': 'di',
    'network': 'network',
    'storage': 'storage',
    'localization': 'localization',
    'assets': 'assets',
    'codegen': 'modelCodegen',
    'loading-blocking': 'blockingLoader',
    'loading-list': 'listLoader',
    'loading-inline': 'inlineLoader',
    'pagination': 'pagination',
  };

  /// Read/write access to every scalar config field, in preset export order.
  /// One table so field access has a single owner instead of a switch per
  /// call site. `uiComponents` is absent: it holds a map, not a scalar.
  static final Map<String, ConfigField> fields = <String, ConfigField>{
    'mode': ConfigField((c) => c.mode, (c, v) => c.mode = v ?? c.mode),
    'architecture':
        ConfigField((c) => c.architecture, (c, v) => c.architecture = v),
    'featureRoot':
        ConfigField((c) => c.featureRoot, (c, v) => c.featureRoot = v),
    'sharedRoot': ConfigField((c) => c.sharedRoot, (c, v) => c.sharedRoot = v),
    'state': ConfigField((c) => c.state, (c, v) => c.state = v),
    'routing': ConfigField((c) => c.routing, (c, v) => c.routing = v),
    'di': ConfigField((c) => c.di, (c, v) => c.di = v),
    'network': ConfigField((c) => c.network, (c, v) => c.network = v),
    'storage': ConfigField((c) => c.storage, (c, v) => c.storage = v),
    'localization':
        ConfigField((c) => c.localization, (c, v) => c.localization = v),
    'assets': ConfigField((c) => c.assets, (c, v) => c.assets = v),
    'modelCodegen':
        ConfigField((c) => c.modelCodegen, (c, v) => c.modelCodegen = v),
    'jsonCodegen':
        ConfigField((c) => c.jsonCodegen, (c, v) => c.jsonCodegen = v),
    'blockingLoader':
        ConfigField((c) => c.blockingLoader, (c, v) => c.blockingLoader = v),
    'listLoader': ConfigField((c) => c.listLoader, (c, v) => c.listLoader = v),
    'inlineLoader':
        ConfigField((c) => c.inlineLoader, (c, v) => c.inlineLoader = v),
    'pagination': ConfigField((c) => c.pagination, (c, v) => c.pagination = v),
    'ruleset': ConfigField((c) => c.ruleset, (c, v) => c.ruleset = v),
    'rulesetProfile':
        ConfigField((c) => c.rulesetProfile, (c, v) => c.rulesetProfile = v),
  };
}

/// Read and write access to one scalar [StackConfig] field, so callers can
/// work with a field by name without a switch per call site.
class ConfigField {
  const ConfigField(this.read, this.write);

  final String? Function(StackConfig config) read;
  final void Function(StackConfig config, String? value) write;
}

class DetectionResult {
  DetectionResult(this.config, this.dependencies, this.notes);

  final StackConfig config;
  final Set<String> dependencies;
  final List<String> notes;
}

class ManagedFileRecord {
  ManagedFileRecord({required this.path, required this.sha256});

  final String path;
  final String sha256;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'sha256': sha256,
      };

  factory ManagedFileRecord.fromJson(Map<String, dynamic> json) =>
      ManagedFileRecord(
        path: json['path'].toString(),
        sha256: json['sha256'].toString(),
      );
}

class AgentsManifest {
  AgentsManifest({
    required this.version,
    required this.config,
    required this.files,
  });

  final String version;
  final StackConfig config;
  final Map<String, ManagedFileRecord> files;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'config': config.toJson(),
        'files': files.map((key, value) => MapEntry(key, value.toJson())),
      };

  factory AgentsManifest.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final files = <String, ManagedFileRecord>{};
    if (rawFiles is Map) {
      for (final entry in rawFiles.entries) {
        final value = entry.value;
        if (value is Map) {
          files[entry.key.toString()] = ManagedFileRecord.fromJson(
            value.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
    }
    final rawConfig = json['config'];
    return AgentsManifest(
      version: json['version']?.toString() ?? 'unknown',
      config: rawConfig is Map
          ? StackConfig.fromJson(
              rawConfig.map((key, value) => MapEntry(key.toString(), value)),
            )
          : StackConfig(mode: 'existing'),
      files: files,
    );
  }
}

class GenerationReport {
  final List<String> created = <String>[];
  final List<String> updated = <String>[];
  final List<String> deleted = <String>[];
  final List<String> preservedModified = <String>[];
  final List<String> preservedUnmanaged = <String>[];
  final List<String> missingTemplates = <String>[];

  bool get hasWarnings =>
      preservedModified.isNotEmpty ||
      preservedUnmanaged.isNotEmpty ||
      missingTemplates.isNotEmpty;
}
