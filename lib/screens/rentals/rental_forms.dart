import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../shared/common.dart';

/// Occasional actions expand in place; primary tasks remain easy to find.
class RentalSection extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const RentalSection({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class InlineRentalForm extends StatefulWidget {
  final Map<String, String> fields, initial;
  final String label;
  final Future<void> Function(Map<String, String>, String) save;
  const InlineRentalForm({
    super.key,
    required this.fields,
    this.initial = const {},
    required this.label,
    required this.save,
  });
  @override
  State<InlineRentalForm> createState() => _InlineRentalFormState();
}

class _InlineRentalFormState extends State<InlineRentalForm> {
  final form = GlobalKey<FormState>();
  late final controls = {
    for (final k in widget.fields.keys)
      k: TextEditingController(text: widget.initial[k] ?? ''),
  };
  String eventId = const Uuid().v4();
  bool busy = false;
  @override
  void dispose() {
    for (final c in controls.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in widget.fields.entries)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              key: ValueKey('inline-${entry.key}'),
              controller: controls[entry.key],
              enabled: !busy,
              maxLines:
                  [
                    'message',
                    'reason',
                    'evidence',
                    'note',
                    'description',
                  ].contains(entry.key)
                  ? 2
                  : 1,
              decoration: InputDecoration(labelText: entry.value),
              validator: requiredField,
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setState(() => busy = true);
                    final ok = await perform(
                      context,
                      () => widget.save({
                        for (final e in controls.entries)
                          e.key: e.value.text.trim(),
                      }, eventId),
                      success: 'Saved.',
                    );
                    if (mounted)
                      setState(() {
                        busy = false;
                        if (ok) eventId = const Uuid().v4();
                      });
                  },
            child: Text(busy ? 'Saving…' : widget.label),
          ),
        ),
      ],
    ),
  );
}
