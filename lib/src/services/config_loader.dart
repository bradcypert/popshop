import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:popshop/src/models/popshop_config.dart';
import 'package:yaml/yaml.dart';

/// {@template config_loader}
/// Service responsible for loading and parsing PopShop YAML configuration files
/// {@endtemplate}
class ConfigLoader {
  /// {@macro config_loader}
  const ConfigLoader({required Logger logger}) : _logger = logger;

  final Logger _logger;

  /// Loads PopShop rules from a file or directory
  Future<List<PopshopRule>> loadRules(String configPath) async {
    final file = File(configPath);
    final directory = Directory(configPath);

    if (await file.exists()) {
      return _loadRulesFromFile(file);
    } else if (await directory.exists()) {
      return _loadRulesFromDirectory(directory);
    } else {
      throw FileSystemException(
        'Configuration path not found',
        configPath,
      );
    }
  }

  /// Loads rules from a single YAML file
  Future<List<PopshopRule>> _loadRulesFromFile(File file) async {
    _logger.detail('Loading configuration from ${file.path}');
    
    final content = await file.readAsString();
    final yamlDoc = loadYaml(content);

    if (yamlDoc is Map) {
      // Single rule in file
      return [_parseRule(_convertYamlToMap(yamlDoc), file.path)];
    } else if (yamlDoc is List) {
      // Multiple rules in file
      return yamlDoc
          .map((rule) => _parseRule(_convertYamlToMap(rule), file.path))
          .toList();
    } else {
      throw FormatException(
        'YAML must contain a rule object or array of rules',
        file.path,
      );
    }
  }

  /// Loads rules from all YAML files in a directory
  Future<List<PopshopRule>> _loadRulesFromDirectory(Directory directory) async {
    _logger.detail('Loading configuration from directory ${directory.path}');
    
    final rules = <PopshopRule>[];
    
    await for (final entity in directory.list()) {
      if (entity is File && _isYamlFile(entity.path)) {
        try {
          final fileRules = await _loadRulesFromFile(entity);
          rules.addAll(fileRules);
        } catch (e) {
          _logger.warn('Failed to load ${entity.path}: $e');
        }
      }
    }

    if (rules.isEmpty) {
      throw FileSystemException(
        'No valid YAML configuration files found in directory',
        directory.path,
      );
    }

    return rules;
  }

  /// Parses a single rule from YAML data
  PopshopRule _parseRule(Map<String, dynamic> data, String source) {
    try {
      // Convert YamlMap to regular Map recursively
      final convertedData = _convertYamlToMap(data);
      return PopshopRule.fromMap(convertedData);
    } catch (e) {
      throw FormatException(
        'Invalid rule format in $source: $e',
        source,
      );
    }
  }

  /// Recursively converts YamlMap to Map<String, dynamic>
  dynamic _convertYamlToMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => 
          MapEntry(key.toString(), _convertYamlToMap(val)));
    } else if (value is List) {
      return value.map(_convertYamlToMap).toList();
    } else {
      return value;
    }
  }

  /// Checks if a file has a YAML extension
  bool _isYamlFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ext == '.yaml' || ext == '.yml';
  }

  /// Validates that a rule is well-formed
  void validateRule(PopshopRule rule, String source) {
    // Validate request
    if (rule.request.path.isEmpty) {
      throw FormatException('Request path cannot be empty', source);
    }

    if (rule.request.verb.isEmpty) {
      throw FormatException('Request verb cannot be empty', source);
    }

    final validVerbs = {'get', 'post', 'put', 'delete', 'patch', 'head', 'options'};
    if (!validVerbs.contains(rule.request.verb.toLowerCase())) {
      throw FormatException(
        'Invalid HTTP verb: ${rule.request.verb}',
        source,
      );
    }

    // Validate that either response or proxy is provided
    if (!rule.isMock && !rule.isProxy) {
      throw FormatException(
        'Rule must have either a response or proxy configuration',
        source,
      );
    }

    // Validate proxy URL if present
    if (rule.isProxy && rule.proxy!.url.isEmpty) {
      throw FormatException('Proxy URL cannot be empty', source);
    }

    // Validate response if present
    if (rule.isMock) {
      final response = rule.response!;
      if (response.status < 100 || response.status > 599) {
        throw FormatException(
          'Invalid HTTP status code: ${response.status}',
          source,
        );
      }
    }
  }
}