import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../../ui/design.dart';
import '../shared/common.dart';
import 'research_records.dart' show isoDay;

import 'rental_forms.dart';

class SimpleReportsScreen extends StatelessWidget {
  final String? tenancyId;
  const SimpleReportsScreen({super.key, this.tenancyId});
  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Reported problems',
    maxWidth: 900,
    children: [SimpleReports(tenancyId: tenancyId)],
  );
}

class SimpleReports extends StatelessWidget {
  final String? tenancyId;
  const SimpleReports({super.key, this.tenancyId});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context),
        owner = s.currentUser!.role == Role.landlord;
    final reports =
        s.caseRecords
            .where(
              (r) =>
                  ['repair', 'query'].contains(r['kind']) &&
                  (tenancyId == null || r['tenancyId'] == tenancyId),
            )
            .toList()
          ..sort(
            (a, b) => (b['createdAt'] as String).compareTo(a['createdAt']),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tenancyId != null && !owner)
          InlineRentalForm(
            fields: const {
              'location': 'Where is the problem?',
              'description': 'Describe the issue',
            },
            label: 'Send issue',
            save: (v, id) async {
              await s.researchAction('case', {
                'tenancyId': tenancyId,
                'eventId': id,
                'kind': 'repair',
                'body': {
                  'category': 'Other',
                  'urgency': 'Routine',
                  'incidentDate': isoDay(DateTime.now()),
                  'cause': 'Unknown',
                  'location': v['location'],
                  'description': v['description'],
                  'accessAvailability': '',
                },
              });
            },
          ),
        if (reports.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No issues reported.'),
          ),
        for (final r in reports)
          Builder(
            builder: (context) {
              final noted = s.research.caseStatus(r) != 'open',
                  t = s.tenancy(r['tenancyId']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Room ${t.room} · ${s.tenantAccount(t).name}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(r['body']['description']),
                    if (r['body']['location'] != null)
                      Text(
                        r['body']['location'],
                        style: const TextStyle(color: Palette.muted),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: noted,
                      onChanged: owner && !noted
                          ? (v) => perform(
                              context,
                              () => s.researchAction('case', {
                                'tenancyId': t.id,
                                'eventId': const Uuid().v4(),
                                'kind': 'case_update',
                                'body': {
                                  'parentId': r['id'],
                                  'status': 'in_progress',
                                  'message': 'Landlord has noted your issue.',
                                },
                              }),
                            )
                          : null,
                      title: const Text('Noted by landlord'),
                      subtitle: Text(
                        noted
                            ? 'Acknowledgement visible to both parties'
                            : 'Waiting for acknowledgement',
                      ),
                    ),
                    if (s.research.caseStatus(r) == 'resolved')
                      const Text(
                        'Resolved',
                        style: TextStyle(color: Palette.green),
                      ),
                    if (owner &&
                        noted &&
                        s.research.caseStatus(r) != 'resolved')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => perform(
                            context,
                            () => s.researchAction('case', {
                              'tenancyId': t.id,
                              'eventId': const Uuid().v4(),
                              'kind': 'case_update',
                              'body': {
                                'parentId': r['id'],
                                'status': 'resolved',
                                'message':
                                    'Landlord marked this issue resolved.',
                              },
                            }),
                          ),
                          child: const Text('Mark resolved'),
                        ),
                      ),
                    for (final reply
                        in s.research
                            .forTenancy(t.id, 'case_update')
                            .where((x) => x['body']['parentId'] == r['id']))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${reply['body']['message']} · ${reply['createdAt'].toString().split('T').first}',
                          style: const TextStyle(color: Palette.muted),
                        ),
                      ),
                    RentalSection(
                      title: owner ? 'Reply / send update' : 'Add message',
                      children: [
                        if (owner)
                          PropertyMessage(
                            propertyId: t.propertyId,
                            tenancyId: t.id,
                            parentId: r['id'],
                          )
                        else
                          InlineRentalForm(
                            fields: const {'message': 'Message'},
                            label: 'Send message',
                            save: (v, id) async {
                              await s.researchAction('case', {
                                'tenancyId': t.id,
                                'eventId': id,
                                'kind': 'case_update',
                                'body': {
                                  'parentId': r['id'],
                                  'status': 'comment',
                                  'message': v['message'],
                                },
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
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
  bool all = false;
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
      children: [
        if (widget.tenancyId != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: all,
            onChanged: (v) => setState(() => all = v),
            title: Text(
              all ? 'All current tenants at this property' : 'Only this tenant',
            ),
            subtitle: Text(
              all
                  ? '$linked linked tenant accounts receive the update'
                  : 'The issue remains private',
            ),
          )
        else
          Text('$linked linked tenant accounts at this property'),
        const Text(
          'In-app notification only. Do not include a tenant’s private information in a shared update.',
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
        InlineRentalForm(
          fields: const {'message': 'Update message'},
          label: 'Send update',
          save: (v, id) async {
            if (widget.tenancyId != null && !all && widget.parentId != null) {
              await s.researchAction('case', {
                'tenancyId': widget.tenancyId,
                'eventId': id,
                'kind': 'case_update',
                'body': {
                  'parentId': widget.parentId,
                  'status': 'comment',
                  'message': v['message'],
                },
              });
            } else {
              final sent = await s.researchAction('property_message', {
                'propertyId': widget.propertyId,
                'eventId': id,
                if (widget.tenancyId != null && !all)
                  'tenancyId': widget.tenancyId,
                'message': v['message'],
              });
              if (context.mounted)
                tell(context, 'Update sent to $sent tenant account(s).');
            }
          },
        ),
      ],
    );
  }
}
