import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> otherUser;
  
  const ChatScreen({super.key, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _messagesChannel;
  bool _isBlockedByMe = false;
  bool _isBlockedByOther = false;

  String get _currentUserId => _supabase.auth.currentUser!.id;
  String get _otherUserId => widget.otherUser['id'] as String;

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
    _loadMessages();
    _setupRealtimeSubscription();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _messagesChannel = _supabase
        .channel('chat_${_currentUserId}_${_otherUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMessage = payload.newRecord;
            // Only add if it's part of this conversation
            if ((newMessage['sender_id'] == _currentUserId && newMessage['receiver_id'] == _otherUserId) ||
                (newMessage['sender_id'] == _otherUserId && newMessage['receiver_id'] == _currentUserId)) {
              if (mounted) {
                setState(() {
                  // Check if message already exists to avoid duplicates
                  if (!_messages.any((m) => m['id'] == newMessage['id'])) {
                    _messages.add(newMessage);
                  }
                });
                _scrollToBottom();
                // Mark as read if received
                if (newMessage['sender_id'] == _otherUserId) {
                  _markMessagesAsRead();
                }
              }
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$_currentUserId,receiver_id.eq.$_otherUserId),and(sender_id.eq.$_otherUserId,receiver_id.eq.$_currentUserId)')
          .order('created_at', ascending: true);
      
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.errorLoadingMessages}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', _otherUserId)
          .eq('receiver_id', _currentUserId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _checkBlockStatus() async {
    try {
      final blocks = await _supabase
          .from('user_blocks')
          .select()
          .or('and(blocker_id.eq.$_currentUserId,blocked_id.eq.$_otherUserId),and(blocker_id.eq.$_otherUserId,blocked_id.eq.$_currentUserId)');
      
      if (mounted) {
        setState(() {
          _isBlockedByMe = blocks.any((b) => b['blocker_id'] == _currentUserId);
          _isBlockedByOther = blocks.any((b) => b['blocker_id'] == _otherUserId);
        });
      }
    } catch (e) {
      debugPrint('Error checking block status: $e');
    }
  }

  Future<void> _toggleBlock() async {
    try {
      if (_isBlockedByMe) {
        // Unblock
        await _supabase
            .from('user_blocks')
            .delete()
            .eq('blocker_id', _currentUserId)
            .eq('blocked_id', _otherUserId);
            
        if (mounted) {
          setState(() {
            _isBlockedByMe = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.userUnblocked), backgroundColor: Colors.green),
          );
        }
      } else {
        // Block
        await _supabase.from('user_blocks').insert({
          'blocker_id': _currentUserId,
          'blocked_id': _otherUserId,
        });

        if (mounted) {
          setState(() {
            _isBlockedByMe = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.userBlocked), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorMsg(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _supabase.from('messages').insert({
        'sender_id': _currentUserId,
        'receiver_id': _otherUserId,
        'content': content,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.failedToSendMessage}: $e'), backgroundColor: Colors.red),
      );
      // Restore the message if failed
      _messageController.text = content;
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 0) {
        return '${date.day}/${date.month}';
      }
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final otherUserName = widget.otherUser['full_name'] ?? 'User';
    final otherUserPhoto = widget.otherUser['profile_photo_url'];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFF8F7FC),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: primaryColor.withOpacity(0.1),
                backgroundImage: otherUserPhoto != null ? NetworkImage(otherUserPhoto) : null,
                child: otherUserPhoto == null
                    ? Icon(Icons.person, color: primaryColor, size: 22)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherUserName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Matched',
                        style: GoogleFonts.poppins(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.more_vert_rounded, color: primaryColor, size: 20),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'block') {
                _toggleBlock();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      _isBlockedByMe ? Icons.check_circle_outline : Icons.block_rounded,
                      color: _isBlockedByMe ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isBlockedByMe ? 'Unblock User' : 'Block User',
                        style: GoogleFonts.poppins(
                          color: _isBlockedByMe ? Colors.black87 : Colors.red,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _messages.isEmpty
                    ? _buildEmptyState(isDark, primaryColor)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['sender_id'] == _currentUserId;
                          final showDate = index == 0 ||
                              _shouldShowDate(_messages[index - 1]['created_at'], message['created_at']);
                          
                          return Column(
                            children: [
                              if (showDate) _buildDateSeparator(message['created_at'], isDark),
                              _buildMessageBubble(message, isMe, isDark, primaryColor),
                            ],
                          );
                        },
                      ),
          ),
          
          // Message Input or Blocked State
          if (_isBlockedByMe || _isBlockedByOther)
            _buildBlockedState(isDark)
          else
            _buildMessageInput(isDark, primaryColor),
        ],
      ),
    );
  }

  Widget _buildBlockedState(bool isDark) {
    return Container(
      padding: EdgeInsets.all(24),
      width: double.infinity,
      color: isDark ? Colors.grey[900] : Colors.grey[100],
      child: Column(
        children: [
          Text(
            _isBlockedByMe 
                ? 'You have blocked this user.' 
                : 'You cannot reply to this conversation.',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          if (_isBlockedByMe)
            TextButton(
              onPressed: _toggleBlock,
              child: Text(AppLocalizations.of(context)!.unblock, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.15), primaryColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 56, color: primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Start the conversation!',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Say hello and get to know each other',
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDate(String? prevDate, String? currentDate) {
    if (prevDate == null || currentDate == null) return true;
    try {
      final prev = DateTime.parse(prevDate).toLocal();
      final current = DateTime.parse(currentDate).toLocal();
      return prev.day != current.day || prev.month != current.month || prev.year != current.year;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDateSeparator(String? dateString, bool isDark) {
    if (dateString == null) return const SizedBox.shrink();
    
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      String label;
      
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        label = 'Today';
      } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
        label = 'Yesterday';
      } else {
        label = '${date.day}/${date.month}/${date.year}';
      }
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe, bool isDark, Color primaryColor) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : (isDark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: isMe 
                  ? primaryColor.withOpacity(0.3) 
                  : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['content'] ?? '',
              style: GoogleFonts.poppins(
                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message['created_at']),
                  style: GoogleFonts.poppins(
                    color: isMe ? Colors.white70 : Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message['is_read'] == true ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: message['is_read'] == true ? Colors.white : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isDark, Color primaryColor) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(fontSize: 15),
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.typeMessage,
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
