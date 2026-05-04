import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hitwardhini/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;

  const EditProfileScreen({super.key, required this.currentData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _occupationController;
  late TextEditingController _educationController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentData['full_name']);
    _cityController = TextEditingController(text: widget.currentData['city']);
    _occupationController = TextEditingController(text: widget.currentData['occupation']);
    _educationController = TextEditingController(text: widget.currentData['education']);
    _phoneController = TextEditingController(text: widget.currentData['phone_number']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _occupationController.dispose();
    _educationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      
      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'city': _cityController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'education': _educationController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdatedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorUpdatingProfile}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.editProfile,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(AppLocalizations.of(context)!.fullName, _nameController, Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(AppLocalizations.of(context)!.phoneNumber, _phoneController, Icons.phone_outlined, TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField(AppLocalizations.of(context)!.city, _cityController, Icons.location_on_outlined),
              const SizedBox(height: 16),
              _buildTextField(AppLocalizations.of(context)!.occupation, _occupationController, Icons.work_outline),
              const SizedBox(height: 16),
              _buildTextField(AppLocalizations.of(context)!.education, _educationController, Icons.school_outlined),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          AppLocalizations.of(context)!.saveChanges,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, [TextInputType? type]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          size: 20,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) => value?.isEmpty == true ? AppLocalizations.of(context)!.pleaseEnter(label) : null,
    );
  }
}
