import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _matches = [];
  Map<String, Map<String, dynamic>> _lastMessages = {};
  Map<String, int> _unreadCounts = {};
  bool _isLoading = true;
  RealtimeChannel? _messagesChannel;

  String get _currentUserId => _supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadMatches();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _messagesChannel = _supabase
        .channel('conversations_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Refresh when new messages arrive
            _loadLastMessages();
          },
        )
        .subscribe();
  }

  Future<void> _loadMatches() async {
    try {
      // Get matches: anyone who sent me interest that I accepted OR anyone I sent interest to who accepted
      
      // Get interests I sent that were accepted
      final sentAccepted = await _supabase
          .from('interests')
          .select('receiver_id, receiver:receiver_id(*)')
          .eq('sender_id', _currentUserId)
          .eq('status', 'accepted');
      
      // Get interests I received and accepted
      final receivedAccepted = await _supabase
          .from('interests')
          .select('sender_id, sender:sender_id(*)')
          .eq('receiver_id', _currentUserId)
          .eq('status', 'accepted');
      
      // Combine both lists - anyone I can chat with
      final List<Map<String, dynamic>> matches = [];
      final Set<String> addedIds = {};
      
      // Add people I sent interest to who accepted
      for (final interest in sentAccepted) {
        final receiverId = interest['receiver_id'] as String;
        if (!addedIds.contains(receiverId) && interest['receiver'] != null) {
          matches.add(interest['receiver'] as Map<String, dynamic>);
          addedIds.add(receiverId);
        }
      }
      
      // Add people who sent me interest that I accepted
      for (final interest in receivedAccepted) {
        final senderId = interest['sender_id'] as String;
        if (!addedIds.contains(senderId) && interest['sender'] != null) {
          matches.add(interest['sender'] as Map<String, dynamic>);
          addedIds.add(senderId);
        }
      }
      
      if (mounted) {
        setState(() {
          _matches = matches;
        });
        await _loadLastMessages();
      }
    } catch (e) {
      debugPrint('Error loading matches: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadLastMessages() async {
    try {
      for (final match in _matches) {
        final matchId = match['id'] as String;
        
        // Get last message
        final messages = await _supabase
            .from('messages')
            .select()
            .or('and(sender_id.eq.$_currentUserId,receiver_id.eq.$matchId),and(sender_id.eq.$matchId,receiver_id.eq.$_currentUserId)')
            .order('created_at', ascending: false)
            .limit(1);
        
        if (messages.isNotEmpty) {
          _lastMessages[matchId] = messages[0];
        }
        
        // Get unread count
        final unreadResult = await _supabase
            .from('messages')
            .select()
            .eq('sender_id', matchId)
            .eq('receiver_id', _currentUserId)
            .eq('is_read', false);
        
        _unreadCounts[matchId] = unreadResult.length;
      }
      
      // Sort matches by last message time
      _matches.sort((a, b) {
        final aLastMsg = _lastMessages[a['id']];
        final bLastMsg = _lastMessages[b['id']];
        if (aLastMsg == null && bLastMsg == null) return 0;
        if (aLastMsg == null) return 1;
        if (bLastMsg == null) return -1;
        return DateTime.parse(bLastMsg['created_at'])
            .compareTo(DateTime.parse(aLastMsg['created_at']));
      });
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading last messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTimeAgo(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 7) {
        return '${date.day}/${date.month}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m';
      } else {
        return 'Now';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _matches.isEmpty
              ? _buildEmptyState(isDark, primaryColor)
              : RefreshIndicator(
                  onRefresh: _loadMatches,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _matches.length,
                    itemBuilder: (context, index) {
                      final match = _matches[index];
                      return _buildConversationTile(match, isDark, primaryColor);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor.withOpacity(0.15), primaryColor.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 72, color: primaryColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 32),
            Text(
              'No Matches Yet',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When you or another person accepts\nan interest, you can start chatting!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.explore_rounded),
              label: Text('Explore Profiles', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> match, bool isDark, Color primaryColor) {
    final matchId = match['id'] as String;
    final lastMessage = _lastMessages[matchId];
    final unreadCount = _unreadCounts[matchId] ?? 0;
    final hasUnread = unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: hasUnread ? Border.all(color: primaryColor.withOpacity(0.3), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: hasUnread ? primaryColor.withOpacity(0.1) : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(otherUser: match),
              ),
            );
            // Refresh after returning from chat
            _loadLastMessages();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Photo
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [primaryColor.withOpacity(0.2), primaryColor.withOpacity(0.1)],
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
                        radius: 30,
                        backgroundColor: Colors.transparent,
                        backgroundImage: match['profile_photo_url'] != null
                            ? NetworkImage(match['profile_photo_url'])
                            : null,
                        child: match['profile_photo_url'] == null
                            ? Icon(Icons.person, color: primaryColor, size: 28)
                            : null,
                      ),
                    ),
                    // Online indicator
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.grey[900]! : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Name and Last Message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            match['full_name'] ?? 'User',
                            style: GoogleFonts.poppins(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (lastMessage != null)
                            Text(
                              _getTimeAgo(lastMessage['created_at']),
                              style: GoogleFonts.poppins(
                                color: hasUnread ? primaryColor : Colors.grey[500],
                                fontSize: 12,
                                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage != null
                                  ? (lastMessage['sender_id'] == _currentUserId ? 'You: ' : '') +
                                    (lastMessage['content'] ?? '')
                                  : 'Say hello! 👋',
                              style: GoogleFonts.poppins(
                                color: hasUnread 
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey[600],
                                fontSize: 14,
                                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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
