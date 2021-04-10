import 'package:popshop/server.dart' as popshop;

void main(List<String> arguments) async {
  var server = popshop.Server();
  await server.serveHTTP();
}
