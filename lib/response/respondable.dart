import 'dart:io';

abstract class Respondable {
  Future<HttpResponse> toHttpResponse();
}
