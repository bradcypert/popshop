import 'dart:io';

import 'package:popshop/config/yaml_reader.dart';
import 'package:popshop/request_respondable_pair.dart';
import 'package:popshop/request_respondable_pair_generator.dart';

class ConfigFinder {
  static List<RequestRespondablePair> generateConfigsFrom({required Directory directory}) {
    return directory.listSync(recursive: true)
      .map((e) => File(e.path))
      .where((file) => file.path.endsWith('.yml'))
      .map((file) => YamlReader(file: file)..read())
      .map((yamlReader) => yamlReader.parsed)
      .map((contents) => RequestRespondablePairGenerator.generateFromMap(contents))
      .toList();
  }
}
