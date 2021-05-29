import 'package:popshop/request_respondable_pair.dart';
import 'package:popshop/request/request_mapping.dart';
import 'package:popshop/response/respondable.dart';
import 'package:popshop/response/response.dart';
import 'package:popshop/response/proxy.dart';

class RequestRespondablePairGenerator {

  static RequestRespondablePair generateFromMap(Map<String, dynamic> data) {
    var requestData = data['request'];
    var responseData = data['response'];
    var proxyData = data['proxy'];

    var request = RequestMapping(path: requestData['path'], verb: requestData['verb']);
    Respondable respondable;
    if (responseData != null) {
      respondable = Response(body: responseData['body'], statusCode: responseData['status'], headers: responseData['headers']);
    } else if (proxyData != null) {
      respondable = Proxy(url: proxyData['url'], verb: proxyData['verb']);
    } else {
      throw Error();
    }
    return RequestRespondablePair(request, respondable);
  }

}
