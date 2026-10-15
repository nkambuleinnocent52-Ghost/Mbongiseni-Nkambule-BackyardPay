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
    'Address': property.address,
    'Room': tenancy.room,
    'Rent month': payment.period,
    'Amount': money(payment.amountCents),
    'Payment method': payment.method,
    'Payment date': payment.paidOn.toIso8601String().split('T').first,
    'Confirmed on': payment.reviewedAt!.toIso8601String().split('T').first,
    'Reference': payment.reference,
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
          pw.Text('Rent payment receipt'),
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
            'This receipt records a payment confirmed by the landlord. BackyardPay does not transfer money.',
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
