import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import 'research_records.dart' show isoDay;

String issueStatusLabel(String status) => switch (status) {
  'acknowledged' => 'Acknowledged',
  'in_progress' => 'In progress',
  'resolved' => 'Resolved',
  _ => 'Submitted',
};

class SimpleReportsScreen extends StatelessWidget {
  final String? tenancyId, reportId;
  const SimpleReportsScreen({super.key, this.tenancyId, this.reportId});
  @override
  Widget build(BuildContext context) => PageShell(
    title: reportId == null ? 'Problems and messages' : 'Reported problem',
    maxWidth: 900,
    children: [SimpleReports(tenancyId: tenancyId, reportId: reportId)],
  );
}

class SimpleReports extends StatefulWidget {
  final String? tenancyId, reportId;
  const SimpleReports({super.key, this.tenancyId, this.reportId});
  @override
  State<SimpleReports> createState() => _SimpleReportsState();
}

class _SimpleReportsState extends State<SimpleReports> {
  bool composing = true;
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        owner = s.currentUser!.role == Role.landlord;
    final reports =
        s.caseRecords
            .where(
              (r) =>
                  ['repair', 'query'].contains(r['kind']) &&
                  (widget.tenancyId == null ||
                      r['tenancyId'] == widget.tenancyId) &&
                  (widget.reportId == null || r['id'] == widget.reportId),
            )
            .toList()
          ..sort(
            (a, b) => (b['createdAt'] as String).compareTo(a['createdAt']),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tenancyId != null && !owner && widget.reportId == null) ...[
          if (composing)
            IssueEntryForm(
              tenancyId: widget.tenancyId!,
              onSubmitted: () => setState(() => composing = false),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => setState(() => composing = true),
                icon: const Icon(Icons.add),
                label: const Text('Report a problem'),
              ),
            ),
          gap(20),
        ],
        if (reports.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No problems reported.'),
          ),
        for (final report in reports)
          IssueCard(
            key: ValueKey(report['id']),
            report: report,
            initiallyExpanded: widget.reportId != null,
          ),
      ],
    );
  }
}

class IssueEntryForm extends StatefulWidget {
  final String tenancyId;
  final VoidCallback onSubmitted;
  const IssueEntryForm({
    super.key,
    required this.tenancyId,
    required this.onSubmitted,
  });
  @override
  State<IssueEntryForm> createState() => _IssueEntryFormState();
}

class _IssueEntryFormState extends State<IssueEntryForm> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController(),
      otherLocation = TextEditingController();
  String location = 'Inside my room', category = 'Repair or damage';
  final eventId = const Uuid().v4();
  bool busy = false;
  @override
  void dispose() {
    description.dispose();
    otherLocation.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final s = StoreScope.of(context);
    final ok = await perform(context, () async {
      await s.researchAction('case', {
        'tenancyId': widget.tenancyId,
        'eventId': eventId,
        'kind': category == 'Payment or account question' ? 'query' : 'repair',
        'body': {
          'category': category,
          'urgency': 'Routine',
          'incidentDate': isoDay(DateTime.now()),
          'cause': 'Unknown',
          'location': location == 'Other'
              ? otherLocation.text.trim()
              : location,
          'description': description.text.trim(),
          'accessAvailability': '',
        },
      });
    }, success: 'Problem sent to your landlord.');
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) {
      description.clear();
      otherLocation.clear();
      widget.onSubmitted();
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('Report a problem'),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'What is it about?'),
              isExpanded: true,
              items: [
                'Repair or damage',
                'Noise or shared spaces',
                'Payment or account question',
                'Other',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: busy ? null : (v) => setState(() => category = v!),
            ),
            gap(12),
            DropdownButtonFormField<String>(
              initialValue: location,
              decoration: const InputDecoration(
                labelText: 'Where is the problem?',
              ),
              isExpanded: true,
              items: [
                'Inside my room',
                'Shared yard',
                'Outside the building',
                'Gate or entrance',
                'Other',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: busy ? null : (v) => setState(() => location = v!),
            ),
            if (location == 'Other')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextFormField(
                  controller: otherLocation,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'Describe the location',
                  ),
                  validator: requiredField,
                ),
              ),
            gap(12),
            TextFormField(
              controller: description,
              enabled: !busy,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Describe the issue',
              ),
              validator: (v) => (v?.trim().length ?? 0) < 3
                  ? 'Describe the problem in a few words.'
                  : null,
            ),
            gap(12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: busy ? null : send,
                child: Text(busy ? 'Sending…' : 'Send issue'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class IssueCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool initiallyExpanded;
  const IssueCard({
    super.key,
    required this.report,
    this.initiallyExpanded = false,
  });
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        owner = s.currentUser!.role == Role.landlord;
    final t = s.tenancy(report['tenancyId']);
    final status = s.research.caseStatus(report), noted = status != 'open';
    final body = Map<String, dynamic>.from(report['body']);
    final replies = s.research
        .forTenancy(t.id, 'case_update')
        .where((x) => x['body']['parentId'] == report['id'])
        .toList();
    Future<void> update(String next, String text) => perform(context, () async {
      await s.researchAction('case', {
        'tenancyId': t.id,
        'eventId': const Uuid().v4(),
        'kind': 'case_update',
        'body': {'parentId': report['id'], 'status': next, 'message': text},
      });
    }).then((_) {});
    return Card(
      child: ExpansionTile(
        key: ValueKey('issue-${report['id']}'),
        initiallyExpanded: initiallyExpanded,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        title: Text(
          body['description']?.toString() ?? 'Reported problem',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Room ${t.room} · ${s.tenantAccount(t).name}'),
              Text(
                '${body['location'] ?? 'Location not specified'} · ${issueStatusLabel(status)}',
                style: TextStyle(
                  color: status == 'resolved'
                      ? Palette.green
                      : Palette.goldLight,
                ),
              ),
            ],
          ),
        ),
        children: [
          Text(body['description']?.toString() ?? ''),
          gap(12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stage in [
                'open',
                'acknowledged',
                'in_progress',
                'resolved',
              ])
                Chip(
                  avatar: Icon(
                    stage == status
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                  ),
                  label: Text(issueStatusLabel(stage)),
                ),
            ],
          ),
          if (owner && !noted)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => update(
                  'acknowledged',
                  'Landlord has acknowledged your issue.',
                ),
                icon: const Icon(Icons.check),
                label: const Text('Acknowledge issue'),
              ),
            ),
          if (noted)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline, color: Palette.green),
              title: Text('Acknowledged by landlord'),
            ),
          if (owner && noted && status != 'resolved')
            Wrap(
              spacing: 12,
              children: [
                if (status != 'in_progress')
                  TextButton(
                    onPressed: () => update(
                      'in_progress',
                      'Landlord is looking into this issue.',
                    ),
                    child: const Text('Mark in progress'),
                  ),
                TextButton(
                  onPressed: () => update(
                    'resolved',
                    'Landlord marked this issue resolved.',
                  ),
                  child: const Text('Mark resolved'),
                ),
              ],
            ),
          if (replies.isNotEmpty) ...[
            gap(12),
            for (final reply in replies)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reply['body']['message'] ?? ''),
                    Text(
                      reply['createdAt'].toString().split('T').first,
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (owner)
            PropertyMessage(
              propertyId: t.propertyId,
              tenancyId: t.id,
              parentId: report['id'],
            )
          else
            IssueReplyForm(tenancyId: t.id, parentId: report['id']),
        ],
      ),
    );
  }
}

