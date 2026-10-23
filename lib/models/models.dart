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

enum ReviewState { pending, confirmed, rejected }

class Account {
  final String id, name, phone, email, salt, passwordHash;
  final Role role;
  const Account({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.salt,
    required this.passwordHash,
    required this.role,
  });
  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'],
    name: j['name'],
    phone: j['phone'],
    email: j['email'],
    salt: j['salt'],
    passwordHash: j['passwordHash'],
    role: Role.values.byName(j['role']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'salt': salt,
    'passwordHash': passwordHash,
    'role': role.name,
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
  final int rooms, rentCents, dueDay;
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
    'rooms': rooms,
    'rentCents': rentCents,
    'dueDay': dueDay,
    'latitude': latitude,
    'longitude': longitude,
  };
}

class Tenancy {
  final String id, userId, propertyId, room, startPeriod;
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
    userId: j['userId'],
    propertyId: j['propertyId'],
    room: j['room'],
    startPeriod: j['startPeriod'],
    rentCents: j['rentCents'],
    dueDay: j['dueDay'] ?? 1,
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

class RentPayment {
  final String id, tenancyId, period, method, reference, notes;
  final int amountCents;
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
    'bankReference': bankReference,
    'amountCents': amountCents,
    'paidOn': paidOn.toIso8601String(),
    'submittedAt': submittedAt.toIso8601String(),
    'state': state.name,
    'rejectionReason': rejectionReason,
    'reviewedAt': reviewedAt?.toIso8601String(),
  };
}

class AppNotice {
  final String id, userId, title, message;
  final DateTime createdAt;
  final bool read;
  const AppNotice({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.read = false,
  });
  factory AppNotice.fromJson(Map<String, dynamic> j) => AppNotice(
    id: j['id'],
    userId: j['userId'],
    title: j['title'],
    message: j['message'],
    createdAt: DateTime.parse(j['createdAt']),
    read: j['read'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
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
