import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:popshop/src/server/popshop_server.dart';
import 'package:popshop/src/services/config_loader.dart';

/// {@template serve_command}
///
/// `popshop serve`
/// A [Command] to start the PopShop HTTP server
/// {@endtemplate}
class ServeCommand extends Command<int> {
  /// {@macro serve_command}
  ServeCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'port',
        abbr: 'p',
        help: 'Port to run the server on',
        defaultsTo: '8080',
      )
      ..addOption(
        'host',
        help: 'Host to bind the server to',
        defaultsTo: 'localhost',
      )
      ..addOption(
        'config',
        abbr: 'c',
        help: 'Path to YAML configuration file or directory',
        defaultsTo: '.',
      )
      ..addFlag(
        'watch',
        abbr: 'w',
        help: 'Watch for changes and reload configuration',
        negatable: false,
      );
  }

  @override
  String get description => 'Start the PopShop HTTP server';

  @override
  String get name => 'serve';

  final Logger _logger;

  @override
  Future<int> run() async {
    final port = int.tryParse(argResults?['port'] as String? ?? '8080') ?? 8080;
    final host = argResults?['host'] as String? ?? 'localhost';
    final configPath = argResults?['config'] as String? ?? '.';
    final watch = argResults?['watch'] as bool? ?? false;

    _logger.info('Starting PopShop server...');
    _logger.info('Host: $host');
    _logger.info('Port: $port');
    _logger.info('Config: $configPath');

    try {
      final configLoader = ConfigLoader(logger: _logger);
      final rules = await configLoader.loadRules(configPath);

      _logger.info('Loaded ${rules.length} rule(s)');

      final server = PopshopServer(
        logger: _logger,
        rules: rules,
        configLoader: configLoader,
        configPath: configPath,
        watchMode: watch,
      );

      await server.start(host: host, port: port);

      // Keep the server running
      _logger.info('Server started at http://$host:$port');
      _logger.info('Press Ctrl+C to stop the server');

      // Listen for SIGINT (Ctrl+C) to gracefully shutdown
      ProcessSignal.sigint.watch().listen((_) async {
        _logger.info('Shutting down server...');
        await server.stop();
        exit(0);
      });

      // Keep the process alive
      while (true) {
        await Future.delayed(const Duration(seconds: 1));
      }
    } on FileSystemException catch (e) {
      _logger.err('Configuration error: ${e.message}');
      return ExitCode.ioError.code;
    } on FormatException catch (e) {
      _logger.err('YAML parsing error: ${e.message}');
      return ExitCode.data.code;
    } catch (e) {
      _logger.err('Server error: $e');
      return ExitCode.software.code;
    }
  }
}