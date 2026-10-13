import 'package:flutter/material.dart';

void main() {
  runApp(const BackyardPayApp());
}

// ============================================================
// BACKYARDPAY COLOUR PALETTE
// ============================================================

class AppColors {
  // Primary
  static const Color royalGold = Color(0xFFFFB800);
  static const Color sunriseOrange = Color(0xFFFF6B00);

  // Premium / Accent
  static const Color royalPurple = Color(0xFF6A0DAD);

  // Backgrounds
  static const Color deepNavy = Color(0xFF0A1931);
  static const Color warmBlack = Color(0xFF1A1A1A);
  static const Color creamWhite = Color(0xFFFFF8E7);

  // Supporting colours
  static const Color white = Colors.white;
  static const Color lightGold = Color(0xFFFFE7A3);
  static const Color lightOrange = Color(0xFFFFE0CC);
  static const Color lightPurple = Color(0xFFEBD9F7);
  static const Color greyText = Color(0xFF64748B);
  static const Color border = Color(0xFFE7DCC4);
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);
}

// ============================================================
// MAIN APP
// ============================================================

class BackyardPayApp extends StatelessWidget {
  const BackyardPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BackyardPay',

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',

        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.royalGold,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.royalGold,
          secondary: AppColors.sunriseOrange,
          tertiary: AppColors.royalPurple,
          surface: AppColors.creamWhite,
        ),

        scaffoldBackgroundColor: AppColors.creamWhite,

        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.creamWhite,
          foregroundColor: AppColors.deepNavy,
          elevation: 0,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.royalGold,
              width: 2,
            ),
          ),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}

