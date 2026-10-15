import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

abstract interface class DataStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesStorage implements DataStorage {
  static const key = 'backyardpay_v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Could not save your changes. Please try again.');
    }
  }
}

class AppStore extends ChangeNotifier {
  final DataStorage storage;
  AppStore(this.storage);
  List<Account> _accounts = [];
  List<RentalProperty> _properties = [];
  List<Tenancy> _tenancies = [];
  List<RentPayment> _payments = [];
  List<AppNotice> _notices = [];
  String? _session;
  bool _writing = false;
  bool get isBusy => _writing;
  Account? get currentUser =>
      _accounts.where((a) => a.id == _session).firstOrNull;
  bool get hasAccounts => _accounts.isNotEmpty;
  static const _uuid = Uuid();
  static final _hash = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  Future<void> load() async {
    final raw = await storage.read();
    if (raw != null) _restore(raw);
    notifyListeners();
  }

  String _snapshot() => jsonEncode({
    'version': 1,
    'session': _session,
    'accounts': _accounts.map((a) => a.toJson()).toList(),
    'properties': _properties.map((a) => a.toJson()).toList(),
    'tenancies': _tenancies.map((a) => a.toJson()).toList(),
    'payments': _payments.map((a) => a.toJson()).toList(),
    'notices': _notices.map((a) => a.toJson()).toList(),
  });
  void _restore(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['version'] != 1) throw StateError('Unsupported saved data version.');
    _accounts = (j['accounts'] as List)
        .map((a) => Account.fromJson(a))
        .toList();
    _properties = (j['properties'] as List)
        .map((a) => RentalProperty.fromJson(a))
        .toList();
    _tenancies = (j['tenancies'] as List)
        .map((a) => Tenancy.fromJson(a))
        .toList();
    _payments = (j['payments'] as List)
        .map((a) => RentPayment.fromJson(a))
        .toList();
    _notices = (j['notices'] as List)
        .map((a) => AppNotice.fromJson(a))
        .toList();
    _session = j['session'];
  }

  // Serialize writes and restore the previous state if persistent storage fails.
  Future<T> _transaction<T>(T Function() change) async {
    if (_writing)
      throw StateError('Another change is saving. Please try again.');
    final before = _snapshot();
    _writing = true;
    try {
      final result = change();
      await storage.write(_snapshot());
      notifyListeners();
      return result;
    } catch (_) {
      _restore(before);
      rethrow;
    } finally {
      _writing = false;
    }
  }

  Account _user([Role? role]) {
    final a = currentUser;
    if (a == null || (role != null && a.role != role))
      throw StateError('You do not have access to this action.');
    return a;
  }

  Future<String> _password(String password, String salt) async => base64Encode(
    await (await _hash.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: base64Decode(salt),
    )).extractBytes(),
  );
  String _salt() =>
      base64Encode(List.generate(16, (_) => Random.secure().nextInt(256)));
  bool _equal(String a, String b) {
    final x = utf8.encode(a), y = utf8.encode(b);
    var difference = x.length ^ y.length;
    for (var i = 0; i < min(x.length, y.length); i++) {
      difference |= x[i] ^ y[i];
    }
    return difference == 0;
  }

  void _identity(String name, String email, String phone) {
    if (name.trim().length < 2 || name.trim().length > 80) {
      throw ArgumentError('Use a full name between 2 and 80 characters.');
    }
    if (email.trim().length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim()))
      throw ArgumentError('Enter a valid email address.');
    if (!RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(phone.trim()))
      throw ArgumentError('Enter a valid phone number.');
  }

  void _passwordRules(String password) {
    if (password.length < 8)
      throw ArgumentError('Use a password with at least 8 characters.');
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required Role role,
    String code = '',
    String room = '',
  }) async {
    _identity(name, email, phone);
    _passwordRules(password);
    final normalized = email.trim().toLowerCase();
    final salt = _salt();
    // Use the same random salt for both derivation and the stored credential.
    final actualHash = await _password(password, salt);
    await _transaction(() {
      if (_accounts.any((a) => a.email == normalized))
        throw ArgumentError('This email is already registered.');
      RentalProperty? property;
      if (role == Role.tenant) {
        property = _properties
            .where((p) => p.code == code.trim().toUpperCase())
            .firstOrNull;
        if (property == null)
          throw ArgumentError('Ask your landlord for a valid property code.');
        _checkRoom(property, room);
      }
      final account = Account(
        id: _uuid.v4(),
        name: name.trim(),
        phone: phone.trim(),
        email: normalized,
        salt: salt,
        passwordHash: actualHash,
        role: role,
      );
      _accounts.add(account);
      if (property != null) {
        _tenancies.add(
          Tenancy(
            id: _uuid.v4(),
            userId: account.id,
            propertyId: property.id,
            room: room.trim(),
            startPeriod: periodOf(DateTime.now()),
            rentCents: property.rentCents,
            dueDay: property.dueDay,
          ),
        );
        _notice(
          property.landlordId,
          'New tenant',
          '${account.name} joined ${property.name}, room ${room.trim()}.',
        );
      }
      _session = account.id;
    });
  }

  void _checkRoom(RentalProperty p, String room) {
    final number = int.tryParse(room.trim());
    if (number == null || number < 1 || number > p.rooms)
      throw ArgumentError('Choose a room number from 1 to ${p.rooms}.');
    if (_tenancies.any(
      (t) => t.propertyId == p.id && t.room == number.toString(),
    ))
      throw ArgumentError('That room already has a tenant.');
    if (room.trim() != number.toString())
      throw ArgumentError('Use a room number without leading zeros.');
  }

  Future<void> login(String email, String password, Role role) async {
    final account = _accounts
        .where((a) => a.email == email.trim().toLowerCase() && a.role == role)
        .firstOrNull;
    if (account == null ||
        !_equal(
          await _password(password, account.salt),
          account.passwordHash,
        )) {
      throw ArgumentError('The email, password or selected role is incorrect.');
    }
    await _transaction(() => _session = account.id);
  }

  Future<void> logout() async => _transaction(() {
    _session = null;
  });
  Future<void> updateProfile(String name, String phone) async {
    final a = _user();
    _identity(name, a.email, phone);
    await _transaction(() {
      _accounts[_accounts.indexOf(a)] = Account(
        id: a.id,
        name: name.trim(),
        email: a.email,
        phone: phone.trim(),
        salt: a.salt,
        passwordHash: a.passwordHash,
        role: a.role,
      );
    });
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final a = _user();
    _passwordRules(newPassword);
    if (!_equal(await _password(oldPassword, a.salt), a.passwordHash))
      throw ArgumentError('Current password is incorrect.');
    final salt = _salt();
    final actualHash = await _password(newPassword, salt);
    await _transaction(() {
      if (_user().id != a.id)
        throw StateError('Your session changed. Sign in again.');
      _accounts[_accounts.indexOf(a)] = Account(
        id: a.id,
        name: a.name,
        email: a.email,
        phone: a.phone,
        salt: salt,
        passwordHash: actualHash,
        role: a.role,
      );
    });
  }

  List<RentalProperty> get properties {
    final a = _user();
    return List.unmodifiable(
      _properties.where(
        (p) => a.role == Role.landlord
            ? p.landlordId == a.id
            : _tenancies.any((t) => t.userId == a.id && t.propertyId == p.id),
      ),
    );
  }

  List<Tenancy> get tenancies {
    final a = _user();
    return List.unmodifiable(
      _tenancies.where(
        (t) => a.role == Role.tenant
            ? t.userId == a.id
            : _properties.any(
                (p) => p.id == t.propertyId && p.landlordId == a.id,
              ),
      ),
    );
  }

  Tenancy tenancy(String id) => tenancies.firstWhere(
    (t) => t.id == id,
    orElse: () => throw StateError('You do not have access to this tenancy.'),
  );
  RentalProperty property(String id) => properties.firstWhere(
    (p) => p.id == id,
    orElse: () => throw StateError('You do not have access to this property.'),
  );
  Account tenantAccount(Tenancy t) {
    tenancy(t.id);
    return _accounts.firstWhere((a) => a.id == t.userId);
  }

  List<RentPayment> get payments {
    final ids = tenancies.map((t) => t.id).toSet();
    return List.unmodifiable(
      _payments.where((p) => ids.contains(p.tenancyId)).toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt)),
    );
  }

  RentPayment payment(String id) => payments.firstWhere(
    (p) => p.id == id,
    orElse: () => throw StateError('You do not have access to this payment.'),
  );
  List<AppNotice> get notices {
    final a = _user();
    return List.unmodifiable(
      _notices.where((n) => n.userId == a.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  void _notice(String userId, String title, String message) => _notices.add(
    AppNotice(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      message: message,
      createdAt: DateTime.now(),
    ),
  );
  Future<void> markRead(String id) async => _transaction(() {
    final n = notices.firstWhere((n) => n.id == id);
    _notices[_notices.indexOf(n)] = AppNotice(
      id: n.id,
      userId: n.userId,
      title: n.title,
      message: n.message,
      createdAt: n.createdAt,
      read: true,
    );
  });
  Future<String> saveProperty({
    String? id,
    required String name,
    required String address,
    required int rooms,
    required int rentCents,
    required int dueDay,
  }) async {
    final a = _user(Role.landlord);
    if (name.trim().length < 2 ||
        name.trim().length > 100 ||
        address.trim().length < 3 ||
        address.trim().length > 250 ||
        rooms < 1 ||
        rooms > 999 ||
        rentCents <= 0 ||
        dueDay < 1 ||
        dueDay > 28)
      throw ArgumentError('Check the property fields. Due day must be 1–28.');
    return _transaction(() {
      final old = id == null ? null : property(id);
      if (old != null &&
          _tenancies.any(
            (t) => t.propertyId == id && int.parse(t.room) > rooms,
          )) {
        throw ArgumentError('Room count cannot exclude an occupied room.');
      }
      final p = RentalProperty(
        id: old?.id ?? _uuid.v4(),
        landlordId: a.id,
        name: name.trim(),
        address: address.trim(),
        code: old?.code ?? 'BP-${_uuid.v4().substring(0, 8).toUpperCase()}',
        rooms: rooms,
        rentCents: rentCents,
        dueDay: dueDay,
        latitude: old?.latitude,
        longitude: old?.longitude,
      );
      if (old == null) {
        _properties.add(p);
      } else {
        _properties[_properties.indexOf(old)] = p;
      }
      return p.id;
    });
  }

  Future<void> deleteProperty(String id) async {
    _user(Role.landlord);
    final p = property(id);
    if (_tenancies.any((t) => t.propertyId == id))
      throw StateError('A property with tenants cannot be deleted.');
    await _transaction(() => _properties.remove(p));
  }

  Future<void> saveLocation(
    String id,
    double latitude,
    double longitude,
  ) async {
    _user(Role.landlord);
    final p = property(id);
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180)
      throw ArgumentError('Invalid coordinates.');
    await _transaction(() {
      _properties[_properties.indexOf(p)] = RentalProperty(
        id: p.id,
        landlordId: p.landlordId,
        name: p.name,
        address: p.address,
        code: p.code,
        rooms: p.rooms,
        rentCents: p.rentCents,
        dueDay: p.dueDay,
        latitude: latitude,
        longitude: longitude,
      );
    });
  }

  int expected(Tenancy t, String period) {
    tenancy(t.id);
    periodDate(period);
    return period.compareTo(t.startPeriod) < 0 ? 0 : t.rentCents;
  }

  int collected(Tenancy t, String period) => payments
      .where(
        (p) =>
            p.tenancyId == t.id &&
            p.period == period &&
            p.state == ReviewState.confirmed,
      )
      .fold(0, (sum, p) => sum + p.amountCents);
  int outstanding(Tenancy t, String period) =>
      max(0, expected(t, period) - collected(t, period));
  String rentStatus(Tenancy t, String period) {
    final due = expected(t, period), paid = collected(t, period);
    if (due == 0) return 'Not applicable';
    if (paid >= due) return 'Paid';
    return paid > 0 ? 'Partially paid' : 'Outstanding';
  }

  DateTime dueDate(Tenancy t, String period) {
    final month = periodDate(period);
    return DateTime(month.year, month.month, t.dueDay);
  }

  bool isLate(RentPayment p) => DateTime(
    p.paidOn.year,
    p.paidOn.month,
    p.paidOn.day,
  ).isAfter(dueDate(tenancy(p.tenancyId), p.period));
  bool overdue(Tenancy t, String period) =>
      outstanding(t, period) > 0 &&
      DateTime.now().isAfter(dueDate(t, period).add(const Duration(days: 1)));
  Future<String> submitPayment({
    required String tenancyId,
    required String period,
    required int amountCents,
    required String method,
    required DateTime paidOn,
    required String reference,
    String notes = '',
  }) async {
    final a = _user(Role.tenant), t = tenancy(tenancyId);
    if (t.userId != a.id)
      throw StateError('You can only submit your own payments.');
    periodDate(period);
    if (expected(t, period) == 0 ||
        period.compareTo(periodOf(DateTime.now())) > 0) {
      throw ArgumentError(
        'Choose a rent month from your tenancy start through this month.',
      );
    }
    if (amountCents <= 0 ||
        !['Cash', 'EFT', 'PayShap', 'Other'].contains(method) ||
        reference.trim().isEmpty)
      throw ArgumentError('Complete the payment fields.');
    if (reference.trim().length > 80 || notes.trim().length > 500) {
      throw ArgumentError(
        'References may use up to 80 characters and notes up to 500.',
      );
    }
    final today = DateTime.now();
    if (paidOn.isAfter(
          DateTime(today.year, today.month, today.day, 23, 59, 59),
        ) ||
        paidOn.year < 2020)
      throw ArgumentError('Choose a valid payment date, not a future date.');
    return _transaction(() {
      if (_payments.any(
        (p) => p.reference.toLowerCase() == reference.trim().toLowerCase(),
      ))
        throw ArgumentError('That reference has already been used.');
      final committed = _payments
          .where(
            (p) =>
                p.tenancyId == t.id &&
                p.period == period &&
                p.state != ReviewState.rejected,
          )
          .fold(0, (sum, p) => sum + p.amountCents);
      if (committed + amountCents > expected(t, period))
        throw ArgumentError(
          'This exceeds the rent still available after confirmed and pending payments.',
        );
      final p = RentPayment(
        id: _uuid.v4(),
        tenancyId: t.id,
        period: period,
        amountCents: amountCents,
        method: method,
        paidOn: paidOn,
        reference: reference.trim(),
        notes: notes.trim(),
        submittedAt: DateTime.now(),
      );
      _payments.add(p);
      _notice(
        property(t.propertyId).landlordId,
        'Payment awaiting review',
        '${a.name} submitted ${money(amountCents)} for $period.',
      );
      return p.id;
    });
  }

  Future<void> reviewPayment(
    String id, {
    required bool confirm,
    String reason = '',
  }) async {
    _user(Role.landlord);
    await _transaction(() {
      final p = payment(id), t = tenancy(p.tenancyId);
      if (p.state != ReviewState.pending)
        throw StateError('This payment has already been reviewed.');
      if (!confirm && (reason.trim().isEmpty || reason.trim().length > 500))
        throw ArgumentError('Give the tenant a reason for rejection.');
      if (confirm &&
          collected(t, p.period) + p.amountCents > expected(t, p.period))
        throw StateError('Confirming would exceed the rent due.');
      _payments[_payments.indexOf(p)] = RentPayment(
        id: p.id,
        tenancyId: p.tenancyId,
        period: p.period,
        method: p.method,
        reference: p.reference,
        notes: p.notes,
        amountCents: p.amountCents,
        paidOn: p.paidOn,
        submittedAt: p.submittedAt,
        state: confirm ? ReviewState.confirmed : ReviewState.rejected,
        rejectionReason: confirm ? null : reason.trim(),
        reviewedAt: DateTime.now(),
      );
      _notice(
        t.userId,
        confirm ? 'Payment confirmed' : 'Payment rejected',
        '${money(p.amountCents)} for ${p.period}. ${confirm ? 'Your receipt is available in payment history.' : reason.trim()}',
      );
    });
  }

  Future<void> sendReminder(
    String tenancyId,
    String period,
    String message,
  ) async {
    _user(Role.landlord);
    final t = tenancy(tenancyId);
    periodDate(period);
    if (message.trim().isEmpty || message.trim().length > 500)
      throw ArgumentError('Enter a reminder message.');
    await _transaction(
      () => _notice(t.userId, 'Rent reminder • $period', message.trim()),
    );
  }

  String get newReference => 'BP-${_uuid.v4().substring(0, 13).toUpperCase()}';
  Future<void> createDemo() async {
    if (hasAccounts)
      throw StateError('Demo data can only be created in an empty app.');
    final ownerSalt = _salt(), tenantSalt = _salt();
    final ownerHash = await _password('DemoPass123!', ownerSalt);
    final tenantHash = await _password('DemoPass123!', tenantSalt);
    await _transaction(() {
      if (hasAccounts)
        throw StateError('Accounts already exist; no demo data was added.');
      final ownerId = _uuid.v4(),
          tenantId = _uuid.v4(),
          propertyId = _uuid.v4();
      _accounts.addAll([
        Account(
          id: ownerId,
          name: 'Demo Landlord',
          phone: '0710000001',
          email: 'landlord@demo.test',
          salt: ownerSalt,
          passwordHash: ownerHash,
          role: Role.landlord,
        ),
        Account(
          id: tenantId,
          name: 'Demo Tenant',
          phone: '0710000002',
          email: 'tenant@demo.test',
          salt: tenantSalt,
          passwordHash: tenantHash,
          role: Role.tenant,
        ),
      ]);
      _properties.add(
        RentalProperty(
          id: propertyId,
          landlordId: ownerId,
          name: 'BackyardPay Demo Rooms',
          address: 'East London, Eastern Cape',
          code: 'BP-${_uuid.v4().substring(0, 8).toUpperCase()}',
          rooms: 4,
          rentCents: 150000,
          dueDay: 1,
        ),
      );
      _tenancies.add(
        Tenancy(
          id: _uuid.v4(),
          userId: tenantId,
          propertyId: propertyId,
          room: '1',
          startPeriod: periodOf(DateTime.now()),
          rentCents: 150000,
          dueDay: 1,
        ),
      );
    });
  }
}
