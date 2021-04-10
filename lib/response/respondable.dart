import 'package:popshop/response/response.dart';

abstract class Respondable {
  Future<Response> processResponse();
}
