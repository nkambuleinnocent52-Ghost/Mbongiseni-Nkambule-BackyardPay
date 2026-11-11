part of 'dashboard.dart';

// Shared month selector, totals and navigation used by both role pages.
class _DashboardLayout extends StatefulWidget {
  final Role role;
  final List<Widget> Function(BuildContext, String) contentBuilder;
  const _DashboardLayout({required this.role, required this.contentBuilder});
  @override
  State<_DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<_DashboardLayout> {
  String period = periodOf(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context), user = store.currentUser;
    if (user == null || user.role != widget.role)
      return const Scaffold(body: SizedBox.shrink());
    final owner = user.role == Role.landlord, ts = store.tenancies;
    final expected = ts.fold(0, (sum, t) => sum + store.expected(t, period));
    final collected = ts.fold(0, (sum, t) => sum + store.collected(t, period));
    final pending = store.payments
        .where((p) => p.period == period && p.state == ReviewState.pending)
        .toList();
    final unread = store.notices.where((n) => !n.read).length;
    final balance = math.max(0, expected - collected), first = ts.firstOrNull;
    final arrears = ts.fold(0, (sum, t) => sum + store.totalArrears(t));
    final reviewAmount = pending.fold(0, (sum, p) => sum + p.amountCents);
    return PageShell(
      title: owner ? 'Landlord dashboard' : 'Tenant dashboard',
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: () => open(context, const ProfileScreen()),
          icon: const Icon(Icons.person_outline),
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owner ? 'YOUR PROPERTY PORTFOLIO' : 'YOUR RENTAL WORKSPACE',
                    style: const TextStyle(
                      color: Palette.gold,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  heading('Hello, ${user.name}'),
                  Text(
                    owner
                        ? 'A clear view of every room, every tenant and every rand.'
                        : 'Your home, your payments and your peace of mind.',
                    style: const TextStyle(color: Palette.muted, height: 1.7),
                  ),
                ],
              ),
            ),
          ],
        ),
        const RentalPaymentRules(),
        gap(10),
        if (!owner && first != null) DepositReminderNotice(tenancyId: first.id),
        Align(
          alignment: Alignment.centerLeft,
          child: MonthSelector(
            period: period,
            onChanged: (v) => setState(() => period = v),
          ),
        ),
        gap(18),
        GoldHero(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                owner
                    ? 'CONFIRMED RENT • ${monthLabel(period).toUpperCase()}'
                    : 'REMAINING RENT • ${monthLabel(period).toUpperCase()}',
                style: const TextStyle(
                  color: Palette.goldLight,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              gap(18),
              Text(
                money(owner ? collected : balance),
                style: const TextStyle(
                  fontSize: 43,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              gap(12),
              Text(
                owner
                    ? '${expected == 0 ? 0 : (collected / expected * 100).round()}% of ${money(expected)} expected rent has been confirmed.'
                    : balance == 0 && expected > 0
                    ? 'All settled for this month. Your confirmed receipts are ready.'
                    : '${money(collected)} confirmed · ${money(reviewAmount)} waiting for review',
                style: const TextStyle(
                  color: Palette.muted,
                  height: 1.8,
                  fontSize: 12,
                ),
              ),
              gap(18),
              SizedBox(
                width: 360,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: expected == 0
                        ? 0
                        : (collected / expected).clamp(0, 1),
                    minHeight: 6,
                    color: Palette.gold,
                    backgroundColor: Palette.border,
                  ),
                ),
              ),
              gap(20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatusPill(
                    owner
                        ? '${pending.length} awaiting review'
                        : first == null
                        ? 'No rental'
                        : store.rentStatus(first, period),
                  ),
                  if (!owner && first != null)
                    StatusPill(
                      'Due ${dateLabel(store.dueDate(first, period))}',
                    ),
                ],
              ),
            ],
          ),
        ),
        gap(18),
        LayoutBuilder(
          builder: (context, c) {
            final count = c.maxWidth >= 960
                ? 4
                : c.maxWidth >= 320
                ? 2
                : 1;
            final metrics = [
              MetricCard(
                label: owner ? 'Expected rent' : 'Monthly rent',
                value: money(expected),
                icon: Icons.account_balance_wallet_outlined,
                caption: monthLabel(period),
              ),
              Semantics(
                label:
                    '${store.researchReady ? 'Recorded balance' : 'Outstanding'}: ${money(balance)}',
                child: MetricCard(
                  label: store.researchReady
                      ? 'Recorded balance'
                      : 'Outstanding',
                  value: money(balance),
                  icon: Icons.pie_chart_outline,
                  caption: 'Pending submissions are not deducted',
                  highlight: balance > 0,
                ),
              ),
              MetricCard(
                label: owner
                    ? 'Past-due recorded balance'
                    : 'Past-due recorded balance',
                value: money(arrears),
                icon: Icons.history_rounded,
                caption: 'Confirmed-record balance past due date',
              ),
              MetricCard(
                label: owner ? 'Occupied rooms' : 'Deposit still due',
                value: owner
                    ? '${ts.where(store.isOccupied).length} / ${store.properties.fold(0, (sum, p) => sum + p.rooms)}'
                    : first?.depositCents == null
                    ? 'Not recorded'
                    : money(
                        math.max(
                          0,
                          first!.depositCents! -
                              (store.researchReady
                                  ? store.research.depositReceived(first)
                                  : (first.depositReceivedCents ?? 0)),
                        ),
                      ),
                icon: owner
                    ? Icons.meeting_room_outlined
                    : Icons.savings_outlined,
                caption: owner
                    ? 'Current occupancy across properties'
                    : 'Kept separate from rent',
              ),
            ];
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final m in metrics)
                  SizedBox(
                    width: (c.maxWidth - 14 * (count - 1)) / count,
                    child: m,
                  ),
              ],
            );
          },
        ),
        gap(24),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (!owner && first != null)
              action(
                'Record payment',
                () => open(context, PaymentFormScreen(tenancyId: first.id)),
                icon: Icons.add_card,
              ),
            action(
              owner ? 'Payment records' : 'Payment history',
              () => open(context, const PaymentsScreen()),
              icon: Icons.receipt_long_outlined,
            ),
            if (!owner && first != null)
              action(
                'Monthly rental account',
                () => open(context, RentalAccountScreen(tenancyId: first.id)),
                icon: Icons.calendar_month_outlined,
              ),
            action(
              'Notifications ($unread)',
              () => open(context, const NotificationsScreen()),
              icon: Icons.notifications_outlined,
            ),
            action(
              'Profile',
              () => open(context, const ProfileScreen()),
              icon: Icons.person_outline,
            ),
            if (owner) ...[
              action(
                'My tenants',
                () => open(context, const TenantsScreen()),
                icon: Icons.people_outline,
              ),
              action(
                'My properties',
                () => open(context, const PropertiesScreen()),
                icon: Icons.apartment_outlined,
              ),
            ],
          ],
        ),
        if (store.researchReady) ...[
          gap(16),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Balances use payments the landlord has confirmed for each month. Check pending payments and any money not yet linked to a month before asking for more rent.',
                  style: TextStyle(color: Palette.muted, height: 1.7),
                ),
                if (!owner && ts.every((t) => t.endedOn != null))
                  action(
                    'Join another rental',
                    () => open(
                      context,
                      EditorPage(
                        title: 'Join another rental',
                        help: 'Use the private invitation for your new rental. Your old records remain available.',
                        fields: const [
                          FieldSpec(
                            'invitation',
                            'Private invitation from landlord',
                          ),
                        ],
                        save: (v) async {
                          await store.researchAction('join_rental', {
                            'invitation': v['invitation'],
                          });
                        },
                      ),
                    ),
                  ),
                if (!owner && first != null) RentalCosts(tenancy: first),
                if (owner)
                  detail(
                    'Security deposits still due',
                    money(
                      ts.fold<int>(
                        0,
                        (sum, t) =>
                            sum + (store.research.depositOutstanding(t) ?? 0),
                      ),
                    ),
                  ),
                detail(
                  'Money received but not yet linked to a month',
                  money(ts.fold(0, (sum, t) => sum + store.creditFor(t))),
                ),
                detail(
                  'Open reports / account queries',
                  '${store.caseRecords.where((r) => ['repair', 'query'].contains(r['kind']) && store.research.caseStatus(r) != 'resolved').length}',
                ),
                if (owner) ...[
                  detail(
                    'Incomplete essential lease records',
                    '${ts.where((t) => ['landlordAddress', 'tenantAddress', 'authority', 'dwellingDescription', 'sharedFacilities', 'paymentInstructions', 'noticeTerms', 'escalationTerms', 'otherCharges'].any((k) => (t.record[k]?.toString().trim() ?? '').isEmpty)).length}',
                  ),
                  detail(
                    'Planned term ended; handover not recorded',
                    '${ts.where((t) => t.endedOn == null && t.leaseEnd != null && t.leaseEnd!.isBefore(DateTime.now())).length}',
                  ),
                ],
                if (owner)
                  action(
                    'Tenant reports',
                    () => open(context, const SimpleReportsScreen()),
                    icon: Icons.report_outlined,
                  ),
                if (owner)
                  action(
                    'Add tenant record',
                    () => createTenantRecord(context),
                  ),
                if (!owner && first != null)
                  action(
                    'Report a problem / account query',
                    () =>
                        open(context, SimpleReportsScreen(tenancyId: first.id)),
                  ),
              ],
            ),
          ),
        ],
        gap(20),
        ...widget.contentBuilder(context, period),
        gap(24),
        const Text(
          'Only landlord-confirmed payments reduce rent balances. Bank payments are made outside BackyardPay.',
          style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.7),
        ),
      ],
    );
  }
}
