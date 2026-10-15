import 'package:mbongiseni_nkambule_apt_application/data/store.dart';

class MemoryStorage implements DataStorage {
  String? data;
  bool failWrites = false;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('Storage unavailable');
    data = value;
  }
}
