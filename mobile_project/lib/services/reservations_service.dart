import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_token_store.dart';

class ReservationsService {
  Map<String, String> _authHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{};
    final token = AuthTokenStore.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Future<List<dynamic>> fetchReservations() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.apiBaseUrl}/reservations'),
      headers: _authHeaders(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load reservations: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> fetchReservation(String id) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.apiBaseUrl}/reservations/$id'),
      headers: _authHeaders(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load reservation: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> createReservation(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.apiBaseUrl}/reservations'),
      headers: _authHeaders(extra: {'Content-Type': 'application/json'}),
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create reservation: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> updateReservation(String id, Map<String, dynamic> payload) async {
    final res = await http.patch(
      Uri.parse('${ApiConfig.apiBaseUrl}/reservations/$id'),
      headers: _authHeaders(extra: {'Content-Type': 'application/json'}),
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update reservation: ${res.statusCode}');
  }
}
