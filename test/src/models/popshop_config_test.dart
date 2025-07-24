import 'package:popshop/src/models/popshop_config.dart';
import 'package:test/test.dart';

void main() {
  group('PopshopRequest', () {
    test('creates from map correctly', () {
      final map = {
        'path': '/users/1',
        'verb': 'get',
        'headers': {'authorization': 'Bearer token'},
        'body': '{"test": true}',
      };

      final request = PopshopRequest.fromMap(map);

      expect(request.path, equals('/users/1'));
      expect(request.verb, equals('get'));
      expect(request.method, equals('GET'));
      expect(request.headers, equals({'authorization': 'Bearer token'}));
      expect(request.body, equals('{"test": true}'));
    });

    test('creates from minimal map', () {
      final map = {
        'path': '/users',
        'verb': 'post',
      };

      final request = PopshopRequest.fromMap(map);

      expect(request.path, equals('/users'));
      expect(request.verb, equals('post'));
      expect(request.method, equals('POST'));
      expect(request.headers, isNull);
      expect(request.body, isNull);
    });
  });

  group('PopshopResponse', () {
    test('creates from map correctly', () {
      final map = {
        'body': '{"id": 1, "name": "Brad"}',
        'status': 201,
        'headers': {'content-type': 'application/json'},
      };

      final response = PopshopResponse.fromMap(map);

      expect(response.body, equals('{"id": 1, "name": "Brad"}'));
      expect(response.status, equals(201));
      expect(response.headers, equals({'content-type': 'application/json'}));
    });

    test('defaults status to 200', () {
      final map = {
        'body': 'OK',
      };

      final response = PopshopResponse.fromMap(map);

      expect(response.body, equals('OK'));
      expect(response.status, equals(200));
      expect(response.headers, isNull);
    });
  });

  group('PopshopProxy', () {
    test('creates from map correctly', () {
      final map = {
        'url': 'https://api.example.com/users',
        'verb': 'post',
        'headers': {'x-api-key': 'secret'},
      };

      final proxy = PopshopProxy.fromMap(map);

      expect(proxy.url, equals('https://api.example.com/users'));
      expect(proxy.verb, equals('post'));
      expect(proxy.headers, equals({'x-api-key': 'secret'}));
    });

    test('getMethod returns verb or fallback', () {
      final proxyWithVerb = PopshopProxy.fromMap({
        'url': 'https://api.example.com',
        'verb': 'put',
      });

      final proxyWithoutVerb = PopshopProxy.fromMap({
        'url': 'https://api.example.com',
      });

      expect(proxyWithVerb.getMethod('GET'), equals('PUT'));
      expect(proxyWithoutVerb.getMethod('POST'), equals('POST'));
    });
  });

  group('PopshopRule', () {
    test('creates mock rule from map', () {
      final map = {
        'request': {
          'path': '/users/1',
          'verb': 'get',
        },
        'response': {
          'body': '{"id": 1}',
          'status': 200,
        },
      };

      final rule = PopshopRule.fromMap(map);

      expect(rule.request.path, equals('/users/1'));
      expect(rule.isMock, isTrue);
      expect(rule.isProxy, isFalse);
      expect(rule.response?.body, equals('{"id": 1}'));
    });

    test('creates proxy rule from map', () {
      final map = {
        'request': {
          'path': '/readme',
          'verb': 'get',
        },
        'proxy': {
          'url': 'https://raw.githubusercontent.com/example/repo/main/README.md',
        },
      };

      final rule = PopshopRule.fromMap(map);

      expect(rule.request.path, equals('/readme'));
      expect(rule.isMock, isFalse);
      expect(rule.isProxy, isTrue);
      expect(rule.proxy?.url, contains('README.md'));
    });

    test('throws when neither response nor proxy provided', () {
      expect(
        () => PopshopRule(
          request: PopshopRequest.fromMap({
            'path': '/test',
            'verb': 'get',
          }),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}