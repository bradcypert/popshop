import 'dart:io';

import 'package:popshop/response/respondable.dart';

class Response implements Respondable {
  int statusCode = 200;
  Map<String, dynamic>? headers;
  dynamic body;

  Response({this.statusCode = 200, this.headers, this.body});

  @override
  Future<Response> processResponse() {
    return Future.value(this);
  }
}
