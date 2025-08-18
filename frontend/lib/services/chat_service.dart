import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/chat_model.dart';
import 'api_service.dart';

class ChatService {
  static const String baseUrl = '/api/chat';
  static IO.Socket? _socket;
  static bool _isConnected = false;

  /// Initialize Socket.IO connection
  static void initializeSocket() {
    if (_socket != null) return;

    _socket = IO.io(ApiService.base, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.onConnect((_) {
      _isConnected = true;
      print('Socket connected');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('Socket disconnected');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });

    _socket!.connect();
  }

  /// Disconnect Socket.IO
  static void disconnectSocket() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }

  /// Listen for new messages
  static void listenForMessages(Function(ChatMessage) onMessageReceived) {
    if (_socket == null) {
      initializeSocket();
    }

    _socket!.on('new_message', (data) {
      final message = ChatMessage.fromJson(data);
      onMessageReceived(message);
    });
  }

  /// Stop listening for messages
  static void stopListeningForMessages() {
    _socket?.off('new_message');
  }

  static StreamController<ChatMessage>? _messageStreamController;
  static StreamController<ChatRoom>? _roomStreamController;

  // Chat rooms cache
  static final Map<String, ChatRoom> _chatRooms = {};
  static final Map<String, List<ChatMessage>> _messages = {};

  /// Initialize chat service
  static void initialize() {
    _messageStreamController = StreamController<ChatMessage>.broadcast();
    _roomStreamController = StreamController<ChatRoom>.broadcast();
  }

  /// Get message stream
  static Stream<ChatMessage> get messageStream =>
      _messageStreamController?.stream ?? Stream.empty();

  /// Get room stream
  static Stream<ChatRoom> get roomStream =>
      _roomStreamController?.stream ?? Stream.empty();

  /// Create or get chat room between two users
  static Future<ChatRoom> createOrGetChatRoom({
    required String otherUserId,
    required String otherUserName,
    String? donationId,
    String? requestId,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'donationId': donationId,
          'requestId': requestId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final room = ChatRoom.fromJson(data['room']);
        _chatRooms[room.id] = room;
        _roomStreamController?.add(room);
        return room;
      } else {
        throw Exception('Failed to create/get chat room: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating/getting chat room: $e');
    }
  }

  /// Get user's chat rooms
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

        // Update cache
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

  /// Get messages for a specific chat room
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

        // Update cache
        _messages[roomId] = messages;

        return messages;
      } else {
        throw Exception('Failed to fetch messages: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching messages: $e');
    }
  }

  /// Send a text message
  static Future<ChatMessage> sendTextMessage({
    required String roomId,
    required String message,
    String? replyTo,
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
          'message': message,
          'messageType': 'text',
          'replyTo': replyTo,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final chatMessage = ChatMessage.fromJson(data['message']);

        // Add to cache
        if (_messages[roomId] != null) {
          _messages[roomId]!.add(chatMessage);
        } else {
          _messages[roomId] = [chatMessage];
        }

        // Emit to stream
        _messageStreamController?.add(chatMessage);

        return chatMessage;
      } else {
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  /// Send an image message
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

        // Add to cache
        if (_messages[roomId] != null) {
          _messages[roomId]!.add(chatMessage);
        } else {
          _messages[roomId] = [chatMessage];
        }

        // Emit to stream
        _messageStreamController?.add(chatMessage);

        return chatMessage;
      } else {
        throw Exception('Failed to send image message: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending image message: $e');
    }
  }

  /// Send a location message
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

        // Add to cache
        if (_messages[roomId] != null) {
          _messages[roomId]!.add(chatMessage);
        } else {
          _messages[roomId] = [chatMessage];
        }

        // Emit to stream
        _messageStreamController?.add(chatMessage);

        return chatMessage;
      } else {
        throw Exception('Failed to send location message: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending location message: $e');
    }
  }

  /// Mark messages as read
  static Future<void> markMessagesAsRead(String roomId) async {
    try {
      final token = await _getToken();
      final response = await http.patch(
        Uri.parse('${ApiService.base}$baseUrl/rooms/$roomId/read'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark messages as read: ${response.body}');
      }

      // Update local cache
      if (_messages[roomId] != null) {
        for (final message in _messages[roomId]!) {
          message.copyWith(isRead: true);
        }
      }
    } catch (e) {
      throw Exception('Error marking messages as read: $e');
    }
  }

  /// Delete a message
  static Future<void> deleteMessage(String roomId, String messageId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse(
          '${ApiService.base}$baseUrl/rooms/$roomId/messages/$messageId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete message: ${response.body}');
      }

      // Remove from local cache
      if (_messages[roomId] != null) {
        _messages[roomId]!.removeWhere((msg) => msg.id == messageId);
      }
    } catch (e) {
      throw Exception('Error deleting message: $e');
    }
  }

  /// Get cached messages for a room
  static List<ChatMessage> getCachedMessages(String roomId) {
    return _messages[roomId] ?? [];
  }

  /// Get cached chat room
  static ChatRoom? getCachedRoom(String roomId) {
    return _chatRooms[roomId];
  }

  /// Clear cache for a specific room
  static void clearRoomCache(String roomId) {
    _messages.remove(roomId);
    _chatRooms.remove(roomId);
  }

  /// Clear all cache
  static void clearAllCache() {
    _messages.clear();
    _chatRooms.clear();
  }

  /// Disconnect and cleanup
  static void dispose() {
    _messageStreamController?.close();
    _roomStreamController?.close();
    _messageStreamController = null;
    _roomStreamController = null;
    clearAllCache();
  }

  /// Get token from SharedPreferences
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }
}
