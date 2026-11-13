import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication belongs to Supabase Auth; passwords never enter rental records.
class CloudGateway {
  final SupabaseClient client;
  CloudGateway(this.client);
  Future<Map<String, dynamic>> snapshot() async {
    if (client.auth.currentSession == null) return emptySnapshot;
    final data = Map<String, dynamic>.from(await client.rpc('bp_snapshot'));
    if (data['researchVersion'] != 2)
      throw StateError(
        'Run the Research Update SQL in Supabase before using this version. Existing records have not been erased.',
      );
    if (data['prorationVersion'] != 1)
      throw StateError(
        'Run BackyardPay-Proration-Update.sql in Supabase before using this update. Existing rental balances have been preserved.',
      );
    if (data['depositReportsVersion'] != 1)
      throw StateError(
        'Run BackyardPay-Deposit-Reports-Update.sql before using this version. Existing records are preserved.',
      );
    final loginId = data['currentLoginId'];
    if (data['loginIdsEnabled'] == true &&
        loginId is String &&
        RegExp(r'^[1-9][0-9]{8}$').hasMatch(loginId)) {
      data['accounts'] = [
        for (final account in data['accounts'] as List)
          {
            ...Map<String, dynamic>.from(account),
            if (account['id'] == data['session']) 'loginId': loginId,
          },
      ];
    }
    return data;
  }

  Future<Map<String, dynamic>> action(
    String operation,
    Map<String, dynamic> args,
  ) async {
    final response = Map<String, dynamic>.from(
      await client.rpc(
        'bp_action',
        params: {'operation': operation, 'args': args},
      ),
    );
    try {
      response['snapshot'] = await snapshot();
    } catch (_) {
      throw StateError(
        'Your change was saved, but updated records could not be loaded. Refresh before trying again.',
      );
    }
    return response;
  }

  /// Optional alias sign-in is hidden until both SQL and the server endpoint work.
  Future<bool> loginIdsAvailable() async {
    try {
      if (await client.rpc('bp_login_id_enabled') != true) return false;
      final status = await client.functions.invoke(
        'login-with-id',
        method: HttpMethod.get,
      );
      return status.status == 200 &&
          status.data is Map &&
          status.data['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signInWithLoginId(String id, String password) async {
    if (!await loginIdsAvailable())
      throw ArgumentError(
        'Login ID sign-in is not available yet. Use your email and password.',
      );
    try {
      final response = await client.functions.invoke(
        'login-with-id',
        body: {'loginId': id, 'password': password},
      );
      final token = response.data is Map
          ? response.data['refresh_token']
          : null;
      if (response.status != 200 || token is! String)
        throw StateError('Invalid sign-in response.');
      await client.auth.setSession(token);
    } catch (_) {
      throw ArgumentError(
        'The Login ID or password is incorrect, or sign-in is temporarily unavailable. Use your email or try again later.',
      );
    }
  }

  static Map<String, dynamic> get emptySnapshot => {
    'version': 1,
    'researchVersion': 2,
    'prorationVersion': 1,
    'depositReportsVersion': 1,
    'rentTerms': [],
    'caseRecords': [],
    'session': null,
    'accounts': [],
    'properties': [],
    'tenancies': [],
    'payments': [],
    'notices': [],
  };
}
