import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_token_store.dart';

class ListingsService {
  Map<String, String> _authHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{};
    final token = AuthTokenStore.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Future<List<dynamic>> fetchListings() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.apiBaseUrl}/listings'),
      headers: _authHeaders(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load listings: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> fetchListing(String id) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.apiBaseUrl}/listings/$id'),
      headers: _authHeaders(),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load listing: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> createListing(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.apiBaseUrl}/listings'),
      headers: _authHeaders(extra: {'Content-Type': 'application/json'}),
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create listing: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> updateListing(String id, Map<String, dynamic> payload) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.apiBaseUrl}/listings/$id'),
      headers: _authHeaders(extra: {'Content-Type': 'application/json'}),
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update listing: ${res.statusCode}');
  }

  Future<void> deleteListing(String id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.apiBaseUrl}/listings/$id'),
      headers: _authHeaders(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to delete listing: ${res.statusCode}');
    }
  }

  Future<void> uploadImage(String listingId, String filePath) async {
    final req = http.MultipartRequest('POST', Uri.parse('${ApiConfig.apiBaseUrl}/listings/$listingId/images'));
    final token = AuthTokenStore.token;
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(await http.MultipartFile.fromPath('images', filePath));
    final streamed = await req.send();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Failed to upload image: ${streamed.statusCode}');
    }
  }
}
