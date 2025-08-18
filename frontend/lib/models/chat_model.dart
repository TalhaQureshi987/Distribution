// chat_model.dart
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String message;
  final DateTime timestamp;
  final String messageType; // 'text', 'image', 'location'
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final bool isRead;
  final String? replyTo;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.message,
    required this.timestamp,
    required this.messageType,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.isRead = false,
    this.replyTo,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? json['_id'] ?? '',
      senderId: json['senderId'],
      senderName: json['senderName'],
      receiverId: json['receiverId'],
      receiverName: json['receiverName'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      messageType: json['messageType'],
      imageUrl: json['imageUrl'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      isRead: json['isRead'] ?? false,
      replyTo: json['replyTo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'messageType': messageType,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'isRead': isRead,
      'replyTo': replyTo,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? receiverName,
    String? message,
    DateTime? timestamp,
    String? messageType,
    String? imageUrl,
    double? latitude,
    double? longitude,
    bool? isRead,
    String? replyTo,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isRead: isRead ?? this.isRead,
      replyTo: replyTo ?? this.replyTo,
    );
  }
}

class ChatRoom {
  final String id;
  final String participant1Id;
  final String participant1Name;
  final String participant2Id;
  final String participant2Name;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessage;
  final int unreadCount;
  final String? donationId;
  final String? requestId;

  ChatRoom({
    required this.id,
    required this.participant1Id,
    required this.participant1Name,
    required this.participant2Id,
    required this.participant2Name,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.donationId,
    this.requestId,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] ?? json['_id'] ?? '',
      participant1Id: json['participant1Id'],
      participant1Name: json['participant1Name'],
      participant2Id: json['participant2Id'],
      participant2Name: json['participant2Name'],
      createdAt: DateTime.parse(json['createdAt']),
      lastMessageAt:
          json['lastMessageAt'] != null
              ? DateTime.parse(json['lastMessageAt'])
              : null,
      lastMessage: json['lastMessage'],
      unreadCount: json['unreadCount'] ?? 0,
      donationId: json['donationId'],
      requestId: json['requestId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participant1Id': participant1Id,
      'participant1Name': participant1Name,
      'participant2Id': participant2Id,
      'participant2Name': participant2Name,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'donationId': donationId,
      'requestId': requestId,
    };
  }

  String getOtherParticipantName(String currentUserId) {
    if (participant1Id == currentUserId) {
      return participant2Name;
    } else {
      return participant1Name;
    }
  }

  String getOtherParticipantId(String currentUserId) {
    if (participant1Id == currentUserId) {
      return participant2Id;
    } else {
      return participant1Id;
    }
  }
}
