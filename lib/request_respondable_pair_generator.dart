import 'package:popshop/request_respondable_pair.dart';
import 'package:popshop/request/request_mapping.dart';
import 'package:popshop/response/response.dart';

class RequestRespondablePairGenerator {

  static RequestRespondablePair generateFromMap(Map<String, dynamic> data) {
    var requestData = data['request'];
    var responseData = data['response'];

    var request = RequestMapping(path: requestData['path'], verb: requestData['verb']);
    var response = Response(body: responseData['body'], statusCode: responseData['status'], headers: responseData['headers']);

    return RequestRespondablePair(request, response);
  }

}
