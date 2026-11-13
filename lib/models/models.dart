String money(int cents) => 'R ${(cents / 100).toStringAsFixed(2)}';
String periodOf(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';
DateTime periodDate(String value) {
  final bits = value.split('-');
  if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
    throw const FormatException('Use a rent month such as 2026-10.');
  }
  return DateTime(int.parse(bits[0]), int.parse(bits[1]));
}

int parseMoney(String value) {
  final text = value.trim();
  if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text)) {
    throw const FormatException(
      'Enter a positive amount with at most two decimals.',
    );
  }
  final pieces = text.split('.');
  final amount =
      int.parse(pieces[0]) * 100 +
      (pieces.length == 2 ? int.parse(pieces[1].padRight(2, '0')) : 0);
  if (amount <= 0)
    throw const FormatException('Amount must be greater than zero.');
  return amount;
}

enum Role { landlord, tenant }

enum ReviewState { pending, confirmed, rejected, reversed }

class Account {
  final String id, name, phone, email, salt, passwordHash;
  final Role role;
  final String? loginId;
  const Account({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.salt,
    required this.passwordHash,
    required this.role,
    this.loginId,
  });
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'],
    name: j['name'],
    phone: j['phone'],
    email: j['email'],
    salt: j['salt'],
    passwordHash: j['passwordHash'],
    role: Role.values.byName(j['role']),
    loginId: j['loginId'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'salt': salt,
    'passwordHash': passwordHash,
    'role': role.name,
    if (loginId != null) 'loginId': loginId,
  };
}

