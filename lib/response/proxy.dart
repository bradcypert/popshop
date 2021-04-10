import 'package:popshop/response/respondable.dart';

class Proxy implements Respondable {
  String url;
  bool sendHeaders = false;

  Proxy({required this.url, this.sendHeaders = false});
}
