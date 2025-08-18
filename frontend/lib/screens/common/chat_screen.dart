// chat_screen.dart// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../models/chat_model.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;
  String? currentRoomId;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _initializeSocket();
  }

  void _initializeSocket() {
    // Initialize Socket.IO connection
    ChatService.initializeSocket();

    // Listen for new messages
    ChatService.listenForMessages((message) {
      if (mounted) {
        setState(() {
          messages.add(message);
        });
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      // TODO: Get actual room ID from navigation or parameters
      const roomId = 'sample-room-id';
      currentRoomId = roomId;

      final chatMessages = await ChatService.getRoomMessages(roomId);
      setState(() {
        messages = chatMessages;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || currentRoomId == null) return;

    try {
      final newMessage = await ChatService.sendTextMessage(
        roomId: currentRoomId!,
        message: text,
      );

      setState(() {
        messages.add(newMessage);
      });

      _controller.clear();
      Future.delayed(Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    // Stop listening for messages and disconnect socket
    ChatService.stopListeningForMessages();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = const Color(0xFFF4F4F4);
    final Color accentColor = Colors.brown;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Private Chat'),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                isLoading
                    ? Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                    ? Center(
                      child: Text(
                        'No messages yet. Start the conversation!',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 12,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe =
                            msg.senderId ==
                            'current-user-id'; // TODO: Get actual current user ID
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 250),
                          curve: Curves.easeIn,
                          child: Row(
                            mainAxisAlignment:
                                isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.brown.shade200,
                                    child: Text(
                                      msg.senderName.isNotEmpty
                                          ? msg.senderName[0].toUpperCase()
                                          : 'A',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    radius: 18,
                                  ),
                                ),
                              Flexible(
                                child: Container(
                                  margin: EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 4,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe ? accentColor : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                      bottomLeft: Radius.circular(
                                        isMe ? 18 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 18,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.message,
                                        style: TextStyle(
                                          color:
                                              isMe
                                                  ? Colors.white
                                                  : Colors.black87,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        DateFormat(
                                          'hh:mm a',
                                        ).format(msg.timestamp),
                                        style: TextStyle(
                                          color:
                                              isMe
                                                  ? Colors.white70
                                                  : Colors.black38,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.brown,
                                    child: Text(
                                      'Y',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    radius: 18,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
          _MessageInputBar(
            accentColor: accentColor,
            controller: _controller,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final Color accentColor;
  final TextEditingController controller;
  final VoidCallback onSend;
  const _MessageInputBar({
    required this.accentColor,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ), // Increased vertical padding
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end, // Aligns send button with text field
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 44,
                maxHeight: 100, // Allow multi-line expansion if needed
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: Colors.brown, width: 1),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12, // More vertical space inside the input
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 44, // Match the minHeight of the input
            width: 44,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: onSend,
              iconSize: 22,
              padding: EdgeInsets.zero,
              splashRadius: 24,
            ),
          ),
        ],
      ),
    );
  }
}
