import 'dart:io';

import 'package:popshop/response/respondable.dart';

class Response implements Respondable {
  int statusCode = 200;
  Map<String, dynamic>? headers;
  dynamic body;

  @override
  Future<HttpResponse> toHttpResponse() {
    var resp = HttpResponse();
    resp.headers = headers;
    resp.statusCode = statusCode;
    
    return Future.value(resp);
  }
}
