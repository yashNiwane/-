import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  static const List<String> _biodataAllowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _occupationController;
  late TextEditingController _educationController;
  late TextEditingController _phoneController;
  late TextEditingController _heightFeetController;
  late TextEditingController _heightInchesController;

  DateTime? _selectedDob;
  File? _profileImageFile;
  File? _biodataFile;
  String? _biodataFileName;
  String? _existingProfilePhotoUrl;
  String? _existingBiodataUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentData['full_name'],
    );
    _cityController = TextEditingController(text: widget.currentData['city']);
    _occupationController = TextEditingController(
      text: widget.currentData['occupation'],
    );
    _educationController = TextEditingController(
      text: widget.currentData['education'],
    );
    _phoneController = TextEditingController(
      text: widget.currentData['phone_number'],
    );
    _existingProfilePhotoUrl = widget.currentData['profile_photo_url'];
    _existingBiodataUrl = widget.currentData['biodata_url'];

    final dobRaw = widget.currentData['date_of_birth'];
    if (dobRaw is String && dobRaw.isNotEmpty) {
      _selectedDob = DateTime.tryParse(dobRaw);
    }

    final heightRaw = (widget.currentData['height'] ?? '').toString();
    final heightMatch = RegExp(r"(\d+)\s*'\s*(\d+)").firstMatch(heightRaw);
    final feet = heightMatch?.group(1) ?? '';
    final inches = heightMatch?.group(2) ?? '';
    _heightFeetController = TextEditingController(text: feet);
    _heightInchesController = TextEditingController(text: inches);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _occupationController.dispose();
    _educationController.dispose();
    _phoneController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Profile Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery / Album'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await ImagePicker().pickImage(source: source);
    if (image != null) {
      setState(() => _profileImageFile = File(image.path));
    }
  }

  Future<void> _pickBiodata() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Biodata Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Choose Biodata File'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );

    if (action == 'camera') {
      final image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image == null) return;
      setState(() {
        _biodataFile = File(image.path);
        _biodataFileName = image.name;
      });
    } else if (action == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _biodataAllowedExtensions,
      );
      final path = result?.files.single.path;
      if (path == null) return;
      setState(() {
        _biodataFile = File(path);
        _biodataFileName = result!.files.single.name;
      });
    }
  }

  Future<void> _selectDob(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDob ?? DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<String?> _uploadFile(File file, String bucket, String prefix) async {
    final userId = _supabase.auth.currentUser!.id;
    final ext = file.path.split('.').last;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${prefix}_$userId.$ext';
    await _supabase.storage.from(bucket).upload(fileName, file);
    return _supabase.storage.from(bucket).getPublicUrl(fileName);
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectDob)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      String? profilePhotoUrl = _existingProfilePhotoUrl;
      String? biodataUrl = _existingBiodataUrl;

      if (_profileImageFile != null) {
        profilePhotoUrl = await _uploadFile(
          _profileImageFile!,
          'avatars',
          'profile',
        );
      }
      if (_biodataFile != null) {
        biodataUrl = await _uploadFile(_biodataFile!, 'documents', 'biodata');
      }

      await _supabase
          .from('profiles')
          .update({
            'full_name': _nameController.text.trim(),
            'city': _cityController.text.trim(),
            'occupation': _occupationController.text.trim(),
            'education': _educationController.text.trim(),
            'phone_number': _phoneController.text.trim(),
            'date_of_birth': _selectedDob!.toIso8601String(),
            'height':
                "${_heightFeetController.text.trim()}' ${_heightInchesController.text.trim()}\"",
            'profile_photo_url': profilePhotoUrl,
            'biodata_url': biodataUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.profileUpdatedSuccessfully,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.errorUpdatingProfile}: $e',
            ),
          ),
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
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(context)!.gender,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: Text(
                  (widget.currentData['gender'] ??
                          AppLocalizations.of(context)!.notSet)
                      .toString(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildDobField(),
              const SizedBox(height: 16),
              _buildTextField(
                AppLocalizations.of(context)!.fullName,
                _nameController,
                Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                AppLocalizations.of(context)!.phoneNumber,
                _phoneController,
                Icons.phone_outlined,
                TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                AppLocalizations.of(context)!.city,
                _cityController,
                Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                AppLocalizations.of(context)!.occupation,
                _occupationController,
                Icons.work_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                AppLocalizations.of(context)!.education,
                _educationController,
                Icons.school_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      'Height (ft)',
                      _heightFeetController,
                      Icons.height_rounded,
                      TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      'Height (in)',
                      _heightInchesController,
                      Icons.straighten_rounded,
                      TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildUploadCard(
                title: 'Profile Photo',
                subtitle: _profileImageFile != null
                    ? _profileImageFile!.path.split('\\').last
                    : (_existingProfilePhotoUrl != null
                          ? 'Current photo available'
                          : 'No photo uploaded'),
                icon: Icons.photo_camera_back_rounded,
                onTap: _pickProfileImage,
              ),
              const SizedBox(height: 12),
              _buildUploadCard(
                title: 'Biodata',
                subtitle:
                    _biodataFileName ??
                    (_existingBiodataUrl != null
                        ? 'Current biodata available'
                        : 'Tap to upload'),
                icon: Icons.picture_as_pdf_rounded,
                onTap: _pickBiodata,
              ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                          AppLocalizations.of(context)!.saveChanges,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, [
    TextInputType? type,
  ]) {
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
          borderSide: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (value) => value?.isEmpty == true
          ? AppLocalizations.of(context)!.pleaseEnter(label)
          : null,
    );
  }

  Widget _buildDobField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = _selectedDob == null
        ? 'Date of Birth'
        : '${_selectedDob!.day.toString().padLeft(2, '0')}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.year}';

    return InkWell(
      onTap: () => _selectDob(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            const SizedBox(width: 10),
            Text(text, style: GoogleFonts.inter(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.upload_file_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}
