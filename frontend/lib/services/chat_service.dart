import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/chat_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ChatService {
  static const String baseUrl = '/api/chat';
  static IO.Socket? _socket;
  static bool _isConnected = false;

  static StreamController<ChatMessage>? _messageStreamController;
  static StreamController<Map<String, dynamic>>? _roomStreamController;

  static Stream<ChatMessage> get messageStream =>
      _messageStreamController?.stream ?? const Stream.empty();

  static Stream<Map<String, dynamic>> get roomStream =>
      _roomStreamController?.stream ?? const Stream.empty();

  static IO.Socket? get socket => _socket;

  static void initialize() {
    _messageStreamController ??= StreamController<ChatMessage>.broadcast();
    _roomStreamController ??= StreamController<Map<String, dynamic>>.broadcast();
  }

  static Future<void> initializeSocket() async {
    if (_socket != null && _isConnected) return;
    
    try {
      final token = await AuthService.getValidToken();
      final user = AuthService.getCurrentUser();
      
      if (user == null) {
        print('❌ ChatService: No user found for socket connection');
        return;
      }

      print('💬 ChatService: Initializing Socket.IO connection for chat...');
      
      _socket = IO.io(
        ApiService.base,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setAuth({
              'token': 'Bearer $token',
            })
            .setExtraHeaders({
              'Authorization': 'Bearer $token',
              'userId': user.id,
              'userName': user.name,
            })
            .build(),
      );

      _socket!.onConnect((_) {
        print('✅ ChatService: Socket connected successfully');
        _isConnected = true;
        
        // Listen for real-time chat messages only
        _socket!.on('new_message', (data) {
          print('📨 ChatService: New message received: $data');
          try {
            final message = ChatMessage.fromJson(data);
            _messageStreamController?.add(message);
          } catch (e) {
            print('❌ ChatService: Error parsing message: $e');
          }
        });

        // Listen for typing indicators
        _socket!.on('typing', (data) {
          print('⌨️ ChatService: Typing indicator: $data');
          // Handle typing indicators if needed
        });

        // Listen for user status changes
        _socket!.on('userStatusChanged', (data) {
          print('👤 ChatService: User status changed: $data');
          // Handle user online/offline status
        });

        // Listen for room join success
        _socket!.on('joinRoomSuccess', (data) {
          print('🏠 ChatService: Successfully joined room: ${data['roomId']}');
        });
      });

      _socket!.onDisconnect((_) {
        print('❌ ChatService: Socket disconnected');
        _isConnected = false;
      });

      _socket!.onConnectError((error) {
        print('❌ ChatService: Socket connection error: $error');
        _isConnected = false;
      });

      _socket!.onError((error) {
        print('❌ ChatService: Socket error: $error');
      });

      _socket!.connect();
      
    } catch (e) {
      print('❌ ChatService: Error initializing socket: $e');
    }
  }

  static final Map<String, ChatRoom> _chatRooms = {};
  static final Map<String, List<ChatMessage>> _messages = {};

  static Future<ChatRoom> createOrGetChatRoom({
    required String otherUserId,
    required String otherUserName,
    String? donationId,
    String? requestId,
  }) async {
    try {
      final token = await _getToken();

      print('🔍 Creating chat room with:');
      print('  otherUserId: $otherUserId');
      print('  otherUserName: $otherUserName');
      print('  donationId: $donationId');
      print('  requestId: $requestId');

      final requestBody = {
        'otherUserId': otherUserId,
        'otherUserName': otherUserName,
      };

      if (donationId != null && donationId.isNotEmpty) {
        requestBody['donationId'] = donationId;
      }
      if (requestId != null && requestId.isNotEmpty) {
        requestBody['requestId'] = requestId;
      }

      print('📤 Sending request body: $requestBody');

      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final room = ChatRoom.fromJson(data['room']);
        _chatRooms[room.id] = room;
        _roomStreamController?.add({
          'id': room.id,
          'participant1Id': room.participant1Id,
          'participant1Name': room.participant1Name,
          'participant2Id': room.participant2Id,
          'participant2Name': room.participant2Name,
          'lastMessage': room.lastMessage,
          'lastMessageAt': room.lastMessageAt?.toIso8601String(),
          'unreadCount': room.unreadCount,
        });
        return room;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error creating chat room: $e');
      throw Exception('Error creating/getting chat room: $e');
    }
  }

  static Future<List<ChatRoom>> getChatRooms() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/rooms'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rooms =
            (data['rooms'] as List)
                .map((json) => ChatRoom.fromJson(json))
                .toList();

        for (final room in rooms) {
          _chatRooms[room.id] = room;
        }

        return rooms;
      } else {
        throw Exception('Failed to fetch chat rooms: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching chat rooms: $e');
    }
  }

  static Future<List<ChatMessage>> getRoomMessages(String roomId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiService.base}$baseUrl/rooms/$roomId/messages'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages =
            (data['messages'] as List)
                .map((json) => ChatMessage.fromJson(json))
                .toList();

        _messages[roomId] = messages;

        return messages;
      } else {
        throw Exception('Failed to fetch messages: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching messages: $e');
    }
  }

  static Future<ChatMessage> sendTextMessage({
    required String roomId,
    required String message,
    String? replyTo,
  }) async {
    try {
      print('ChatService: Getting token...');
      final token = await _getToken();
      print('ChatService: Token obtained');

      final url = '${ApiService.base}$baseUrl/rooms/$roomId/messages';
      print('ChatService: Sending POST to $url');

      final requestBody = {
        'message': message,
        'messageType': 'text',
        'replyTo': replyTo,
      };
      print('ChatService: Request body: $requestBody');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('ChatService: Response status: ${response.statusCode}');
      print('ChatService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final chatMessage = ChatMessage.fromJson(data['message']);

        if (_messages[roomId] != null) {
          _messages[roomId]!.add(chatMessage);
        } else {
          _messages[roomId] = [chatMessage];
        }

        _messageStreamController?.add(chatMessage);

        return chatMessage;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('ChatService: Error sending message: $e');
      throw Exception('Error sending message: $e');
    }
  }

  static Future<ChatMessage> sendImageMessage({
    required String roomId,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/rooms/$roomId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': caption ?? '',
          'messageType': 'image',
          'imageUrl': imageUrl,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final chatMessage = ChatMessage.fromJson(data['message']);

        if (_messages[roomId] != null) {
          _messages[roomId]!.add(chatMessage);
        } else {
          _messages[roomId] = [chatMessage];
        }

        _messageStreamController?.add(chatMessage);

        return chatMessage;
      } else {
        throw Exception('Failed to send image message: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending image message: $e');
    }
  }

  static Future<ChatMessage> sendLocationMessage({
    required String roomId,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/rooms/$roomId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': address ?? 'Location shared',
          'messageType': 'location',
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final chatMessage = ChatMessage.fromJson(data['message']);

        if (_messages[roomId] != null) {
          _messages[roomId]!.add(chatMessage);
        } else {
          _messages[roomId] = [chatMessage];
        }

        _messageStreamController?.add(chatMessage);

        return chatMessage;
      } else {
        throw Exception('Failed to send location message: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending location message: $e');
    }
  }

  static Future<void> markMessagesAsRead(String roomId) async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('${ApiService.base}$baseUrl/rooms/$roomId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (_messages[roomId] != null) {
          for (final message in _messages[roomId]!) {
            if (message.receiverId == getCurrentUserId()) {
              message.isRead = true;
              message.readAt = DateTime.now();
            }
          }
        }
      } else {
        throw Exception('Failed to mark messages as read: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error marking messages as read: $e');
    }
  }

  static List<ChatMessage> getCachedMessages(String roomId) {
    return _messages[roomId] ?? [];
  }

  static ChatRoom? getCachedRoom(String roomId) {
    return _chatRooms[roomId];
  }

  static void clearRoomCache(String roomId) {
    _messages.remove(roomId);
    _chatRooms.remove(roomId);
  }

  static void clearAllCache() {
    _messages.clear();
    _chatRooms.clear();
  }

  /// Clear all cache and disconnect (for logout)
  static Future<void> clearCache() async {
    print('🧹 ChatService: Clearing all cache and disconnecting...');
    
    // Clear all cached data
    clearAllCache();
    
    // Close stream controllers
    _messageStreamController?.close();
    _roomStreamController?.close();
    _messageStreamController = null;
    _roomStreamController = null;
    
    // Disconnect socket
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
    
    print('✅ ChatService: Cache cleared and disconnected');
  }

  static void sendTypingIndicator(String roomId, bool isTyping) {
    if (_socket != null && _isConnected) {
      _socket!.emit('typing', {'roomId': roomId, 'isTyping': isTyping});
    }
  }

  static void joinRoom(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join_room', {'roomId': roomId});
    }
  }

  static void leaveRoom(String roomId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leave_room', {'roomId': roomId});
    }
  }

  static void stopListeningForMessages() {
    if (_socket != null && _isConnected) {
      _socket!.off('new_message');
    }
  }

  static void stopListeningForTyping() {
    if (_socket != null && _isConnected) {
      _socket!.off('typing');
    }
  }

  static void dispose() {
    _messageStreamController?.close();
    _roomStreamController?.close();
    _messageStreamController = null;
    _roomStreamController = null;
    clearAllCache();
    
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
  }

  static String getCurrentUserId() {
    final user = AuthService.getCurrentUser();
    if (user != null && user.id.isNotEmpty) {
      return user.id;
    }
    throw Exception('No current user found - please login');
  }

  static Future<String> _getToken() async {
    try {
      return await AuthService.getValidToken();
    } catch (e) {
      throw Exception('Authentication required: $e');
    }
  }
}
