import 'package:flutter/material.dart';

import '../models/models.dart';
import 'common.dart';
import '../ui/design.dart';

import 'login_page.dart';

export 'login_page.dart' show AuthScreen;
export 'password_reset_request.dart' show PasswordResetRequestScreen;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 650 ? 22 : 48,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    BrandMark(),
                    SizedBox(width: 14),
                    Text(
                      'BACKYARDPAY',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                gap(40),
                LayoutBuilder(
                  builder: (context, c) {
                    final intro = GoldHero(
                      height: c.maxWidth > 850 ? 560 : 340,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DIGITAL RENTAL MANAGEMENT',
                            style: TextStyle(
                              color: Palette.gold,
                              fontSize: 11,
                              letterSpacing: 2,
                            ),
                          ),
                          gap(24),
                          Text(
                            'Your rental.\nIn perfect order.',
                            style: TextStyle(
                              fontSize: c.maxWidth > 850 ? 52 : 36,
                              fontWeight: FontWeight.w700,
                              height: 1.18,
                              letterSpacing: -1,
                            ),
                          ),
                          gap(22),
                          if (c.maxWidth <= 850) ...[
                            action(
                              'GET STARTED',
                              busy
                                  ? null
                                  : () => open(context, const UserTypeScreen()),
                            ),
                            gap(18),
                          ],
                          const SizedBox(
                            width: 390,
                            child: Text(
                              'Know who has paid. See what is still owed. Keep a clear record for every room and every month.',
                              style: TextStyle(
                                color: Palette.muted,
                                fontSize: 16,
                                height: 1.8,
                              ),
                            ),
                          ),
                          gap(32),
                          const Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              StatusPill('Clear balances'),
                              StatusPill('Confirmed receipts'),
                              StatusPill('Two connected roles'),
                            ],
                          ),
                          gap(32),
                          const Text(
                            'Rental payment recording made simple.',
                            style: TextStyle(
                              color: Palette.goldLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                    final entry = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading('A better place to manage rent'),
                        const Text(
                          'Digital Rental Management',
                          style: TextStyle(color: Palette.muted, height: 1.7),
                        ),
                        gap(22),
                        if (c.maxWidth > 850)
                          action(
                            'GET STARTED',
                            busy
                                ? null
                                : () => open(context, const UserTypeScreen()),
                          ),
                        gap(12),
                        const Text(
                          'Already registered? Choose your role and sign in. New landlords can create a property and invite a tenant with its code.',
                          style: TextStyle(
                            color: Palette.muted,
                            height: 1.8,
                            fontSize: 12,
                          ),
                        ),
                        gap(22),
                        const Divider(),
                        gap(),
                        const Text(
                          'Your records are saved to your account. BackyardPay records payments; it never moves money.',
                          style: TextStyle(
                            color: Palette.muted,
                            fontSize: 11,
                            height: 1.7,
                          ),
                        ),
                      ],
                    );
                    return c.maxWidth > 850
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: intro),
                              const SizedBox(width: 56),
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: entry,
                                ),
                              ),
                            ],
                          )
                        : Column(children: [intro, gap(24), panel(entry)]);
                  },
                ),
                gap(30),
                const Text(
                  'BUILT FOR BACKYARD COMMUNITIES. DESIGNED FOR EVERYDAY CLARITY.',
                  style: TextStyle(
                    color: Palette.muted,
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class UserTypeScreen extends StatelessWidget {
  const UserTypeScreen({super.key});
  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Welcome to BackyardPay',
    children: [
      const Text(
        'YOUR SPACE. YOUR ROLE.',
        style: TextStyle(color: Palette.gold, fontSize: 11, letterSpacing: 2),
      ),
      heading('How will you use the app?'),
      const Text(
        'Choose the workspace that fits your rental journey.',
        style: TextStyle(color: Palette.muted),
      ),
      gap(18),
      for (final role in Role.values)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                role == Role.landlord
                    ? Icons.home_work_rounded
                    : Icons.person_rounded,
                size: 38,
              ),
              action(
                role.name.toUpperCase(),
                () => open(context, AuthScreen(role: role)),
              ),
              Text(
                role == Role.landlord
                    ? 'Manage my rental property'
                    : 'Manage my rental payments',
              ),
            ],
          ),
        ),
      gap(),
      const Text(
        'The landlord assigns the room first and shares a private invitation. Tenants use that invitation once to create their own login.',
      ),
    ],
  );
}
