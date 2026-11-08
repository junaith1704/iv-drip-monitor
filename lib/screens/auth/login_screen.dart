import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../theme/clinical_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _emailChecked = false;
  bool _isFirstTimeSetup = false;
  bool _checkingEmail = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (FirebaseService.isMockFallback) {
      setState(() => _errorMessage = 'Firebase service unavailable. Secure login required.');
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Enter a valid email address');
      return;
    }
    setState(() {
      _errorMessage = null;
      _checkingEmail = true;
    });
    final authService = context.read<AuthService>();
    final isFirstTime = await authService.checkFirstTimeSetup(email);
    if (!mounted) return;
    setState(() {
      _emailChecked = true;
      _isFirstTimeSetup = isFirstTime;
      _checkingEmail = false;
    });
  }

  Future<void> _handleCreatePassword() async {
    if (FirebaseService.isMockFallback) {
      setState(() => _errorMessage = 'Firebase service unavailable. Secure login required.');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    setState(() => _errorMessage = null);
    final authService = context.read<AuthService>();
    final error = await authService.completeFirstTimeSetup(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (error != null && mounted) {
      setState(() => _errorMessage = error);
    }
  }

  Future<void> _handleLogin() async {
    if (FirebaseService.isMockFallback) {
      setState(() => _errorMessage = 'Firebase service unavailable. Secure login required.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Password is required');
      return;
    }
    setState(() => _errorMessage = null);
    final authService = context.read<AuthService>();
    final error = await authService.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (error != null && mounted) {
      setState(() => _errorMessage = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: ClinicalTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: ClinicalTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: ClinicalTheme.primaryBlue.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'IV Drip Monitor',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: ClinicalTheme.deepNavy,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Clinical Hardware Infusion Telemetry System',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: ClinicalTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ClinicalTheme.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Staff Authentication',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ClinicalTheme.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your clinical email and credentials to access your ward workstation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: ClinicalTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ClinicalTheme.statusAlarmBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClinicalTheme.statusAlarmBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: ClinicalTheme.statusAlarm, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: ClinicalTheme.statusAlarm,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text(
                        'Hospital Email',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ClinicalTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_emailChecked,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: ClinicalTheme.textMuted),
                          hintText: 'e.g. nurse@hospital.org',
                          suffixIcon: _emailChecked
                              ? IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _emailChecked = false;
                                      _isFirstTimeSetup = false;
                                      _errorMessage = null;
                                      _passwordController.clear();
                                      _confirmPasswordController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_emailChecked) ...[
                        ElevatedButton(
                          onPressed: _checkingEmail ? null : _handleContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClinicalTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _checkingEmail
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'CONTINUE',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                                ),
                        ),
                      ] else if (_isFirstTimeSetup) ...[
                        const Text(
                          'First time here — create your password',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ClinicalTheme.primaryBlue),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'New Password',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClinicalTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: ClinicalTheme.textMuted),
                            hintText: 'At least 6 characters',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                                color: ClinicalTheme.textMuted,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Confirm Password',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClinicalTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscurePassword,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.lock_outline, size: 20, color: ClinicalTheme.textMuted),
                            hintText: 'Re-enter password',
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: authService.isLoading ? null : _handleCreatePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClinicalTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: authService.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'CREATE PASSWORD & SIGN IN',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                                ),
                        ),
                      ] else ...[
                        const Text(
                          'Password',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ClinicalTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: ClinicalTheme.textMuted),
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                                color: ClinicalTheme.textMuted,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: authService.isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClinicalTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: authService.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'SIGN IN TO WORKSTATION',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ],
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
