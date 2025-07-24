import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:popshop/src/commands/serve_command.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  group('ServeCommand', () {
    late Logger logger;
    late ServeCommand command;

    setUp(() {
      logger = MockLogger();
      command = ServeCommand(logger: logger);
    });

    test('should have correct name and description', () {
      expect(command.name, equals('serve'));
      expect(command.description, equals('Start the PopShop HTTP server'));
    });

    test('should accept port option', () {
      expect(command.argParser.options.containsKey('port'), isTrue);
      expect(command.argParser.options['port']?.defaultsTo, equals('8080'));
    });

    test('should accept host option', () {
      expect(command.argParser.options.containsKey('host'), isTrue);
      expect(command.argParser.options['host']?.defaultsTo, equals('localhost'));
    });

    test('should accept config option', () {
      expect(command.argParser.options.containsKey('config'), isTrue);
      expect(command.argParser.options['config']?.defaultsTo, equals('.'));
    });

    test('should accept watch flag', () {
      expect(command.argParser.options.containsKey('watch'), isTrue);
      expect(command.argParser.options['watch']?.isFlag, isTrue);
    });
  });
}