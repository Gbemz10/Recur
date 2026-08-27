import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A canned backend for widget tests, installed with
/// `HttpOverrides.runZoned(..., createHttpClient: (_) => FakeHttpClient(...))`.
///
/// The app talks to the network through one lazily-created global
/// `apiClient`, so there is no constructor to hand a stub to — this replaces
/// the dart:io client underneath `package:http` instead, which is the one
/// seam that reaches it without changing production code.

/// How long a write takes to answer. Read at request time rather than
/// captured per client, because the first test's HttpClient is the one every
/// later test's requests go through — see the note above.
Duration fakeWriteDelay = Duration.zero;

/// Canned GET responses by path, e.g. `{'/trials': {'trialReminders': []}}`.
///
/// Top-level and mutable for the same reason as [fakeWriteDelay], and it is a
/// sharper trap here. `apiClient` is a lazily-created global that builds its
/// `http.Client` once, so `createHttpClient` runs for the *first* test only —
/// every later test's requests go through that first FakeHttpClient. A map
/// passed to a second constructor is silently never consulted, which reads as
/// the app failing to parse a fixture that is in fact correct.
///
/// So tests set this, rather than constructing a client with their responses.
Map<String, Map<String, dynamic>> fakeResponses = {};

/// Replaces the canned responses for the test about to run.
void setFakeResponses(Map<String, Map<String, dynamic>> responses) {
  fakeResponses = responses;
}

/// The API client reaches the keychain for the device id and access token
/// before every request. There is no plugin behind that channel in a test, so
/// without this the call fails long before HTTP is involved.
void stubSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    return switch (call.method) {
      'read' => 'test-value',
      'readAll' => <String, String>{},
      _ => null,
    };
  });
}

/// A dart:io client that answers every request from memory. `package:http`
/// wraps whatever `HttpOverrides.createHttpClient` returns, so this is the
/// one seam that reaches ApiClient without changing it: GET returns the seed
/// list, and the status PATCH just succeeds, which is all this test asks of
/// the network.
class FakeHttpClient implements HttpClient {
  /// Seeds [fakeResponses] as a convenience for the first test; every later
  /// test must call [setFakeResponses], since this constructor will not run
  /// again — see the note on [fakeResponses].
  FakeHttpClient([Map<String, Map<String, dynamic>>? seed]) {
    if (seed != null) fakeResponses = seed;
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final canned = method == 'GET' ? fakeResponses[url.path] : null;
    return FakeRequest(method, url, jsonEncode(canned ?? const {}),
        isWrite: canned == null);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRequest implements HttpClientRequest {
  FakeRequest(this.method, this.uri, this._body, {this.isWrite = false});

  final bool isWrite;

  @override
  final String method;
  @override
  final Uri uri;
  final String _body;

  @override
  final HttpHeaders headers = FakeHeaders();

  @override
  Encoding encoding = utf8;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  void add(List<int> data) {}

  @override
  void write(Object? object) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Future<HttpClientResponse> close() async {
    if (isWrite && fakeWriteDelay > Duration.zero) {
      await Future<void>.delayed(fakeWriteDelay);
    }
    return FakeResponse(_body);
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  Future<void> flush() async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  FakeResponse(this._body);

  final String _body;

  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => utf8.encode(_body).length;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => true;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = FakeHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(utf8.encode(_body)).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHeaders implements HttpHeaders {
  final _values = <String, List<String>>{};

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _values[name.toLowerCase()] = ['$value'];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _values.putIfAbsent(name.toLowerCase(), () => []).add('$value');

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _values.forEach(action);

  @override
  ContentType? get contentType => ContentType.json;

  @override
  int get contentLength => -1;

  @override
  set contentLength(int value) {}

  @override
  bool get chunkedTransferEncoding => false;

  @override
  set chunkedTransferEncoding(bool value) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
