import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mobile_project/core/session/session_store.dart';

typedef FakeHandler = Future<ResponseBody> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final FakeHandler handler;
  final List<RequestOptions> requests = [];

  int count(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

class MemorySessionStore implements SessionStore {
  MemorySessionStore({this.access, this.refresh});
  String? access;
  String? refresh;

  @override
  Future<String?> readAccess() async => access;
  @override
  Future<String?> readRefresh() async => refresh;
  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

const meJson = {
  'id': 'u1',
  'name': 'Awa Koné',
  'phone': '+2250707070707',
  'whatsappPhone': null,
  'avatarUrl': null,
  'isSeller': false,
  'createdAt': '2026-11-05T10:00:00.000Z',
};
