import 'dart:io';
import 'dart:convert';
import 'package:yaml/yaml.dart';

class YamlReader {
  File file;
  Map<String, Object> parsed = {};

  YamlReader({required this.file});

  void read() {
    var data = file.readAsStringSync();
    YamlMap yamlMap = loadYaml(data);
    parsed = jsonDecode(jsonEncode(yamlMap));
  }
}
