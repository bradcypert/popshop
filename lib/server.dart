import 'dart:io';

import 'package:popshop/request_respondable_pair.dart';
import 'package:popshop/response/respondable.dart';
import 'package:popshop/response/response.dart';

class Server {

  var port = 7777;
  List<RequestRespondablePair> bindings = [];

  Future serveHTTP() async {
    var server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );

    print('Bound server to port $port');

    await for (HttpRequest request in server) {
      var hasMatch = false;
      for (var i = 0; i < bindings.length; i++) {
      hasMatch = request.uri.path.endsWith(bindings[i].request.path);

      var response = bindings[i].respondable;

      if (hasMatch) {
          _renderResponse(request, response);
          break;
        }
      }

      if (!hasMatch) {
        request.response.statusCode = 404;
      }

      await request.response.close();
    }
  }

  void _renderResponse(HttpRequest request, Respondable response) async {
    request.response.write(await response.processResponse());
  }

}
