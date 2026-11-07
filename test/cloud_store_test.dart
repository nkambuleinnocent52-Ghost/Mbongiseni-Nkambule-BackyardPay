import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mbongiseni_nkambule_apt_application/data/cloud_gateway.dart';
import 'package:mbongiseni_nkambule_apt_application/data/store.dart';
import 'package:mbongiseni_nkambule_apt_application/models/models.dart';

import 'test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late AppStore store;
  late MemoryStorage storage;
  late List<http.Request> requests;
  bool confirmationRequired = false, failSnapshot = false;
  String serverRole = 'landlord';
  Map<String, dynamic> user() => {
    'id': '11111111-1111-4111-8111-111111111111',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'owner@example.test',
    'app_metadata': {'provider': 'email'},
    'user_metadata': {},
    'created_at': '2026-01-01T00:00:00Z',
  };
  Map<String, dynamic> snapshot() => {
    ...CloudGateway.emptySnapshot,
    'session': user()['id'],
    'accounts': [
      {
        'id': user()['id'],
        'name': 'Owner',
        'phone': '0711234567',
        'email': 'owner@example.test',
        'role': serverRole,
        'salt': '',
        'passwordHash': '',
      },
    ],
  };
  setUp(() {
    requests = [];
    confirmationRequired = false;
    failSnapshot = false;
    serverRole = 'landlord';
    storage = MemoryStorage()
      ..data = 'old browser records must not be uploaded';
    client = SupabaseClient(
      'https://test.example',
      'public-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: TestPkceStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/signup') && confirmationRequired)
          return http.Response(
            jsonEncode({'user': user(), 'session': null}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        if (path.endsWith('/token') || path.endsWith('/signup')) {
          final jwt =
              '${base64Url.encode(utf8.encode('{"alg":"HS256"}')).replaceAll('=', '')}.${base64Url.encode(utf8.encode(jsonEncode({'sub': user()['id'], 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}))).replaceAll('=', '')}.test';
          return http.Response(
            jsonEncode({
              'access_token': jwt,
              'refresh_token': 'test-only',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': user(),
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/bp_tenant_signup_mode'))
          return http.Response(
            jsonEncode('invitation_only'),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        if (path.endsWith('/bp_snapshot')) {
          if (failSnapshot)
            return http.Response(
              '{"message":"offline","code":"TEST"}',
              400,
              request: request,
            );
          return http.Response(
            jsonEncode(snapshot()),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/bp_action'))
          return http.Response(
            '{"result":"property-id"}',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        return http.Response(
          '{}',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    store = AppStore(storage, cloud: CloudGateway(client));
  });
  tearDown(() async {
    store.dispose();
    await client.dispose();
  });
  test(
    'cloud load ignores old local accounts and cloud signup uses Auth',
    () async {
      await store.load();
      expect(store.currentUser, isNull);
      expect(requests, isEmpty);
      await store.register(
        name: 'Owner',
        email: 'owner@example.test',
        phone: '0711234567',
        password: 'UniquePassword123!',
        role: Role.landlord,
      );
      expect(store.currentUser?.role, Role.landlord);
      final signup = requests.singleWhere(
        (r) => r.url.path.endsWith('/signup'),
      );
      expect(jsonDecode(signup.body)['data']['role'], 'landlord');
      expect(requests.where((r) => r.url.path.endsWith('/bp_action')), isEmpty);
      expect(storage.data, 'old browser records must not be uploaded');
      expect(jsonEncode(snapshot()), isNot(contains('UniquePassword123!')));
    },
  );
  test(
    'email confirmation leaves user signed out with a clear next step',
    () async {
      confirmationRequired = true;
      await expectLater(
        store.register(
          name: 'Owner',
          email: 'owner@example.test',
          phone: '0711234567',
          password: 'UniquePassword123!',
          role: Role.landlord,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Check your email'),
          ),
        ),
      );
      expect(store.currentUser, isNull);
    },
  );
  test(
    'cloud mutation calls a checked server command then fetches scoped records',
    () async {
      await store.login(
        'owner@example.test',
        'UniquePassword123!',
        Role.landlord,
      );
      final id = await store.saveProperty(
        name: 'My Rooms',
        address: '1 First Street',
        rooms: 2,
        rentCents: 150000,
        dueDay: 1,
      );
      expect(id, 'property-id');
      final command = jsonDecode(
        requests.singleWhere((r) => r.url.path.endsWith('/bp_action')).body,
      );
      expect(command['operation'], 'property');
      expect(command['args']['rentCents'], 150000);
      expect(requests.last.url.path, endsWith('/bp_snapshot'));
      expect(storage.data, 'old browser records must not be uploaded');
    },
  );
  test(
    'a role mismatch signs out rather than opening the wrong workspace',
    () async {
      serverRole = 'tenant';
      await expectLater(
        store.login('owner@example.test', 'UniquePassword123!', Role.landlord),
        throwsStateError,
      );
      expect(store.currentUser, isNull);
      expect(client.auth.currentSession, isNull);
    },
  );
  test(
    'successful save followed by failed refresh is not silently retried',
    () async {
      await store.login(
        'owner@example.test',
        'UniquePassword123!',
        Role.landlord,
      );
      failSnapshot = true;
      await expectLater(
        store.saveProperty(
          name: 'My Rooms',
          address: '1 First Street',
          rooms: 2,
          rentCents: 150000,
          dueDay: 1,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('was saved'),
          ),
        ),
      );
      expect(
        requests.where((r) => r.url.path.endsWith('/bp_action')).length,
        1,
      );
    },
  );
  test(
    'password recovery uses Supabase Auth, logout clears loaded records',
    () async {
      await store.login(
        'owner@example.test',
        'UniquePassword123!',
        Role.landlord,
      );
      await store.resetPassword('owner@example.test');
      expect(requests.any((r) => r.url.path.endsWith('/recover')), isTrue);
      await store.logout();
      expect(store.currentUser, isNull);
      expect(storage.data, 'old browser records must not be uploaded');
    },
  );
  test(
    'cloud tenant signup sends a private invitation and no room selection',
    () async {
      serverRole = 'tenant';
      await store.register(
        name: 'Tenant',
        email: 'tenant@example.test',
        phone: '0711234567',
        password: 'UniquePassword123!',
        role: Role.tenant,
        code: 'JOIN-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      );
      final data = jsonDecode(
        requests.singleWhere((r) => r.url.path.endsWith('/signup')).body,
      )['data'];
      expect(data['code'], 'JOIN-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA');
      expect(data.containsKey('room'), false);
      expect(
        requests.any((r) => r.url.path.endsWith('/bp_tenant_signup_mode')),
        true,
      );
    },
  );
  test(
    'cloud property codes and client room choices are rejected before signup',
    () async {
      await expectLater(
        store.register(
          name: 'Tenant',
          email: 'tenant@example.test',
          phone: '0711234567',
          password: 'UniquePassword123!',
          role: Role.tenant,
          code: 'BP-PUBLIC',
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.register(
          name: 'Tenant',
          email: 'tenant@example.test',
          phone: '0711234567',
          password: 'UniquePassword123!',
          role: Role.tenant,
          code: 'JOIN-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          room: '10',
        ),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    },
  );
}

class TestPkceStorage extends GotrueAsyncStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}
