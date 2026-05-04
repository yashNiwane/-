import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:hitwardhini/l10n/app_localizations.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _supabase = Supabase.instance.client;
  late Razorpay _razorpay;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _openUpiIntent() {
    final user = _supabase.auth.currentUser;
    
    var options = {
      'key': 'rzp_test_S49rSEiIf7Pt6S',
      'amount': 10100, // Amount in paise (₹101 = 10100 paise)
      'currency': 'INR',
      'name': 'Hitwardhini',
      'description': 'Yearly Donation',
      'retry': {
        'enabled': true,
        'max_count': 3,
      },
      'prefill': {
        'email': user?.email ?? '',
        'contact': user?.phone ?? '',
      },
      'external': {
        'wallets': ['paytm'],
      },
      'theme': {
        'color': '#7C3AED',
      },
      'notes': {
        'user_id': user?.id ?? '',
      },
    };

    try {
      setState(() => _isLoading = true);
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('${AppLocalizations.of(context)!.errorOpeningGateway}: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Calculate expiry date (1 year from now)
      final expiryDate = DateTime.now().add(const Duration(days: 365));

      await _supabase.from('profiles').update({
        'is_paid': true,
        'subscription_expiry': expiryDate.toIso8601String(),
        'razorpay_payment_id': response.paymentId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _supabase.auth.currentUser!.id);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.donationSuccessful),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('${AppLocalizations.of(context)!.paymentSuccessfulUpdateError}: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) setState(() => _isLoading = false);
    _showError('${AppLocalizations.of(context)!.paymentFailed}: ${response.message ?? AppLocalizations.of(context)!.unknown}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppLocalizations.of(context)!.externalWallet}: ${response.walletName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context) 
          ? IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 40),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 64),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context)!.supportOurCause,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.donateToHelp,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Benefits
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildBenefitItem(context, Icons.people_outline_rounded, AppLocalizations.of(context)!.viewUnlimitedProfiles, AppLocalizations.of(context)!.viewUnlimitedSubtitle),
                      _buildBenefitItem(context, Icons.chat_bubble_outline_rounded, AppLocalizations.of(context)!.directMessaging, AppLocalizations.of(context)!.directMessagingSubtitle),
                      _buildBenefitItem(context, Icons.verified_user_outlined, AppLocalizations.of(context)!.verifiedBadge, AppLocalizations.of(context)!.verifiedBadgeSubtitle),
                      _buildBenefitItem(context, Icons.support_agent_rounded, AppLocalizations.of(context)!.prioritySupport, AppLocalizations.of(context)!.prioritySupportSubtitle),
                    ],
                  ),
                ),
              ),

              // Pricing and Action
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.yearlyDonation,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '₹101',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.bestValue,
                            style: GoogleFonts.poppins(
                              color: Colors.amber[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _openUpiIntent,
                        icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.account_balance_wallet_rounded),
                        label: Text(
                          _isLoading ? AppLocalizations.of(context)!.processing : AppLocalizations.of(context)!.payViaUpi,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(BuildContext context, IconData icon, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 14,
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
