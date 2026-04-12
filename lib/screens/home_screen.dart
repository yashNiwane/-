import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hitwardhini/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _myProfile;
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _savedProfiles = [];
  List<Map<String, dynamic>> _sentInterests = [];
  List<Map<String, dynamic>> _receivedInterests = [];
  Set<String> _savedProfileIds = {};
  Set<String> _sentInterestIds = {};
  bool _isLoading = true;
  String _searchQuery = '';
  RangeValues _ageRange = const RangeValues(18, 60);
  int _currentIndex = 0;
  late TabController _tabController;
  
  // Realtime subscriptions
  RealtimeChannel? _profilesChannel;
  RealtimeChannel? _savedChannel;
  RealtimeChannel? _interestsChannel;
  RealtimeChannel? _messagesChannel;
  int _unreadMessagesCount = 0;
  List<Map<String, dynamic>> _updates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentIndex = _tabController.index);
    });
    _initializeData();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _profilesChannel?.unsubscribe();
    _savedChannel?.unsubscribe();
    _interestsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    final userId = _supabase.auth.currentUser?.id;
    
    // Listen for current user's profile changes (subscription status)
    _profilesChannel = _supabase
        .channel('my_profile_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: userId != null ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ) : null,
          callback: (payload) {
            debugPrint('My profile changed: ${payload.eventType}');
            _checkSubscriptionStatus();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            debugPrint('Profiles changed: ${payload.eventType}');
            _fetchProfiles();
          },
        )
        .subscribe();

    // Listen for saved profiles changes
    _savedChannel = _supabase
        .channel('public:saved_profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'saved_profiles',
          callback: (payload) {
            debugPrint('Saved profiles changed: ${payload.eventType}');
            _fetchSavedProfiles();
          },
        )
        .subscribe();

    // Listen for interests changes
    _interestsChannel = _supabase
        .channel('public:interests')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'interests',
          callback: (payload) {
            debugPrint('Interests changed: ${payload.eventType}');
            _fetchInterests();
          },
        )
        .subscribe();

    // Listen for new messages for chat alerts
    _messagesChannel = _supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMessage = payload.newRecord;
            if (newMessage['receiver_id'] == userId) {
              _loadUnreadMessagesCount();
              _showNewMessageAlert(newMessage);
            }
          },
        )
        .subscribe();
  }

  Future<void> _initializeData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    final myProfileData = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    
    if (mounted) {
      if (myProfileData == null) {
        Navigator.of(context).pushReplacementNamed('/profile-creation');
        return;
      }

      bool isPaid = myProfileData['is_paid'] ?? false;
      if (isPaid && myProfileData['subscription_expiry'] != null) {
        final expiry = DateTime.parse(myProfileData['subscription_expiry']);
        if (expiry.isBefore(DateTime.now())) isPaid = false;
      }

      if (!isPaid) {
        Navigator.of(context).pushReplacementNamed('/subscription');
        return;
      }

      _myProfile = myProfileData;
      await _fetchAllData();
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final data = await _supabase.from('profiles').select('is_paid, subscription_expiry').eq('id', user.id).maybeSingle();
    
    if (data != null && mounted) {
      bool isPaid = data['is_paid'] ?? false;
      
      if (isPaid && data['subscription_expiry'] != null) {
        final expiry = DateTime.parse(data['subscription_expiry']);
        if (expiry.isBefore(DateTime.now())) isPaid = false;
      }

      if (!isPaid) {
        // Subscription expired - redirect to payment page
        Navigator.of(context).pushReplacementNamed('/subscription');
      }
    }
  }

  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchProfiles(),
      _fetchSavedProfiles(),
      _fetchInterests(),
      _loadUnreadMessagesCount(),
      _fetchUpdates(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUpdates() async {
    try {
      final data = await _supabase
          .from('updates')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) setState(() => _updates = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error fetching updates: $e');
    }
  }

  Future<void> _fetchProfiles() async {
    final userId = _supabase.auth.currentUser!.id;
    
    // Determine opposite gender for matching
    final myGender = _myProfile?['gender'];
    String? targetGender;
    if (myGender == 'Male') {
      targetGender = 'Female';
    } else if (myGender == 'Female') {
      targetGender = 'Male';
    }
    
    var query = _supabase
        .from('profiles')
        .select()
        .neq('id', userId)
        .eq('is_paid', true);
    
    // Only filter by gender if user has set their gender
    if (targetGender != null) {
      query = query.eq('gender', targetGender);
    }
    
    final data = await query.order('created_at', ascending: false);
    
    if (mounted) {
      setState(() => _profiles = List<Map<String, dynamic>>.from(data));
    }
  }

  Future<void> _fetchSavedProfiles() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('saved_profiles')
        .select('*, saved_profile:saved_profile_id(*)')
        .eq('user_id', userId);
    
    if (mounted) {
      setState(() {
        _savedProfiles = List<Map<String, dynamic>>.from(data);
        _savedProfileIds = _savedProfiles.map((e) => e['saved_profile_id'] as String).toSet();
      });
    }
  }

  Future<void> _fetchInterests() async {
    final userId = _supabase.auth.currentUser!.id;
    
    final sent = await _supabase
        .from('interests')
        .select('*, receiver:receiver_id(*)')
        .eq('sender_id', userId);
    
    final received = await _supabase
        .from('interests')
        .select('*, sender:sender_id(*)')
        .eq('receiver_id', userId);
    
    if (mounted) {
      setState(() {
        _sentInterests = List<Map<String, dynamic>>.from(sent);
        _receivedInterests = List<Map<String, dynamic>>.from(received);
        _sentInterestIds = _sentInterests.map((e) => e['receiver_id'] as String).toSet();
      });
    }
  }

  Future<void> _toggleSaveProfile(String profileId) async {
    final userId = _supabase.auth.currentUser!.id;
    
    try {
      if (_savedProfileIds.contains(profileId)) {
        await _supabase.from('saved_profiles')
            .delete()
            .eq('user_id', userId)
            .eq('saved_profile_id', profileId);
        if (mounted) {
          setState(() {
            _savedProfileIds.remove(profileId);
          });
        }
        _showSnackBar('Removed from saved', Colors.grey);
      } else {
        await _supabase.from('saved_profiles').insert({
          'user_id': userId,
          'saved_profile_id': profileId,
        });
        if (mounted) {
          setState(() {
            _savedProfileIds.add(profileId);
          });
        }
        _showSnackBar('Profile saved!', Colors.green);
      }
      await _fetchSavedProfiles();
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _sendInterest(String receiverId) async {
    final userId = _supabase.auth.currentUser!.id;
    
    try {
      await _supabase.from('interests').insert({
        'sender_id': userId,
        'receiver_id': receiverId,
      });
      if (mounted) {
        setState(() {
          _sentInterestIds.add(receiverId);
        });
      }
      _showSnackBar('Interest sent!', Colors.green);
      await _fetchInterests();
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _updateInterestStatus(String interestId, String status) async {
    try {
      await _supabase.from('interests').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', interestId);
      
      _showSnackBar(status == 'accepted' ? 'Interest accepted!' : 'Interest declined', 
          status == 'accepted' ? Colors.green : Colors.grey);
      await _fetchInterests();
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _loadUnreadMessagesCount() async {
    final userId = _supabase.auth.currentUser!.id;
    try {
      final result = await _supabase
          .from('messages')
          .select()
          .eq('receiver_id', userId)
          .eq('is_read', false);
      
      if (mounted) {
        setState(() {
          _unreadMessagesCount = result.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread messages count: $e');
    }
  }

  void _showNewMessageAlert(Map<String, dynamic> message) async {
    // Get sender profile for the alert
    try {
      final senderProfile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', message['sender_id'])
          .single();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'New message from ${senderProfile['full_name']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        message['content'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ConversationsScreen()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error showing message alert: $e');
    }
  }

  Future<void> _updateProfilePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final file = File(image.path);
      final userId = _supabase.auth.currentUser!.id;
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}_profile_$userId.$fileExt';
      
      try {
        await _supabase.storage.from('avatars').upload(fileName, file);
        final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
        
        await _supabase.from('profiles').update({
          'profile_photo_url': imageUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        
        await _initializeData();
        _showSnackBar('Profile photo updated!', Colors.green);
      } catch (e) {
        _showSnackBar('Error: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  int _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null) return 0;
    final dob = DateTime.parse(dateOfBirth);
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  List<Map<String, dynamic>> get _filteredProfiles {
    return _profiles.where((profile) {
      final name = (profile['full_name'] ?? '').toLowerCase();
      final city = (profile['city'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      final age = _calculateAge(profile['date_of_birth']);
      
      final matchesSearch = name.contains(query) || city.contains(query);
      final matchesAge = age >= _ageRange.start && age <= _ageRange.end;
      
      return matchesSearch && matchesAge;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFFDFCFB),
      appBar: _buildAppBar(isDark, primaryColor),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHomeTab(isDark, primaryColor),
          _buildExploreTab(isDark, primaryColor),
          _buildSavedTab(isDark, primaryColor),
          _buildInterestsTab(isDark, primaryColor),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark, primaryColor),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        [l10n.home, l10n.explore, l10n.saved, l10n.interests][_currentIndex],
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      actions: [
        // Enhanced Chat Button with premium design
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ConversationsScreen()),
                    );
                    _loadUnreadMessagesCount();
                  },
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
              ),
              if (_unreadMessagesCount > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4757), Color(0xFFFF3742)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4757).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _unreadMessagesCount > 99 ? '99+' : '$_unreadMessagesCount',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_currentIndex == 1)
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: isDark ? Colors.white70 : Colors.black54),
            onPressed: () => _showFilterSheet(isDark, primaryColor),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.1),
            onSelected: (value) async {
              if (value == 'view_profile') {
                _showProfileBottomSheet(isDark, primaryColor);
              } else if (value == 'update_photo') {
                await _updateProfilePhoto();
              } else if (value == 'admin_panel') {
                Navigator.of(context).pushNamed('/admin');
              } else if (value == 'logout') {
                await _supabase.auth.signOut();
                if (mounted) Navigator.of(context).pushReplacementNamed('/');
              }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: primaryColor.withOpacity(0.1),
              backgroundImage: _myProfile?['profile_photo_url'] != null
                  ? NetworkImage(_myProfile!['profile_photo_url'])
                  : null,
              child: _myProfile?['profile_photo_url'] == null
                  ? Icon(Icons.person, size: 20, color: primaryColor)
                  : null,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view_profile',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.person_outline_rounded, color: primaryColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.viewProfile,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'update_photo',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.camera_alt_outlined, color: Colors.blue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.updatePhoto,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Admin Panel option - only visible for admins
              if (_myProfile?['is_admin'] == true)
                PopupMenuItem(
                  value: 'admin_panel',
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.withOpacity(0.2), Colors.blue.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.purple, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.adminPanel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'logout',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.signOut,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: primaryColor,
        indicatorWeight: 3,
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey,
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(icon: const Icon(Icons.home_rounded), text: l10n.home),
          Tab(icon: const Icon(Icons.explore_rounded), text: l10n.explore),
          Tab(icon: const Icon(Icons.favorite_rounded), text: l10n.saved),
          Tab(icon: const Icon(Icons.mail_rounded), text: l10n.interests),
        ],
      ),
    );
  }

  void _showFilterSheet(bool isDark, Color primaryColor) {
    RangeValues tempAgeRange = _ageRange;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor.withOpacity(0.15), primaryColor.withOpacity(0.08)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tune_rounded, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.filterProfiles,
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          AppLocalizations.of(context)!.refineByAge,
                          style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              
              // Age Range Filter Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (isDark ? Colors.grey[800] : Colors.grey[200])!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cake_rounded, size: 18, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.ageRange,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                          ],
                        ),
                        Text(
                          '${tempAgeRange.start.round()} - ${tempAgeRange.end.round()} ${AppLocalizations.of(context)!.years}',
                          style: GoogleFonts.poppins(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    RangeSlider(
                      values: tempAgeRange,
                      min: 18,
                      max: 60,
                      divisions: 42,
                      activeColor: primaryColor,
                      inactiveColor: primaryColor.withOpacity(0.2),
                      labels: RangeLabels(
                        '${tempAgeRange.start.round()}', 
                        '${tempAgeRange.end.round()}',
                      ),
                      onChanged: (RangeValues values) {
                        setModalState(() {
                          tempAgeRange = values;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  // Reset Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _ageRange = const RangeValues(18, 60));
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(AppLocalizations.of(context)!.reset, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Apply Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _ageRange = tempAgeRange);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(AppLocalizations.of(context)!.applyFilter, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption({
    required bool isDark,
    required Color primaryColor,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? primaryColor;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? effectiveColor.withOpacity(0.15)
              : isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? effectiveColor : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: effectiveColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? effectiveColor : Colors.grey[500],
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? effectiveColor : (isDark ? Colors.grey[400] : Colors.grey[700]),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: effectiveColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  void _showProfileBottomSheet(bool isDark, Color primaryColor) {
    final age = _calculateAge(_myProfile?['date_of_birth']);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Profile Photo
            CircleAvatar(
              radius: 50,
              backgroundColor: primaryColor.withOpacity(0.1),
              backgroundImage: _myProfile?['profile_photo_url'] != null
                  ? NetworkImage(_myProfile!['profile_photo_url'])
                  : null,
              child: _myProfile?['profile_photo_url'] == null
                  ? Icon(Icons.person, size: 50, color: primaryColor)
                  : null,
            ),
            const SizedBox(height: 12),
            // Name and Age
            Text(
              _myProfile?['full_name'] ?? AppLocalizations.of(context)!.user,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (age > 0)
              Text(
                AppLocalizations.of(context)!.yearsOld(age),
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            const SizedBox(height: 20),
            // Profile Details - Scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info Section
                    _buildSectionHeader(isDark, AppLocalizations.of(context)!.basicInformation),
                    const SizedBox(height: 12),
                    _buildProfileInfoRow(isDark, primaryColor, Icons.person_outline, AppLocalizations.of(context)!.gender, _myProfile?['gender'] ?? AppLocalizations.of(context)!.notSet),
                    _buildProfileInfoRow(isDark, primaryColor, Icons.height_rounded, AppLocalizations.of(context)!.height, _myProfile?['height'] ?? AppLocalizations.of(context)!.notSet),
                    
                    // Location & Career Section
                    _buildSectionHeader(isDark, AppLocalizations.of(context)!.locationCareer),
                    const SizedBox(height: 12),
                    _buildProfileInfoRow(isDark, primaryColor, Icons.location_on_outlined, AppLocalizations.of(context)!.city, _myProfile?['city'] ?? AppLocalizations.of(context)!.notSet),
                    _buildProfileInfoRow(isDark, primaryColor, Icons.work_outline, AppLocalizations.of(context)!.occupation, _myProfile?['occupation'] ?? AppLocalizations.of(context)!.notSet),
                    _buildProfileInfoRow(isDark, primaryColor, Icons.school_outlined, AppLocalizations.of(context)!.education, _myProfile?['education'] ?? AppLocalizations.of(context)!.notSet),
                    
                    // Contact Section
                    _buildSectionHeader(isDark, AppLocalizations.of(context)!.contact),
                    const SizedBox(height: 12),
                    _buildProfileInfoRow(isDark, primaryColor, Icons.phone_outlined, AppLocalizations.of(context)!.phone, _myProfile?['phone_number'] ?? AppLocalizations.of(context)!.notSet),
                    
                    // Edit Button
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final result = await Navigator.of(context).pushNamed('/edit-profile', arguments: _myProfile ?? {});
                          if (result == true) {
                            await _initializeData();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.editProfile,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(bool isDark, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(bool isDark, Color primaryColor, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    final age = _calculateAge(_myProfile?['date_of_birth']);
    final pendingCount = _receivedInterests.where((i) => i['status'] == 'pending').length;
    final firstName = _myProfile?['full_name']?.split(' ').first ?? l10n.user;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Welcome Card with Glassmorphism
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withOpacity(0.85),
                  primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Profile Photo with border
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: _myProfile?['profile_photo_url'] != null
                            ? NetworkImage(_myProfile!['profile_photo_url'])
                            : null,
                        child: _myProfile?['profile_photo_url'] == null
                            ? const Icon(Icons.person, size: 32, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getGreeting(context),
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              Text(_getGreetingEmoji(), style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          Text(
                            firstName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Profile completion indicator
                    GestureDetector(
                      onTap: () => _showProfileBottomSheet(isDark, primaryColor),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Quick info row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildWelcomeInfoItem(Icons.location_on_rounded, _myProfile?['city'] ?? l10n.addCity),
                      Container(width: 1, height: 24, color: Colors.white24),
                      _buildWelcomeInfoItem(Icons.work_rounded, _myProfile?['occupation'] ?? l10n.addJob),
                      Container(width: 1, height: 24, color: Colors.white24),
                      _buildWelcomeInfoItem(Icons.cake_rounded, age > 0 ? l10n.yrs(age) : l10n.addDob),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Pending Interests Alert Banner
          if (pendingCount > 0) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _tabController.animateTo(3),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withOpacity(0.15),
                      Colors.orange.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pendingCount == 1 ? l10n.waitingInterest(pendingCount) : l10n.waitingInterests(pendingCount),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          Text(
                            l10n.tapToViewRespond,
                            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.view,
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Activity Stats Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor.withOpacity(0.15), primaryColor.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.analytics_rounded, color: primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.yourActivity,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          // Stat Cards Row
          Row(
            children: [
              Expanded(child: _buildStatCard(isDark, primaryColor, Icons.favorite_rounded, l10n.saved, _savedProfiles.length.toString(), Colors.pink, () => _tabController.animateTo(2))),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard(isDark, primaryColor, Icons.send_rounded, l10n.sent, _sentInterests.length.toString(), Colors.blue, () => _tabController.animateTo(3))),
              const SizedBox(width: 10),
              Expanded(child: _buildStatCard(isDark, primaryColor, Icons.inbox_rounded, l10n.received, _receivedInterests.length.toString(), Colors.green, () => _tabController.animateTo(3))),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Updates & Success Stories Section
          if (_updates.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.08)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.celebration_rounded, color: Colors.green, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.updatesSuccessStories,
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ..._updates.map((update) => _buildUpdateFeedCard(update, isDark, primaryColor)),
          ],
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context)!;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  Widget _buildWelcomeInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatCard(bool isDark, Color primaryColor, IconData icon, String label, String value, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateFeedCard(Map<String, dynamic> update, bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    final type = update['update_type'] ?? 'update';
    final mediaType = update['media_type'] ?? 'none';
    final createdAt = update['created_at'] != null ? DateTime.parse(update['created_at']) : DateTime.now();
    final timeAgo = _getTimeAgo(createdAt, context);
    
    Color typeColor;
    IconData typeIcon;
    switch (type) {
      case 'success_story': typeColor = Colors.green; typeIcon = Icons.favorite_rounded; break;
      case 'announcement': typeColor = Colors.orange; typeIcon = Icons.campaign_rounded; break;
      default: typeColor = Colors.blue; typeIcon = Icons.update_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: typeColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mediaType != 'none' && update['media_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: mediaType == 'image'
                  ? Image.network(update['media_url'], height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 180, color: Colors.grey[300], child: const Icon(Icons.broken_image, size: 40)))
                  : Container(height: 180, color: Colors.grey[800], child: const Center(child: Icon(Icons.play_circle_outlined, size: 60, color: Colors.white))),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 14, color: typeColor),
                          const SizedBox(width: 4),
                          Text(type == 'success_story' ? l10n.successStory : type == 'announcement' ? l10n.announcement : l10n.update, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: typeColor)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(_getTimeAgo(createdAt, context), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                const SizedBox(height: 12),
                Text(update['title'] ?? '', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                if (update['content'] != null && update['content'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(update['content'], style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime, BuildContext context) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) return '${(difference.inDays / 7).floor()}w ago';
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return AppLocalizations.of(context)!.justNow;
  }

  Widget _buildQuickActionCard(bool isDark, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreTab(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Premium search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.08),
                  primaryColor.withOpacity(0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primaryColor.withOpacity(0.15)),
            ),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: GoogleFonts.poppins(fontSize: 15),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 15),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                  ),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
        ),
        // Header with count
        if (_filteredProfiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor.withOpacity(0.15), primaryColor.withOpacity(0.08)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.people_rounded, color: primaryColor, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.discoverMatches,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    Text(
                      _filteredProfiles.length == 1 ? l10n.profileFound(_filteredProfiles.length) : l10n.profilesFound(_filteredProfiles.length),
                      style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                if (_searchQuery.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt_rounded, size: 14, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          l10n.filtered,
                          style: GoogleFonts.poppins(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _filteredProfiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withOpacity(0.1),
                              primaryColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.search_off_rounded, size: 56, color: primaryColor.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _searchQuery.isNotEmpty ? l10n.noMatchesFound : l10n.noProfilesAvailable,
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty
                            ? l10n.tryAdjustingSearch
                            : l10n.checkBackLater,
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _searchQuery = ''),
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          label: Text(l10n.clearSearch, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAllData,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredProfiles.length,
                    itemBuilder: (context, index) => _buildProfileCard(_filteredProfiles[index], isDark, primaryColor),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile, bool isDark, Color primaryColor) {
    final profileId = profile['id'] as String;
    final isSaved = _savedProfileIds.contains(profileId);
    final hasInterest = _sentInterestIds.contains(profileId);
    final age = _calculateAge(profile['date_of_birth']);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFullProfileSheet(profile, isDark, primaryColor),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image Section
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: profile['profile_photo_url'] != null
                        ? Image.network(
                            profile['profile_photo_url'],
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: double.infinity,
                              height: 220,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor.withOpacity(0.15), primaryColor.withOpacity(0.05)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(Icons.person, size: 70, color: primaryColor.withOpacity(0.4)),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: 220,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor.withOpacity(0.15), primaryColor.withOpacity(0.05)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(Icons.person, size: 70, color: primaryColor.withOpacity(0.4)),
                          ),
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Name and age overlay
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile['full_name'] ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (age > 0)
                          Row(
                            children: [
                              const Icon(Icons.cake_rounded, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                l10n.yearsOld(age),
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Save Button (top right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () async {
                        await _toggleSaveProfile(profileId);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isSaved ? Colors.pink : Colors.grey[600],
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  // Interest status badge
                  if (hasInterest)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              l10n.interestSent,
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              // Details section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Info chips row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (profile['city'] != null)
                          _buildExploreInfoChip(Icons.location_on_rounded, profile['city'], Colors.blue),
                        if (profile['occupation'] != null)
                          _buildExploreInfoChip(Icons.work_rounded, profile['occupation'], Colors.orange),
                        if (profile['education'] != null)
                          _buildExploreInfoChip(Icons.school_rounded, profile['education'], Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showFullProfileSheet(profile, isDark, primaryColor),
                            icon: const Icon(Icons.visibility_rounded, size: 18),
                            label: Text(l10n.viewProfile, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: hasInterest ? null : () async {
                              await _sendInterest(profileId);
                            },
                            icon: Icon(hasInterest ? Icons.check_rounded : Icons.favorite_rounded, size: 18),
                            label: Text(
                              hasInterest ? l10n.sent : l10n.sendInterest,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasInterest ? Colors.grey[300] : primaryColor,
                              foregroundColor: hasInterest ? Colors.grey[600] : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullProfileSheet(Map<String, dynamic> profile, bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    final age = _calculateAge(profile['date_of_birth']);
    final profileId = profile['id'] as String;
    final isSaved = _savedProfileIds.contains(profileId);
    final hasInterest = _sentInterestIds.contains(profileId);
    
    // Check for match (either party accepted the other's interest)
    bool isMatch = false;
    // Check if I sent interest that was accepted OR they sent me interest that I accepted
    final mySentToThem = _sentInterests.where((i) => i['receiver_id'] == profileId).toList();
    final theirSentToMe = _receivedInterests.where((i) => i['sender_id'] == profileId).toList();
    
    final mySentAccepted = mySentToThem.any((i) => i['status'] == 'accepted');
    final theirSentAccepted = theirSentToMe.any((i) => i['status'] == 'accepted');
    isMatch = mySentAccepted || theirSentAccepted;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            final isSaved = _savedProfileIds.contains(profileId);
            final hasInterest = _sentInterestIds.contains(profileId);

            return Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Image Section
                        Stack(
                          children: [
                            Container(
                              height: 500,
                              width: double.infinity,
                              foregroundDecoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.2),
                                    Colors.black.withOpacity(0.8),
                                  ],
                                  stops: const [0.0, 0.6, 0.8, 1.0],
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                                child: profile['profile_photo_url'] != null
                                    ? Image.network(
                                        profile['profile_photo_url'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                                      )
                                    : Container(color: Colors.grey[300]),
                              ),
                            ),
                            Positioned(
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${profile['full_name'] ?? 'Unknown'}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white30),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.cake, color: Colors.white, size: 14),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$age ${l10n.years}',
                                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (profile['gender'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white30),
                                          ),
                                          child: Text(
                                            profile['gender'], 
                                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Quick Info Chips
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildDetailChip(isDark, Icons.location_on_rounded, profile['city'] ?? 'City', Colors.blue),
                                    const SizedBox(width: 12),
                                    _buildDetailChip(isDark, Icons.work_rounded, profile['occupation'] ?? 'Occupation', Colors.orange),
                                    const SizedBox(width: 12),
                                    _buildDetailChip(isDark, Icons.school_rounded, profile['education'] ?? 'Education', Colors.purple),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              
                              
                              // Personal Details Grid (from DB)
                              Text(l10n.personalDetails, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[850] : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    if (profile['height'] != null && (profile['height'] as String).isNotEmpty)
                                      _buildCompactDetailRow(Icons.height_rounded, l10n.height, profile['height']),
                                    if (profile['height'] != null && (profile['height'] as String).isNotEmpty)
                                      const SizedBox(height: 16),
                                    if (profile['phone_number'] != null) 
                                      _buildCompactDetailRow(Icons.phone_rounded, l10n.phone, profile['phone_number']),
                                  ],
                                ),
                              ),
                              
                              // Biodata Section
                              if (profile['biodata_url'] != null) ...[
                                const SizedBox(height: 30),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: primaryColor.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 10)],
                                        ),
                                        child: Icon(Icons.description_rounded, color: primaryColor),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(l10n.detailedBiodata, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(l10n.viewFullFamilyDetails, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _showBiodataViewer(profile['biodata_url'], profile['full_name'] ?? l10n.unknown, primaryColor);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
                                        ),
                                        child: Text(l10n.view, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 100), // Spacing for fab
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Floating Action Bar
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Row(
                      children: [
                        // Save Button
                        GestureDetector(
                          onTap: () async {
                            await _toggleSaveProfile(profileId);
                            setSheetState(() {}); // Trigger local rebuild of the bottom sheet
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                            ),
                            child: Icon(
                              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isSaved ? Colors.pink : Colors.grey,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Chat Button (for matches) or Send Interest Button
                        Expanded(
                          child: isMatch
                              ? ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(otherUser: profile),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble_rounded, size: 22),
                                  label: Text(
                                    l10n.chatNow,
                                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 8,
                                    shadowColor: Colors.green.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: hasInterest ? null : () async {
                                    await _sendInterest(profileId);
                                    setSheetState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    elevation: 8,
                                    shadowColor: primaryColor.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                  child: Text(
                                    hasInterest ? l10n.interestSent : l10n.sendInterest,
                                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Close Button
                  Positioned(
                    top: 20,
                    right: 20,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                  
                  // Handle (Top Center overlay)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailChip(bool isDark, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
              Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
              Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  void _showBiodataViewer(String biodataUrl, String name, Color primaryColor) {
    // Detect file type from URL
    final lowerUrl = biodataUrl.toLowerCase();
    final isImage = lowerUrl.endsWith('.jpg') || 
                    lowerUrl.endsWith('.jpeg') || 
                    lowerUrl.endsWith('.png') || 
                    lowerUrl.endsWith('.gif') || 
                    lowerUrl.endsWith('.webp');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _BiodataViewerScreen(
          biodataUrl: biodataUrl,
          name: name,
          primaryColor: primaryColor,
          isImage: isImage,
        ),
      ),
    );
  }

  Widget _buildSavedTab(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    if (_savedProfiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.pink.withOpacity(0.1),
                    Colors.pink.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_rounded, size: 56, color: Colors.pink.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noSavedProfiles,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tapHeartToSave,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.explore_rounded, size: 20),
              label: Text(l10n.exploreProfiles, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchSavedProfiles,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.pink.withOpacity(0.15), Colors.pink.withOpacity(0.08)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.pink, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        l10n.yourShortlist,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    Text(
                        _savedProfiles.length == 1 ? l10n.profileSaved(_savedProfiles.length) : l10n.profilesSaved(_savedProfiles.length),
                      style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Profile cards - one per row
          ..._savedProfiles.map((saved) {
            final profile = saved['saved_profile'] as Map<String, dynamic>?;
            if (profile == null) return const SizedBox.shrink();
            return _buildSavedProfileCard(profile, isDark, primaryColor);
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSavedProfileCard(Map<String, dynamic> profile, bool isDark, Color primaryColor) {
    final profileId = profile['id'] as String;
    final isSaved = _savedProfileIds.contains(profileId);
    final hasInterest = _sentInterestIds.contains(profileId);
    final age = _calculateAge(profile['date_of_birth']);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showFullProfileSheet(profile, isDark, primaryColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Image with overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: profile['profile_photo_url'] != null
                        ? Image.network(
                            profile['profile_photo_url'],
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
                                ),
                              ),
                              child: Icon(Icons.person, size: 64, color: primaryColor.withOpacity(0.4)),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
                              ),
                            ),
                            child: Icon(Icons.person, size: 64, color: primaryColor.withOpacity(0.4)),
                          ),
                  ),
                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Name and age overlay
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile['full_name'] ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (age > 0)
                                Text(
                                l10n.yearsOld(age),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Heart button (to unsave)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => _toggleSaveProfile(profileId),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: Colors.pink,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Details section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Info chips row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (profile['city'] != null)
                          _buildInfoChip(Icons.location_on_rounded, profile['city'], Colors.blue),
                        if (profile['occupation'] != null)
                          _buildInfoChip(Icons.work_rounded, profile['occupation'], Colors.orange),
                        if (profile['education'] != null)
                          _buildInfoChip(Icons.school_rounded, profile['education'], Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showFullProfileSheet(profile, isDark, primaryColor),
                            icon: const Icon(Icons.visibility_rounded, size: 18),
                            label: Text(l10n.viewProfile, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: hasInterest ? null : () => _sendInterest(profileId),
                            icon: Icon(hasInterest ? Icons.check_rounded : Icons.favorite_rounded, size: 18),
                            label: Text(
                              hasInterest ? l10n.sent : l10n.interests,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasInterest ? Colors.grey[300] : Colors.pink,
                              foregroundColor: hasInterest ? Colors.grey[600] : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 12, color: color, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsTab(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Premium header with gradient
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.15),
                  primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.received),
                      if (_receivedInterests.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_receivedInterests.length}',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.sent),
                      if (_sentInterests.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_sentInterests.length}',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildReceivedInterestsList(isDark, primaryColor),
                _buildSentInterestsList(isDark, primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildReceivedInterestsList(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    if (_receivedInterests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.1),
                    primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded, size: 56, color: primaryColor.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noInterestsReceived,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.whenSomeoneSends,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Group interests by status
    final pendingInterests = _receivedInterests.where((i) => i['status'] == 'pending').toList();
    final otherInterests = _receivedInterests.where((i) => i['status'] != 'pending').toList();

    return RefreshIndicator(
      onRefresh: _fetchInterests,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Pending interests section (priority)
          if (pendingInterests.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.awaitingResponse,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.newCount(pendingInterests.length),
                      style: GoogleFonts.poppins(color: Colors.amber[700], fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            ...pendingInterests.map((interest) => _buildReceivedInterestCard(interest, isDark, primaryColor, isPending: true)),
          ],
          
          // Other interests section
          if (otherInterests.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.history_rounded, color: Colors.grey[600], size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.previousInterests,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            ...otherInterests.map((interest) => _buildReceivedInterestCard(interest, isDark, primaryColor, isPending: false)),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReceivedInterestCard(Map<String, dynamic> interest, bool isDark, Color primaryColor, {required bool isPending}) {
    final sender = interest['sender'] as Map<String, dynamic>?;
    if (sender == null) return const SizedBox.shrink();
    
    final timeAgo = interest['created_at'] != null 
        ? _getTimeAgo(DateTime.parse(interest['created_at']), context)
        : '';
    final age = _calculateAge(sender['date_of_birth']);
    final status = interest['status'] as String;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isPending 
            ? Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isPending 
                ? Colors.amber.withOpacity(0.08) 
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showFullProfileSheet(sender, isDark, primaryColor),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Profile photo with status indicator
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(0.2),
                                primaryColor.withOpacity(0.1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.transparent,
                            backgroundImage: sender['profile_photo_url'] != null
                                ? NetworkImage(sender['profile_photo_url'])
                                : null,
                            child: sender['profile_photo_url'] == null
                                ? Icon(Icons.person, color: primaryColor, size: 28)
                                : null,
                          ),
                        ),
                        if (isPending)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? Colors.grey[900]! : Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Profile info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sender['full_name'] ?? 'Unknown',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (timeAgo.isNotEmpty)
                                Text(
                                  timeAgo,
                                  style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (age > 0) ...[
                                Icon(Icons.cake_rounded, size: 13, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(l10n.yrs(age), style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                                const SizedBox(width: 12),
                              ],
                              Icon(Icons.location_on_rounded, size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  sender['city'] ?? l10n.unknown,
                                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildStatusChip(status),
                        ],
                      ),
                    ),
                  ],
                ),
                // Action buttons for pending
                if (isPending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _updateInterestStatus(interest['id'], 'declined');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: Text(l10n.decline, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _updateInterestStatus(interest['id'], 'accepted');
                          },
                          icon: const Icon(Icons.favorite_rounded, size: 18),
                          label: Text(l10n.acceptInterest, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildSentInterestsList(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    if (_sentInterests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.1),
                    Colors.blue.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_rounded, size: 56, color: Colors.blue.withOpacity(0.6)),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noInterestsSent,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.sendInterestFromExplore,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.explore_rounded, size: 20),
              label: Text(l10n.exploreProfiles, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    // Group by status
    final pendingInterests = _sentInterests.where((i) => i['status'] == 'pending').toList();
    final acceptedInterests = _sentInterests.where((i) => i['status'] == 'accepted').toList();
    final declinedInterests = _sentInterests.where((i) => i['status'] == 'declined').toList();

    return RefreshIndicator(
      onRefresh: _fetchInterests,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Accepted matches (priority)
          if (acceptedInterests.isNotEmpty) ...[
            _buildInterestSectionHeader(
              icon: Icons.favorite_rounded,
              title: l10n.matched,
              count: acceptedInterests.length,
              color: Colors.green,
            ),
            ...acceptedInterests.map((interest) => _buildSentInterestCard(interest, isDark, primaryColor)),
          ],
          
          // Pending interests
          if (pendingInterests.isNotEmpty) ...[
            _buildInterestSectionHeader(
              icon: Icons.hourglass_top_rounded,
              title: l10n.awaitingResponse,
              count: pendingInterests.length,
              color: Colors.amber,
            ),
            ...pendingInterests.map((interest) => _buildSentInterestCard(interest, isDark, primaryColor)),
          ],
          
          // Declined interests
          if (declinedInterests.isNotEmpty) ...[
            _buildInterestSectionHeader(
              icon: Icons.sentiment_neutral_rounded,
              title: l10n.notMatched,
              count: declinedInterests.length,
              color: Colors.grey,
            ),
            ...declinedInterests.map((interest) => _buildSentInterestCard(interest, isDark, primaryColor)),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInterestSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentInterestCard(Map<String, dynamic> interest, bool isDark, Color primaryColor) {
    final receiver = interest['receiver'] as Map<String, dynamic>?;
    if (receiver == null) return const SizedBox.shrink();
    
    final timeAgo = interest['created_at'] != null 
        ? _getTimeAgo(DateTime.parse(interest['created_at']), context)
        : '';
    final age = _calculateAge(receiver['date_of_birth']);
    final status = interest['status'] as String;
    final isAccepted = status == 'accepted';
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isAccepted 
            ? Border.all(color: Colors.green.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isAccepted 
                ? Colors.green.withOpacity(0.08) 
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showFullProfileSheet(receiver, isDark, primaryColor),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile photo with status indicator
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            (isAccepted ? Colors.green : primaryColor).withOpacity(0.2),
                            (isAccepted ? Colors.green : primaryColor).withOpacity(0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isAccepted ? Colors.green : primaryColor).withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.transparent,
                        backgroundImage: receiver['profile_photo_url'] != null
                            ? NetworkImage(receiver['profile_photo_url'])
                            : null,
                        child: receiver['profile_photo_url'] == null
                            ? Icon(Icons.person, color: primaryColor, size: 28)
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? Colors.grey[900]! : Colors.white, width: 2),
                        ),
                        child: Icon(_getStatusIcon(status), color: Colors.white, size: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // Profile info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              receiver['full_name'] ?? 'Unknown',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeAgo.isNotEmpty)
                            Text(
                              timeAgo,
                              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (age > 0) ...[
                            Icon(Icons.cake_rounded, size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(l10n.yrs(age), style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                            const SizedBox(width: 12),
                          ],
                          Icon(Icons.location_on_rounded, size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              receiver['city'] ?? l10n.unknown,
                              style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(status),
                    ],
                  ),
                ),
                // Arrow indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, color: primaryColor, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.grey;
      default:
        return Colors.amber;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_rounded;
      case 'declined':
        return Icons.close_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String label;
    final l10n = AppLocalizations.of(context)!;
    
    switch (status) {
      case 'accepted':
        color = Colors.green;
        icon = Icons.favorite_rounded;
        label = l10n.matched;
        break;
      case 'declined':
        color = Colors.grey;
        icon = Icons.close_rounded;
        label = l10n.notInterested;
        break;
      default:
        color = Colors.amber;
        icon = Icons.schedule_rounded;
        label = l10n.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(bool isDark, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    final age = _calculateAge(_myProfile?['date_of_birth']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: primaryColor.withOpacity(0.1),
            backgroundImage: _myProfile?['profile_photo_url'] != null
                ? NetworkImage(_myProfile!['profile_photo_url'])
                : null,
            child: _myProfile?['profile_photo_url'] == null
                ? Icon(Icons.person, size: 60, color: primaryColor)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _myProfile?['full_name'] ?? l10n.user,
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          if (age > 0)
            Text(l10n.yearsOld(age), style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          _buildProfileInfoCard(isDark, primaryColor, Icons.location_on_rounded, l10n.city, _myProfile?['city'] ?? l10n.notSet),
          _buildProfileInfoCard(isDark, primaryColor, Icons.work_rounded, l10n.occupation, _myProfile?['occupation'] ?? l10n.notSet),
          _buildProfileInfoCard(isDark, primaryColor, Icons.school_rounded, l10n.education, _myProfile?['education'] ?? l10n.notSet),
          _buildProfileInfoCard(isDark, primaryColor, Icons.person_rounded, l10n.gender, _myProfile?['gender'] ?? l10n.notSet),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.of(context).pushNamed('/edit-profile', arguments: _myProfile ?? {});
                if (result == true) {
                  await _initializeData();
                }
              },
              icon: const Icon(Icons.edit_rounded),
              label: Text(l10n.editProfile, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard(bool isDark, Color primaryColor, IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
              Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

// Biodata Viewer Screen - handles images and documents
class _BiodataViewerScreen extends StatefulWidget {
  final String biodataUrl;
  final String name;
  final Color primaryColor;
  final bool isImage;

  const _BiodataViewerScreen({
    required this.biodataUrl,
    required this.name,
    required this.primaryColor,
    required this.isImage,
  });

  @override
  State<_BiodataViewerScreen> createState() => _BiodataViewerScreenState();
}

class _BiodataViewerScreenState extends State<_BiodataViewerScreen> {
  late WebViewController? _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (!widget.isImage) {
      _initWebView();
    }
  }

  void _initWebView() {
    // Use Google Docs Viewer to display PDFs and documents in-app
    final googleDocsUrl = 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.biodataUrl)}';
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(googleDocsUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isImage ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: widget.isImage ? Colors.black : widget.primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          "${widget.name}'s Biodata",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: widget.isImage ? _buildImageViewer() : _buildDocumentViewer(),
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      panEnabled: true,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          widget.biodataUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                color: widget.primaryColor,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(context),
        ),
      ),
    );
  }

  Widget _buildDocumentViewer() {
    if (_webViewController == null) {
      return _buildErrorWidget(context);
    }
    
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController!),
        if (_isLoading)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: widget.primaryColor),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.loadingDocument,
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.couldNotLoadBiodata,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.unsupportedFormat,
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
