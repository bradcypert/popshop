/// {@template popshop_request}
/// Represents an incoming HTTP request configuration
/// {@endtemplate}
class PopshopRequest {
  /// {@macro popshop_request}
  const PopshopRequest({
    required this.path,
    required this.verb,
    this.headers,
    this.body,
  });

  /// Creates a PopshopRequest from a Map (parsed YAML)
  factory PopshopRequest.fromMap(Map<String, dynamic> map) {
    return PopshopRequest(
      path: map['path'] as String,
      verb: map['verb'] as String,
      headers: map['headers'] != null 
          ? Map<String, String>.from(map['headers'] as Map)
          : null,
      body: map['body'] as String?,
    );
  }

  /// The request path (e.g., "/users/1")
  final String path;

  /// The HTTP verb (e.g., "get", "post", "put", "delete")
  final String verb;

  /// Optional request headers to match
  final Map<String, String>? headers;

  /// Optional request body to match
  final String? body;

  /// Returns the HTTP method in uppercase
  String get method => verb.toUpperCase();
}

/// {@template popshop_response}
/// Represents a mock HTTP response configuration
/// {@endtemplate}
class PopshopResponse {
  /// {@macro popshop_response}
  const PopshopResponse({
    required this.body,
    this.status = 200,
    this.headers,
  });

  /// Creates a PopshopResponse from a Map (parsed YAML)
  factory PopshopResponse.fromMap(Map<String, dynamic> map) {
    return PopshopResponse(
      body: map['body'] as String,
      status: map['status'] as int? ?? 200,
      headers: map['headers'] != null 
          ? Map<String, String>.from(map['headers'] as Map)
          : null,
    );
  }

  /// The response body content
  final String body;

  /// The HTTP status code (defaults to 200)
  final int status;

  /// Optional response headers
  final Map<String, String>? headers;
}

/// {@template popshop_proxy}
/// Represents a proxy configuration for forwarding requests
/// {@endtemplate}
class PopshopProxy {
  /// {@macro popshop_proxy}
  const PopshopProxy({
    required this.url,
    this.verb,
    this.headers,
  });

  /// Creates a PopshopProxy from a Map (parsed YAML)
  factory PopshopProxy.fromMap(Map<String, dynamic> map) {
    return PopshopProxy(
      url: map['url'] as String,
      verb: map['verb'] as String?,
      headers: map['headers'] != null 
          ? Map<String, String>.from(map['headers'] as Map)
          : null,
    );
  }

  /// The target URL to proxy to
  final String url;

  /// Optional HTTP verb override (defaults to same as incoming request)
  final String? verb;

  /// Optional headers to add/override when proxying
  final Map<String, String>? headers;

  /// Returns the proxy HTTP method in uppercase
  String getMethod(String fallbackMethod) => 
      (verb ?? fallbackMethod).toUpperCase();
}

/// {@template popshop_rule}
/// Represents a complete PopShop rule with request matching and response/proxy
/// {@endtemplate}
class PopshopRule {
  /// {@macro popshop_rule}
  const PopshopRule({
    required this.request,
    this.response,
    this.proxy,
  }) : assert(
         response != null || proxy != null,
         'Either response or proxy must be provided',
       );

  /// Creates a PopshopRule from a Map (parsed YAML)
  factory PopshopRule.fromMap(Map<String, dynamic> map) {
    final request = PopshopRequest.fromMap(
      map['request'] as Map<String, dynamic>,
    );
    
    PopshopResponse? response;
    PopshopProxy? proxy;
    
    if (map.containsKey('response')) {
      response = PopshopResponse.fromMap(
        map['response'] as Map<String, dynamic>,
      );
    }
    
    if (map.containsKey('proxy')) {
      proxy = PopshopProxy.fromMap(
        map['proxy'] as Map<String, dynamic>,
      );
    }
    
    return PopshopRule(
      request: request,
      response: response,
      proxy: proxy,
    );
  }

  /// The request configuration to match against
  final PopshopRequest request;

  /// Optional response configuration for mocking
  final PopshopResponse? response;

  /// Optional proxy configuration for forwarding
  final PopshopProxy? proxy;

  /// Returns true if this is a proxy rule
  bool get isProxy => proxy != null;

  /// Returns true if this is a mock response rule
  bool get isMock => response != null;
}