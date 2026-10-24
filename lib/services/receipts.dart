import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/store.dart';
import '../models/models.dart';

Future<Uint8List> receiptPdf(AppStore store, String paymentId) async {
  final payment = store.payment(paymentId);
  if (payment.state != ReviewState.confirmed)
    throw StateError(
      'A receipt is available only after landlord confirmation.',
    );
  final tenancy = store.tenancy(payment.tenancyId);
  final tenant = store.tenantAccount(tenancy);
  final property = store.property(tenancy.propertyId);
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final details = <String, String>{
    'Tenant': tenant.name,
    'Property': property.name,
    'Address': property.fullAddress,
    'Room': tenancy.room,
    'Rent month': payment.period,
    'Amount': money(payment.amountCents),
    'Payment method': payment.method,
    'Payment date': payment.paidOn.toIso8601String().split('T').first,
    'Confirmed on': payment.reviewedAt!.toIso8601String().split('T').first,
    'Record reference': payment.reference,
    if (payment.bankReference.isNotEmpty)
      'Bank transaction reference': payment.bankReference,
    'Status': 'CONFIRMED',
  };
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BACKYARDPAY',
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            payment.method == 'Cash'
                ? 'Rent payment receipt'
                : 'Rent allocation acknowledgement',
          ),
          pw.Divider(),
          ...details.entries.map(
            (e) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 130, child: pw.Text(e.key)),
                  pw.Expanded(child: pw.Text(e.value)),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            payment.method == 'Cash'
                ? 'This receipt records cash confirmed by the landlord. BackyardPay does not transfer money.'
                : 'This acknowledgement records the landlord’s confirmation of money received and allocated to this rental month. It is not a bank-issued proof of payment. Keep your original bank confirmation.',
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Remaining rent for this month: ${money(store.outstanding(tenancy, payment.period))}',
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

Future<Uint8List> accountStatementPdf(AppStore store, String tenancyId) async {
  final t = store.tenancy(tenancyId),
      property = store.property(t.propertyId),
      tenant = store.tenantAccount(t),
      rows = store.ledger(t);
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Text(
          'BACKYARDPAY',
          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Monthly rental account · not a bank statement'),
        pw.Divider(color: PdfColor.fromHex('#B28C3A')),
        pw.Text(
          'Tenant: ${tenant.name}  |  Property: ${property.name}  |  Room: ${t.room}',
        ),
        pw.SizedBox(height: 6),
        pw.Text('Address: ${property.fullAddress}'),
        pw.SizedBox(height: 6),
        pw.Text(
          'Monthly rent: ${money(t.rentCents)}  |  Due: day ${t.dueDay}  |  Account begins: ${t.startPeriod}',
        ),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: [
            'Month',
            'Rent charged',
            'Confirmed',
            'Pending',
            'Month owed',
            'Running balance',
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
          headerDecoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#17181C'),
          ),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellPadding: const pw.EdgeInsets.all(10),
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Total rent still owed: ${money(rows.isEmpty ? 0 : rows.last.closingBalanceCents)}',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Only landlord-confirmed payments reduce the balance. A pending submission does not prove receipt of money. Deposits are kept separate from rent. Full calendar-month charges apply.',
        ),
      ],
    ),
  );
  return doc.save();
}
