import 'dart:convert';

import 'cloud_gateway.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

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
  AppStore(this.storage, {this.cloud});
  final CloudGateway? cloud;
  bool get isCloud => cloud != null;
  String? syncError;
  DateTime? lastSyncedAt;
  Future<void> refresh() async {
    if (cloud == null || _writing) return;
    final userId = cloud!.client.auth.currentUser?.id;
    try {
      final data = await cloud!.snapshot();
      if (cloud!.client.auth.currentUser?.id != userId) return;
      _restore(jsonEncode(data));
      syncError = null;
      lastSyncedAt = DateTime.now();
      notifyListeners();
    } catch (_) {
      syncError = 'Could not refresh records. Check your connection. The last loaded records are shown.';
      notifyListeners();
      rethrow;
    }
  }

  Future<dynamic> _remote(String op, Map<String, dynamic> args) async {
    if (_writing)
      throw StateError('Another change is saving. Please try again.');
    _writing = true;
    final userId = cloud!.client.auth.currentUser?.id;
    try {
      final response = await cloud!.action(op, args);
      if (cloud!.client.auth.currentUser?.id != userId)
        throw StateError(
          'Your session changed. Sign in and reload your records.',
        );
      _restore(jsonEncode(response['snapshot']));
      syncError = null;
      lastSyncedAt = DateTime.now();
      notifyListeners();
      return response['result'];
    } finally {
      _writing = false;
    }
  }

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
    if (cloud != null) {
      await refresh();
      return;
    }
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
    if (cloud != null) {
      _identity(name, email, phone);
      _passwordRules(password);
      final response = await cloud!.client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'name': name.trim(),
          'phone': phone.trim(),
          'role': role.name,
          'code': code.trim().toUpperCase(),
          'room': room.trim(),
        },
        emailRedirectTo: 'https://quiet-pastelito-19fa50.netlify.app/',
      );
      if (response.session == null) {
        throw StateError(
          'Check your email to confirm your account, then return here and sign in. If already registered, sign in or reset your password.',
        );
      }
      await refresh();
      return;
    }
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
      (t) =>
          t.propertyId == p.id && t.room == number.toString() && isOccupied(t),
    ))
      throw ArgumentError('That room already has a tenant.');
    if (room.trim() != number.toString())
      throw ArgumentError('Use a room number without leading zeros.');
  }

  Future<void> login(String email, String password, Role role) async {
    if (cloud != null) {
      await cloud!.client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      try {
        await refresh();
        if (currentUser?.role != role)
          throw StateError('Choose the correct role for your account.');
      } catch (_) {
        await cloud!.client.auth.signOut();
        _restore(jsonEncode(CloudGateway.emptySnapshot));
        notifyListeners();
        rethrow;
      }
      return;
    }
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

  Future<void> logout() async {
    if (cloud != null) {
      await cloud!.client.auth.signOut();
      _restore(jsonEncode(CloudGateway.emptySnapshot));
      notifyListeners();
      return;
    }
    await _transaction(() => _session = null);
  }

  Future<void> resetPassword(String email) async {
    if (cloud == null)
      throw StateError('Email recovery requires the cloud connection.');
    await cloud!.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'https://quiet-pastelito-19fa50.netlify.app/',
    );
  }

  Future<void> completePasswordReset(String password) async {
    _passwordRules(password);
    await cloud!.client.auth.updateUser(UserAttributes(password: password));
    await logout();
  }

  Future<void> updateProfile(String name, String phone) async {
    if (cloud != null) {
      await _remote('profile', {'name': name.trim(), 'phone': phone.trim()});
      return;
    }
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
    if (cloud != null) {
      _passwordRules(newPassword);
      await cloud!.client.auth.signInWithPassword(
        email: currentUser!.email,
        password: oldPassword,
      );
      await cloud!.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return;
    }
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
  Future<void> markRead(String id) async {
    if (cloud != null) {
      await _remote('read', {'id': id});
      return;
    }
    await _transaction(() {
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
  }

  Future<String> saveProperty({
    String? id,
    required String name,
    required String address,
    required int rooms,
    required int rentCents,
    required int dueDay,
    String suburb = '',
    String city = '',
    String postalCode = '',
  }) async {
    if (cloud != null)
      return await _remote('property', {
        'id': id,
        'name': name.trim(),
        'address': address.trim(),
        'rooms': rooms,
        'rentCents': rentCents,
        'dueDay': dueDay,
        'suburb': suburb.trim(),
        'city': city.trim(),
        'postalCode': postalCode.trim(),
      }) as String;
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
      if (city.length > 100 ||
          suburb.length > 100 ||
          (postalCode.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(postalCode)))
        throw ArgumentError('Use a four-digit South African postal code.');
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
        suburb: suburb.trim(),
        city: city.trim(),
        postalCode: postalCode.trim(),
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
    if (cloud != null) {
      await _remote('deleteProperty', {'id': id});
      return;
    }
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
    if (cloud != null) {
      await _remote('location', {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
      });
      return;
    }
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
        suburb: p.suburb,
        city: p.city,
        postalCode: p.postalCode,
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
    return period.compareTo(t.startPeriod) < 0 ||
            (t.leaseEnd != null && period.compareTo(periodOf(t.leaseEnd!)) > 0)
        ? 0
        : t.rentCents;
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
    String bankReference = '',
  }) async {
    if (cloud != null)
      return await _remote('payment', {
        'tenancyId': tenancyId,
        'period': period,
        'amountCents': amountCents,
        'method': method,
        'paidOn': paidOn.toIso8601String().split('T').first,
        'reference': reference.trim(),
        'notes': notes.trim(),
        'bankReference': bankReference.trim(),
      }) as String;
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
    if (['EFT', 'PayShap'].contains(method) &&
        (bankReference.trim().isEmpty || bankReference.length > 100))
      throw ArgumentError(
        'Enter the reference from your bank payment confirmation.',
      );
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
        bankReference: bankReference.trim(),
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
    if (cloud != null) {
      await _remote('review', {
        'id': id,
        'confirm': confirm,
        'reason': reason.trim(),
      });
      return;
    }
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
        bankReference: p.bankReference,
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
    if (cloud != null) {
      await _remote('reminder', {
        'tenancyId': tenancyId,
        'period': period,
        'message': message.trim(),
      });
      return;
    }
    _user(Role.landlord);
    final t = tenancy(tenancyId);
    periodDate(period);
    if (message.trim().isEmpty || message.trim().length > 500)
      throw ArgumentError('Enter a reminder message.');
    await _transaction(
      () => _notice(t.userId, 'Rent reminder • $period', message.trim()),
    );
  }

  bool isOccupied(Tenancy t) {
    final now = DateTime.now(),
        today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
    return (t.leaseStart == null || !t.leaseStart!.isAfter(now)) &&
        (t.leaseEnd == null || !t.leaseEnd!.isBefore(today));
  }

  Account landlordFor(Tenancy t) {
    tenancy(t.id);
    final p = property(t.propertyId);
    return _accounts.firstWhere((a) => a.id == p.landlordId);
  }

  List<MonthlyAccount> ledger(Tenancy t, {String? through}) {
    tenancy(t.id);
    final end = periodDate(through ?? periodOf(DateTime.now()));
    if (end.isAfter(periodDate(periodOf(DateTime.now()))))
      throw ArgumentError('Future rent is not yet charged.');
    final start = periodDate(t.startPeriod);
    final rows = <MonthlyAccount>[];
    var balance = 0;
    for (var m = start; !m.isAfter(end); m = DateTime(m.year, m.month + 1)) {
      final period = periodOf(m), charge = expected(t, period);
      if (charge == 0) continue;
      final confirmed = collected(t, period);
      final pending = payments
          .where(
            (p) =>
                p.tenancyId == t.id &&
                p.period == period &&
                p.state == ReviewState.pending,
          )
          .fold(0, (sum, p) => sum + p.amountCents);
      balance += max(0, charge - confirmed);
      rows.add(
        MonthlyAccount(
          period: period,
          chargedCents: charge,
          confirmedCents: confirmed,
          pendingCents: pending,
          closingBalanceCents: balance,
          overdue: overdue(t, period),
        ),
      );
    }
    return List.unmodifiable(rows);
  }

  int totalArrears(Tenancy t) => ledger(t)
      .fold(0, (sum, row) => sum + (row.overdue ? row.outstandingCents : 0));
  Future<void> saveAgreement(
    String tenancyId, {
    required DateTime start,
    DateTime? end,
    required String agreementType,
    required int depositCents,
    required int depositReceivedCents,
    required String utilities,
    required String houseRules,
    String emergencyName = '',
    String emergencyPhone = '',
  }) async {
    if (cloud != null) {
      await _remote('agreement', {
        'tenancyId': tenancyId,
        'start': start.toIso8601String().split('T').first,
        'end': end?.toIso8601String().split('T').first,
        'agreementType': agreementType,
        'depositCents': depositCents,
        'depositReceivedCents': depositReceivedCents,
        'utilities': utilities.trim(),
        'houseRules': houseRules.trim(),
        'emergencyName': emergencyName.trim(),
        'emergencyPhone': emergencyPhone.trim(),
      });
      return;
    }
    _user(Role.landlord);
    final t = tenancy(tenancyId);
    final current = DateTime.now();
    if (start.year < 2020 ||
        start.isAfter(
          DateTime(current.year, current.month, current.day, 23, 59, 59),
        )) {
      throw ArgumentError('Start date must be from 2020 through today.');
    }
    if (end != null && end.isBefore(start))
      throw ArgumentError('End date must be after the start date.');
    if (!['Month-to-month', 'Fixed term'].contains(agreementType) ||
        (agreementType == 'Fixed term' && end == null)) {
      throw ArgumentError(
        'Choose the rental type and an end date for a fixed term.',
      );
    }
    if (agreementType == 'Month-to-month' && end != null)
      throw ArgumentError(
        'Leave the end date empty for a month-to-month tenancy.',
      );
    if (depositCents < 0 ||
        depositReceivedCents < 0 ||
        depositReceivedCents > depositCents)
      throw ArgumentError(
        'Deposit received must be between zero and the agreed deposit.',
      );
    if (utilities.trim().isEmpty ||
        houseRules.trim().isEmpty ||
        utilities.length > 1000 ||
        houseRules.length > 2000) {
      throw ArgumentError(
        'Record utility responsibilities and rental terms within the stated limits.',
      );
    }
    if (emergencyName.length > 80 ||
        emergencyPhone.length > 20 ||
        (emergencyPhone.isNotEmpty &&
            !RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(emergencyPhone)))
      throw ArgumentError('Check the emergency contact details.');
    if (_payments.any(
      (p) =>
          p.tenancyId == t.id &&
          (p.period.compareTo(periodOf(start)) < 0 ||
              (end != null && p.period.compareTo(periodOf(end)) > 0)),
    ))
      throw ArgumentError(
        'Rental dates cannot exclude an existing payment record.',
      );
    final infinity = DateTime(9999);
    if (_tenancies.any(
      (other) =>
          other.id != t.id &&
          other.propertyId == t.propertyId &&
          other.room == t.room &&
          !start.isAfter(other.leaseEnd ?? infinity) &&
          !(other.leaseStart ?? periodDate(other.startPeriod)).isAfter(
            end ?? infinity,
          ),
    )) {
      throw ArgumentError(
        'These rental dates overlap another tenancy in the same room.',
      );
    }
    await _transaction(() {
      _tenancies[_tenancies.indexOf(t)] = Tenancy(
        id: t.id,
        userId: t.userId,
        propertyId: t.propertyId,
        room: t.room,
        startPeriod: periodOf(start),
        rentCents: t.rentCents,
        dueDay: t.dueDay,
        leaseStart: start,
        leaseEnd: end,
        agreementType: agreementType,
        depositCents: depositCents,
        depositReceivedCents: depositReceivedCents,
        utilities: utilities.trim(),
        houseRules: houseRules.trim(),
        emergencyName: emergencyName.trim(),
        emergencyPhone: emergencyPhone.trim(),
        termsUpdatedAt: DateTime.now(),
      );
      _notice(
        t.userId,
        'Rental details updated',
        'Your landlord updated your rental record. Review the dates, deposit and responsibilities in Rental details.',
      );
    });
  }

  Future<void> acknowledgeAgreement(String tenancyId) async {
    if (cloud != null) {
      await _remote('acknowledge', {'tenancyId': tenancyId});
      return;
    }
    final a = _user(Role.tenant), t = tenancy(tenancyId);
    if (t.userId != a.id || !t.agreementRecorded)
      throw StateError(
        'No recorded rental terms are available to acknowledge.',
      );
    await _transaction(() {
      _tenancies[_tenancies.indexOf(t)] = Tenancy.fromJson({
        ...t.toJson(),
        'acknowledgedAt': DateTime.now().toIso8601String(),
      });
      _notice(
        property(t.propertyId).landlordId,
        'Rental details reviewed',
        '${a.name} has acknowledged reading their rental record. This is not a digital signature.',
      );
    });
  }

  String get newReference => 'BP-${_uuid.v4().substring(0, 13).toUpperCase()}';
}
