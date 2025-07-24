import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:popshop/src/middleware/security_middleware.dart';
import 'package:popshop/src/models/popshop_config.dart';
import 'package:popshop/src/server/request_handler.dart';
import 'package:popshop/src/services/config_loader.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// {@template popshop_server}
/// HTTP server that handles requests based on PopShop configuration rules
/// {@endtemplate}
class PopshopServer {
  /// {@macro popshop_server}
  PopshopServer({
    required Logger logger,
    required List<PopshopRule> rules,
    required ConfigLoader configLoader,
    required String configPath,
    bool watchMode = false,
    SecurityConfig? securityConfig,
  })  : _logger = logger,
        _rules = rules,
        _configLoader = configLoader,
        _configPath = configPath,
        _watchMode = watchMode,
        _requestHandler = RequestHandler(logger: logger),
        _securityMiddleware = SecurityMiddleware(logger: logger, config: securityConfig);

  final Logger _logger;
  final ConfigLoader _configLoader;
  final String _configPath;
  final bool _watchMode;
  final RequestHandler _requestHandler;
  final SecurityMiddleware _securityMiddleware;

  List<PopshopRule> _rules;
  HttpServer? _server;
  StreamSubscription<FileSystemEvent>? _watchSubscription;
  Timer? _reloadDebounceTimer;

  /// Starts the HTTP server
  Future<void> start({required String host, required int port}) async {
    final handler = Pipeline()
        .addMiddleware(_securityMiddleware.createSecurityMiddleware())
        .addMiddleware(_loggingMiddleware())
        .addMiddleware(_corsMiddleware())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, host, port);

    if (_watchMode) {
      await _startWatching();
    }
  }

  /// Stops the HTTP server
  Future<void> stop() async {
    await _watchSubscription?.cancel();
    _reloadDebounceTimer?.cancel();
    await _server?.close(force: true);
    _server = null;
  }

  /// Handles incoming HTTP requests
  Future<Response> _handleRequest(Request request) async {
    try {
      return await _requestHandler.handleRequest(request, _rules);
    } catch (e, stackTrace) {
      _logger.err('Error handling request: $e');
      _logger.detail('Stack trace: $stackTrace');
      return Response.internalServerError(
        body: 'Internal server error',
      );
    }
  }

  /// Creates logging middleware
  Middleware _loggingMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final startTime = DateTime.now();
        final response = await innerHandler(request);
        final duration = DateTime.now().difference(startTime);
        
        final statusColor = _getStatusColor(response.statusCode);
        _logger.info(
          '${request.method} ${request.url.path} - '
          '${statusColor.wrap(response.statusCode.toString())} '
          '(${duration.inMilliseconds}ms)',
        );
        
        return response;
      };
    };
  }

  /// Creates CORS middleware
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  /// CORS headers
  Map<String, String> get _corsHeaders => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, PATCH, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  /// Gets color for HTTP status code
  AnsiCode _getStatusColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return lightGreen;
    } else if (statusCode >= 300 && statusCode < 400) {
      return lightYellow;
    } else if (statusCode >= 400 && statusCode < 500) {
      return lightRed;
    } else {
      return red;
    }
  }

  /// Starts watching for configuration file changes
  Future<void> _startWatching() async {
    _logger.info('Watching for configuration changes...');
    
    final configFile = File(_configPath);
    final configDir = Directory(_configPath);
    
    Stream<FileSystemEvent> events;
    
    if (await configFile.exists()) {
      events = configFile.watch();
    } else if (await configDir.exists()) {
      events = configDir.watch(recursive: true);
    } else {
      _logger.warn('Cannot watch non-existent path: $_configPath');
      return;
    }
    
    _watchSubscription = events.listen(_onConfigChange);
  }

  /// Handles configuration file changes with debouncing
  void _onConfigChange(FileSystemEvent event) {
    if (event.type == FileSystemEvent.delete) {
      return;
    }
    
    // Cancel any existing timer
    _reloadDebounceTimer?.cancel();
    
    // Start a new debounced reload
    _reloadDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _logger.info('Configuration changed, reloading...');
      _reloadConfiguration();
    });
  }

  /// Reloads configuration from files
  Future<void> _reloadConfiguration() async {
    try {
      final newRules = await _configLoader.loadRules(_configPath);
      _rules = newRules;
      _logger.info('Reloaded ${_rules.length} rule(s)');
    } catch (e) {
      _logger.err('Failed to reload configuration: $e');
    }
  }
}