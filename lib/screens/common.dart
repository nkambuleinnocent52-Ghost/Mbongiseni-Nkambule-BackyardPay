import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../ui/design.dart';
import 'dashboard.dart';
import 'payments.dart';
import 'properties.dart';
import 'profile.dart';

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
  final double maxWidth;
  const PageShell({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.maxWidth = 1150,
  });
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), user = store.currentUser;
    final wide = MediaQuery.sizeOf(context).width >= 1180 && user != null;
    final content = Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 18 : 30,
              ),
              children: children,
            ),
          ),
        ),
      ),
    );
    if (!wide) return content;
    return Row(
      children: [
        SizedBox(
          width: 230,
          child: Material(
            color: const Color(0xFF101114),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 26,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        BrandMark(size: 37),
                        SizedBox(width: 10),
                        Text(
                          'BACKYARDPAY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 38),
                    Text(
                      '${user.role.name.toUpperCase()} WORKSPACE',
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _nav(
                      context,
                      'Overview',
                      Icons.space_dashboard_outlined,
                      title.contains('dashboard'),
                      () => home(context),
                    ),
                    _nav(
                      context,
                      'Payments',
                      Icons.receipt_long_outlined,
                      title == 'Payment records',
                      () => open(context, const PaymentsScreen()),
                    ),
                    if (user.role == Role.landlord) ...[
                      _nav(
                        context,
                        'Tenants',
                        Icons.people_outline,
                        title == 'My tenants',
                        () => open(context, const TenantsScreen()),
                      ),
                      _nav(
                        context,
                        'Properties',
                        Icons.apartment_outlined,
                        title.contains('propert'),
                        () => open(context, const PropertiesScreen()),
                      ),
                    ],
                    _nav(
                      context,
                      'Notifications',
                      Icons.notifications_outlined,
                      title == 'Notifications',
                      () => open(context, const NotificationsScreen()),
                    ),
                    _nav(
                      context,
                      'Account',
                      Icons.person_outline,
                      title == 'My profile',
                      () => open(context, const ProfileScreen()),
                    ),
                    const Spacer(),
                    const Divider(),
                    Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.email,
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'CLARITY IN EVERY RENTAL.',
                      style: TextStyle(
                        fontSize: 9,
                        color: Palette.gold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: content),
      ],
    );
  }

  Widget _nav(
    BuildContext context,
    String label,
    IconData icon,
    bool selected,
    VoidCallback callback,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: TextButton.icon(
      onPressed: selected ? () {} : callback,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: selected
            ? const Color(0xFF302817)
            : Colors.transparent,
        foregroundColor: selected ? Palette.goldLight : Palette.muted,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 19),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    ),
  );
}

Widget panel(Widget child) => Card(
  child: Padding(padding: const EdgeInsets.all(22), child: child),
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
  final bool secret, numeric, multiline, optional;
  const FieldSpec(
    this.keyName,
    this.label, {
    this.initial = '',
    this.secret = false,
    this.numeric = false,
    this.multiline = false,
    this.optional = false,
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
    maxWidth: 680,
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
                  validator: f.optional ? null : requiredField,
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
