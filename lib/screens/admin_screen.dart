import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hitwardhini/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
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
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _updates = [];
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;
  String _userSearchQuery = '';
  String _genderFilter = 'All';
  bool _routeArgsApplied = false;
  final Set<String> _expandedUserIds = <String>{};
  late TabController _tabController;

  // Statistics
  int _totalUsers = 0;
  int _paidUsers = 0;
  int _pendingInterests = 0;
  int _totalMessages = 0;
  int _totalUpdates = 0;
  int _blockedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsApplied) return;
    _routeArgsApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final search = (args['searchQuery'] ?? '').toString().trim();
      final gender = (args['genderFilter'] ?? '').toString().trim();
      if (search.isNotEmpty || gender.isNotEmpty) {
        setState(() {
          if (search.isNotEmpty) _userSearchQuery = search;
          if (gender == 'Girls' || gender == 'Boys' || gender == 'All') {
            _genderFilter = gender;
          }
          _tabController.index = 0; // Users tab
        });
      }
    }
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchUsers(),
      _fetchStatistics(),
      _fetchUpdates(),
      _fetchBlockedUsers(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchUsers() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('is_admin', false)
          .order('created_at', ascending: false);
      if (mounted)
        setState(() => _users = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _showSnackBar(
        AppLocalizations.of(context)!.errorMsg(e.toString()),
        Colors.red,
      );
    }
  }

  Future<void> _fetchStatistics() async {
    try {
      final profiles = await _supabase.from('profiles').select('is_paid');
      final interests = await _supabase
          .from('interests')
          .select()
          .eq('status', 'pending');
      final messages = await _supabase.from('messages').select();

      if (mounted) {
        setState(() {
          _totalUsers = profiles.length;
          _paidUsers = profiles.where((p) => p['is_paid'] == true).length;
          _pendingInterests = interests.length;
          _totalMessages = messages.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching statistics: $e');
    }
  }

  Future<void> _fetchUpdates() async {
    try {
      final data = await _supabase
          .from('updates')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _updates = List<Map<String, dynamic>>.from(data);
          _totalUpdates = _updates.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching updates: $e');
    }
  }

  Future<void> _fetchBlockedUsers() async {
    try {
      final data = await _supabase
          .from('blocked_users')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _blockedUsers = List<Map<String, dynamic>>.from(data);
          _blockedCount = _blockedUsers.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
    }
  }

  Future<void> _toggleAdminStatus(String id, bool currentStatus) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'is_admin': !currentStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
      _showSnackBar(
        !currentStatus
            ? AppLocalizations.of(context)!.adminAccessGranted
            : AppLocalizations.of(context)!.adminAccessRevoked,
        !currentStatus ? Colors.blue : Colors.orange,
      );
      await _fetchAllData();
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _deleteUser(
    String id,
    String name, {
    bool isAdmin = false,
  }) async {
    if (isAdmin) {
      _showSnackBar('Admin profile cannot be deleted.', Colors.orange);
      return;
    }
    final confirmed = await _showConfirmDialog(
      AppLocalizations.of(context)!.deleteUser,
      AppLocalizations.of(context)!.deleteUserConfirm(name),
    );
    if (confirmed == true) {
      try {
        await _supabase.from('saved_profiles').delete().eq('user_id', id);
        await _supabase
            .from('saved_profiles')
            .delete()
            .eq('saved_profile_id', id);
        await _supabase.from('interests').delete().eq('sender_id', id);
        await _supabase.from('interests').delete().eq('receiver_id', id);
        await _supabase.from('messages').delete().eq('sender_id', id);
        await _supabase.from('messages').delete().eq('receiver_id', id);
        final deleted = await _supabase
            .from('profiles')
            .delete()
            .eq('id', id)
            .select('id');
        if (deleted.isEmpty) {
          throw Exception(
            'Profile was not deleted. Possible RLS restriction or user already removed.',
          );
        }
        _showSnackBar(
          AppLocalizations.of(context)!.userDeletedSuccessfully,
          Colors.green,
        );
        await _fetchAllData();
      } catch (e) {
        _showSnackBar(
          AppLocalizations.of(context)!.errorMsg(e.toString()),
          Colors.red,
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _showCreateUserProfileDialog(
    bool isDark,
    Color primaryColor,
  ) async {
    final loginIdController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final genderController = TextEditingController(text: 'Male');
    final phoneController = TextEditingController();
    final dobController = TextEditingController();
    final educationController = TextEditingController();
    final occupationController = TextEditingController();
    final cityController = TextEditingController();
    final heightController = TextEditingController();
    File? profilePhotoFile;
    File? biodataFile;
    String? profilePhotoName;
    String? biodataName;
    bool isSubmitting = false;
    String? statusMessage;
    Color statusColor = Colors.grey;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildField(String label, TextEditingController controller) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            }

            Future<void> submit() async {
              if (loginIdController.text.trim().isEmpty ||
                  passwordController.text.isEmpty ||
                  nameController.text.trim().isEmpty) {
                setModalState(() {
                  statusMessage =
                      'Login ID, password, and full name are required.';
                  statusColor = Colors.orange;
                });
                return;
              }
              setModalState(() {
                isSubmitting = true;
                statusMessage = 'Creating profile...';
                statusColor = Colors.blue;
              });
              try {
                final loginId = loginIdController.text.trim();
                final phone = phoneController.text.trim();
                final fullName = nameController.text.trim();
                final dob = dobController.text.trim();

                // Duplicate guard 1: login_id (skip if column is not migrated yet)
                bool loginIdColumnMissing = false;
                try {
                  final existingByLogin = await _supabase
                      .from('profiles')
                      .select('id')
                      .eq('login_id', loginId)
                      .maybeSingle();
                  if (existingByLogin != null) {
                    setModalState(() {
                      statusMessage =
                          'Profile already exists for this Login ID.';
                      statusColor = Colors.orange;
                    });
                    return;
                  }
                } catch (e) {
                  final msg = e.toString();
                  if (msg.contains('login_id') &&
                      msg.contains('does not exist')) {
                    loginIdColumnMissing = true;
                    setModalState(() {
                      statusMessage =
                          'DB migration pending: login_id column missing. Continuing without Login ID duplicate check.';
                      statusColor = Colors.orange;
                    });
                  } else {
                    rethrow;
                  }
                }

                // Duplicate guard 2: phone number
                if (phone.isNotEmpty) {
                  final existingByPhone = await _supabase
                      .from('profiles')
                      .select('id')
                      .eq('phone_number', phone)
                      .maybeSingle();
                  if (existingByPhone != null) {
                    setModalState(() {
                      statusMessage =
                          'Profile already exists for this phone number.';
                      statusColor = Colors.orange;
                    });
                    return;
                  }
                }

                // Duplicate guard 3: full_name + DOB combination
                if (dob.isNotEmpty) {
                  final existingByNameDob = await _supabase
                      .from('profiles')
                      .select('id')
                      .eq('full_name', fullName)
                      .eq('date_of_birth', dob)
                      .maybeSingle();
                  if (existingByNameDob != null) {
                    setModalState(() {
                      statusMessage =
                          'Profile already exists for this name and date of birth.';
                      statusColor = Colors.orange;
                    });
                    return;
                  }
                }

                String? profilePhotoUrl;
                String? biodataUrl;

                if (profilePhotoFile != null) {
                  final ext = profilePhotoFile!.path.split('.').last;
                  final fileName =
                      'admin_${DateTime.now().millisecondsSinceEpoch}_avatar.$ext';
                  await _supabase.storage
                      .from('avatars')
                      .upload(fileName, profilePhotoFile!);
                  profilePhotoUrl = _supabase.storage
                      .from('avatars')
                      .getPublicUrl(fileName);
                }

                if (biodataFile != null) {
                  final ext = biodataFile!.path.split('.').last;
                  final fileName =
                      'admin_${DateTime.now().millisecondsSinceEpoch}_biodata.$ext';
                  await _supabase.storage
                      .from('documents')
                      .upload(fileName, biodataFile!);
                  biodataUrl = _supabase.storage
                      .from('documents')
                      .getPublicUrl(fileName);
                }

                final res = await _supabase.functions.invoke(
                  'admin-create-user-profile',
                  body: {
                    'login_id': loginId,
                    'login_id_column_missing': loginIdColumnMissing,
                    'password': passwordController.text,
                    'profile': {
                      'full_name': fullName,
                      'gender': genderController.text.trim().isEmpty
                          ? 'Male'
                          : genderController.text.trim(),
                      'phone_number': phone,
                      'date_of_birth': dob,
                      'education': educationController.text.trim(),
                      'occupation': occupationController.text.trim(),
                      'city': cityController.text.trim(),
                      'height': heightController.text.trim(),
                      'profile_photo_url': profilePhotoUrl,
                      'biodata_url': biodataUrl,
                      'is_paid': true,
                      'payment_exempt': true,
                      'created_by_admin': true,
                      'prompt_password_change': true,
                    },
                  },
                );

                if (res.status >= 200 && res.status < 300) {
                  setModalState(() {
                    statusMessage = 'Profile created successfully.';
                    statusColor = Colors.green;
                  });
                  if (mounted) Navigator.pop(context);
                  if (mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Profile Created'),
                        content: Text(
                          'User profile created successfully.\n\nLogin ID: $loginId',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                  await _fetchAllData();
                } else {
                  final failMessage = 'Creation failed: ${res.data}';
                  setModalState(() {
                    statusMessage = failMessage;
                    statusColor = Colors.red;
                  });
                  if (mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Creation Failed'),
                        content: Text(failMessage),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              } catch (e) {
                final failMessage = 'Creation failed: $e';
                setModalState(() {
                  statusMessage = failMessage;
                  statusColor = Colors.red;
                });
                if (mounted) {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Creation Failed'),
                      content: Text(failMessage),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              } finally {
                setModalState(() => isSubmitting = false);
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Create User & Profile',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Column(
                            children: [
                              buildField(
                                'Login ID (email or custom ID)',
                                loginIdController,
                              ),
                              buildField(
                                'Temporary Password',
                                passwordController,
                              ),
                              buildField('Full Name', nameController),
                              buildField('Gender', genderController),
                              buildField('Phone Number', phoneController),
                              buildField(
                                'Date of Birth (YYYY-MM-DD)',
                                dobController,
                              ),
                              buildField('Education', educationController),
                              buildField('Occupation', occupationController),
                              buildField('City', cityController),
                              buildField('Height', heightController),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: isSubmitting
                                          ? null
                                          : () async {
                                              final source =
                                                  await showModalBottomSheet<
                                                    ImageSource
                                                  >(
                                                    context: context,
                                                    builder: (context) => SafeArea(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons
                                                                  .camera_alt_rounded,
                                                            ),
                                                            title: const Text(
                                                              'Take Profile Photo',
                                                            ),
                                                            onTap: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  ImageSource
                                                                      .camera,
                                                                ),
                                                          ),
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons
                                                                  .photo_library_rounded,
                                                            ),
                                                            title: const Text(
                                                              'Choose from Gallery / Album',
                                                            ),
                                                            onTap: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  ImageSource
                                                                      .gallery,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                              if (source == null) return;
                                              final picked = await ImagePicker()
                                                  .pickImage(source: source);
                                              if (picked != null) {
                                                setModalState(() {
                                                  profilePhotoFile = File(
                                                    picked.path,
                                                  );
                                                  profilePhotoName =
                                                      picked.name;
                                                });
                                              }
                                            },
                                      icon: const Icon(Icons.photo_rounded),
                                      label: Text(
                                        profilePhotoName == null
                                            ? 'Add Profile Photo'
                                            : 'Photo Selected',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: isSubmitting
                                          ? null
                                          : () async {
                                              final action = await showModalBottomSheet<String>(
                                                context: context,
                                                builder: (context) => SafeArea(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      ListTile(
                                                        leading: const Icon(
                                                          Icons
                                                              .camera_alt_rounded,
                                                        ),
                                                        title: const Text(
                                                          'Take Biodata Photo',
                                                        ),
                                                        onTap: () =>
                                                            Navigator.pop(
                                                              context,
                                                              'camera',
                                                            ),
                                                      ),
                                                      ListTile(
                                                        leading: const Icon(
                                                          Icons
                                                              .upload_file_rounded,
                                                        ),
                                                        title: const Text(
                                                          'Choose Biodata File',
                                                        ),
                                                        onTap: () =>
                                                            Navigator.pop(
                                                              context,
                                                              'file',
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );

                                              if (action == 'camera') {
                                                final image =
                                                    await ImagePicker()
                                                        .pickImage(
                                                          source: ImageSource
                                                              .camera,
                                                        );
                                                if (image == null) return;
                                                setModalState(() {
                                                  biodataFile = File(
                                                    image.path,
                                                  );
                                                  biodataName = image.name;
                                                });
                                              } else if (action == 'file') {
                                                final picked = await FilePicker
                                                    .platform
                                                    .pickFiles(
                                                      type: FileType.custom,
                                                      allowedExtensions:
                                                          _biodataAllowedExtensions,
                                                    );
                                                final path =
                                                    picked?.files.single.path;
                                                if (path == null) return;
                                                setModalState(() {
                                                  biodataFile = File(path);
                                                  biodataName =
                                                      picked!.files.single.name;
                                                });
                                              }
                                            },
                                      icon: const Icon(
                                        Icons.description_rounded,
                                      ),
                                      label: Text(
                                        biodataName == null
                                            ? 'Add Biodata'
                                            : biodataName!,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (statusMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            statusMessage!,
                            style: GoogleFonts.poppins(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ========== POST UPDATE METHODS ==========
  void _showCreateUpdateDialog(bool isDark, Color primaryColor) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedType = 'update';
    String? mediaUrl;
    String mediaType = 'none';
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, primaryColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_circle_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      AppLocalizations.of(context)!.createPost,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Post Type Selection
                      Text(
                        AppLocalizations.of(context)!.postType,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildTypeChip(
                            AppLocalizations.of(context)!.update,
                            'update',
                            selectedType,
                            Colors.blue,
                            (v) => setModalState(() => selectedType = v),
                          ),
                          const SizedBox(width: 10),
                          _buildTypeChip(
                            AppLocalizations.of(context)!.successStory,
                            'success_story',
                            selectedType,
                            Colors.green,
                            (v) => setModalState(() => selectedType = v),
                          ),
                          const SizedBox(width: 10),
                          _buildTypeChip(
                            AppLocalizations.of(context)!.announcement,
                            'announcement',
                            selectedType,
                            Colors.orange,
                            (v) => setModalState(() => selectedType = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        AppLocalizations.of(context)!.title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.enterTitle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey[850]
                              : Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Content
                      Text(
                        AppLocalizations.of(context)!.content,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: contentController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.writePost,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey[850]
                              : Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Media Upload
                      Text(
                        AppLocalizations.of(context)!.mediaOptional,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (mediaUrl != null)
                        Stack(
                          children: [
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: mediaType == 'image'
                                    ? DecorationImage(
                                        image: NetworkImage(mediaUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: Colors.grey[300],
                              ),
                              child: mediaType == 'video'
                                  ? const Center(
                                      child: Icon(
                                        Icons.play_circle_filled,
                                        size: 50,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setModalState(() {
                                  mediaUrl = null;
                                  mediaType = 'none';
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildMediaButton(
                                icon: Icons.image_rounded,
                                label: AppLocalizations.of(context)!.addImage,
                                color: Colors.purple,
                                isDark: isDark,
                                isLoading: isUploading,
                                onTap: () async {
                                  setModalState(() => isUploading = true);
                                  final url = await _pickAndUploadMedia(
                                    'image',
                                  );
                                  setModalState(() {
                                    mediaUrl = url;
                                    mediaType = url != null ? 'image' : 'none';
                                    isUploading = false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMediaButton(
                                icon: Icons.videocam_rounded,
                                label: AppLocalizations.of(context)!.addVideo,
                                color: Colors.teal,
                                isDark: isDark,
                                isLoading: isUploading,
                                onTap: () async {
                                  setModalState(() => isUploading = true);
                                  final url = await _pickAndUploadMedia(
                                    'video',
                                  );
                                  setModalState(() {
                                    mediaUrl = url;
                                    mediaType = url != null ? 'video' : 'none';
                                    isUploading = false;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 30),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (titleController.text.isEmpty) {
                              _showSnackBar(
                                'Please enter a title',
                                Colors.orange,
                              );
                              return;
                            }
                            try {
                              await _supabase.from('updates').insert({
                                'admin_id': _supabase.auth.currentUser!.id,
                                'title': titleController.text,
                                'content': contentController.text,
                                'update_type': selectedType,
                                'media_type': mediaType,
                                'media_url': mediaUrl,
                              });
                              Navigator.pop(context);
                              _showSnackBar(
                                AppLocalizations.of(
                                  context,
                                )!.postCreatedSuccessfully,
                                Colors.green,
                              );
                              await _fetchUpdates();
                            } catch (e) {
                              _showSnackBar('Error: $e', Colors.red);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.publishPost,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    String value,
    String selected,
    Color color,
    Function(String) onTap,
  ) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
              )
            : Column(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<String?> _pickAndUploadMedia(String type) async {
    final picker = ImagePicker();
    final XFile? file;

    if (type == 'image') {
      file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
    } else {
      file = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (file == null) return null;

    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$type.$ext';

      await _supabase.storage.from('updates').uploadBinary(fileName, bytes);
      return _supabase.storage.from('updates').getPublicUrl(fileName);
    } catch (e) {
      _showSnackBar(
        AppLocalizations.of(context)!.errorMsg(e.toString()),
        Colors.red,
      );
      return null;
    }
  }

  Future<void> _deleteUpdate(String id) async {
    final confirmed = await _showConfirmDialog(
      AppLocalizations.of(context)!.deletePost,
      AppLocalizations.of(context)!.deletePostConfirm,
    );
    if (confirmed == true) {
      try {
        await _supabase.from('updates').delete().eq('id', id);
        _showSnackBar(AppLocalizations.of(context)!.postDeleted, Colors.green);
        await _fetchUpdates();
      } catch (e) {
        _showSnackBar('Error: $e', Colors.red);
      }
    }
  }

  // ========== BLOCK USER METHODS ==========
  void _showBlockUserDialog(bool isDark, Color primaryColor) {
    final emailController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.block_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.blockUser),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.reason,
                prefixIcon: const Icon(Icons.note_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty ||
                  !emailController.text.contains('@')) {
                _showSnackBar('Enter a valid email', Colors.orange);
                return;
              }
              try {
                final inserted = await _supabase
                    .from('blocked_users')
                    .insert({
                      'email': emailController.text.toLowerCase(),
                      'reason': reasonController.text.isNotEmpty
                          ? reasonController.text
                          : null,
                      'blocked_by': _supabase.auth.currentUser!.id,
                    })
                    .select('id');
                if (inserted.isEmpty) {
                  throw Exception(
                    'Block insert failed. Check RLS policy for blocked_users.',
                  );
                }
                Navigator.pop(context);
                _showSnackBar(
                  AppLocalizations.of(context)!.userBlocked,
                  Colors.green,
                );
                await _fetchBlockedUsers();
              } catch (e) {
                if (e.toString().contains('duplicate')) {
                  _showSnackBar(
                    AppLocalizations.of(context)!.emailAlreadyBlocked,
                    Colors.orange,
                  );
                } else {
                  _showSnackBar('Error: $e', Colors.red);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.of(context)!.blockUser),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser(String id, String email) async {
    final confirmed = await _showConfirmDialog(
      AppLocalizations.of(context)!.unblock,
      AppLocalizations.of(context)!.unblockUserConfirm(email),
    );
    if (confirmed == true) {
      try {
        final removed = await _supabase
            .from('blocked_users')
            .delete()
            .eq('id', id)
            .select('id');
        if (removed.isEmpty) {
          throw Exception(
            'Unblock failed. Record not removed (RLS restriction or invalid id).',
          );
        }
        _showSnackBar(
          AppLocalizations.of(context)!.userUnblocked,
          Colors.green,
        );
        await _fetchBlockedUsers();
      } catch (e) {
        _showSnackBar('Error: $e', Colors.red);
      }
    }
  }

  Future<void> _blockUserFromProfile(Map<String, dynamic> user) async {
    final email = (user['email'] ?? '').toString().trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar(
        'This user does not have a valid email. Cannot block.',
        Colors.orange,
      );
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Block User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final inserted = await _supabase
          .from('blocked_users')
          .insert({
            'email': email,
            'reason': reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
            'blocked_by': _supabase.auth.currentUser!.id,
          })
          .select('id');
      if (inserted.isEmpty) {
        throw Exception(
          'Block insert failed. Check RLS policy for blocked_users.',
        );
      }
      _showSnackBar(AppLocalizations.of(context)!.userBlocked, Colors.green);
      await _fetchBlockedUsers();
    } catch (e) {
      if (e.toString().toLowerCase().contains('duplicate')) {
        _showSnackBar(
          AppLocalizations.of(context)!.emailAlreadyBlocked,
          Colors.orange,
        );
      } else {
        _showSnackBar('Error: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1E1B4B)
          : const Color(0xFFFDFCFB),
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.adminPanel,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.person_add_alt_1_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () => _showCreateUserProfileDialog(isDark, primaryColor),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: _fetchAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: l10n.users),
            Tab(text: l10n.posts),
            Tab(text: l10n.blocked),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(isDark, primaryColor),
                _buildUpdatesTab(isDark, primaryColor),
                _buildBlockedTab(isDark, primaryColor),
              ],
            ),
    );
  }

  Widget _buildDashboardTab(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.overview,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildStatCard(
                l10n.totalUsers,
                _totalUsers.toString(),
                Icons.people_rounded,
                const Color(0xFF6366F1),
                isDark,
              ),
              _buildStatCard(
                l10n.paidUsers,
                _paidUsers.toString(),
                Icons.verified_rounded,
                const Color(0xFF22C55E),
                isDark,
              ),
              _buildStatCard(
                l10n.totalPosts,
                _totalUpdates.toString(),
                Icons.article_rounded,
                const Color(0xFFF59E0B),
                isDark,
              ),
              _buildStatCard(
                l10n.blocked,
                _blockedCount.toString(),
                Icons.block_rounded,
                const Color(0xFFEF4444),
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            l10n.recentUsers,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ..._users
              .take(5)
              .map(
                (user) => _buildUserListTile(
                  user,
                  isDark,
                  primaryColor,
                  compact: true,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(isDark ? 0.3 : 0.15),
            color.withOpacity(isDark ? 0.15 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(bool isDark, Color primaryColor) {
    final filteredUsers = _users.where((user) {
      final gender = (user['gender'] ?? '').toString();
      if (_genderFilter == 'Girls' && gender != 'Female') return false;
      if (_genderFilter == 'Boys' && gender != 'Male') return false;
      if (_userSearchQuery.trim().isEmpty) return true;
      final q = _userSearchQuery.toLowerCase().trim();
      final name = (user['full_name'] ?? '').toString().toLowerCase();
      final city = (user['city'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final phone = (user['phone_number'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          city.contains(q) ||
          email.contains(q) ||
          phone.contains(q);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredUsers.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_alt_rounded, size: 18),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _genderFilter,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Girls', child: Text('Girls')),
                        DropdownMenuItem(value: 'Boys', child: Text('Boys')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _genderFilter = value);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) =>
                      setState(() => _userSearchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name, city, email, phone',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _userSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                setState(() => _userSearchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return _buildUserListTile(
          filteredUsers[index - 1],
          isDark,
          primaryColor,
        );
      },
    );
  }

  Widget _buildUserListTile(
    Map<String, dynamic> user,
    bool isDark,
    Color primaryColor, {
    bool compact = false,
  }) {
    final userId = (user['id'] ?? '').toString();
    final name = user['full_name'] ?? 'Unknown';
    final city = user['city'] ?? 'N/A';
    final isPaid = user['is_paid'] ?? false;
    final isAdmin = user['is_admin'] ?? false;
    final isExpanded = _expandedUserIds.contains(userId);
    final createdAt = user['created_at'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(user['created_at']))
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdmin
              ? Colors.blue.withOpacity(0.5)
              : (isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1)),
          width: isAdmin ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedUserIds.remove(userId);
              } else {
                _expandedUserIds.add(userId);
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: compact ? 22 : 28,
                          backgroundColor: primaryColor.withOpacity(0.1),
                          backgroundImage: user['profile_photo_url'] != null
                              ? NetworkImage(user['profile_photo_url'])
                              : null,
                          child: user['profile_photo_url'] == null
                              ? Icon(
                                  Icons.person,
                                  size: compact ? 20 : 26,
                                  color: primaryColor,
                                )
                              : null,
                        ),
                        if (isAdmin)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: compact ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isPaid
                                      ? AppLocalizations.of(context)!.paid
                                      : AppLocalizations.of(context)!.free,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isPaid
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (user['email'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user['email'],
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  city,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    createdAt,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildExpandedUserDetailRow(
                          isDark,
                          'Full Name',
                          (user['full_name'] ?? 'N/A').toString(),
                        ),
                        _buildExpandedUserDetailRow(
                          isDark,
                          'Phone',
                          (user['phone_number'] ?? 'N/A').toString(),
                        ),
                        _buildExpandedUserDetailRow(
                          isDark,
                          'DOB',
                          (user['date_of_birth'] ?? 'N/A').toString(),
                        ),
                        _buildExpandedUserDetailRow(
                          isDark,
                          'Gender',
                          (user['gender'] ?? 'N/A').toString(),
                        ),
                        _buildExpandedUserDetailRow(
                          isDark,
                          'Education',
                          (user['education'] ?? 'N/A').toString(),
                        ),
                        _buildExpandedUserDetailRow(
                          isDark,
                          'Occupation',
                          (user['occupation'] ?? 'N/A').toString(),
                        ),
                        _buildExpandedUserDetailRow(
                          isDark,
                          'Height',
                          (user['height'] ?? 'N/A').toString(),
                        ),
                        _buildExpandedUserDetailRow(
                          isDark,
                          'Login ID',
                          (user['login_id'] ?? 'N/A').toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditUserProfileDialog(
                        user,
                        isDark,
                        primaryColor,
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit User'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Tooltip(
                        message: 'Block User',
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                          ),
                          onPressed: () => _blockUserFromProfile(user),
                          child: const Icon(Icons.block_rounded, size: 18),
                        ),
                      ),
                      if (!isAdmin)
                        Tooltip(
                          message: 'Delete User',
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () =>
                                _deleteUser(user['id'], name, isAdmin: isAdmin),
                            child: const Icon(Icons.delete_rounded, size: 18),
                          ),
                        ),
                      Tooltip(
                        message: 'View Photo',
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                          ),
                          onPressed:
                              (user['profile_photo_url'] ?? '')
                                  .toString()
                                  .isEmpty
                              ? null
                              : () => _showProfileAssetPopup(
                                  title: 'Profile Photo',
                                  url: user['profile_photo_url'].toString(),
                                ),
                          child: const Icon(Icons.photo_outlined, size: 18),
                        ),
                      ),
                      Tooltip(
                        message: 'View Biodata',
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                          ),
                          onPressed:
                              (user['biodata_url'] ?? '').toString().isEmpty
                              ? null
                              : () => _showProfileAssetPopup(
                                  title: 'Biodata',
                                  url: user['biodata_url'].toString(),
                                ),
                          child: const Icon(
                            Icons.description_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditUserProfileDialog(
    Map<String, dynamic> user,
    bool isDark,
    Color primaryColor,
  ) async {
    final nameController = TextEditingController(
      text: (user['full_name'] ?? '').toString(),
    );
    final loginIdController = TextEditingController(
      text: (user['login_id'] ?? '').toString(),
    );
    final genderController = TextEditingController(
      text: (user['gender'] ?? '').toString(),
    );
    final phoneController = TextEditingController(
      text: (user['phone_number'] ?? '').toString(),
    );
    final dobController = TextEditingController(
      text: (user['date_of_birth'] ?? '').toString(),
    );
    final educationController = TextEditingController(
      text: (user['education'] ?? '').toString(),
    );
    final occupationController = TextEditingController(
      text: (user['occupation'] ?? '').toString(),
    );
    final cityController = TextEditingController(
      text: (user['city'] ?? '').toString(),
    );
    final heightController = TextEditingController(
      text: (user['height'] ?? '').toString(),
    );

    bool isPaid = user['is_paid'] == true;
    bool isAdmin = user['is_admin'] == true;
    bool paymentExempt = user['payment_exempt'] == true;
    bool createdByAdmin = user['created_by_admin'] == true;
    bool promptPasswordChange = user['prompt_password_change'] == true;
    bool isSubmitting = false;
    String? statusMessage;
    Color statusColor = Colors.grey;
    File? profilePhotoFile;
    File? biodataFile;

    Widget buildField(String label, TextEditingController controller) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> save() async {
            if (nameController.text.trim().isEmpty) {
              setModalState(() {
                statusMessage = 'Full name is required.';
                statusColor = Colors.orange;
              });
              return;
            }
            setModalState(() {
              isSubmitting = true;
              statusMessage = 'Saving changes...';
              statusColor = Colors.blue;
            });
            try {
              final userId = (user['id'] ?? '').toString();
              String? profilePhotoUrl;
              String? biodataUrl;

              if (profilePhotoFile != null) {
                final ext = profilePhotoFile!.path.split('.').last;
                final fileName =
                    'admin_edit_${DateTime.now().millisecondsSinceEpoch}_$userId.$ext';
                await _supabase.storage
                    .from('avatars')
                    .upload(fileName, profilePhotoFile!);
                profilePhotoUrl = _supabase.storage
                    .from('avatars')
                    .getPublicUrl(fileName);
              }

              if (biodataFile != null) {
                final ext = biodataFile!.path.split('.').last;
                final fileName =
                    'admin_edit_${DateTime.now().millisecondsSinceEpoch}_$userId.$ext';
                await _supabase.storage
                    .from('documents')
                    .upload(fileName, biodataFile!);
                biodataUrl = _supabase.storage
                    .from('documents')
                    .getPublicUrl(fileName);
              }

              final payload = <String, dynamic>{
                'full_name': nameController.text.trim(),
                'login_id': loginIdController.text.trim().isEmpty
                    ? null
                    : loginIdController.text.trim(),
                'gender': genderController.text.trim(),
                'phone_number': phoneController.text.trim(),
                'date_of_birth': dobController.text.trim().isEmpty
                    ? null
                    : dobController.text.trim(),
                'education': educationController.text.trim(),
                'occupation': occupationController.text.trim(),
                'city': cityController.text.trim(),
                'height': heightController.text.trim(),
                'is_paid': isPaid,
                'is_admin': isAdmin,
                'payment_exempt': paymentExempt,
                'created_by_admin': createdByAdmin,
                'prompt_password_change': promptPasswordChange,
                'updated_at': DateTime.now().toIso8601String(),
              };
              if (profilePhotoUrl != null) {
                payload['profile_photo_url'] = profilePhotoUrl;
              }
              if (biodataUrl != null) {
                payload['biodata_url'] = biodataUrl;
              }

              await _supabase.from('profiles').update(payload).eq('id', userId);
              if (mounted) Navigator.pop(context);
              _showSnackBar('User updated successfully.', Colors.green);
              await _fetchAllData();
            } catch (e) {
              setModalState(() {
                statusMessage = 'Update failed: $e';
                statusColor = Colors.red;
              });
            } finally {
              setModalState(() => isSubmitting = false);
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Edit User Profile',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          children: [
                            buildField('Full Name', nameController),
                            buildField('Login ID', loginIdController),
                            buildField('Gender', genderController),
                            buildField('Phone Number', phoneController),
                            buildField(
                              'Date of Birth (YYYY-MM-DD)',
                              dobController,
                            ),
                            buildField('Education', educationController),
                            buildField('Occupation', occupationController),
                            buildField('City', cityController),
                            buildField('Height', heightController),
                            SwitchListTile(
                              value: isPaid,
                              onChanged: (v) => setModalState(() => isPaid = v),
                              title: const Text('Paid User'),
                            ),
                            SwitchListTile(
                              value: isAdmin,
                              onChanged: (v) =>
                                  setModalState(() => isAdmin = v),
                              title: const Text('Admin Access'),
                            ),
                            SwitchListTile(
                              value: paymentExempt,
                              onChanged: (v) =>
                                  setModalState(() => paymentExempt = v),
                              title: const Text('Payment Exempt'),
                            ),
                            SwitchListTile(
                              value: createdByAdmin,
                              onChanged: (v) =>
                                  setModalState(() => createdByAdmin = v),
                              title: const Text('Created By Admin'),
                            ),
                            SwitchListTile(
                              value: promptPasswordChange,
                              onChanged: (v) =>
                                  setModalState(() => promptPasswordChange = v),
                              title: const Text('Prompt Password Change'),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isSubmitting
                                        ? null
                                        : () async {
                                            final source =
                                                await showModalBottomSheet<
                                                  ImageSource
                                                >(
                                                  context: context,
                                                  builder: (context) => SafeArea(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        ListTile(
                                                          leading: const Icon(
                                                            Icons
                                                                .camera_alt_rounded,
                                                          ),
                                                          title: const Text(
                                                            'Take Profile Photo',
                                                          ),
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                context,
                                                                ImageSource
                                                                    .camera,
                                                              ),
                                                        ),
                                                        ListTile(
                                                          leading: const Icon(
                                                            Icons
                                                                .photo_library_rounded,
                                                          ),
                                                          title: const Text(
                                                            'Choose from Gallery / Album',
                                                          ),
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                context,
                                                                ImageSource
                                                                    .gallery,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                            if (source == null) return;
                                            final picked = await ImagePicker()
                                                .pickImage(source: source);
                                            if (picked != null) {
                                              setModalState(() {
                                                profilePhotoFile = File(
                                                  picked.path,
                                                );
                                              });
                                            }
                                          },
                                    icon: const Icon(Icons.photo_rounded),
                                    label: const Text('Update Profile Photo'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isSubmitting
                                        ? null
                                        : () async {
                                            final action =
                                                await showModalBottomSheet<
                                                  String
                                                >(
                                                  context: context,
                                                  builder: (context) => SafeArea(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        ListTile(
                                                          leading: const Icon(
                                                            Icons
                                                                .camera_alt_rounded,
                                                          ),
                                                          title: const Text(
                                                            'Take Biodata Photo',
                                                          ),
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                context,
                                                                'camera',
                                                              ),
                                                        ),
                                                        ListTile(
                                                          leading: const Icon(
                                                            Icons
                                                                .upload_file_rounded,
                                                          ),
                                                          title: const Text(
                                                            'Choose Biodata File',
                                                          ),
                                                          onTap: () =>
                                                              Navigator.pop(
                                                                context,
                                                                'file',
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );

                                            if (action == 'camera') {
                                              final image = await ImagePicker()
                                                  .pickImage(
                                                    source: ImageSource.camera,
                                                  );
                                              if (image == null) return;
                                              setModalState(() {
                                                biodataFile = File(image.path);
                                              });
                                            } else if (action == 'file') {
                                              final picked = await FilePicker
                                                  .platform
                                                  .pickFiles(
                                                    type: FileType.custom,
                                                    allowedExtensions:
                                                        _biodataAllowedExtensions,
                                                  );
                                              final path =
                                                  picked?.files.single.path;
                                              if (path == null) return;
                                              setModalState(() {
                                                biodataFile = File(path);
                                              });
                                            }
                                          },
                                    icon: const Icon(Icons.description_rounded),
                                    label: const Text('Update Biodata'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (statusMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          statusMessage!,
                          style: GoogleFonts.poppins(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpandedUserDetailRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileAssetPopup({required String title, required String url}) {
    final normalized = url.trim().toLowerCase();
    final isImage =
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.png') ||
        normalized.endsWith('.webp');

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Text('Could not load preview.'),
                    ),
                  )
                else
                  const Text('Preview not available for this file type.'),
                const SizedBox(height: 12),
                SelectableText(url, style: GoogleFonts.poppins(fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesTab(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        _updates.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noPostsYet,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey[500],
                      ),
                    ),
                    Text(
                      l10n.createFirstPost,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _updates.length,
                itemBuilder: (context, index) =>
                    _buildUpdateCard(_updates[index], isDark, primaryColor),
              ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _showCreateUpdateDialog(isDark, primaryColor),
            backgroundColor: primaryColor,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              l10n.newPost,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateCard(
    Map<String, dynamic> update,
    bool isDark,
    Color primaryColor,
  ) {
    final type = update['update_type'] ?? 'update';
    final mediaType = update['media_type'] ?? 'none';
    final createdAt = update['created_at'] != null
        ? DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(DateTime.parse(update['created_at']))
        : '';

    Color typeColor;
    IconData typeIcon;
    switch (type) {
      case 'success_story':
        typeColor = Colors.green;
        typeIcon = Icons.favorite_rounded;
        break;
      case 'announcement':
        typeColor = Colors.orange;
        typeIcon = Icons.campaign_rounded;
        break;
      default:
        typeColor = Colors.blue;
        typeIcon = Icons.update_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: typeColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mediaType != 'none' && update['media_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: mediaType == 'image'
                  ? Image.network(
                      update['media_url'],
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 40),
                      ),
                    )
                  : Container(
                      height: 180,
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outlined,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 14, color: typeColor),
                          const SizedBox(width: 4),
                          Text(
                            type.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _deleteUpdate(update['id']),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  update['title'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (update['content'] != null &&
                    update['content'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    update['content'],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  createdAt,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedTab(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        _blockedUsers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noBlockedUsers,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _blockedUsers.length,
                itemBuilder: (context, index) {
                  final blocked = _blockedUsers[index];
                  final createdAt = blocked['created_at'] != null
                      ? DateFormat(
                          'dd MMM yyyy',
                        ).format(DateTime.parse(blocked['created_at']))
                      : '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.block_rounded,
                          color: Colors.red,
                        ),
                      ),
                      title: Text(
                        blocked['email'] ?? '',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (blocked['reason'] != null)
                            Text(
                              blocked['reason'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          Text(
                            'Blocked: $createdAt',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      trailing: TextButton(
                        onPressed: () =>
                            _unblockUser(blocked['id'], blocked['email']),
                        child: Text(
                          'Unblock',
                          style: GoogleFonts.poppins(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _showBlockUserDialog(isDark, primaryColor),
            backgroundColor: Colors.red,
            icon: const Icon(Icons.block, color: Colors.white),
            label: Text(
              l10n.blockUser,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
