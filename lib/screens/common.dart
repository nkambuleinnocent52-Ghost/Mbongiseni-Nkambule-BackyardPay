import 'package:flutter/material.dart';

import '../data/store.dart';

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class PageShell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  const PageShell({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: children,
          ),
        ),
      ),
    ),
  );
}

Widget panel(Widget child) => Card(
  child: Padding(padding: const EdgeInsets.all(18), child: child),
);
Widget gap([double height = 16]) => SizedBox(height: height);
Widget heading(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Text(
    text,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
  ),
);
Widget detail(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Text('$label: $value'),
);
Widget action(
  String text,
  VoidCallback? callback, {
  IconData icon = Icons.arrow_forward,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: FilledButton.icon(
    onPressed: callback,
    icon: Icon(icon),
    label: Text(text),
  ),
);
void open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
void home(BuildContext context) =>
    Navigator.of(context).popUntil((r) => r.isFirst);
String errorText(Object error) => error.toString().replaceFirst(
  RegExp(r'^(Invalid argument\(s\)|Bad state|FormatException|Exception): ?'),
  '',
);
void tell(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
Future<bool> perform(
  BuildContext context,
  Future<void> Function() operation, {
  String? success,
}) async {
  try {
    await operation();
    if (context.mounted && success != null) tell(context, success);
    return true;
  } catch (error) {
    if (context.mounted) tell(context, errorText(error));
    return false;
  }
}

String? requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

class FieldSpec {
  final String keyName, label, initial;
  final bool secret, numeric, multiline;
  const FieldSpec(
    this.keyName,
    this.label, {
    this.initial = '',
    this.secret = false,
    this.numeric = false,
    this.multiline = false,
  });
}

class EditorPage extends StatefulWidget {
  final String title, button, help;
  final List<FieldSpec> fields;
  final Future<void> Function(Map<String, String>) save;
  const EditorPage({
    super.key,
    required this.title,
    required this.fields,
    required this.save,
    this.button = 'Save',
    this.help = '',
  });
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controls = {
    for (final f in widget.fields)
      f.keyName: TextEditingController(text: f.initial),
  };
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save(controls.map((key, c) => MapEntry(key, c.text)));
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: widget.title,
    children: [
      if (widget.help.isNotEmpty) panel(Text(widget.help)),
      Form(
        key: form,
        child: Column(
          children: [
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  key: ValueKey(f.keyName),
                  controller: controls[f.keyName],
                  decoration: InputDecoration(labelText: f.label),
                  obscureText: f.secret,
                  keyboardType: f.numeric
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  maxLines: f.multiline ? 3 : 1,
                  validator: requiredField,
                  enabled: !busy,
                ),
              ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            action(
              busy ? 'Saving…' : widget.button,
              busy ? null : submit,
              icon: Icons.save_outlined,
            ),
          ],
        ),
      ),
    ],
  );
}
