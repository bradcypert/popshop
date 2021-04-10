import 'dart:io';
import 'package:yaml/yaml.dart';

class YamlReader {
  File file;
  // @todo: Spooky dynamic
  dynamic parsed;

  YamlReader({this.file});

  void read() {
    var data = file.readAsStringSync();
    parsed = loadYaml(data);
  }
}