class IssueReplyForm extends StatefulWidget {
  final String tenancyId, parentId;
  const IssueReplyForm({
    super.key,
    required this.tenancyId,
    required this.parentId,
  });
  @override
  State<IssueReplyForm> createState() => _IssueReplyFormState();
}

class _IssueReplyFormState extends State<IssueReplyForm> {
  final message = TextEditingController();
  String eventId = const Uuid().v4();
  bool busy = false;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: message,
        enabled: !busy,
        decoration: const InputDecoration(labelText: 'Reply to this issue'),
        maxLines: 2,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: busy
              ? null
              : () async {
                  if (message.text.trim().length < 3) {
                    tell(context, 'Write a short reply first.');
                    return;
                  }
                  setState(() => busy = true);
                  final ok = await perform(context, () async {
                    await StoreScope.of(context).researchAction('case', {
                      'tenancyId': widget.tenancyId,
                      'eventId': eventId,
                      'kind': 'case_update',
                      'body': {
                        'parentId': widget.parentId,
                        'status': 'comment',
                        'message': message.text.trim(),
                      },
                    });
                  }, success: 'Reply sent.');
                  if (mounted)
                    setState(() {
                      busy = false;
                      if (ok) {
                        message.clear();
                        eventId = const Uuid().v4();
                      }
                    });
                },
          child: Text(busy ? 'Sending…' : 'Send reply'),
        ),
      ),
    ],
  );
}

class PropertyMessage extends StatefulWidget {
  final String propertyId;
  final String? tenancyId, parentId;
  const PropertyMessage({
    super.key,
    required this.propertyId,
    this.tenancyId,
    this.parentId,
  });
  @override
  State<PropertyMessage> createState() => _PropertyMessageState();
}

class _PropertyMessageState extends State<PropertyMessage> {
  final message = TextEditingController();
  String eventId = const Uuid().v4();
  bool all = false, busy = false;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (message.text.trim().length < 3) {
      tell(context, 'Write a short update first.');
      return;
    }
    setState(() => busy = true);
    final s = StoreScope.of(context);
    final ok = await perform(context, () async {
      if (widget.tenancyId != null && !all && widget.parentId != null) {
        await s.researchAction('case', {
          'tenancyId': widget.tenancyId,
          'eventId': eventId,
          'kind': 'case_update',
          'body': {
            'parentId': widget.parentId,
            'status': 'comment',
            'message': message.text.trim(),
          },
        });
      } else {
        await s.researchAction('property_message', {
          'propertyId': widget.propertyId,
          'eventId': eventId,
          if (widget.tenancyId != null && !all) 'tenancyId': widget.tenancyId,
          'message': message.text.trim(),
        });
      }
    }, success: 'Update sent.');
    if (mounted)
      setState(() {
        busy = false;
        if (ok) {
          message.clear();
          eventId = const Uuid().v4();
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        linked = s.tenancies
            .where(
              (t) =>
                  t.propertyId == widget.propertyId &&
                  t.userId.isNotEmpty &&
                  t.endedOn == null,
            )
            .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tenancyId != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: all,
            onChanged: busy ? null : (v) => setState(() => all = v),
            title: Text(
              all ? 'All current tenants at this property' : 'Only this tenant',
            ),
            subtitle: all
                ? Text('$linked linked tenant accounts receive this update')
                : null,
          )
        else
          Text('$linked linked tenant accounts at this property'),
        if (all)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Share only information relevant to everyone; keep personal details private.',
              style: TextStyle(color: Palette.muted, fontSize: 12),
            ),
          ),
        TextField(
          controller: message,
          enabled: !busy,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Update message'),
        ),
        gap(8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: busy ? null : send,
            child: Text(busy ? 'Sending…' : 'Send update'),
          ),
        ),
      ],
    );
  }
}
