import 'dart:async';
import 'dart:convert';

import 'package:mason_logger/mason_logger.dart';
import 'package:shelf/shelf.dart';

/// Security configuration for the server
class SecurityConfig {
  const SecurityConfig({
    this.maxRequestSizeBytes = 1024 * 1024, // 1MB default
    this.requestTimeoutSeconds = 30,
    this.maxHeaderSize = 8 * 1024, // 8KB default
    this.allowedHosts,
    this.rateLimitRequests = 100,
    this.rateLimitWindowSeconds = 60,
  });

  final int maxRequestSizeBytes;
  final int requestTimeoutSeconds;
  final int maxHeaderSize;
  final List<String>? allowedHosts;
  final int rateLimitRequests;
  final int rateLimitWindowSeconds;
}

/// Provides security middleware for HTTP requests
class SecurityMiddleware {
  SecurityMiddleware({
    required Logger logger,
    SecurityConfig? config,
  })  : _logger = logger,
        _config = config ?? const SecurityConfig(),
        _rateLimitMap = <String, List<DateTime>>{};

  final Logger _logger;
  final SecurityConfig _config;
  final Map<String, List<DateTime>> _rateLimitMap;

  /// Creates a combined security middleware pipeline
  Middleware createSecurityMiddleware() {
    return const Pipeline()
        .addMiddleware(_requestSizeMiddleware())
        .addMiddleware(_rateLimitMiddleware())
        .addMiddleware(_hostValidationMiddleware())
        .addMiddleware(_timeoutMiddleware())
        .middleware;
  }

  /// Middleware to limit request body size
  Middleware _requestSizeMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        // Check Content-Length header if present
        final contentLengthHeader = request.headers['content-length'];
        if (contentLengthHeader != null) {
          final contentLength = int.tryParse(contentLengthHeader);
          if (contentLength != null && contentLength > _config.maxRequestSizeBytes) {
            _logger.warn('Request rejected: Content-Length too large ($contentLength bytes)');
            return Response(413, body: 'Request entity too large');
          }
        }

        // Check header size
        final headerSize = request.headers.entries
            .map((e) => '${e.key}: ${e.value}\r\n'.length)
            .fold(0, (a, b) => a + b);
        
        if (headerSize > _config.maxHeaderSize) {
          _logger.warn('Request rejected: Headers too large ($headerSize bytes)');
          return Response(431, body: 'Request header fields too large');
        }

        return innerHandler(request);
      };
    };
  }

  /// Middleware for basic rate limiting
  Middleware _rateLimitMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final clientIp = _getClientIp(request);
        final now = DateTime.now();
        
        // Clean up old entries
        _rateLimitMap[clientIp]?.removeWhere(
          (timestamp) => now.difference(timestamp).inSeconds > _config.rateLimitWindowSeconds,
        );
        
        // Initialize if not exists
        _rateLimitMap[clientIp] ??= <DateTime>[];
        
        // Check rate limit
        if (_rateLimitMap[clientIp]!.length >= _config.rateLimitRequests) {
          _logger.warn('Request rejected: Rate limit exceeded for $clientIp');
          return Response(429, 
            body: 'Too many requests',
            headers: {
              'Retry-After': _config.rateLimitWindowSeconds.toString(),
            },
          );
        }
        
        // Add current request
        _rateLimitMap[clientIp]!.add(now);
        
        return innerHandler(request);
      };
    };
  }

  /// Middleware to validate allowed hosts
  Middleware _hostValidationMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (_config.allowedHosts != null && _config.allowedHosts!.isNotEmpty) {
          final host = request.headers['host'];
          if (host == null || !_config.allowedHosts!.contains(host)) {
            _logger.warn('Request rejected: Invalid host header ($host)');
            return Response(400, body: 'Invalid host');
          }
        }
        
        return innerHandler(request);
      };
    };
  }

  /// Middleware to add request timeout
  Middleware _timeoutMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        try {
          return await innerHandler(request)
              .timeout(Duration(seconds: _config.requestTimeoutSeconds));
        } on TimeoutException {
          _logger.warn('Request timed out after ${_config.requestTimeoutSeconds}s');
          return Response(408, body: 'Request timeout');
        }
      };
    };
  }

  /// Extracts client IP from request
  String _getClientIp(Request request) {
    // Check X-Forwarded-For header first (for proxied requests)
    final xForwardedFor = request.headers['x-forwarded-for'];
    if (xForwardedFor != null && xForwardedFor.isNotEmpty) {
      return xForwardedFor.split(',').first.trim();
    }
    
    // Check X-Real-IP header
    final xRealIp = request.headers['x-real-ip'];
    if (xRealIp != null && xRealIp.isNotEmpty) {
      return xRealIp.trim();
    }
    
    // Fall back to connection info if available
    return request.context['shelf.io.connection_info']?.remoteAddress.address ?? 'unknown';
  }
}

/// Validates proxy URLs to prevent SSRF attacks
class ProxyUrlValidator {
  static const _allowedSchemes = {'http', 'https'};
  static const _blockedHosts = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '::1',
  };
  static const _blockedPorts = {22, 23, 25, 53, 69, 80, 110, 135, 139, 143, 443, 445, 993, 995};

  /// Validates if a proxy URL is safe to use
  static bool isValidProxyUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Check scheme
      if (!_allowedSchemes.contains(uri.scheme.toLowerCase())) {
        return false;
      }
      
      // Check for blocked hosts
      if (_blockedHosts.contains(uri.host.toLowerCase())) {
        return false;
      }
      
      // Check for private IP ranges
      if (_isPrivateIp(uri.host)) {
        return false;
      }
      
      // Check for blocked ports
      if (uri.hasPort && _blockedPorts.contains(uri.port)) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Checks if an IP address is in a private range
  static bool _isPrivateIp(String host) {
    // Basic check for common private IP ranges
    // Note: This is a simplified check, a production implementation
    // should use a proper IP address parsing library
    
    if (host.startsWith('10.')) return true;
    if (host.startsWith('192.168.')) return true;
    if (host.startsWith('172.')) {
      final parts = host.split('.');
      if (parts.length >= 2) {
        final secondOctet = int.tryParse(parts[1]);
        if (secondOctet != null && secondOctet >= 16 && secondOctet <= 31) {
          return true;
        }
      }
    }
    if (host.startsWith('169.254.')) return true; // Link-local
    if (host.startsWith('fc00:') || host.startsWith('fd00:')) return true; // IPv6 private
    
    return false;
  }
}