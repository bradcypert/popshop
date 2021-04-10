class RequestMapping {
  String path;
  String verb;
  dynamic body;

  RequestMapping({required this.path, required this.verb, this.body});
}
