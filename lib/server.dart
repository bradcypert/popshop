import 'dart:io';

import 'package:popshop/request_respondable_pair.dart';

class Server {

  var port = 7777;
  RequestRespondablePair[] bindings = [];

  Future serveHTTP() async {
    var server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );

    print('Bound server to port $port');

    await for (HttpRequest request in server) {
      var hasMatch = false;
      for (var i = 0; i < bindings.length; i++) {
      hasMatch = request.uri.path.endsWith(bindings[i]);

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

  void _renderResponse(HttpRequest request, Response response) {
    request.response.write(response.body);
  }

}
