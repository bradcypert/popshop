import 'dart:io';

import 'package:popshop/response/respondable.dart';
import 'package:popshop/response/response.dart';

class Proxy implements Respondable {
  String url;
  String verb;
  bool sendHeaders = false;

  Proxy({required this.url, required this.verb, this.sendHeaders = false});

  @override
  Future<Response> processResponse() {

    // this should work for gets, but we'll need to handle other verbs, too.
    return HttpClient()
      .getUrl(Uri.parse(url))
      .then((request) => request.close())
      .then((response) {
        // do stuff here.
        return Response();
      });
  }
}
