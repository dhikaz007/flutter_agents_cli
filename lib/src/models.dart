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
    this.uiComponents = const <String, String>{},
    this.rules = const <String, String>{},
  });

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
  Map<String, String> uiComponents;
  Map<String, String> rules; // layer -> custom rule name; absent means CLI default

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
        'uiComponents': uiComponents,
        'rules': rules,
      };

  factory StackConfig.fromJson(Map<String, dynamic> json) {
    final rawUi = json['uiComponents'];
    final rawRules = json['rules'];
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
      uiComponents: rawUi is Map
          ? rawUi.map((key, value) => MapEntry(key.toString(), value.toString()))
          : <String, String>{},
      rules: rawRules is Map
          ? rawRules.map((key, value) => MapEntry(key.toString(), value.toString()))
          : <String, String>{},
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
    switch (kind) {
      case 'architecture':
        return architecture;
      case 'state':
        return state;
      case 'routing':
        return routing;
      case 'di':
        return di;
      case 'network':
        return network;
      case 'storage':
        return storage;
      case 'localization':
        return localization;
      case 'assets':
        return assets;
      case 'codegen':
        return modelCodegen;
      case 'loading-blocking':
        return blockingLoader;
      case 'loading-list':
        return listLoader;
      case 'loading-inline':
        return inlineLoader;
      case 'pagination':
        return pagination;
    }
    return null;
  }

  void setKind(String kind, String? value) {
    switch (kind) {
      case 'architecture':
        architecture = value;
        break;
      case 'state':
        state = value;
        break;
      case 'routing':
        routing = value;
        break;
      case 'di':
        di = value;
        break;
      case 'network':
        network = value;
        break;
      case 'storage':
        storage = value;
        break;
      case 'localization':
        localization = value;
        break;
      case 'assets':
        assets = value;
        break;
      case 'codegen':
        modelCodegen = value;
        break;
      case 'loading-blocking':
        blockingLoader = value;
        break;
      case 'loading-list':
        listLoader = value;
        break;
      case 'loading-inline':
        inlineLoader = value;
        break;
      case 'pagination':
        pagination = value;
        break;
      default:
        throw ArgumentError('Unknown profile kind: $kind');
    }
  }
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

  factory ManagedFileRecord.fromJson(Map<String, dynamic> json) => ManagedFileRecord(
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
          ? StackConfig.fromJson(rawConfig.map((key, value) => MapEntry(key.toString(), value)))
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
      preservedModified.isNotEmpty || preservedUnmanaged.isNotEmpty || missingTemplates.isNotEmpty;
}
