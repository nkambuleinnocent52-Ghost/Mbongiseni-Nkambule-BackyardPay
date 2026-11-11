import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/store.dart';
import '../../models/models.dart';
import '../../ui/design.dart';
import 'dashboard.dart';
import '../payments/payments.dart';
import '../properties/properties.dart';
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
      drawer: wide || user == null
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'BackyardPay',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('Overview'),
                      onTap: () {
                        Navigator.pop(context);
                        home(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Payments'),
                      onTap: () {
                        Navigator.pop(context);
                        open(context, const PaymentsScreen());
                      },
                    ),
                    if (user.role == Role.landlord) ...[
                      ListTile(
                        leading: const Icon(Icons.people_outline),
                        title: const Text('Tenants'),
                        onTap: () {
                          Navigator.pop(context);
                          open(context, const TenantsScreen());
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.apartment_outlined),
                        title: const Text('Properties'),
                        onTap: () {
                          Navigator.pop(context);
                          open(context, const PropertiesScreen());
                        },
                      ),
                    ],
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Notifications'),
                      onTap: () {
                        Navigator.pop(context);
                        open(context, const NotificationsScreen());
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Account'),
                      onTap: () {
                        Navigator.pop(context);
                        open(context, const ProfileScreen());
                      },
                    ),
                  ],
                ),
              ),
            ),
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (store.isCloud && user != null)
            IconButton(
              tooltip: 'Refresh records',
              onPressed: () => perform(context, store.refresh),
              icon: const Icon(Icons.sync),
            ),
          ...?actions,
        ],
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
              children: [
                if (store.isCloud && store.syncError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      store.syncError!,
                      style: const TextStyle(color: Palette.red),
                    ),
                  ),
                ...children,
              ],
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
String errorText(Object error) {
  if (error is AuthException) {
    if (error.message.toLowerCase().contains('database error saving'))
      return 'Account could not be created. Ask your landlord to check that your private invitation is correct, unused and linked to your assigned rental.';
    return error.message;
  }
  if (error is PostgrestException) {
    if (error.code == '23505')
      return 'That reference or record already exists. Refresh your records before trying again.';
    if (error.code == '23514' || error.code == '23502' || error.code == '22P02')
      return 'Check the required fields, amounts and dates.';
    if (error.code == 'PGRST202' || error.code == '42P01')
      return 'The cloud database setup is not complete yet. Ask the project owner to run the BackyardPay setup script.';
    if (error.code == '42501')
      return 'You do not have access to this action. Sign in and try again.';
    if (error.code == 'P0001') return error.message;
    return 'Your records could not be saved. Check your connection, refresh, and try again.';
  }
  return error.toString().replaceFirst(
    RegExp(r'^(Invalid argument\(s\)|Bad state|FormatException|Exception): ?'),
    '',
  );
}

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
  final List<String>? options;
  final List<String> Function(Map<String, String>)? optionsForValues;
  final String optionPrefix, emptyOptionsMessage;
  const FieldSpec(
    this.keyName,
    this.label, {
    this.initial = '',
    this.options,
    this.optionsForValues,
    this.optionPrefix = '',
    this.emptyOptionsMessage = 'No choices available',
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
  final Widget Function(BuildContext, Map<String, String>)? preview;
  const EditorPage({
    super.key,
    required this.title,
    required this.fields,
    required this.save,
    this.preview,
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

  Widget optionsField(FieldSpec f) {
    final values = controls.map((k, c) => MapEntry(k, c.text));
    final choices = f.optionsForValues?.call(values) ?? f.options!;
    final selected = choices.contains(controls[f.keyName]!.text)
        ? controls[f.keyName]!.text
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('${f.keyName}:${choices.join(',')}:$selected'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: f.label,
        helperText: choices.isEmpty ? f.emptyOptionsMessage : null,
        helperMaxLines: 2,
      ),
      disabledHint: Text(f.emptyOptionsMessage),
      items: choices
          .map(
            (s) =>
                DropdownMenuItem(value: s, child: Text('${f.optionPrefix}$s')),
          )
          .toList(),
      validator: (v) => f.optional
          ? null
          : choices.isEmpty
          ? f.emptyOptionsMessage
          : v == null
          ? 'Choose an available option'
          : null,
      onChanged: busy || choices.isEmpty
          ? null
          : (v) => setState(() => controls[f.keyName]!.text = v!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fields.any((f) => f.optionsForValues != null))
      StoreScope.of(context);
    return PageShell(
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
                  child: f.options != null || f.optionsForValues != null
                      ? optionsField(f)
                      : TextFormField(
                          onChanged: (_) {
                            if (widget.preview != null) setState(() {});
                          },
                          key: ValueKey(f.keyName),
                          controller: controls[f.keyName],
                          decoration: InputDecoration(labelText: f.label),
                          obscureText: f.secret,
                          keyboardType: f.numeric
                              ? const TextInputType.numberWithOptions(
                                  decimal: true,
                                )
                              : TextInputType.text,
                          maxLines: f.multiline ? 3 : 1,
                          validator: f.optional ? null : requiredField,
                          enabled: !busy,
                        ),
                ),
              if (widget.preview != null)
                widget.preview!(
                  context,
                  controls.map((k, c) => MapEntry(k, c.text)),
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
}
