import 'package:flutter/material.dart';
import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hitwardhini/widgets/glass_container.dart';
import 'package:hitwardhini/providers/locale_provider.dart';
import 'package:hitwardhini/l10n/app_localizations.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authStateSub;
  bool _isLoading = false;
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scrollController = ScrollController();
  final _passwordFocusNode = FocusNode();
  final _passwordFieldKey = GlobalKey();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final existingSession = supabase.auth.currentSession;
    if (existingSession != null) {
      Future.microtask(() => _routeAfterLogin(existingSession));
    }
    _authStateSub = supabase.auth.onAuthStateChange.listen((data) async {
      final Session? session = data.session;
      if (session != null && mounted) {
        await _routeAfterLogin(session);
      }
    });
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        _ensurePasswordVisible();
      }
    });
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    _loginIdController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _ensurePasswordVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _passwordFieldKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.25,
      );
    });
  }

  Future<void> _routeAfterLogin(Session session) async {
    final userEmail = session.user.email?.toLowerCase();
    final userId = session.user.id;

    Map<String, dynamic>? blockedByEmail;
    if (userEmail != null && userEmail.isNotEmpty) {
      blockedByEmail = await supabase
          .from('blocked_users')
          .select()
          .eq('email', userEmail)
          .maybeSingle();
    }

    Map<String, dynamic>? blockedByUserId;
    try {
      blockedByUserId = await supabase
          .from('blocked_users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (_) {
      blockedByUserId = null;
    }

    final blocked = blockedByUserId ?? blockedByEmail;
    if (blocked != null && mounted) {
      await supabase.auth.signOut();
      _showBlockedDialog(blocked['reason']);
      return;
    }

    final profile = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    final hasProfile = profile != null;
    final shouldPromptPasswordChange =
        (profile?['prompt_password_change'] == true);

    if (!mounted) return;

    if (shouldPromptPasswordChange) {
      Navigator.of(context).pushReplacementNamed(
        '/password-preferences',
        arguments: {'hasProfile': hasProfile},
      );
      return;
    }
    if (!hasProfile) {
      await supabase.auth.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile not found. Please contact admin. New profile creation is disabled.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  void _showBlockedDialog(String? reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.block_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.accountBlocked),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.accountBlockedMessage,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${AppLocalizations.of(context)!.reason}: $reason',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.contactSupport,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePasswordLogin() async {
    final loginId = _loginIdController.text.trim();
    final password = _passwordController.text;

    if (loginId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Login ID and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? emailToUse;
      if (loginId.contains('@')) {
        emailToUse = loginId;
      } else {
        try {
          final match = await supabase
              .from('profiles')
              .select('email')
              .eq('login_id', loginId)
              .maybeSingle();
          emailToUse = match?['email'] as String?;
        } catch (_) {
          emailToUse = null;
        }
      }

      if (emailToUse == null || emailToUse.isEmpty) {
        throw const AuthException('Invalid login credentials');
      }

      await supabase.auth.signInWithPassword(
        email: emailToUse,
        password: password,
      );
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Login ID or password.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.loginFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Subtle top gradient for a modern touch (only 20% of screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Language Switcher
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButton<Locale>(
                value: Provider.of<LocaleProvider>(context).locale,
                isExpanded: true,
                isDense: true,
                underline: const SizedBox(),
                iconSize: 18,
                dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                selectedItemBuilder: (context) => const [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('मराठी', overflow: TextOverflow.ellipsis),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('English', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (Locale? newLocale) {
                  if (newLocale != null) {
                    Provider.of<LocaleProvider>(
                      context,
                      listen: false,
                    ).setLocale(newLocale);
                  }
                },
                items: const [
                  DropdownMenuItem(value: Locale('mr'), child: Text('मराठी')),
                  DropdownMenuItem(value: Locale('en'), child: Text('English')),
                ],
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
                return SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    52,
                    24,
                    keyboardInset > 0 ? keyboardInset + 120 : 120,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Main Card
                      GlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 48,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/logo.png',
                              height: 112,
                              fit: BoxFit.contain,
                              semanticLabel: AppLocalizations.of(
                                context,
                              )!.appTitle,
                            ),
                            const SizedBox(height: 32),

                            // Titles
                            Text(
                              AppLocalizations.of(context)!.appTitle,
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context)!.findProperMatches,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 48),

                            TextField(
                              controller: _loginIdController,
                              decoration: InputDecoration(
                                labelText: 'Login ID',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: _passwordFieldKey,
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : _handlePasswordLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Login',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Footer within card
                            Text(
                              AppLocalizations.of(
                                context,
                              )!.secureTrustedMatrimony,
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 160),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButton<Locale>(
                value: Provider.of<LocaleProvider>(context).locale,
                isExpanded: true,
                isDense: true,
                underline: const SizedBox(),
                iconSize: 18,
                dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                selectedItemBuilder: (context) => const [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('मराठी', overflow: TextOverflow.ellipsis),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('English', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (Locale? newLocale) {
                  if (newLocale != null) {
                    Provider.of<LocaleProvider>(
                      context,
                      listen: false,
                    ).setLocale(newLocale);
                  }
                },
                items: const [
                  DropdownMenuItem(value: Locale('mr'), child: Text('मराठी')),
                  DropdownMenuItem(value: Locale('en'), child: Text('English')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
