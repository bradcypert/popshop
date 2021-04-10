import 'dart:io';

import 'package:popshop/response/respondable.dart';

class Response implements Respondable {
  int statusCode = 200;
  Map<String, dynamic>? headers;
  dynamic body;

  @override
  Future<Response> processResponse() {
    return Future.value(this);
  }
}
