import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/chat_model.dart';
import '../../config/theme.dart';
import '../../config/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String? roomId;
  final String? otherUserName;
  final String? donationId; 
  final bool isMessagingAllowed;
  
  const ChatScreen({
    Key? key, 
    this.roomId, 
    this.otherUserName, 
    this.donationId,
    this.isMessagingAllowed = true
  }) : super(key: key);
  
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;
  String? currentRoomId;
  bool isTyping = false;
  String? typingUser;
  Timer? _typingTimer;
  bool isDeliveryAssigned = false;
  bool isVolunteerAssigned = false;
  String assignmentStatus = 'none'; 
  StreamSubscription? _chatAvailabilitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeliveryAssignment();
      _loadMessages();
      _setupTextFieldListener();
      _listenForChatAvailability();
    });
  }

  Future<void> _checkDeliveryAssignment() async {
    if (widget.donationId == null) return;
    
    try {
      final token = await AuthService.getValidToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/donations/${widget.donationId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final donation = data['donation'];
        
        setState(() {
          assignmentStatus = donation['assignmentType'] ?? 'none';
          isDeliveryAssigned = assignmentStatus == 'delivery' && donation['assignedTo'] != null;
          isVolunteerAssigned = assignmentStatus == 'volunteer' && donation['assignedTo'] != null;
        });

        // Show availability prompt if no one is assigned yet
        if (assignmentStatus == 'none' || donation['assignedTo'] == null) {
          await _sendAvailabilityPrompt();
        }
        // Send acceptance confirmation if someone just got assigned
        else if ((isDeliveryAssigned || isVolunteerAssigned) && messages.isEmpty) {
          await _sendAcceptanceConfirmation();
        }
      }
    } catch (e) {
      print('❌ Error checking delivery assignment: $e');
    }
  }

  Future<void> _sendAvailabilityPrompt() async {
    if (currentRoomId == null) return;
    
    String promptMessage = 'Looking for volunteers and delivery partners for this donation. Chat will be enabled once someone accepts the assignment.';

    try {
      await ChatService.sendTextMessage(
        roomId: currentRoomId!,
        message: promptMessage,
      );
    } catch (e) {
      print('❌ Error sending availability prompt: $e');
    }
  }

  Future<void> _sendAcceptanceConfirmation() async {
    if (currentRoomId == null) return;
    
    String promptMessage = '';
    if (isDeliveryAssigned) {
      promptMessage = '🚚 A delivery person has accepted your donation! You can now coordinate pickup details through this chat.';
    } else if (isVolunteerAssigned) {
      promptMessage = '🤝 A volunteer has accepted your donation! You can now coordinate pickup and delivery details through this chat.';
    }

    if (promptMessage.isNotEmpty) {
      try {
        await ChatService.sendTextMessage(
          roomId: currentRoomId!,
          message: promptMessage,
        );
      } catch (e) {
        print('❌ Error sending acceptance confirmation: $e');
      }
    }
  }

  void _initializeSocket() async {
    // Socket.IO initialization removed - only used for identity verification notifications
    // Chat functionality will work without real-time Socket.IO
  }

  void _setupTextFieldListener() {
    _controller.addListener(() {
      if (currentRoomId != null) {
        final text = _controller.text.trim();
        if (text.isNotEmpty) {
          ChatService.sendTypingIndicator(currentRoomId!, true);
        } else {
          ChatService.sendTypingIndicator(currentRoomId!, false);
        }
      }
    });
  }

  void _listenForChatAvailability() {
    _chatAvailabilitySubscription = NotificationService.chatAvailabilityStream.listen((data) {
      if (data['donationId'] == widget.donationId) {
        setState(() {
          assignmentStatus = data['assignmentType'] ?? 'none';
          isDeliveryAssigned = assignmentStatus == 'delivery';
          isVolunteerAssigned = assignmentStatus == 'volunteer';
        });
        
        // Refresh assignment status and send confirmation message
        _checkDeliveryAssignment();
        
        print('✅ Chat enabled for donation ${widget.donationId} - ${data['assignmentType']} assigned');
      }
    });
  }

  Future<void> _loadMessages() async {
    if (widget.roomId == null) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      currentRoomId = widget.roomId;
      ChatService.joinRoom(widget.roomId!);
      
      final loadedMessages = await ChatService.getRoomMessages(widget.roomId!);
      setState(() {
        messages = loadedMessages;
        isLoading = false;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('❌ Error loading messages: $e');
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load messages: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || currentRoomId == null) return;

    // Check if messaging is allowed
    if (!_isMessagingAllowed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Messaging is only available when a delivery person or volunteer is assigned to this donation.'),
          backgroundColor: AppTheme.warningColor,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    _controller.clear();
    
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final sentMessage = ChatMessage(
      id: tempId,
      roomId: currentRoomId!,
      senderId: ChatService.getCurrentUserId(),
      senderName: AuthService.getCurrentUser()?.name ?? 'You',
      message: text,
      timestamp: DateTime.now(),
      receiverId: null,
    );

    setState(() {
      messages.add(sentMessage);
      _scrollToBottom();
    });

    try {
      await ChatService.sendTextMessage(
        roomId: currentRoomId!,
        message: text,
      );
      
      setState(() {
        messages.removeWhere((m) => m.id == tempId);
      });
      
    } catch (e) {
      print('❌ Error sending message: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMessagingAllowed() {
    return widget.isMessagingAllowed && (isDeliveryAssigned || isVolunteerAssigned || assignmentStatus == 'self');
  }

  Widget _buildAssignmentStatusBanner() {
    if (assignmentStatus == 'none') {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Messaging will be available once a delivery person or volunteer is assigned to this donation.',
                style: TextStyle(
                  color: AppTheme.warningColor,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (isDeliveryAssigned) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.delivery_dining, color: AppTheme.successColor, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delivery person assigned. You can now coordinate pickup details.',
                style: TextStyle(
                  color: AppTheme.successColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (isVolunteerAssigned) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.volunteer_activism, color: AppTheme.primaryColor, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Volunteer assigned. You can now coordinate pickup and delivery.',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _chatAvailabilitySubscription?.cancel();
    if (currentRoomId != null) {
      ChatService.leaveRoom(currentRoomId!);
    }
    ChatService.stopListeningForMessages();
    ChatService.stopListeningForTyping();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildModernAppBar(),
      body: Column(
        children: [
          _buildAssignmentStatusBanner(),
          Expanded(
            child: _buildChatBody(),
          ),
          _ModernMessageInputBar(
            controller: _controller,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppTheme.primaryTextColor),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(
              widget.otherUserName?.isNotEmpty == true
                  ? widget.otherUserName![0].toUpperCase()
                  : 'U',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName ?? 'Private Chat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.videocam, color: AppTheme.primaryColor),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.call, color: AppTheme.primaryColor),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: AppTheme.primaryColor),
          onPressed: _showChatOptions,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppTheme.dividerColor.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildChatBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: TextStyle(
                color: AppTheme.primaryTextColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isMe = msg.senderId == ChatService.getCurrentUserId();
              final showAvatar = index == 0 ||
                  (index > 0 && messages[index - 1].senderId != msg.senderId);
              final showTimestamp = index == messages.length - 1 ||
                  (index < messages.length - 1 &&
                      messages[index + 1].timestamp.difference(msg.timestamp).inMinutes > 5);

              return _buildModernMessageBubble(msg, isMe, showAvatar, showTimestamp);
            },
          ),
        ),
        if (isTyping && typingUser != null) _buildTypingIndicator(),
      ],
    );
  }

  Widget _buildModernMessageBubble(ChatMessage msg, bool isMe, bool showAvatar, bool showTimestamp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && showAvatar)
                Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              else if (!isMe)
                const SizedBox(width: 40),
              
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.message,
                        style: TextStyle(
                          color: isMe ? Colors.white : AppTheme.primaryTextColor,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(msg.timestamp),
                            style: TextStyle(
                              color: isMe ? Colors.white70 : AppTheme.secondaryTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              if (isMe && showAvatar)
                Container(
                  margin: const EdgeInsets.only(left: 8, bottom: 4),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      AuthService.getCurrentUser()?.name?.isNotEmpty == true
                          ? AuthService.getCurrentUser()!.name[0].toUpperCase()
                          : 'Y',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (showTimestamp)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              child: Text(
                DateFormat('MMM dd, yyyy').format(msg.timestamp),
                style: TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDots(),
                const SizedBox(width: 8),
                Text(
                  '$typingUser is typing',
                  style: TextStyle(
                    color: AppTheme.secondaryTextColor,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return Row(
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.only(right: index < 2 ? 2 : 0),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 600 + (index * 200)),
            curve: Curves.easeInOut,
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: AppTheme.primaryColor),
              title: Text('Chat Info', style: TextStyle(color: AppTheme.primaryTextColor)),
              onTap: () {
                Navigator.pop(context);
                // Show chat info
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: AppTheme.errorColor),
              title: Text('Block User', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                // Block user functionality
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ModernMessageInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  
  const _ModernMessageInputBar({
    required this.controller,
    required this.onSend,
  });

  @override
  _ModernMessageInputBarState createState() => _ModernMessageInputBarState();
}

class _ModernMessageInputBarState extends State<_ModernMessageInputBar> {
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _isComposing = widget.controller.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.dividerColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(
                Icons.add,
                color: AppTheme.primaryColor,
                size: 28,
              ),
              onPressed: () {},
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 44,
                  maxHeight: 120,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _isComposing ? AppTheme.primaryColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: "Message...",
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor.withOpacity(0.7),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(
                          color: AppTheme.primaryTextColor,
                          fontSize: 16,
                        ),
                        onSubmitted: (_) => widget.onSend(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        color: AppTheme.secondaryTextColor,
                        size: 22,
                      ),
                      onPressed: () {},
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: _isComposing ? AppTheme.primaryColor : AppTheme.secondaryTextColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(22),
              ),
              child: IconButton(
                icon: Icon(
                  _isComposing ? Icons.send : Icons.mic,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _isComposing ? widget.onSend : () {},
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }
}
