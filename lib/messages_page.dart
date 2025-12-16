import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme_controller.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _supabase = Supabase.instance.client;
  final Map<String, Map<String, dynamic>?> _profileCache = {};
  List<Map<String, dynamic>> conversations = [];
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String userType = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Check if user is professor or student
      final professorCheck = await _supabase
          .from('professors')
          .select('name, subject, classes_taught')
          .eq('id', user.id)
          .maybeSingle();

      if (professorCheck != null) {
        userData = professorCheck;
        userType = 'professor';
        await _loadConversations();
      } else {
        final studentCheck = await _supabase
            .from('students')
            .select('name, class')
            .eq('id', user.id)
            .single();
        userData = studentCheck;
        userType = 'student';
        await _loadConversations();
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _getProfile(String userId) async {
    if (_profileCache.containsKey(userId)) return _profileCache[userId];
    final profile = await _supabase
        .from('user_profiles')
        .select('id, name, email, role, class_or_subject')
        .eq('id', userId)
        .maybeSingle();
    _profileCache[userId] = profile;
    return profile;
  }

  Future<Map<String, dynamic>?> _getLastMessage(String conversationId) async {
    return await _supabase
        .from('messages')
        .select('id, subject, content, created_at, sender_id')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<void> _loadConversations() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final conversationsData = await _supabase
          .from('conversations')
          .select('id, user1_id, user2_id, last_message_at, created_at')
          .or('user1_id.eq.${currentUser.id},user2_id.eq.${currentUser.id}')
          .order('last_message_at', ascending: false);

      final List<Map<String, dynamic>> enriched = [];
      for (final conv in conversationsData) {
        final isMeUser1 = conv['user1_id'] == currentUser.id;
        final otherUserId = isMeUser1 ? conv['user2_id'] : conv['user1_id'];
        final otherProfile = await _getProfile(otherUserId);
        final lastMessage = await _getLastMessage(conv['id']);
        enriched.add({
          ...conv,
          'other_user_id': otherUserId,
          'other_user_name': otherProfile?['name'] ?? 'Unknown',
          'other_user_email': otherProfile?['email'],
          'last_message': lastMessage,
        });
      }

      setState(() {
        conversations = enriched;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _startNewConversation() async {
    if (userType == 'professor') {
      await _showStudentSelection();
    } else {
      await _showUserSelection();
    }
  }

  Future<void> _showStudentSelection() async {
    try {
      final classesTaught = List<String>.from(userData?['classes_taught'] ?? []);
      if (classesTaught.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No classes assigned to your account yet.')),
        );
        return;
      }
      final students = await _supabase
          .from('students')
          .select('id, name, class, email')
          .inFilter('class', classesTaught);

      final selectedStudent = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Student'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return ListTile(
                  title: Text(student['name']),
                  subtitle: Text('${student['class']} - ${student['email']}'),
                  onTap: () => Navigator.of(context).pop(student),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedStudent != null) {
        await _createConversation(selectedStudent['id']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
    }
  }

  Future<void> _showUserSelection() async {
    try {
      // For students, show other students from same class and professors
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;
      
      final students = await _supabase
          .from('students')
          .select('id, name, class, email')
          .eq('class', userData!['class'])
          .neq('id', currentUser.id);

      final professors = await _supabase
          .from('professors')
          .select('id, name, subject, email')
          .contains('classes_taught', [userData!['class']]);

      final allUsers = [...students, ...professors];

      final selectedUser = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select User'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: allUsers.length,
              itemBuilder: (context, index) {
                final user = allUsers[index];
                final isProfessor = user.containsKey('subject');
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isProfessor ? Colors.blue : Colors.green,
                    child: Icon(
                      isProfessor ? Icons.school : Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(user['name']),
                  subtitle: Text(
                    isProfessor 
                        ? '${user['subject']} - ${user['email']}'
                        : '${user['class']} - ${user['email']}'
                  ),
                  onTap: () => Navigator.of(context).pop(user),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedUser != null) {
        await _createConversation(selectedUser['id']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e')),
      );
    }
  }

  Future<void> _createConversation(String otherUserId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;
      
      // Check if conversation already exists
      final existing = await _supabase
          .from('conversations')
          .select()
          .or('and(user1_id.eq.${currentUser.id},user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.${currentUser.id})')
          .maybeSingle();

      final otherProfile = await _getProfile(otherUserId);

      if (existing != null) {
        // Navigate to existing conversation
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: existing['id'],
              otherUserId: otherUserId,
              otherUserName: otherProfile?['name'] ?? 'Chat',
            ),
          ),
        ).then((_) => _loadConversations());
        return;
      }

      // Create new conversation
      final result = await _supabase
          .from('conversations')
          .insert({
            'user1_id': currentUser.id,
            'user2_id': otherUserId,
          })
          .select('id')
          .single();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: result['id'],
            otherUserId: otherUserId,
            otherUserName: otherProfile?['name'] ?? 'New Chat',
          ),
        ),
      ).then((_) => _loadConversations());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating conversation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(userType == 'professor' ? 'Student Messages' : 'Messages'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Toggle theme',
            onPressed: ThemeController.toggle,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.message_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userType == 'professor' 
                            ? 'Start a conversation with your students'
                            : 'Start a conversation with classmates or professors',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final titleName = (conversation['other_user_name'] ?? 'Unknown') as String;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          titleName.isNotEmpty
                              ? titleName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(titleName),
                      subtitle: Text(
                        conversation['last_message']?['content'] ?? 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: conversation['last_message'] != null
                          ? Text(
                              _formatTime(conversation['last_message']['created_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              conversationId: conversation['id'],
                              otherUserId: conversation['other_user_id'],
                              otherUserName: conversation['other_user_name'] ?? 'Unknown',
                            ),
                          ),
                        ).then((_) => _loadConversations());
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewConversation,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final messagesData = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', widget.conversationId)
          .order('created_at', ascending: true);

      setState(() {
        messages = messagesData;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading messages: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => isSending = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      await _supabase.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.otherUserId,
        'conversation_id': widget.conversationId,
        'subject': 'Message',
        'content': _messageController.text.trim(),
        'message_type': 'chat',
      });

      // Update conversation last_message_at
      await _supabase
          .from('conversations')
          .update({'last_message_at': DateTime.now().toIso8601String()})
          .eq('id', widget.conversationId);

      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Start the conversation!'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message['sender_id'] == user!.id;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.deepPurple : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                                ),
                                child: Text(
                                  message['content'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isSending ? null : _sendMessage,
                  icon: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
