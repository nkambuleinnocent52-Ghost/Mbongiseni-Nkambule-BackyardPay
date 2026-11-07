import '../data/research_ledger.dart';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/store.dart';
import '../models/models.dart';

Future<pw.Document> _document() async => pw.Document(
  theme: pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf')),
    bold: pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
    ),
  ),
);
pw.Widget _row(String k, String v) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 6),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(width: 140, child: pw.Text(k)),
      pw.Expanded(child: pw.Text(v)),
    ],
  ),
);
List<pw.Widget> _heading(String title) => [
  pw.Text(
    'BACKYARDPAY',
    style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold),
  ),
  pw.SizedBox(height: 8),
  pw.Text(title),
  pw.Divider(),
];

Future<Uint8List> receiptPdf(AppStore store, String paymentId) async {
  final p = store.payment(paymentId);
  if (p.state != ReviewState.confirmed && p.state != ReviewState.reversed)
    throw StateError('Only a landlord-confirmed receipt can be downloaded.');
  final t = store.tenancy(p.tenancyId),
      property = store.property(t.propertyId),
      tenant = store.tenantAccount(t),
      issuer = store.landlordFor(t),
      snap = p.receiptDetails ?? {};
  final issued =
      (snap['issuedAllocations'] as List?)
          ?.map((a) => PaymentAllocation.fromJson(Map<String, dynamic>.from(a)))
          .toList() ??
      p.splits;
  final credit = snap['issuedCreditCents'] as int? ?? p.creditCents;
  final doc = await _document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        ..._heading('Rental payment receipt — ${p.method}'),
        if (p.state == ReviewState.reversed)
          pw.Text(
            'REVERSED: ${p.rejectionReason}. These are retained original issue details. This payment no longer reduces the account balance.',
          ),
        _row('Receipt identifier', p.reference),
        _row(
          'Issued / confirmed on',
          p.reviewedAt!.toIso8601String().split('T').first,
        ),
        _row('Landlord / issuer', snap['landlord'] ?? issuer.name),
        _row(
          'Issuer notice address',
          snap['landlordAddress'] ??
              t.record['landlordAddress'] ??
              'Not recorded',
        ),
        _row('Tenant', snap['tenant'] ?? tenant.name),
        _row('Actual payer', p.payer.isEmpty ? tenant.name : p.payer),
        _row('Property', snap['property'] ?? property.name),
        _row('Dwelling address', snap['address'] ?? property.fullAddress),
        _row('Room / unit', snap['room'] ?? t.room),
        _row('Money received', money(p.amountCents)),
        _row('Method', p.method),
        _row('Payment date', p.paidOn.toIso8601String().split('T').first),
        if (p.bankReference.isNotEmpty)
          _row('Bank transaction reference', p.bankReference),
        pw.SizedBox(height: 14),
        pw.Text(
          'Purpose and allocations at receipt issue',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        for (final a in issued)
          _row('Rent / arrears: ${a.period}', money(a.amountCents)),
        if (credit > 0) _row('Unallocated rental credit', money(credit)),
        if (p.notes.isNotEmpty) _row('Payment explanation', p.notes),
        pw.SizedBox(height: 18),
        pw.Text(
          'The landlord acknowledges receipt of the money above. For electronic payments this refers to the same payment as the bank record; it does not create a second payment or independently verify a bank transaction. BackyardPay does not transfer money. Deposits are recorded separately.',
        ),
        if (snap['issuedAllocations'] != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'Original issue details are retained. Later allocation of credit appears in the rental account and change history; this receipt is not silently rewritten.',
            ),
          ),
        if (snap.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'Legacy record: property/party details were not frozen at original issue and are taken from the available rental record.',
            ),
          ),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> depositReceiptPdf(
  AppStore store,
  String tenancyId,
  Map<String, dynamic> record,
) async {
  final t = store.tenancy(tenancyId);
  if (record['tenancyId'] != t.id ||
      record['kind'] != 'deposit' ||
      record['body']['event'] != 'received')
    throw StateError('This is not a deposit receipt event.');
  final body = Map<String, dynamic>.from(record['body']),
      snap = Map<String, dynamic>.from(body['receiptDetails'] ?? {}),
      property = store.property(t.propertyId);
  final doc = await _document();
  doc.addPage(
    pw.MultiPage(
      build: (_) => [
        ..._heading('Deposit payment receipt'),
        _row('Receipt identifier', 'DEP-${record['id']}'),
        _row('Recorded on', record['createdAt']),
        _row(
          'Landlord / issuer',
          snap['landlord'] ?? store.landlordFor(t).name,
        ),
        _row('Tenant', snap['tenant'] ?? store.tenantAccount(t).name),
        _row('Address', snap['address'] ?? property.fullAddress),
        _row('Room / unit', snap['room'] ?? t.room),
        _row('Purpose', 'Rental security deposit — not rent'),
        _row('Occupancy starts', t.record['tenancyStartedOn'] ?? t.startPeriod),
        _row('Amount received', money(body['amountCents'])),
        _row('Payment date', body['date']),
        _row('Method', body['method'] ?? 'Not recorded'),
        _row('Actual payer', body['payer'] ?? 'Not recorded'),
        _row('Transaction / evidence reference', body['reference']),
        if ((body['note'] ?? '').isNotEmpty) _row('Explanation', body['note']),
        pw.SizedBox(height: 16),
        pw.Text(
          'The landlord records money received as a deposit. Interest, deductions and refunds have separate dated records. This receipt does not establish that a future deduction is lawful and does not transfer money.',
        ),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> accountStatementPdf(AppStore store, String tenancyId) async {
  final t = store.tenancy(tenancyId),
      property = store.property(t.propertyId),
      tenant = store.tenantAccount(t),
      rows = store.ledger(t);
  final doc = await _document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        ..._heading(
          'Rental account statement — allocations as at ${DateTime.now().toIso8601String().split('T').first}',
        ),
        _row(
          'Tenant / dwelling',
          '${tenant.name} | ${property.fullAddress} | Room ${t.room}',
        ),
        _row('Landlord', store.landlordFor(t).name),
        _row('Account begins', t.startPeriod),
        _row(
          'Agreed security deposit',
          t.depositCents == null ? 'Not recorded' : money(t.depositCents!),
        ),
        _row(
          'Deposit still due (separate from rent)',
          store.research.depositOutstanding(t) == null
              ? 'Not recorded'
              : money(store.research.depositOutstanding(t)!),
        ),
        if (t.record['firstMonthProration'] != null)
          pw.Text(
            firstChargeExplanation(
              t.rentCents,
              DateTime.parse(t.record['tenancyStartedOn']),
              t.record['firstMonthProration'] == 'actual_days',
            ),
          ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: [
            'Charge month',
            'Recorded charges',
            'Confirmed allocations',
            'Pending proposals',
            'Recorded balance',
            'Cumulative balance',
          ],
          data: rows
              .map(
                (r) => [
                  r.period,
                  money(r.chargedCents),
                  money(r.confirmedCents),
                  money(r.pendingCents),
                  money(r.outstandingCents),
                  money(r.closingBalanceCents),
                ],
              )
              .toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding: const pw.EdgeInsets.all(8),
        ),
        pw.SizedBox(height: 14),
        _row(
          'Confirmed charge balance',
          money(rows.isEmpty ? 0 : rows.last.closingBalanceCents),
        ),
        if (store.researchReady) ...[
          if (store.research.depositOutstanding(t) != null)
            _row(
              'Total recorded rent + deposit due',
              money(
                (rows.isEmpty ? 0 : rows.last.closingBalanceCents) +
                    store.research.depositOutstanding(t)!,
              ),
            ),
          _row('Unallocated received credit', money(store.creditFor(t))),
          _row('Tenant reports awaiting review', money(store.pendingFor(t))),
          _row(
            'Deposit and interest held (separate)',
            money(store.research.depositBalance(t)),
          ),
        ],
        pw.Text(
          'This is an as-of allocation view, not a bank statement or historical month-end cash-flow statement. Later payments may settle earlier charge months. Pending reports do not reduce confirmed-record balances and are not proof of nonpayment. Deposits are separate. Monthly base charges can be corrected by documented agreed adjustments; the app does not decide legal liability.',
        ),
      ],
    ),
  );
  return doc.save();
}