// ============================================================
// SCREEN 1 — SPLASH SCREEN
// ============================================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                // ==================================================
                // LOGO
                // ==================================================

                Container(
                  width: 105,
                  height: 105,

                  decoration: BoxDecoration(
                    color: AppColors.royalGold,
                    borderRadius: BorderRadius.circular(30),

                    boxShadow: [
                      BoxShadow(
                        color: AppColors.royalGold.withValues(
                          alpha: 0.30,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons.home_work_rounded,
                    color: AppColors.deepNavy,
                    size: 58,
                  ),
                ),

                const SizedBox(height: 30),

                // ==================================================
                // APP NAME
                // ==================================================

                const Text(
                  'BACKYARDPAY',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: AppColors.deepNavy,
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // DESCRIPTION
                // ==================================================

                const Text(
                  'Digital Rental Management',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sunriseOrange,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Transforming Informal Rentals\nThrough Digital Finance',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.greyText,
                  ),
                ),

                const SizedBox(height: 50),

                // ==================================================
                // GET STARTED BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 56,

                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const UserTypeScreen(),
                        ),
                      );
                    },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.royalGold,
                      foregroundColor: AppColors.deepNavy,

                      elevation: 3,

                      shadowColor:
                          AppColors.royalGold.withValues(
                        alpha: 0.35,
                      ),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),

                    child: const Text(
                      'GET STARTED',

                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Rental payment recording made simple.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 2 — CHOOSE USER TYPE
// ============================================================

class UserTypeScreen extends StatelessWidget {
  const UserTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.deepNavy,
          ),

          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: Column(
            children: [

              const SizedBox(height: 35),

              // ==================================================
              // WELCOME
              // ==================================================

              const Text(
                'WELCOME TO',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.sunriseOrange,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'BACKYARDPAY',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.deepNavy,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'How will you use the app?',

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 17,
                  color: AppColors.greyText,
                ),
              ),

              const SizedBox(height: 45),

              // ==================================================
              // LANDLORD
              // ==================================================

              UserTypeCard(
                icon: Icons.home_work_rounded,

                title: 'LANDLORD',

                description:
                    'Manage my rental property',

                iconColor: AppColors.royalPurple,

                iconBackground:
                    AppColors.lightPurple,

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const LoginScreen(
                        userType: 'Landlord',
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ==================================================
              // TENANT
              // ==================================================

              UserTypeCard(
                icon: Icons.person_rounded,

                title: 'TENANT',

                description:
                    'Manage my rental payments',

                iconColor: AppColors.sunriseOrange,

                iconBackground:
                    AppColors.lightOrange,

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const LoginScreen(
                        userType: 'Tenant',
                      ),
                    ),
                  );
                },
              ),

              const Spacer(),

              const Padding(
                padding: EdgeInsets.only(bottom: 25),

                child: Text(
                  'Choose the account type that applies to you.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.greyText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// USER TYPE CARD
// ============================================================

class UserTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  final Color iconColor;
  final Color iconBackground;

  final VoidCallback onTap;

  const UserTypeCard({
    super.key,

    required this.icon,
    required this.title,
    required this.description,

    required this.iconColor,
    required this.iconBackground,

    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: Container(
          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(20),

            border: Border.all(
              color: AppColors.border,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.06,
                ),

                blurRadius: 14,

                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Row(
            children: [

              // ==================================================
              // ICON
              // ==================================================

              Container(
                width: 60,
                height: 60,

                decoration: BoxDecoration(
                  color: iconBackground,

                  borderRadius:
                      BorderRadius.circular(16),
                ),

                child: Icon(
                  icon,

                  color: iconColor,

                  size: 32,
                ),
              ),

              const SizedBox(width: 18),

              // ==================================================
              // TEXT
              // ==================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      title,

                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepNavy,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      description,

                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios_rounded,

                size: 18,

                color: AppColors.sunriseOrange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 3 — LOGIN
// ============================================================

class LoginScreen extends StatefulWidget {
  final String userType;

  const LoginScreen({
    super.key,
    required this.userType,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey =
      GlobalKey<FormState>();

  final TextEditingController
      _emailPhoneController =
      TextEditingController();

  final TextEditingController
      _passwordController =
      TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailPhoneController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  void _login() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (widget.userType == 'Landlord') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const LandlordDashboard(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const TenantDashboard(),
        ),
      );
    }
  }

  // ==========================================================
  // FORGOT PASSWORD
  // ==========================================================

  void _forgotPassword() {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Password recovery will be added.',
        ),

        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // CREATE ACCOUNT
  // ==========================================================

  void _createAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistrationScreen(
          userType: widget.userType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTenant =
        widget.userType == 'Tenant';

    return Scaffold(
      backgroundColor: AppColors.creamWhite,

      appBar: AppBar(
        backgroundColor:
            AppColors.creamWhite,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,

            color:
                AppColors.deepNavy,
          ),

          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 15,
          ),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const SizedBox(height: 10),

                // ==================================================
                // LOGIN ICON
                // ==================================================

                Center(
                  child: Container(
                    width: 82,
                    height: 82,

                    decoration:
                        BoxDecoration(
                      color: isTenant
                          ? AppColors.lightOrange
                          : AppColors.lightPurple,

                      borderRadius:
                          BorderRadius.circular(
                        24,
                      ),
                    ),

                    child: Icon(
                      isTenant
                          ? Icons.person_rounded
                          : Icons.home_work_rounded,

                      color: isTenant
                          ? AppColors.sunriseOrange
                          : AppColors.royalPurple,

                      size: 42,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // ==================================================
                // APP NAME
                // ==================================================

                const Center(
                  child: Text(
                    'BACKYARDPAY',

                    style: TextStyle(
                      fontSize: 25,
                      fontWeight:
                          FontWeight.bold,

                      letterSpacing: 1.2,

                      color:
                          AppColors.deepNavy,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ==================================================
                // WELCOME BACK
                // ==================================================

                const Center(
                  child: Text(
                    'Welcome Back 👋',

                    style: TextStyle(
                      fontSize: 27,
                      fontWeight:
                          FontWeight.bold,

                      color:
                          AppColors.deepNavy,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    'Sign in as a ${widget.userType.toLowerCase()}',

                    style:
                        const TextStyle(
                      fontSize: 15,
                      color:
                          AppColors.greyText,
                    ),
                  ),
                ),

                const SizedBox(height: 38),

                // ==================================================
                // EMAIL / PHONE
                // ==================================================

                const Text(
                  'Email / Phone',

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,

                    color:
                        AppColors.deepNavy,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _emailPhoneController,

                  keyboardType:
                      TextInputType.emailAddress,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Enter your email or phone',

                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color:
                          AppColors.greyText,
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter your email or phone';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // ==================================================
                // PASSWORD
                // ==================================================

                const Text(
                  'Password',

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,

                    color:
                        AppColors.deepNavy,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _passwordController,

                  obscureText:
                      _obscurePassword,

                  decoration:
                      InputDecoration(
                    hintText:
                        'Enter your password',

                    prefixIcon:
                        const Icon(
                      Icons.lock_outline_rounded,

                      color:
                          AppColors.greyText,
                    ),

                    suffixIcon:
                        IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons
                                .visibility_off_outlined,

                        color:
                            AppColors.greyText,
                      ),

                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                              !_obscurePassword;
                        });
                      },
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please enter your password';
                    }

                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // ==================================================
                // FORGOT PASSWORD
                // ==================================================

                Align(
                  alignment:
                      Alignment.centerRight,

                  child: TextButton(
                    onPressed:
                        _forgotPassword,

                    child: const Text(
                      'Forgot Password?',

                      style: TextStyle(
                        color:
                            AppColors.royalPurple,

                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // LOGIN BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 56,

                  child: ElevatedButton(
                    onPressed: _login,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.royalGold,

                      foregroundColor:
                          AppColors.deepNavy,

                      elevation: 3,

                      shadowColor:
                          AppColors.royalGold
                              .withValues(
                        alpha: 0.35,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),

                    child: const Text(
                      'LOGIN',

                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,

                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ==================================================
                // CREATE ACCOUNT
                // ==================================================

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [

                    const Text(
                      "Don't have an account? ",

                      style: TextStyle(
                        color:
                            AppColors.greyText,
                      ),
                    ),

                    TextButton(
                      onPressed:
                          _createAccount,

                      child: const Text(
                        'Create Account',

                        style: TextStyle(
                          color:
                              AppColors.sunriseOrange,

                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ==================================================
                // ACCOUNT TYPE
                // ==================================================

                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),

                    decoration:
                        BoxDecoration(
                      color: isTenant
                          ? AppColors.lightOrange
                          : AppColors.lightPurple,

                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),

                    child: Text(
                      '${widget.userType} Account',

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight:
                            FontWeight.w600,

                        color: isTenant
                            ? AppColors.sunriseOrange
                            : AppColors.royalPurple,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 4 — REGISTRATION
// ============================================================

class RegistrationScreen extends StatefulWidget {
  final String userType;

  const RegistrationScreen({
    super.key,
    required this.userType,
  });

  @override
  State<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState
    extends State<RegistrationScreen> {

  final _formKey =
      GlobalKey<FormState>();

  final TextEditingController
      _fullNameController =
      TextEditingController();

  final TextEditingController
      _phoneController =
      TextEditingController();

  final TextEditingController
      _emailController =
      TextEditingController();

  final TextEditingController
      _passwordController =
      TextEditingController();

  final TextEditingController
      _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (widget.userType == 'Landlord') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LandlordDashboard(),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const TenantDashboard(),
        ),
        (route) => false,
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }

    final emailRegex =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }

    final digitsOnly =
        value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length < 10) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isTenant =
        widget.userType == 'Tenant';

    return Scaffold(
      backgroundColor: AppColors.creamWhite,

      appBar: AppBar(
        backgroundColor:
            AppColors.creamWhite,

        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.deepNavy,
          ),

          onPressed: () =>
              Navigator.pop(context),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 10,
          ),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const SizedBox(height: 5),

                Center(
                  child: Container(
                    width: 82,
                    height: 82,

                    decoration:
                        BoxDecoration(
                      color: isTenant
                          ? AppColors.lightOrange
                          : AppColors.lightPurple,

                      borderRadius:
                          BorderRadius.circular(
                        24,
                      ),
                    ),

                    child: Icon(
                      isTenant
                          ? Icons.person_add_rounded
                          : Icons.home_work_rounded,

                      color: isTenant
                          ? AppColors.sunriseOrange
                          : AppColors.royalPurple,

                      size: 42,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                const Center(
                  child: Text(
                    'CREATE ACCOUNT',

                    style: TextStyle(
                      fontSize: 26,
                      fontWeight:
                          FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: Text(
                    'Create your ${widget.userType.toLowerCase()} account',

                    textAlign:
                        TextAlign.center,

                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.greyText,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Full Name',

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
                    color: AppColors.deepNavy,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _fullNameController,

                  textCapitalization:
                      TextCapitalization.words,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Enter your full name',

                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color:
                          AppColors.greyText,
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }

                    if (value.trim().length < 3) {
                      return 'Please enter your full name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                const Text(
                  'Phone Number',

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
                    color: AppColors.deepNavy,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _phoneController,

                  keyboardType:
                      TextInputType.phone,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Enter your phone number',

                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color:
                          AppColors.greyText,
                    ),
                  ),

                  validator:
                      _validatePhone,
                ),

                const SizedBox(height: 18),

                const Text(
                  'Email Address',

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
                    color: AppColors.deepNavy,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _emailController,

                  keyboardType:
                      TextInputType.emailAddress,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Enter your email address',

                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color:
                          AppColors.greyText,
                    ),
                  ),

                  validator:
                      _validateEmail,
                ),

                const SizedBox(height: 18),

                const Text(
                  'Password',

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
                    color: AppColors.deepNavy,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _passwordController,

                  obscureText:
                      _obscurePassword,

                  decoration:
                      InputDecoration(
                    hintText:
                        'Create a password',

                    prefixIcon:
                        const Icon(
                      Icons.lock_outline_rounded,
                      color:
                          AppColors.greyText,
                    ),

                    suffixIcon:
                        IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,

                        color:
                            AppColors.greyText,
                      ),

                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                              !_obscurePassword;
                        });
                      },
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please create a password';
                    }

                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                const Text(
                  'Confirm Password',

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
                    color: AppColors.deepNavy,
                  ),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _confirmPasswordController,

                  obscureText:
                      _obscureConfirmPassword,

                  decoration:
                      InputDecoration(
                    hintText:
                        'Confirm your password',

                    prefixIcon:
                        const Icon(
                      Icons.lock_outline_rounded,
                      color:
                          AppColors.greyText,
                    ),

                    suffixIcon:
                        IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,

                        color:
                            AppColors.greyText,
                      ),

                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword =
                              !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Please confirm your password';
                    }

                    if (value !=
                        _passwordController.text) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,

                  child: ElevatedButton(
                    onPressed: _register,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.royalGold,

                      foregroundColor:
                          AppColors.deepNavy,

                      elevation: 3,

                      shadowColor:
                          AppColors.royalGold
                              .withValues(
                        alpha: 0.35,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),

                    child: const Text(
                      'CREATE ACCOUNT',

                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),

                    decoration:
                        BoxDecoration(
                      color: isTenant
                          ? AppColors.lightOrange
                          : AppColors.lightPurple,

                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),

                    child: Text(
                      '${widget.userType} Account',

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight:
                            FontWeight.w600,

                        color: isTenant
                            ? AppColors.sunriseOrange
                            : AppColors.royalPurple,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 14 — LANDLORD DASHBOARD
// ============================================================

class LandlordDashboard extends StatelessWidget {
  const LandlordDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,

      // ========================================================
      // TOP BAR
      // ========================================================

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.creamWhite,
        elevation: 0,

        title: const Text(
          'BACKYARDPAY',

          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.deepNavy,
          ),
        ),

        actions: [

          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const LandlordNotificationsScreen(),
                ),
              );
            },

            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.deepNavy,
            ),
          ),

          IconButton(
            onPressed: () {
              Navigator.popUntil(
                context,
                (route) => route.isFirst,
              );
            },

            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.royalPurple,
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            100,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // ==================================================
              // PROPERTY SUMMARY CARD
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  color: AppColors.deepNavy,

                  borderRadius:
                      BorderRadius.circular(28),

                  boxShadow: [
                    BoxShadow(
                      color:
                          AppColors.deepNavy.withValues(
                        alpha: 0.18,
                      ),

                      blurRadius: 18,

                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Row(
                      children: [

                        Container(
                          width: 60,
                          height: 60,

                          decoration:
                              BoxDecoration(
                            color:
                                AppColors.royalGold
                                    .withValues(
                              alpha: 0.18,
                            ),

                            borderRadius:
                                BorderRadius.circular(
                              18,
                            ),
                          ),

                          child: const Icon(
                            Icons.home_work_rounded,
                            color:
                                AppColors.royalGold,
                            size: 32,
                          ),
                        ),

                        const SizedBox(width: 18),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [

                              Text(
                                'MY PROPERTY',

                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.bold,
                                  letterSpacing: 1,
                                  color:
                                      AppColors.royalGold,
                                ),
                              ),

                              SizedBox(height: 6),

                              Text(
                                'Dlamini Backyard Rooms',

                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    Row(
                      children: [

                        Expanded(
                          child: _DashboardStat(
                            icon:
                                Icons.meeting_room_outlined,
                            value: '12',
                            label: 'Rooms',
                          ),
                        ),

                        Expanded(
                          child: _DashboardStat(
                            icon:
                                Icons.people_outline_rounded,
                            value: '10',
                            label: 'Active Tenants',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // RENTAL SUMMARY
              // ==================================================

              const Text(
                'RENTAL SUMMARY',

                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                  letterSpacing: 1,
                  color:
                      AppColors.deepNavy,
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [

                  Expanded(
                    child: _MoneyCard(
                      icon:
                          Icons.account_balance_wallet_outlined,
                      title: 'EXPECTED RENT',
                      amount: 'R15 000',
                      iconBackground:
                          AppColors.lightGold,
                      iconColor:
                          AppColors.royalGold,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: _MoneyCard(
                      icon:
                          Icons.check_circle_outline,
                      title: 'COLLECTED',
                      amount: 'R12 000',
                      iconBackground:
                          const Color(0xFFE3F2E5),
                      iconColor:
                          AppColors.success,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ==================================================
              // OUTSTANDING RENT
              // ==================================================

              InkWell(
                borderRadius:
                    BorderRadius.circular(20),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const PaymentRecordsScreen(
                        initialFilter: 'Outstanding',
                      ),
                    ),
                  );
                },

                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(20),

                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.lightOrange,

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),

                    border: Border.all(
                      color:
                          AppColors.sunriseOrange
                              .withValues(
                        alpha: 0.25,
                      ),
                    ),
                  ),

                  child: Row(
                    children: [

                      Container(
                        width: 56,
                        height: 56,

                        decoration:
                            BoxDecoration(
                          color: Colors.white,

                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),

                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color:
                              AppColors.sunriseOrange,
                          size: 30,
                        ),
                      ),

                      const SizedBox(width: 16),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            Text(
                              'OUTSTANDING RENT',

                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    AppColors.sunriseOrange,
                              ),
                            ),

                            SizedBox(height: 5),

                            Text(
                              'R3 000',

                              style: TextStyle(
                                fontSize: 28,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    AppColors.deepNavy,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color:
                            AppColors.sunriseOrange,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // QUICK ACTIONS
              // ==================================================

              const Text(
                'QUICK ACTIONS',

                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                  letterSpacing: 1,
                  color:
                      AppColors.deepNavy,
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [

                  Expanded(
                    child: _QuickActionCard(
                      icon:
                          Icons.people_alt_outlined,

                      title:
                          'My Tenants',

                      iconColor:
                          AppColors.royalPurple,

                      iconBackground:
                          AppColors.lightPurple,

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MyTenantsScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: _QuickActionCard(
                      icon:
                          Icons.receipt_long_outlined,

                      title:
                          'Payments',

                      iconColor:
                          AppColors.sunriseOrange,

                      iconBackground:
                          AppColors.lightOrange,

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PaymentRecordsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [

                  Expanded(
                    child: _QuickActionCard(
                      icon:
                          Icons.home_work_outlined,

                      title:
                          'Property',

                      iconColor:
                          AppColors.royalGold,

                      iconBackground:
                          AppColors.lightGold,

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const PropertyManagementScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: _QuickActionCard(
                      icon:
                          Icons.notifications_active_outlined,

                      title:
                          'Notifications',

                      iconColor:
                          AppColors.royalPurple,

                      iconBackground:
                          AppColors.lightPurple,

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const LandlordNotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,

          border: Border(
            top: BorderSide(
              color: AppColors.border,
            ),
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround,

              children: [

                _BottomNavItem(
                  icon:
                      Icons.dashboard_rounded,

                  label: 'Home',

                  selected: true,

                  onTap: () {},
                ),

                _BottomNavItem(
                  icon:
                      Icons.people_outline_rounded,

                  label: 'Tenants',

                  selected: false,

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MyTenantsScreen(),
                      ),
                    );
                  },
                ),

                _BottomNavItem(
                  icon:
                      Icons.receipt_long_outlined,

                  label: 'Payments',

                  selected: false,

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const PaymentRecordsScreen(),
                      ),
                    );
                  },
                ),

                _BottomNavItem(
                  icon:
                      Icons.person_outline_rounded,

                  label: 'Profile',

                  selected: false,

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ProfileSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ============================================================
// SCREEN 15 — MY TENANTS
// ============================================================

class Tenant {
  final String name;
  final String room;
  final String phone;
  final String monthlyRent;
  final String status;
  final String outstanding;

  const Tenant({
    required this.name,
    required this.room,
    required this.phone,
    required this.monthlyRent,
    required this.status,
    required this.outstanding,
  });
}

class MyTenantsScreen extends StatefulWidget {
  const MyTenantsScreen({super.key});

  @override
  State<MyTenantsScreen> createState() => _MyTenantsScreenState();
}

class _MyTenantsScreenState extends State<MyTenantsScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final List<Tenant> _tenants = [
    const Tenant(
      name: 'Thando Mbeki',
      room: 'Room 1',
      phone: '071 234 5678',
      monthlyRent: 'R1 500',
      status: 'Paid',
      outstanding: 'R0',
    ),
    const Tenant(
      name: 'Ayanda Ndlovu',
      room: 'Room 2',
      phone: '072 345 6789',
      monthlyRent: 'R1 500',
      status: 'Paid',
      outstanding: 'R0',
    ),
    const Tenant(
      name: 'Siyabonga Dlamini',
      room: 'Room 3',
      phone: '073 456 7890',
      monthlyRent: 'R1 500',
      status: 'Outstanding',
      outstanding: 'R1 500',
    ),
    const Tenant(
      name: 'Lerato Mokoena',
      room: 'Room 4',
      phone: '074 567 8901',
      monthlyRent: 'R1 500',
      status: 'Paid',
      outstanding: 'R0',
    ),
    const Tenant(
      name: 'Bongani Cele',
      room: 'Room 5',
      phone: '075 678 9012',
      monthlyRent: 'R1 500',
      status: 'Paid',
      outstanding: 'R0',
    ),
    const Tenant(
      name: 'Nomsa Khumalo',
      room: 'Room 6',
      phone: '076 789 0123',
      monthlyRent: 'R1 500',
      status: 'Outstanding',
      outstanding: 'R1 500',
    ),
    const Tenant(
      name: 'Lunga Maseko',
      room: 'Room 7',
      phone: '077 890 1234',
      monthlyRent: 'R1 500',
      status: 'Paid',
      outstanding: 'R0',
    ),
    const Tenant(
      name: 'Zanele Dube',
      room: 'Room 8',
      phone: '078 901 2345',
      monthlyRent: 'R1 500',
      status: 'Paid',
      outstanding: 'R0',
    ),
    const Tenant(
      name: 'Sipho Zulu',
      room: 'Room 9',
      phone: '079 012 3456',
      monthlyRent: 'R1 500',
      status: 'Outstanding',
      outstanding: 'R0',
    ),
    const Tenant(
      name: 'Nandi Jacobs',
      room: 'Room 10',
      phone: '080 123 4567',
      monthlyRent: 'R1 500',
      status: 'Paid',
      outstanding: 'R0',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Tenant> get _filteredTenants {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _tenants;
    }

    return _tenants.where((tenant) {
      return tenant.name.toLowerCase().contains(query) ||
          tenant.room.toLowerCase().contains(query) ||
          tenant.phone.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _addTenant() async {
    final Tenant? newTenant = await Navigator.push<Tenant>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddTenantScreen(),
      ),
    );

    if (newTenant != null) {
      setState(() {
        _tenants.add(newTenant);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.deepNavy,
          content: Text('Tenant added successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openTenant(Tenant tenant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenantDetailsScreen(
          tenant: tenant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenants = _filteredTenants;
    final activeCount = _tenants.length;
    final outstandingCount = _tenants
        .where((tenant) => tenant.status == 'Outstanding')
        .length;

    return Scaffold(
      backgroundColor: AppColors.creamWhite,

      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,

        title: const Text(
          'MY TENANTS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.deepNavy,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Add tenant',
            onPressed: _addTenant,
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.royalPurple,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    // ==================================================
                    // TENANT SUMMARY
                    // ==================================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color: AppColors.deepNavy,
                        borderRadius:
                            BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.deepNavy.withValues(
                              alpha: 0.18,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),

                      child: Row(
                        children: [
                          Expanded(
                            child: _TenantSummaryItem(
                              icon:
                                  Icons.people_alt_rounded,
                              value:
                                  '$activeCount',
                              label: 'Active Tenants',
                            ),
                          ),

                          Container(
                            width: 1,
                            height: 55,
                            color: Colors.white24,
                          ),

                          Expanded(
                            child: _TenantSummaryItem(
                              icon:
                                  Icons.warning_amber_rounded,
                              value:
                                  '$outstandingCount',
                              label: 'Need Attention',
                              iconColor:
                                  AppColors.sunriseOrange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // SEARCH
                    // ==================================================

                    const Text(
                      'FIND A TENANT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppColors.deepNavy,
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: _searchController,
                      onChanged: (_) {
                        setState(() {});
                      },

                      decoration: InputDecoration(
                        hintText:
                            'Search by name, room or phone',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.greyText,
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color:
                                          AppColors.greyText,
                                    ),
                                  )
                                : null,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TENANTS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: AppColors.deepNavy,
                          ),
                        ),

                        Text(
                          '${tenants.length} shown',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (tenants.isEmpty)
                      _EmptyTenantsState(
                        onAddTenant: _addTenant,
                      )
                    else
                      ...tenants.map(
                        (tenant) => Padding(
                          padding:
                              const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: _TenantCard(
                            tenant: tenant,
                            onTap: () =>
                                _openTenant(tenant),
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // ==================================================
                    // DATABASE NOTE
                    // ==================================================

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: AppColors.lightGold,
                        borderRadius:
                            BorderRadius.circular(16),
                      ),

                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.deepNavy,
                            size: 21,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tenant information is currently stored locally for testing. A database will be connected later.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color:
                                    AppColors.deepNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ============================================================
      // ADD TENANT
      // ============================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTenant,
        backgroundColor: AppColors.royalGold,
        foregroundColor: AppColors.deepNavy,
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
        ),
        label: const Text(
          'ADD TENANT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: AppColors.border,
            ),
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround,

              children: [
                _BottomNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Home',
                  selected: false,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),

                _BottomNavItem(
                  icon:
                      Icons.people_outline_rounded,
                  label: 'Tenants',
                  selected: true,
                  onTap: () {},
                ),

                _BottomNavItem(
                  icon:
                      Icons.receipt_long_outlined,
                  label: 'Payments',
                  selected: false,
                  onTap: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Payment Records will be added next.',
                        ),
                        behavior:
                            SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),

                _BottomNavItem(
                  icon:
                      Icons.person_outline_rounded,
                  label: 'Profile',
                  selected: false,
                  onTap: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Landlord Profile will be added next.',
                        ),
                        behavior:
                            SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TENANT CARD
// ============================================================

class _TenantCard extends StatelessWidget {
  final Tenant tenant;
  final VoidCallback onTap;

  const _TenantCard({
    required this.tenant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool paid = tenant.status == 'Paid';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),

      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.border,
          ),
        ),

        child: Row(
          children: [
            Container(
              width: 55,
              height: 55,

              decoration: BoxDecoration(
                color: paid
                    ? const Color(0xFFE3F2E5)
                    : AppColors.lightOrange,
                borderRadius:
                    BorderRadius.circular(17),
              ),

              child: Icon(
                Icons.person_rounded,
                color: paid
                    ? AppColors.success
                    : AppColors.sunriseOrange,
                size: 29,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    tenant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepNavy,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '${tenant.room} • ${tenant.phone}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Rent ${tenant.monthlyRent}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepNavy,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,

              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),

                  decoration: BoxDecoration(
                    color: paid
                        ? const Color(0xFFE3F2E5)
                        : AppColors.lightOrange,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),

                  child: Text(
                    tenant.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: paid
                          ? AppColors.success
                          : AppColors.sunriseOrange,
                    ),
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  tenant.outstanding == 'R0'
                      ? 'Up to date'
                      : tenant.outstanding,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: paid
                        ? AppColors.greyText
                        : AppColors.sunriseOrange,
                  ),
                ),

                const SizedBox(height: 4),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TENANT SUMMARY ITEM
// ============================================================

class _TenantSummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _TenantSummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.royalGold,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 28,
        ),

        const SizedBox(width: 10),

        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFB8C4D6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// EMPTY TENANTS STATE
// ============================================================

class _EmptyTenantsState extends StatelessWidget {
  final VoidCallback onAddTenant;

  const _EmptyTenantsState({
    required this.onAddTenant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
        ),
      ),

      child: Column(
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: AppColors.greyText,
          ),

          const SizedBox(height: 12),

          const Text(
            'No tenants found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.deepNavy,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Try another search or add a new tenant.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.greyText,
            ),
          ),

          const SizedBox(height: 18),

          ElevatedButton(
            onPressed: onAddTenant,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  AppColors.royalGold,
              foregroundColor:
                  AppColors.deepNavy,
            ),
            child: const Text(
              'ADD TENANT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SCREEN 16 — ADD TENANT
// ============================================================

class AddTenantScreen extends StatefulWidget {
  const AddTenantScreen({super.key});

  @override
  State<AddTenantScreen> createState() =>
      _AddTenantScreenState();
}

class _AddTenantScreenState
    extends State<AddTenantScreen> {
  final _formKey =
      GlobalKey<FormState>();

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _roomController =
      TextEditingController();

  final TextEditingController _rentController =
      TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _roomController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  void _saveTenant() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final tenant = Tenant(
      name: _nameController.text.trim(),
      room: _roomController.text.trim(),
      phone: _phoneController.text.trim(),
      monthlyRent:
          'R${_rentController.text.trim()}',
      status: 'Outstanding',
      outstanding:
          'R${_rentController.text.trim()}',
    );

    Navigator.pop(context, tenant);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.creamWhite,

      appBar: AppBar(
        backgroundColor:
            AppColors.creamWhite,
        elevation: 0,

        leading: IconButton(
          onPressed: () =>
              Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.deepNavy,
          ),
        ),

        title: const Text(
          'ADD TENANT',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.deepNavy,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            30,
          ),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Center(
                  child: Container(
                    width: 82,
                    height: 82,

                    decoration: BoxDecoration(
                      color:
                          AppColors.lightPurple,
                      borderRadius:
                          BorderRadius.circular(
                        24,
                      ),
                    ),

                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color:
                          AppColors.royalPurple,
                      size: 42,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                const Center(
                  child: Text(
                    'NEW TENANT',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight:
                          FontWeight.bold,
                      letterSpacing: 1,
                      color:
                          AppColors.deepNavy,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Center(
                  child: Text(
                    'Enter the tenant details below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          AppColors.greyText,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                _TenantFormLabel(
                  label: 'Full Name',
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _nameController,
                  textCapitalization:
                      TextCapitalization.words,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Enter tenant full name',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter the tenant name';
                    }

                    if (value.trim().length < 3) {
                      return 'Please enter a valid name';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                _TenantFormLabel(
                  label: 'Phone Number',
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _phoneController,
                  keyboardType:
                      TextInputType.phone,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Enter tenant phone number',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter the tenant phone number';
                    }

                    final digits =
                        value.replaceAll(
                      RegExp(r'[^0-9]'),
                      '',
                    );

                    if (digits.length < 10) {
                      return 'Please enter a valid phone number';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                _TenantFormLabel(
                  label: 'Room Number',
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _roomController,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Example: Room 11',
                    prefixIcon: Icon(
                      Icons.meeting_room_outlined,
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter the room number';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                _TenantFormLabel(
                  label: 'Monthly Rent',
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller:
                      _rentController,
                  keyboardType:
                      TextInputType.number,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Example: 1500',
                    prefixText: 'R ',
                    prefixIcon: Icon(
                      Icons.payments_outlined,
                    ),
                  ),

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter the monthly rent';
                    }

                    final amount =
                        double.tryParse(
                      value.trim(),
                    );

                    if (amount == null ||
                        amount <= 0) {
                      return 'Please enter a valid rent amount';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 56,

                  child: ElevatedButton(
                    onPressed: _saveTenant,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.royalGold,
                      foregroundColor:
                          AppColors.deepNavy,
                      elevation: 3,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),

                    child: const Text(
                      'SAVE TENANT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Center(
                  child: Text(
                    'This information will be connected to the database later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          AppColors.greyText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TENANT FORM LABEL
// ============================================================

class _TenantFormLabel extends StatelessWidget {
  final String label;

  const _TenantFormLabel({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.deepNavy,
      ),
    );
  }
}

// ============================================================
// SCREEN 17 — TENANT DETAILS
// ============================================================

class TenantDetailsScreen extends StatelessWidget {
  final Tenant tenant;

  const TenantDetailsScreen({
    super.key,
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    final bool paid = tenant.status == 'Paid';

    return Scaffold(
      backgroundColor:
          AppColors.creamWhite,

      appBar: AppBar(
        backgroundColor:
            AppColors.creamWhite,
        elevation: 0,

        leading: IconButton(
          onPressed: () =>
              Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.deepNavy,
          ),
        ),

        title: const Text(
          'TENANT DETAILS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.deepNavy,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),

          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  color: AppColors.deepNavy,
                  borderRadius:
                      BorderRadius.circular(26),
                ),

                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,

                      decoration: BoxDecoration(
                        color: paid
                            ? const Color(
                                0xFFE3F2E5,
                              )
                            : AppColors.lightOrange,
                        shape: BoxShape.circle,
                      ),

                      child: Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: paid
                            ? AppColors.success
                            : AppColors
                                .sunriseOrange,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      tenant.name,
                      textAlign:
                          TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      tenant.room,
                      style: const TextStyle(
                        fontSize: 14,
                        color:
                            Color(0xFFB8C4D6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _TenantDetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone Number',
                value: tenant.phone,
              ),

              const SizedBox(height: 12),

              _TenantDetailRow(
                icon:
                    Icons.meeting_room_outlined,
                label: 'Room',
                value: tenant.room,
              ),

              const SizedBox(height: 12),

              _TenantDetailRow(
                icon:
                    Icons.payments_outlined,
                label: 'Monthly Rent',
                value: tenant.monthlyRent,
              ),

              const SizedBox(height: 12),

              _TenantDetailRow(
                icon:
                    Icons.account_balance_wallet_outlined,
                label: 'Outstanding',
                value: tenant.outstanding,
                valueColor: paid
                    ? AppColors.success
                    : AppColors.sunriseOrange,
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: paid
                      ? const Color(0xFFE3F2E5)
                      : AppColors.lightOrange,
                  borderRadius:
                      BorderRadius.circular(20),
                ),

                child: Row(
                  children: [
                    Icon(
                      paid
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: paid
                          ? AppColors.success
                          : AppColors.sunriseOrange,
                      size: 28,
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            paid
                                ? 'RENT STATUS'
                                : 'PAYMENT ATTENTION',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.bold,
                              letterSpacing: 0.8,
                              color: paid
                                  ? AppColors.success
                                  : AppColors
                                      .sunriseOrange,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            paid
                                ? 'Rent is up to date.'
                                : 'This tenant has an outstanding balance.',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  AppColors.deepNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Payment activity for this tenant is managed from Rent Payments.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 18 — PAYMENT RECORDS
// ============================================================


// ============================================================
// SCREEN 18 — LANDLORD PAYMENT RECORDS
// ============================================================

class PaymentRecordsScreen extends StatefulWidget {
  final String initialFilter;

  const PaymentRecordsScreen({
    super.key,
    this.initialFilter = 'All',
  });

  @override
  State<PaymentRecordsScreen> createState() =>
      _PaymentRecordsScreenState();
}

class _PaymentRecordsScreenState
    extends State<PaymentRecordsScreen> {
  late String _filter;

  final List<Map<String, String>> _paymentHistory = [
    {
      'tenant': 'Thando Mbeki',
      'room': 'Room 1',
      'amount': 'R1 500',
      'method': 'EFT',
      'date': '25 Sep 2026',
      'status': 'Paid',
    },
    {
      'tenant': 'Ayanda Ndlovu',
      'room': 'Room 2',
      'amount': 'R1 500',
      'method': 'Cash',
      'date': '24 Sep 2026',
      'status': 'Paid',
    },
    {
      'tenant': 'Siyabonga Dlamini',
      'room': 'Room 3',
      'amount': 'R1 500',
      'method': 'Not received',
      'date': '—',
      'status': 'Outstanding',
    },
    {
      'tenant': 'Lerato Mokoena',
      'room': 'Room 4',
      'amount': 'R1 500',
      'method': 'EFT',
      'date': '23 Sep 2026',
      'status': 'Paid',
    },
    {
      'tenant': 'Nomsa Khumalo',
      'room': 'Room 6',
      'amount': 'R1 500',
      'method': 'Not received',
      'date': '—',
      'status': 'Outstanding',
    },
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  List<Map<String, String>> get _filteredPayments {
    if (_filter == 'All') {
      return _paymentHistory;
    }

    return _paymentHistory
        .where((payment) => payment['status'] == _filter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final paidCount = _paymentHistory
        .where((payment) => payment['status'] == 'Paid')
        .length;

    final outstandingCount = _paymentHistory
        .where((payment) => payment['status'] == 'Outstanding')
        .length;

    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'RENT PAYMENTS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.deepNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.deepNavy,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepNavy.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PaymentSummaryStat(
                        value: '$paidCount',
                        label: 'Paid',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: AppColors.royalGold,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 55,
                      color: Colors.white24,
                    ),
                    Expanded(
                      child: _PaymentSummaryStat(
                        value: '$outstandingCount',
                        label: 'Outstanding',
                        icon: Icons.warning_amber_rounded,
                        iconColor: AppColors.sunriseOrange,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'PAYMENT STATUS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.deepNavy,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                children: ['All', 'Paid', 'Outstanding'].map((filter) {
                  final selected = _filter == filter;

                  return ChoiceChip(
                    label: Text(filter),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _filter = filter;
                      });
                    },
                    selectedColor: AppColors.royalGold,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected
                          ? AppColors.royalGold
                          : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.deepNavy
                          : AppColors.greyText,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PAYMENT HISTORY',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppColors.deepNavy,
                    ),
                  ),
                  Text(
                    '${_filteredPayments.length} records',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ..._filteredPayments.map(
                (payment) => _PaymentRecordCard(payment: payment),
              ),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  'Payment records are currently stored locally.\nDatabase connection will be added later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.greyText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentSummaryStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _PaymentSummaryStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFB8C4D6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentRecordCard extends StatelessWidget {
  final Map<String, String> payment;

  const _PaymentRecordCard({
    required this.payment,
  });

  @override
  Widget build(BuildContext context) {
    final paid = payment['status'] == 'Paid';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: paid
                  ? const Color(0xFFE3F2E5)
                  : AppColors.lightOrange,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              paid
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              color: paid
                  ? AppColors.success
                  : AppColors.sunriseOrange,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['tenant']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${payment['room']} • ${payment['amount']}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.greyText,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${payment['method']} • ${payment['date']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.greyText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: paid
                  ? const Color(0xFFE3F2E5)
                  : AppColors.lightOrange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              payment['status']!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: paid
                    ? AppColors.success
                    : AppColors.sunriseOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SCREEN 5A — PROPERTY MANAGEMENT
// ============================================================

class PropertyManagementScreen extends StatefulWidget {
  const PropertyManagementScreen({super.key});

  @override
  State<PropertyManagementScreen> createState() =>
      _PropertyManagementScreenState();
}

class _PropertyManagementScreenState
    extends State<PropertyManagementScreen> {
  String _propertyName = 'Dlamini Backyard Rooms';
  String _address = 'East London, Eastern Cape';
  int _rooms = 12;

  Future<void> _addProperty() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPropertyScreen(),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _propertyName = result['name'] as String;
      _address = result['address'] as String;
      _rooms = result['rooms'] as int;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.deepNavy,
        content: Text('Property added successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'PROPERTIES',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.deepNavy,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProperty,
        backgroundColor: AppColors.royalGold,
        foregroundColor: AppColors.deepNavy,
        icon: const Icon(Icons.add_home_work_rounded),
        label: const Text(
          'ADD PROPERTY',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            const Text(
              'MY PROPERTIES',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppColors.deepNavy,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PropertyDetailsScreen(
                      name: _propertyName,
                      address: _address,
                      rooms: _rooms,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.deepNavy,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepNavy.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppColors.royalGold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: const Icon(
                            Icons.home_work_rounded,
                            color: AppColors.royalGold,
                            size: 31,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _propertyName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.royalGold,
                          size: 17,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _address,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB8C4D6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_outlined,
                          color: AppColors.royalGold,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_rooms rooms',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tap a property to view its details.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _roomsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _roomsController.dispose();
    super.dispose();
  }

  void _saveProperty() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'rooms': int.parse(_roomsController.text.trim()),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'ADD PROPERTY',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROPERTY DETAILS',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Property Name',
                    hintText: 'Example: Dlamini Backyard Rooms',
                    prefixIcon: Icon(
                      Icons.home_work_outlined,
                      color: AppColors.royalGold,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the property name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Property Address',
                    hintText: 'Enter the property address',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.royalGold,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the property address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _roomsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of Rooms',
                    hintText: 'Example: 12',
                    prefixIcon: Icon(
                      Icons.meeting_room_outlined,
                      color: AppColors.royalGold,
                    ),
                  ),
                  validator: (value) {
                    final rooms = int.tryParse(value?.trim() ?? '');
                    if (rooms == null || rooms <= 0) {
                      return 'Please enter a valid number of rooms';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveProperty,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.royalGold,
                      foregroundColor: AppColors.deepNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'SAVE PROPERTY',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Property information is currently stored locally.\nDatabase connection will be added later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.greyText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PropertyDetailsScreen extends StatelessWidget {
  final String name;
  final String address;
  final int rooms;

  const PropertyDetailsScreen({
    super.key,
    required this.name,
    required this.address,
    required this.rooms,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'PROPERTY DETAILS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.deepNavy,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.home_work_rounded,
                    color: AppColors.royalGold,
                    size: 42,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFB8C4D6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _PropertyDetailTile(
              icon: Icons.meeting_room_outlined,
              label: 'Rooms',
              value: '$rooms',
            ),
            const SizedBox(height: 12),
            const _PropertyDetailTile(
              icon: Icons.people_outline_rounded,
              label: 'Active Tenants',
              value: '10',
            ),
            const SizedBox(height: 12),
            const _PropertyDetailTile(
              icon: Icons.payments_outlined,
              label: 'Expected Monthly Rent',
              value: 'R15 000',
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyDetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PropertyDetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.lightGold,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: AppColors.royalGold,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.greyText,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.deepNavy,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SCREEN — NOTIFICATIONS
// ============================================================

class LandlordNotificationsScreen extends StatelessWidget {
  const LandlordNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _NotificationCard(
              icon: Icons.warning_amber_rounded,
              title: 'Rent outstanding',
              message: 'Siyabonga Dlamini has an outstanding balance of R1 500.',
              time: 'Today',
              accent: AppColors.sunriseOrange,
              background: AppColors.lightOrange,
            ),
            SizedBox(height: 12),
            _NotificationCard(
              icon: Icons.check_circle_outline_rounded,
              title: 'Payment received',
              message: 'Thando Mbeki payment of R1 500 is marked as paid.',
              time: 'Today',
              accent: AppColors.success,
              background: Color(0xFFE3F2E5),
            ),
          ],
        ),
      ),
    );
  }
}

class TenantNotificationsScreen extends StatelessWidget {
  const TenantNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _NotificationCard(
              icon: Icons.notifications_active_outlined,
              title: 'Rent reminder',
              message: 'Your rent of R1 500 is due soon.',
              time: 'Today',
              accent: AppColors.sunriseOrange,
              background: AppColors.lightOrange,
            ),
            SizedBox(height: 12),
            _NotificationCard(
              icon: Icons.check_circle_outline_rounded,
              title: 'Payment confirmed',
              message: 'Your rental payment has been confirmed.',
              time: 'Today',
              accent: AppColors.success,
              background: Color(0xFFE3F2E5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String time;
  final Color accent;
  final Color background;

  const _NotificationCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.accent,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.greyText,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SCREEN — PROFILE / SETTINGS
// ============================================================

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'PROFILE / SETTINGS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.deepNavy,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.royalGold,
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.deepNavy,
                      size: 34,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Landlord Account',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Manage your account settings',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB8C4D6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Personal Details',
              subtitle: 'Name, phone number and email',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Personal details editing will be added later.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              subtitle: 'Update your account password',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password settings will be added later.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notification Settings',
              subtitle: 'Manage your notifications',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LandlordNotificationsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 7,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.lightPurple,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: AppColors.royalPurple,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.deepNavy,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.greyText,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: AppColors.greyText,
        ),
      ),
    );
  }
}

class RecordPaymentScreen extends StatefulWidget {
  final Tenant tenant;

  const RecordPaymentScreen({
    super.key,
    required this.tenant,
  });

  @override
  State<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController =
      TextEditingController();
  final TextEditingController _referenceController =
      TextEditingController();
  final TextEditingController _notesController =
      TextEditingController();

  String _paymentMethod = 'Cash';
  DateTime _paymentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.tenant.monthlyRent
        .replaceAll('R', '')
        .replaceAll(' ', '')
        .replaceAll(',', '');

    _referenceController.text =
        'BP-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-001';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.royalGold,
              onPrimary: AppColors.deepNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  void _submitPayment() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentRecordedScreen(
          tenant: widget.tenant,
          amount: _amountController.text.trim(),
          paymentMethod: _paymentMethod,
          paymentDate: _formatDate(_paymentDate),
          reference: _referenceController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'RECORD PAYMENT',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.deepNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.deepNavy,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.royalGold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: AppColors.royalGold,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PAYMENT FOR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: AppColors.royalGold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.tenant.name,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${widget.tenant.room} • Rent ${widget.tenant.monthlyRent}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFB8C4D6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'PAYMENT AMOUNT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter payment amount',
                    prefixText: 'R ',
                    prefixIcon: Icon(
                      Icons.payments_outlined,
                      color: AppColors.royalGold,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the payment amount';
                    }
                    final amount = double.tryParse(
                      value.replaceAll(',', '').trim(),
                    );
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 22),

                const Text(
                  'PAYMENT METHOD',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ['Cash', 'EFT', 'PayShap', 'Other'].map((method) {
                    final selected = _paymentMethod == method;
                    return ChoiceChip(
                      label: Text(method),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _paymentMethod = method;
                        });
                      },
                      selectedColor: AppColors.royalGold,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? AppColors.royalGold
                            : AppColors.border,
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.deepNavy
                            : AppColors.greyText,
                      ),
                    );
                  }).toList(),
                ),

                if (_paymentMethod == 'Cash') ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.lightOrange,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.sunriseOrange.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.sunriseOrange,
                          size: 21,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cash payment: the landlord records the physical cash received. The app only records the payment; it does not transfer money.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.deepNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                const Text(
                  'PAYMENT DATE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.royalGold,
                      ),
                      suffixIcon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppColors.greyText,
                      ),
                    ),
                    child: Text(
                      _formatDate(_paymentDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepNavy,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'REFERENCE NUMBER',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    hintText: 'Payment reference',
                    prefixIcon: Icon(
                      Icons.tag_rounded,
                      color: AppColors.royalGold,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a reference number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 22),

                const Text(
                  'NOTES (OPTIONAL)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add a note about this payment...',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 45),
                      child: Icon(
                        Icons.notes_rounded,
                        color: AppColors.royalGold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _submitPayment,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'RECORD PAYMENT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.royalGold,
                      foregroundColor: AppColors.deepNavy,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                const Center(
                  child: Text(
                    'Payment information is currently stored locally.\nDatabase connection will be added later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.greyText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 19 — PAYMENT RECORDED
// ============================================================

class PaymentRecordedScreen extends StatelessWidget {
  final Tenant tenant;
  final String amount;
  final String paymentMethod;
  final String paymentDate;
  final String reference;

  const PaymentRecordedScreen({
    super.key,
    required this.tenant,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'PAYMENT CONFIRMATION',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.deepNavy,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 54,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'PAYMENT RECORDED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'The rental payment has been recorded successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.greyText,
                ),
              ),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _PaymentConfirmationRow(
                      label: 'Tenant',
                      value: tenant.name,
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Room',
                      value: tenant.room,
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Amount',
                      value: 'R$amount',
                      valueColor: AppColors.deepNavy,
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Method',
                      value: paymentMethod,
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Date',
                      value: paymentDate,
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Reference',
                      value: reference,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.deepNavy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: AppColors.royalGold,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CONFIRMED • Recorded by landlord',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalGold,
                    foregroundColor: AppColors.deepNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'BACK TO TENANT DETAILS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentConfirmationRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PaymentConfirmationRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.greyText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.deepNavy,
            ),
          ),
        ),
      ],
    );
  }
}


// ============================================================
// TENANT FLOW
// ============================================================

class TenantDashboard extends StatelessWidget {
  const TenantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.creamWhite,
        elevation: 0,
        title: const Text(
          'BACKYARDPAY',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: AppColors.deepNavy,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TenantNotificationsScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.deepNavy,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              Navigator.popUntil(
                context,
                (route) => route.isFirst,
              );
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.sunriseOrange,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.deepNavy,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepNavy.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MY RENTAL',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppColors.royalGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Dlamini Backyard Rooms',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Room 1 • East London',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB8C4D6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: const [
                        Expanded(
                          child: _TenantDashboardStat(
                            icon: Icons.payments_outlined,
                            value: 'R1 500',
                            label: 'Monthly Rent',
                          ),
                        ),
                        Expanded(
                          child: _TenantDashboardStat(
                            icon: Icons.account_balance_wallet_outlined,
                            value: 'R0',
                            label: 'Outstanding',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'RENT STATUS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2E5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your rent is up to date.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.payments_outlined,
                      title: 'Pay Rent',
                      iconColor: AppColors.royalGold,
                      iconBackground: AppColors.lightGold,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TenantRentPaymentScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.history_rounded,
                      title: 'Payment History',
                      iconColor: AppColors.royalPurple,
                      iconBackground: AppColors.lightPurple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TenantPaymentHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.home_work_outlined,
                      title: 'My Rental',
                      iconColor: AppColors.sunriseOrange,
                      iconBackground: AppColors.lightOrange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TenantRentalDetailsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notifications',
                      iconColor: AppColors.royalPurple,
                      iconBackground: AppColors.lightPurple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TenantNotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Home',
                  selected: true,
                  onTap: () {},
                ),
                _BottomNavItem(
                  icon: Icons.payments_outlined,
                  label: 'Pay Rent',
                  selected: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TenantRentPaymentScreen(),
                      ),
                    );
                  },
                ),
                _BottomNavItem(
                  icon: Icons.history_rounded,
                  label: 'History',
                  selected: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TenantPaymentHistoryScreen(),
                      ),
                    );
                  },
                ),
                _BottomNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  selected: false,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TenantDashboardStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _TenantDashboardStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.royalGold, size: 28),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB8C4D6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class TenantRentalDetailsScreen extends StatelessWidget {
  const TenantRentalDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'MY RENTAL',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.deepNavy,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROPERTY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.royalGold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Dlamini Backyard Rooms',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Room 1',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFB8C4D6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _TenantDetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Landlord',
            value: 'Mr Dlamini',
          ),
          const SizedBox(height: 12),
          const _TenantDetailRow(
            icon: Icons.phone_outlined,
            label: 'Landlord Phone',
            value: '071 111 2233',
          ),
          const SizedBox(height: 12),
          const _TenantDetailRow(
            icon: Icons.location_on_outlined,
            label: 'Property Address',
            value: 'East London, Eastern Cape',
          ),
          const SizedBox(height: 12),
          const _TenantDetailRow(
            icon: Icons.payments_outlined,
            label: 'Monthly Rent',
            value: 'R1 500',
          ),
        ],
      ),
    );
  }
}

class TenantRentPaymentScreen extends StatefulWidget {
  const TenantRentPaymentScreen({super.key});

  @override
  State<TenantRentPaymentScreen> createState() =>
      _TenantRentPaymentScreenState();
}

class _TenantRentPaymentScreenState extends State<TenantRentPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController =
      TextEditingController(text: '1500');
  final TextEditingController _referenceController =
      TextEditingController();

  String _paymentMethod = 'Cash';

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _confirmPayment() {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TenantPaymentConfirmationScreen(
          amount: _amountController.text.trim(),
          paymentMethod: _paymentMethod,
          reference: _referenceController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCash = _paymentMethod == 'Cash';

    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'RENT PAYMENT',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.deepNavy,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONTHLY RENT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: AppColors.royalGold,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'R1 500',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Dlamini Backyard Rooms • Room 1',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFB8C4D6),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'AMOUNT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter amount',
                    prefixText: 'R ',
                    prefixIcon: Icon(
                      Icons.payments_outlined,
                      color: AppColors.royalGold,
                    ),
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').replaceAll(',', '').trim(),
                    );
                    if (amount == null || amount <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 22),

                const Text(
                  'PAYMENT METHOD',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 10),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ['Cash', 'Bank Transfer / EFT'].map((method) {
                    final selected = _paymentMethod == method;
                    return ChoiceChip(
                      label: Text(method),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _paymentMethod = method;
                        });
                      },
                      selectedColor: AppColors.royalGold,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: selected
                            ? AppColors.royalGold
                            : AppColors.border,
                      ),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.deepNavy
                            : AppColors.greyText,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCash
                        ? AppColors.lightOrange
                        : AppColors.lightGold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isCash
                            ? Icons.payments_outlined
                            : Icons.account_balance_outlined,
                        color: isCash
                            ? AppColors.sunriseOrange
                            : AppColors.royalGold,
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isCash
                              ? 'Cash payment: pay the landlord in person. The app records your payment confirmation; no money is transferred through the app.'
                              : 'Bank transfer / EFT: make the transfer using your bank, then enter the reference below so the payment can be identified.',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.deepNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  'REFERENCE NUMBER',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.deepNavy,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _referenceController,
                  decoration: InputDecoration(
                    hintText: isCash
                        ? 'Optional cash reference'
                        : 'Enter EFT reference',
                    prefixIcon: const Icon(
                      Icons.tag_rounded,
                      color: AppColors.royalGold,
                    ),
                  ),
                  validator: (value) {
                    if (!isCash && (value == null || value.trim().isEmpty)) {
                      return 'Please enter the EFT reference';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _confirmPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.royalGold,
                      foregroundColor: AppColors.deepNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'CONFIRM PAYMENT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TenantPaymentConfirmationScreen extends StatelessWidget {
  final String amount;
  final String paymentMethod;
  final String reference;

  const TenantPaymentConfirmationScreen({
    super.key,
    required this.amount,
    required this.paymentMethod,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final isCash = paymentMethod == 'Cash';

    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'PAYMENT CONFIRMATION',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: isCash
                      ? AppColors.lightOrange
                      : const Color(0xFFE3F2E5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCash
                      ? Icons.hourglass_top_rounded
                      : Icons.check_rounded,
                  color: isCash
                      ? AppColors.sunriseOrange
                      : AppColors.success,
                  size: 54,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                isCash ? 'PAYMENT SUBMITTED' : 'PAYMENT CONFIRMED',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCash
                    ? 'Your cash payment has been recorded as a payment confirmation for the landlord to verify.'
                    : 'Your bank transfer payment details have been recorded.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.greyText,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _PaymentConfirmationRow(
                      label: 'Tenant',
                      value: 'Current Tenant',
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Property',
                      value: 'Dlamini Backyard Rooms',
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Room',
                      value: 'Room 1',
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Amount',
                      value: 'R$amount',
                      valueColor: AppColors.deepNavy,
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Method',
                      value: paymentMethod,
                    ),
                    const Divider(height: 24),
                    _PaymentConfirmationRow(
                      label: 'Status',
                      value: isCash ? 'Pending Verification' : 'Payment Submitted',
                      valueColor: isCash
                          ? AppColors.sunriseOrange
                          : AppColors.success,
                    ),
                    if (reference.isNotEmpty) ...[
                      const Divider(height: 24),
                      _PaymentConfirmationRow(
                        label: 'Reference',
                        value: reference,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.deepNavy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.royalGold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCash
                            ? 'Digital receipt • Pending landlord verification'
                            : 'Digital receipt • Payment submitted',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(
                      context,
                      (route) => route.isFirst,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalGold,
                    foregroundColor: AppColors.deepNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'BACK TO DASHBOARD',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TenantPaymentHistoryScreen extends StatelessWidget {
  const TenantPaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payments = const [
      {
        'date': '25 Sep 2026',
        'amount': 'R1 500',
        'method': 'EFT',
        'status': 'Paid',
      },
      {
        'date': '25 Aug 2026',
        'amount': 'R1 500',
        'method': 'Cash',
        'status': 'Paid',
      },
      {
        'date': '25 Jul 2026',
        'amount': 'R1 500',
        'method': 'EFT',
        'status': 'Paid',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.creamWhite,
      appBar: AppBar(
        backgroundColor: AppColors.creamWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        title: const Text(
          'PAYMENT HISTORY',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          const Text(
            'MY PAYMENTS',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: AppColors.deepNavy,
            ),
          ),
          const SizedBox(height: 12),
          ...payments.map(
            (payment) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3F2E5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment['amount']!,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${payment['method']} • ${payment['date']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    payment['status']!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TENANT DETAIL ROW
// ============================================================

class _TenantDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _TenantDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,

            decoration: BoxDecoration(
              color: AppColors.lightGold,
              borderRadius:
                  BorderRadius.circular(13),
            ),

            child: Icon(
              icon,
              color: AppColors.royalGold,
              size: 23,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        AppColors.greyText,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.bold,
                    color: valueColor ??
                        AppColors.deepNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DASHBOARD STAT
// ============================================================

class _DashboardStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _DashboardStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        Icon(
          icon,
          color:
              AppColors.royalGold,
          size: 28,
        ),

        const SizedBox(width: 10),

        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Text(
              value,

              style: const TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
                color: Colors.white,
              ),
            ),

            Text(
              label,

              style: const TextStyle(
                fontSize: 13,
                color:
                    Color(0xFFB8C4D6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// MONEY CARD
// ============================================================

class _MoneyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String amount;
  final Color iconBackground;
  final Color iconColor;

  const _MoneyCard({
    required this.icon,
    required this.title,
    required this.amount,
    required this.iconBackground,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color:
              AppColors.border,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Container(
            width: 50,
            height: 50,

            decoration:
                BoxDecoration(
              color:
                  iconBackground,

              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),

            child: Icon(
              icon,

              color: iconColor,

              size: 26,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            title,

            style: const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
              color:
                  AppColors.greyText,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            amount,

            style: const TextStyle(
              fontSize: 24,
              fontWeight:
                  FontWeight.bold,
              color:
                  AppColors.deepNavy,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// QUICK ACTION CARD
// ============================================================

class _QuickActionCard
    extends StatelessWidget {

  final IconData icon;
  final String title;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(20),

      child: Container(
        padding:
            const EdgeInsets.all(18),

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(20),

          border: Border.all(
            color:
                AppColors.border,
          ),
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Container(
              width: 52,
              height: 52,

              decoration:
                  BoxDecoration(
                color:
                    iconBackground,

                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),

              child: Icon(
                icon,

                color: iconColor,

                size: 27,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              title,

              style: const TextStyle(
                fontSize: 14,
                fontWeight:
                    FontWeight.bold,
                color:
                    AppColors.deepNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BOTTOM NAV ITEM
// ============================================================

class _BottomNavItem
    extends StatelessWidget {

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(20),

      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 6,
              ),

              decoration:
                  BoxDecoration(
                color: selected
                    ? AppColors.lightGold
                    : Colors.transparent,

                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),

              child: Icon(
                icon,

                color: selected
                    ? AppColors.deepNavy
                    : AppColors.greyText,

                size: 24,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              label,

              style: TextStyle(
                fontSize: 12,

                color: selected
                    ? AppColors.deepNavy
                    : AppColors.greyText,

                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}