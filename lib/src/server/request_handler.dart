import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:popshop/src/middleware/security_middleware.dart';
import 'package:popshop/src/models/popshop_config.dart';
import 'package:shelf/shelf.dart';

/// {@template request_handler}
/// Handles incoming HTTP requests by matching them against PopShop rules
/// {@endtemplate}
class RequestHandler {
  /// {@macro request_handler}
  const RequestHandler({required Logger logger}) : _logger = logger;

  final Logger _logger;

  /// Handles a request by finding a matching rule and serving response or proxy
  Future<Response> handleRequest(
    Request request,
    List<PopshopRule> rules,
  ) async {
    _logger.detail('Handling ${request.method} ${request.url.path}');

    // Find matching rule
    final matchingRule = _findMatchingRule(request, rules);
    
    if (matchingRule == null) {
      _logger.warn('No matching rule found for ${request.method} ${request.url.path}');
      return Response.notFound('No matching rule found');
    }

    if (matchingRule.isMock) {
      return _serveMockResponse(matchingRule.response!);
    } else {
      return _proxyRequest(request, matchingRule.proxy!);
    }
  }

  /// Finds the first rule that matches the incoming request
  PopshopRule? _findMatchingRule(Request request, List<PopshopRule> rules) {
    for (final rule in rules) {
      if (_doesRuleMatch(request, rule)) {
        return rule;
      }
    }
    return null;
  }

  /// Checks if a rule matches the incoming request
  bool _doesRuleMatch(Request request, PopshopRule rule) {
    // Check HTTP method
    if (rule.request.method != request.method) {
      return false;
    }

    // Check path - exact match for now, could support patterns later
    if (rule.request.path != request.url.path) {
      return false;
    }

    // Check headers if specified in rule
    if (rule.request.headers != null) {
      for (final entry in rule.request.headers!.entries) {
        final requestHeaderValue = request.headers[entry.key.toLowerCase()];
        if (requestHeaderValue != entry.value) {
          return false;
        }
      }
    }

    // Check body if specified in rule
    if (rule.request.body != null) {
      // Note: This would require reading the request body
      // For now, we'll skip body matching as it's more complex
      // and would require buffering the entire request
    }

    return true;
  }

  /// Serves a mock response based on the rule configuration
  Response _serveMockResponse(PopshopResponse response) {
    _logger.detail('Serving mock response: ${response.status}');
    
    final headers = <String, String>{
      'content-type': 'application/json',
      ...?response.headers,
    };

    return Response(
      response.status,
      body: response.body,
      headers: headers,
    );
  }

  /// Proxies the request to an external server
  Future<Response> _proxyRequest(Request request, PopshopProxy proxy) async {
    _logger.detail('Proxying request to ${proxy.url}');

    // Validate proxy URL for security
    if (!ProxyUrlValidator.isValidProxyUrl(proxy.url)) {
      _logger.warn('Blocked potentially unsafe proxy URL: ${proxy.url}');
      return Response(400, body: 'Invalid proxy URL');
    }

    try {
      final method = proxy.getMethod(request.method);
      final uri = Uri.parse(proxy.url);
      
      // Prepare headers
      final headers = <String, String>{
        ...request.headers,
        ...?proxy.headers,
      };

      // Read request body if present
      final body = await request.readAsString();

      // Make the proxy request
      final http.Response response;
      
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: body);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: body);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers, body: body);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: body);
          break;
        case 'HEAD':
          response = await http.head(uri, headers: headers);
          break;
        default:
          throw UnsupportedError('HTTP method $method not supported for proxy');
      }

      // Return the proxied response
      return Response(
        response.statusCode,
        body: response.body,
        headers: _filterResponseHeaders(response.headers),
      );
    } catch (e) {
      _logger.err('Proxy request failed: $e');
      return Response(502, body: 'Proxy request failed: $e');
    }
  }

  /// Filters response headers to remove problematic ones
  Map<String, String> _filterResponseHeaders(Map<String, String> headers) {
    final filtered = <String, String>{};
    
    // Headers to exclude (these can cause issues when proxying)
    const excludedHeaders = {
      'content-encoding',
      'content-length',
      'transfer-encoding',
      'connection',
      'upgrade',
    };
    
    for (final entry in headers.entries) {
      if (!excludedHeaders.contains(entry.key.toLowerCase())) {
        filtered[entry.key] = entry.value;
      }
    }
    
    return filtered;
  }
}