class RentalProperty {
  final String id, landlordId, name, address, code;
  final String suburb, city, postalCode;
  String get fullAddress => [
    address,
    suburb,
    city,
    postalCode,
  ].where((s) => s.trim().isNotEmpty).join(', ');
  final Map<String, int> roomRents;
  int rentForRoom(int room) => roomRents['$room'] ?? rentCents;
  final int rooms, rentCents, dueDay;
  final bool prorateFirstMonth;
  final int? securityDepositCents;
  final double? latitude, longitude;
  const RentalProperty({
    required this.id,
    required this.landlordId,
    required this.name,
    required this.address,
    required this.code,
    required this.rooms,
    required this.rentCents,
    required this.dueDay,
    this.latitude,
    this.longitude,
    this.roomRents = const {},
    this.prorateFirstMonth = true,
    this.securityDepositCents,
    this.suburb = '',
    this.city = '',
    this.postalCode = '',
  });
  factory RentalProperty.fromJson(Map<String, dynamic> j) => RentalProperty(
    id: j['id'],
    landlordId: j['landlordId'],
    name: j['name'],
    address: j['address'],
    suburb: j['suburb'] ?? '',
    city: j['city'] ?? '',
    postalCode: j['postalCode'] ?? '',
    code: j['code'],
    prorateFirstMonth: j['prorateFirstMonth'] ?? false,
    securityDepositCents: j['securityDepositCents'],
    roomRents: Map<String, int>.from(j['roomRents'] ?? {}),
    rooms: j['rooms'],
    rentCents: j['rentCents'],
    dueDay: j['dueDay'],
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'landlordId': landlordId,
    'name': name,
    'address': address,
    'suburb': suburb,
    'city': city,
    'postalCode': postalCode,
    'code': code,
    'prorateFirstMonth': prorateFirstMonth,
    'securityDepositCents': securityDepositCents,
    'roomRents': roomRents,
    'rooms': rooms,
    'rentCents': rentCents,
    'dueDay': dueDay,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class Tenancy {
  final String id, userId, propertyId, room, startPeriod;
  final Map<String, dynamic> record;
  final DateTime? endedOn;
  final String? invitation;
  final int ledgerVersion;
  final int rentCents, dueDay;
  final DateTime? leaseStart, leaseEnd, termsUpdatedAt, acknowledgedAt;
  final int? depositCents, depositReceivedCents;
  final String agreementType,
      utilities,
      houseRules,
      emergencyName,
      emergencyPhone;
  bool get agreementRecorded => leaseStart != null;

  const Tenancy({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.room,
    required this.startPeriod,
    required this.rentCents,
    required this.dueDay,
    this.record = const {},
    this.endedOn,
    this.invitation,
    this.ledgerVersion = 1,
    this.leaseStart,
    this.leaseEnd,
    this.termsUpdatedAt,
    this.acknowledgedAt,
    this.depositCents,
    this.depositReceivedCents,
    this.agreementType = 'Not recorded',
    this.utilities = '',
    this.houseRules = '',
    this.emergencyName = '',
    this.emergencyPhone = '',
  });
  factory Tenancy.fromJson(Map<String, dynamic> j) => Tenancy(
    id: j['id'],
    userId: j['userId'] ?? '',
    propertyId: j['propertyId'],
    room: j['room'],
    startPeriod: j['startPeriod'],
    rentCents: j['rentCents'],
    dueDay: j['dueDay'] ?? 1,
    record: Map<String, dynamic>.from(j['record'] ?? {}),
    endedOn: j['endedOn'] == null ? null : DateTime.parse(j['endedOn']),
    invitation: j['invitation'],
    ledgerVersion: j['ledgerVersion'] ?? 1,
    leaseStart: j['leaseStart'] == null
        ? null
        : DateTime.parse(j['leaseStart']),
    leaseEnd: j['leaseEnd'] == null ? null : DateTime.parse(j['leaseEnd']),
    termsUpdatedAt: j['termsUpdatedAt'] == null
        ? null
        : DateTime.parse(j['termsUpdatedAt']),
    acknowledgedAt: j['acknowledgedAt'] == null
        ? null
        : DateTime.parse(j['acknowledgedAt']),
    depositCents: j['depositCents'],
    depositReceivedCents: j['depositReceivedCents'],
    agreementType: j['agreementType'] ?? 'Not recorded',
    utilities: j['utilities'] ?? '',
    houseRules: j['houseRules'] ?? '',
    emergencyName: j['emergencyName'] ?? '',
    emergencyPhone: j['emergencyPhone'] ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'propertyId': propertyId,
    'room': room,
    'startPeriod': startPeriod,
    'rentCents': rentCents,
    'dueDay': dueDay,
    'record': record,
    'endedOn': endedOn?.toIso8601String(),
    'invitation': invitation,
    'ledgerVersion': ledgerVersion,
    'leaseStart': leaseStart?.toIso8601String(),
    'leaseEnd': leaseEnd?.toIso8601String(),
    'termsUpdatedAt': termsUpdatedAt?.toIso8601String(),
    'acknowledgedAt': acknowledgedAt?.toIso8601String(),
    'depositCents': depositCents,
    'depositReceivedCents': depositReceivedCents,
    'agreementType': agreementType,
    'utilities': utilities,
    'houseRules': houseRules,
    'emergencyName': emergencyName,
    'emergencyPhone': emergencyPhone,
  };
}

class PaymentAllocation {
  final String period;
  final int amountCents;
  const PaymentAllocation(this.period, this.amountCents);
  factory PaymentAllocation.fromJson(Map<String, dynamic> j) =>
      PaymentAllocation(j['period'], j['amountCents']);
  Map<String, dynamic> toJson() => {
    'period': period,
    'amountCents': amountCents,
  };
}

class RentPayment {
  final String id, tenancyId, period, method, reference, notes;
  final int amountCents;
  final String payer;
  final List<PaymentAllocation>? allocations;
  final Map<String, dynamic>? receiptDetails;
  final String bankReference;
  final DateTime paidOn, submittedAt;
  final ReviewState state;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  const RentPayment({
    required this.id,
    required this.tenancyId,
    required this.period,
    required this.method,
    required this.reference,
    required this.notes,
    required this.amountCents,
    required this.paidOn,
    required this.submittedAt,
    this.payer = '',
    this.allocations,
    this.receiptDetails,
    this.state = ReviewState.pending,
    this.rejectionReason,
    this.bankReference = '',
    this.reviewedAt,
  });
  factory RentPayment.fromJson(Map<String, dynamic> j) => RentPayment(
    id: j['id'],
    tenancyId: j['tenancyId'],
    period: j['period'],
    method: j['method'],
    reference: j['reference'],
    notes: j['notes'],
    payer: j['payer'] ?? '',
    allocations: j['allocations'] == null
        ? null
        : (j['allocations'] as List)
              .map(
                (a) => PaymentAllocation.fromJson(Map<String, dynamic>.from(a)),
              )
              .toList(),
    receiptDetails: j['receiptDetails'] == null
        ? null
        : Map<String, dynamic>.from(j['receiptDetails']),
    bankReference: j['bankReference'] ?? '',
    amountCents: j['amountCents'],
    paidOn: DateTime.parse(j['paidOn']),
    submittedAt: DateTime.parse(j['submittedAt']),
    state: ReviewState.values.byName(j['state']),
    rejectionReason: j['rejectionReason'],
    reviewedAt: j['reviewedAt'] == null
        ? null
        : DateTime.parse(j['reviewedAt']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'tenancyId': tenancyId,
    'period': period,
    'method': method,
    'reference': reference,
    'notes': notes,
    'payer': payer,
    'allocations': allocations?.map((a) => a.toJson()).toList(),
    'receiptDetails': receiptDetails,
    'bankReference': bankReference,
    'amountCents': amountCents,
    'paidOn': paidOn.toIso8601String(),
    'submittedAt': submittedAt.toIso8601String(),
    'state': state.name,
    'rejectionReason': rejectionReason,
    'reviewedAt': reviewedAt?.toIso8601String(),
  };
}

extension PaymentAllocationTotals on RentPayment {
  List<PaymentAllocation> get splits =>
      allocations ?? [PaymentAllocation(period, amountCents)];
  int get creditCents =>
      amountCents - splits.fold(0, (sum, a) => sum + a.amountCents);
}

class AppNotice {
  final String id, userId, title, message;
  final String? targetKind, targetId, tenancyId;
  final DateTime createdAt;
  final bool read;
  const AppNotice({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.read = false,
    this.targetKind,
    this.targetId,
    this.tenancyId,
  });
  factory AppNotice.fromJson(Map<String, dynamic> j) => AppNotice(
    id: j['id'],
    userId: j['userId'],
    title: j['title'],
    message: j['message'],
    createdAt: DateTime.parse(j['createdAt']),
    read: j['read'] == true,
    targetKind: j['targetKind'] as String?,
    targetId: j['targetId'] as String?,
    tenancyId: j['tenancyId'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
    'targetKind': targetKind,
    'targetId': targetId,
    'tenancyId': tenancyId,
  };
}

class MonthlyAccount {
  final String period;
  final int chargedCents, confirmedCents, pendingCents, closingBalanceCents;
  final bool overdue;
  const MonthlyAccount({
    required this.period,
    required this.chargedCents,
    required this.confirmedCents,
    required this.pendingCents,
    required this.closingBalanceCents,
    required this.overdue,
  });
  int get outstandingCents => chargedCents - confirmedCents;
  String get status => confirmedCents >= chargedCents
      ? 'Paid'
      : confirmedCents > 0
      ? 'Partially paid'
      : 'Outstanding';
}

int parseDeposit(String text) =>
    RegExp(r'^0(?:\.0{1,2})?$').hasMatch(text.trim()) ? 0 : parseMoney(text);
