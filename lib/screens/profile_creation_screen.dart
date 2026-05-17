import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hitwardhini/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({super.key});

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  static const List<String> _biodataAllowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  final _supabase = Supabase.instance.client;
  final _pageController = PageController();

  // Total steps: Name, Gender, Phone, DOB, Height, Education, Occupation, City, Photo, Biodata
  final int _totalSteps = 10;
  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers
  final _nameController = TextEditingController();
  String _selectedGender = 'Male'; // Default
  final _phoneController = TextEditingController();
  final _educationController = TextEditingController();
  final _occupationController = TextEditingController();
  final _cityController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  DateTime? _selectedDate;
  File? _profileImage;
  File? _biodataFile;
  String? _biodataFileName;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchExistingProfile();
  }

  void _checkAuth() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
    }
  }

  Future<void> _fetchExistingProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data != null) {
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _selectedGender = data['gender'] ?? 'Male';
          _phoneController.text = data['phone_number'] ?? '';
          if (data['date_of_birth'] != null) {
            _selectedDate = DateTime.parse(data['date_of_birth']);
          }
          _educationController.text = data['education'] ?? '';
          _occupationController.text = data['occupation'] ?? '';
          _cityController.text = data['city'] ?? '';
          _cityController.text = data['city'] ?? '';
          if (data['height'] != null) {
            // Try to parse existing format like "5' 9""
            final h = data['height'] as String;
            final parts = h.split("'");
            if (parts.isNotEmpty) {
              _heightFeetController.text = parts[0].trim();
              if (parts.length > 1) {
                _heightInchesController.text = parts[1]
                    .replaceAll('"', '')
                    .trim();
              }
            }
          }

          if (data['full_name'] != null && data['education'] != null) {
            _currentStep = _totalSteps - 1;
          }
        });

        if (data['is_paid'] == true) {
          if (mounted) Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      debugPrint('Error fetching existing profile: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _educationController.dispose();
    _occupationController.dispose();
    _cityController.dispose();
    _cityController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    super.dispose();
  }

  // Navigation Logic
  void _nextPage() {
    if (_validateCurrentStep()) {
      if (_currentStep < _totalSteps - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentStep++);
      } else {
        _submitProfile();
      }
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  bool _validateCurrentStep() {
    final l10n = AppLocalizations.of(context)!;
    switch (_currentStep) {
      case 0: // Name
        if (_nameController.text.trim().length < 3) {
          _showError(l10n.pleaseEnterFullName);
          return false;
        }
        return true;
      case 1: // Gender
        return true; // Default selected
      case 2: // Phone
        final phone = _phoneController.text.trim();
        if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
          _showError(l10n.pleaseEnterPhone);
          return false;
        }
        return true;
      case 3: // DOB
        if (_selectedDate == null) {
          _showError(l10n.pleaseSelectDob);
          return false;
        }
        return true;
      case 4: // Height
        final feet = _heightFeetController.text.trim();
        final inches = _heightInchesController.text.trim();

        if (feet.isEmpty) {
          _showError(l10n.pleaseEnterFeet);
          return false;
        }

        final feetVal = int.tryParse(feet);
        if (feetVal == null || feetVal <= 0 || feetVal > 8) {
          _showError(l10n.pleaseEnterValidFeet);
          return false;
        }

        if (inches.isNotEmpty) {
          final inchesVal = int.tryParse(inches);
          if (inchesVal == null || inchesVal < 0 || inchesVal >= 12) {
            _showError(l10n.pleaseEnterValidInches);
            return false;
          }
        }
        return true;
      case 5: // Education
        if (_educationController.text.trim().isEmpty) {
          _showError(l10n.pleaseEnterEducation);
          return false;
        }
        return true;
      case 6: // Occupation
        if (_occupationController.text.trim().isEmpty) {
          _showError(l10n.pleaseEnterOccupation);
          return false;
        }
        return true;
      case 7: // City
        if (_cityController.text.trim().isEmpty) {
          _showError(l10n.pleaseEnterCity);
          return false;
        }
        return true;
      case 8: // Photo
        if (_profileImage == null) {
          _showError(l10n.pleaseSelectPhoto);
          return false;
        }
        return true;
      case 9: // Biodata
        if (_biodataFile == null) {
          _showError(l10n.pleaseUploadBiodata);
          return false;
        }
        return true;
      default:
        return false;
    }
  }

  // Actions
  Future<void> _pickImage() async {
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
      setState(() => _profileImage = File(image.path));
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // 18 years
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<String?> _uploadFile(File file, String bucket, String path) async {
    try {
      final fileExt = file.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}_$path.$fileExt';
      await _supabase.storage.from(bucket).upload(fileName, file);
      return _supabase.storage.from(bucket).getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitProfile() async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profileUrl = await _uploadFile(
        _profileImage!,
        'avatars',
        'profile_$userId',
      );
      final biodataUrl = await _uploadFile(
        _biodataFile!,
        'documents',
        'biodata_$userId',
      );

      if (profileUrl == null || biodataUrl == null)
        throw Exception('File upload failed');

      await _supabase.from('profiles').upsert({
        'id': userId,
        'email': _supabase.auth.currentUser?.email,
        'full_name': _nameController.text.trim(),
        'gender': _selectedGender,
        'phone_number': _phoneController.text.trim(),
        'date_of_birth': _selectedDate!.toIso8601String(),
        'education': _educationController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'city': _cityController.text.trim(),
        'height':
            "${_heightFeetController.text.trim()}' ${_heightInchesController.text.trim()}\"",
        'profile_photo_url': profileUrl,
        'biodata_url': biodataUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 10,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.green,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.profileGenerated,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.profileLiveSearch,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Redirect to Dashboard
                        _goToDashboard();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        l10n.enterMatrimony,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
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
    } catch (e) {
      _showError('${l10n.errorSavingProfile}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Navigation & Access Logic ---

  void _goToDashboard() {
    if (mounted) {
      Navigator.pop(context); // Close success dialog
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  // Legacy check function removed completely as Dashboard handles logic now.

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _prevPage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _totalSteps,
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        color: primaryColor,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentStep + 1}/$_totalSteps',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSimpleStep(
                    title: AppLocalizations.of(context)!.whatIsYourName,
                    subtitle: AppLocalizations.of(context)!.enterFullName,
                    child: _buildTextField(_nameController, "Ex. Rohit Kale"),
                  ),
                  _buildGenderStep(), // New Step 1
                  _buildSimpleStep(
                    title: AppLocalizations.of(context)!.typeYourNumber,
                    subtitle: AppLocalizations.of(
                      context,
                    )!.officialCommunication,
                    child: _buildTextField(
                      _phoneController,
                      "Ex. 9876543210",
                      type: TextInputType.phone,
                    ),
                  ),
                  _buildSimpleStep(
                    title: AppLocalizations.of(context)!.whenWereYouBorn,
                    subtitle: AppLocalizations.of(context)!.findAgeGroupMatches,
                    child: GestureDetector(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? Colors.grey[900] : Colors.grey[50],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: primaryColor),
                            const SizedBox(width: 16),
                            Text(
                              _selectedDate == null
                                  ? AppLocalizations.of(context)!.selectDate
                                  : DateFormat(
                                      'dd MMM yyyy',
                                    ).format(_selectedDate!),
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: _selectedDate == null
                                    ? Colors.grey
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildSimpleStep(
                    title: AppLocalizations.of(context)!.howTallAreYou,
                    subtitle: AppLocalizations.of(
                      context,
                    )!.enterHeightFeetInches,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _heightFeetController,
                            AppLocalizations.of(context)!.feet,
                            type: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            _heightInchesController,
                            AppLocalizations.of(context)!.inches,
                            type: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSimpleStep(
                    title: AppLocalizations.of(context)!.whatIsYourEducation,
                    subtitle: AppLocalizations.of(
                      context,
                    )!.degreesSpecializations,
                    child: _buildTextField(
                      _educationController,
                      "Ex. B.Tech, MBA",
                    ),
                  ),
                  _buildSimpleStep(
                    title: AppLocalizations.of(context)!.whatDoYouDo,
                    subtitle: AppLocalizations.of(context)!.professionJobTitle,
                    child: _buildTextField(
                      _occupationController,
                      "Ex. Software Engineer",
                    ),
                  ),
                  _buildSimpleStep(
                    title: AppLocalizations.of(context)!.whereDoYouLive,
                    subtitle: AppLocalizations.of(context)!.currentCity,
                    child: _buildTextField(_cityController, "Ex. Pune"),
                  ),
                  _buildSimpleStep(
                    title: AppLocalizations.of(context)!.addProfilePhoto,
                    subtitle: AppLocalizations.of(context)!.photoInterestBoost,
                    child: Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 100,
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                          child: _profileImage == null
                              ? Icon(
                                  Icons.add_a_photo_rounded,
                                  size: 60,
                                  color: Colors.grey[400],
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  _buildSimpleStep(
                    title: AppLocalizations.of(context)!.uploadBiodata,
                    subtitle: AppLocalizations.of(context)!.familyBackground,
                    child: GestureDetector(
                      onTap: _pickBiodata,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.5),
                            style: BorderStyle.solid,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file,
                              size: 50,
                              color: primaryColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _biodataFileName ??
                                  AppLocalizations.of(context)!.tapToUpload,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                            if (_biodataFileName == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  AppLocalizations.of(context)!.supportsFormats,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Continue Button Area
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: primaryColor.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _currentStep == _totalSteps - 1
                              ? AppLocalizations.of(context)!.completeProfile
                              : AppLocalizations.of(context)!.continueText,
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionOption(
    String label,
    IconData icon,
    String selectedValue,
    Function(String) onSelect,
  ) {
    final isSelected = selectedValue == label;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => onSelect(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey,
              size: 28,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isSelected ? primaryColor : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderStep() {
    return _buildSimpleStep(
      title: AppLocalizations.of(context)!.whatIsYourGender,
      subtitle: AppLocalizations.of(context)!.findRelevantMatches,
      child: Column(
        children: [
          _buildSelectionOption(
            AppLocalizations.of(context)!.male,
            Icons.male_rounded,
            _selectedGender == 'Male' ? AppLocalizations.of(context)!.male : '',
            (val) => setState(() => _selectedGender = 'Male'),
          ),
          const SizedBox(height: 16),
          _buildSelectionOption(
            AppLocalizations.of(context)!.female,
            Icons.female_rounded,
            _selectedGender == 'Female'
                ? AppLocalizations.of(context)!.female
                : '',
            (val) => setState(() => _selectedGender = 'Female'),
          ),
        ],
      ),
    );
  }

  // Deprecated: Old _buildGenderOption replaced by generic _buildSelectionOption
  // keeping structure logic within _buildGenderStep for now to avoid large diffs if needed,
  // but here I replaced the whole block to be cleaner.
  /* 
  Widget _buildGenderOption(String gender, IconData icon) { ... } 
  */

  Widget _buildSimpleStep({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType type = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: type,
      autofocus: true, // Auto-focus enabled
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _nextPage(), // Pressing Enter/Next goes to next step
      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      ),
      maxLines: type == TextInputType.multiline ? null : 1,
    );
  }
}
