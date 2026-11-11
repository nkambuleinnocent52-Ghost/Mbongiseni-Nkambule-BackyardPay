import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../ui/design.dart';
import '../shared/common.dart';

class RentalDocuments extends StatefulWidget {
  final String tenancyId;
  final String? caseId;
  const RentalDocuments({super.key, required this.tenancyId, this.caseId});
  @override
  State<RentalDocuments> createState() => _RentalDocumentsState();
}

class _RentalDocumentsState extends State<RentalDocuments> {
  final title = TextEditingController();
  String category = 'Lease';
  bool busy = false;
  List<Map<String, dynamic>>? records;
  String? error;
  SupabaseClient get client => StoreScope.of(context).cloud!.client;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (records == null && !busy) {
      if (widget.caseId != null) category = 'Other';
      load();
    }
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> load() async {
    busy = true;
    try {
      var query = client
          .from('bp_documents')
          .select()
          .eq('tenancy_id', widget.tenancyId);
      if (widget.caseId != null) query = query.eq('case_id', widget.caseId!);
      final rows = await query.order('created_at', ascending: false);
      if (mounted)
        setState(() {
          records = rows;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> upload() async {
    if (title.text.trim().length < 3) {
      setState(() => error = 'Enter a descriptive title first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    String? path;
    bool registered = false;
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'PDF or image',
            extensions: ['pdf', 'jpg', 'jpeg', 'png'],
            mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
          ),
        ],
      );
      if (file == null) return;
      final ext = file.name.split('.').last.toLowerCase();
      final mime = {
        'pdf': 'application/pdf',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
      }[ext];
      if (mime == null || await file.length() > 10485760)
        throw StateError('Choose a PDF, JPEG or PNG up to 10 MB.');
      path =
          '${widget.tenancyId}/${const Uuid().v4()}.${ext == 'jpeg' ? 'jpg' : ext}';
      await client.storage
          .from('bp-documents')
          .uploadBinary(
            path,
            await file.readAsBytes(),
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      await client.rpc(
        widget.caseId == null
            ? 'bp_register_document'
            : 'bp_register_case_document',
        params: {
          'tid': widget.tenancyId,
          'path': path,
          'label': title.text.trim(),
          'category_name': category,
          if (widget.caseId != null) 'report_id': widget.caseId,
        },
      );
      registered = true;
      title.clear();
      await load();
    } catch (e) {
      if (path != null && !registered) {
        try {
          await client.storage.from('bp-documents').remove([path]);
        } catch (_) {}
      }
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: widget.caseId == null
        ? 'Rental documents'
        : 'Report photos / evidence',
    maxWidth: 800,
    children: [
      const Text(
        'Supporting files are private to this rental’s landlord and linked tenant. An upload is evidence supplied by a user; it does not verify a bank payment, ownership or a signature. Avoid unnecessary identity documents.',
      ),
      gap(16),
      TextField(
        controller: title,
        enabled: !busy,
        maxLength: 150,
        decoration: const InputDecoration(labelText: 'Document title'),
      ),
      DropdownButtonFormField<String>(
        initialValue: category,
        decoration: const InputDecoration(labelText: 'Category'),
        items: [
          'Lease',
          'Inspection',
          'Payment evidence',
          'Deposit evidence',
          'Other',
        ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: busy ? null : (s) => setState(() => category = s!),
      ),
      gap(12),
      if (error != null)
        Text(error!, style: const TextStyle(color: Palette.red)),
      action(
        busy ? 'Working…' : 'Choose and upload file',
        busy ? null : upload,
        icon: Icons.upload_file,
      ),
      const Text(
        'PDF / JPEG / PNG • maximum 10 MB. Registered evidence is retained; upload a clearly named correction instead of replacing it.',
      ),
      gap(20),
      if (records?.isEmpty ?? false)
        panel(const Text('No supporting files yet.')),
      for (final r in records ?? <Map<String, dynamic>>[])
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(r['title']),
              Text('${r['category']} • ${r['created_at']}'),
              Text(
                r['uploaded_by'] == StoreScope.of(context).currentUser!.id
                    ? 'Uploaded by you'
                    : 'Uploaded by the other party',
              ),
              action(
                'Open private file',
                () => perform(context, () async {
                  final url = await client.storage
                      .from('bp-documents')
                      .createSignedUrl(r['object_path'], 60);
                  if (!await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ))
                    throw StateError('Could not open the file.');
                }),
                icon: Icons.open_in_new,
              ),
            ],
          ),
        ),
    ],
  );
}
