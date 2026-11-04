import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_token_store.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.apiBaseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token != null) AuthTokenStore.setToken(token);
      return data;
    }
    throw Exception('Login failed: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> register(String email, String password, String role) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.apiBaseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'role': role}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token != null) AuthTokenStore.setToken(token);
      return data;
    }
    throw Exception('Register failed: ${res.statusCode}');
  }
}