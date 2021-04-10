import 'package:popshop/response/respondable.dart';
import 'package:popshop/request/request_mapping.dart';

class RequestRespondablePair {
  Respondable respondable;
  RequestMapping request;
  
  RequestRespondablePair(this.request, this.respondable);
}
