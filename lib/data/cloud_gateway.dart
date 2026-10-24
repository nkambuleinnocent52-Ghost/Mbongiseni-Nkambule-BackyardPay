import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication belongs to Supabase Auth; passwords never enter rental records.
class CloudGateway {
  final SupabaseClient client;
  CloudGateway(this.client);
  Future<Map<String, dynamic>> snapshot() async {
    if (client.auth.currentSession == null) return emptySnapshot;
    return Map<String, dynamic>.from(await client.rpc('bp_snapshot'));
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

  static Map<String, dynamic> get emptySnapshot => {
    'version': 1,
    'session': null,
    'accounts': [],
    'properties': [],
    'tenancies': [],
    'payments': [],
    'notices': [],
  };
}
