import 'dart:io';
import 'dart:convert';

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
      .openUrl(verb, Uri.parse(url))
      .then((request) => request.close())
      .then((response) async {
        // do stuff here.
        var data = await response.transform(utf8.decoder).first;
        return Response(statusCode: 200, headers: {}, body: data);
      });
  }
}
