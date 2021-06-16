import 'dart:io';

import 'package:popshop/config/config_finder.dart';
import 'package:popshop/request_respondable_pair.dart';
import 'package:popshop/response/respondable.dart';
import 'package:popshop/response/response.dart';
import 'package:popshop/config/yaml_reader.dart';
import 'package:popshop/request_respondable_pair_generator.dart';

class Server {

  var port = 7777;
  List<RequestRespondablePair> bindings = [];

  Future serveHTTP() async {
    var server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );

    bindings = ConfigFinder.generateConfigsFrom(directory: Directory('.'));
    print('Bound server to port $port');

    await for (HttpRequest request in server) {
      var hasMatch = false;
      for (var i = 0; i < bindings.length; i++) {
        hasMatch = request.uri.path == bindings[i].request.path;
        var response = bindings[i].respondable;

        if (hasMatch) {
          await _renderResponse(request, response);
          break;
        }
      }

      if (!hasMatch) {
        request.response.statusCode = 404;
      }

      await request.response.close();
    }
  }

  Future _renderResponse(HttpRequest request, Respondable response) async {
    var res = await response.processResponse();
    request.response.statusCode = res.statusCode;
    return request.response.write(res.body);
  }

}
