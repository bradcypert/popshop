import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  print('Testing PopShop server functionality...\n');

  // Start server in background
  final serverProcess = await Process.start(
    'dart',
    ['run', 'bin/popshop.dart', 'serve', '--config', 'examples/api.yaml', '--port', '8084'],
  );

  // Wait for server to start
  await Future.delayed(const Duration(seconds: 5));
  
  // Check if server is responding
  var attempts = 0;
  while (attempts < 10) {
    try {
      await http.get(Uri.parse('http://localhost:8084/api/health'));
      break;
    } catch (e) {
      attempts++;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  try {
    // Test health endpoint
    print('Testing /api/health...');
    final healthResponse = await http.get(Uri.parse('http://localhost:8084/api/health'));
    print('Status: ${healthResponse.statusCode}');
    print('Body: ${healthResponse.body}\n');

    // Test users endpoint
    print('Testing /api/users...');
    final usersResponse = await http.get(Uri.parse('http://localhost:8084/api/users'));
    print('Status: ${usersResponse.statusCode}');
    print('Body: ${usersResponse.body}\n');

    // Test POST to users
    print('Testing POST /api/users...');
    final postResponse = await http.post(
      Uri.parse('http://localhost:8084/api/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': 'Test User'}),
    );
    print('Status: ${postResponse.statusCode}');
    print('Body: ${postResponse.body}\n');

    // Test proxy endpoint
    print('Testing /api/external (proxy)...');
    final proxyResponse = await http.get(Uri.parse('http://localhost:8084/api/external'));
    print('Status: ${proxyResponse.statusCode}');
    print('Body length: ${proxyResponse.body.length} characters\n');

    // Test non-existent endpoint
    print('Testing /api/nonexistent...');
    final notFoundResponse = await http.get(Uri.parse('http://localhost:8084/api/nonexistent'));
    print('Status: ${notFoundResponse.statusCode}');
    print('Body: ${notFoundResponse.body}\n');

    print('All tests completed successfully!');
  } catch (e) {
    print('Error during testing: $e');
  } finally {
    // Kill the server
    serverProcess.kill();
    await serverProcess.exitCode;
  }
}