import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    supabase.auth.onAuthStateChange.listen((data) async {
      final Session? session = data.session;
      if (session != null && mounted) {
        final userEmail = session.user.email?.toLowerCase();
        
        // Check if user is blocked
        if (userEmail != null) {
          final blocked = await supabase
              .from('blocked_users')
              .select()
              .eq('email', userEmail)
              .maybeSingle();
          
          if (blocked != null && mounted) {
            // User is blocked - sign out and show message
            await supabase.auth.signOut();
            _showBlockedDialog(blocked['reason']);
            return;
          }
        }
        
        final userId = session.user.id;
        final profile = await supabase.from('profiles').select().eq('id', userId).maybeSingle();
        
        if (mounted) {
          if (profile != null) {
            Navigator.of(context).pushReplacementNamed('/dashboard');
          } else {
            Navigator.of(context).pushReplacementNamed('/profile-creation');
          }
        }
      }
    });
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
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.block_rounded, color: Colors.red, size: 28),
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
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
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

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.hitwardhini://login-callback/',
      );
    } catch (error) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.loginFailed}: $error')));
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
                      Theme.of(context).colorScheme.primary.withOpacity(0.15),
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButton<Locale>(
                value: Provider.of<LocaleProvider>(context).locale,
                underline: const SizedBox(),
                dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                onChanged: (Locale? newLocale) {
                  if (newLocale != null) {
                    Provider.of<LocaleProvider>(context, listen: false).setLocale(newLocale);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: Locale('mr'),
                    child: Text('मराठी'),
                  ),
                  DropdownMenuItem(
                    value: Locale('en'),
                    child: Text('English'),
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main Card
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            ),
                            child: Icon(
                              Icons.diversity_1_rounded, 
                              size: 64, 
                              color: Theme.of(context).colorScheme.primary
                            ),
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

                          // Google Sign In Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleGoogleSignIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: _isLoading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                        child: Image.network('https://www.google.com/favicon.ico', height: 16),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        AppLocalizations.of(context)!.continueWithGoogle,
                                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16),
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Footer within card
                          Text(
                            AppLocalizations.of(context)!.secureTrustedMatrimony,
                            style: GoogleFonts.montserrat(
                              fontSize: 12, 
                              color: isDark ? Colors.grey[500] : Colors.grey[400],
                              fontWeight: FontWeight.w500
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
