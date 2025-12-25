class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? receiverId;
  final String? receiverName;
  final String message;
  final DateTime timestamp;
  final String messageType; // 'text', 'image', 'location'
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  bool isRead;
  bool isDelivered;
  DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.receiverId,
    this.receiverName,
    required this.message,
    required this.timestamp,
    this.messageType = 'text',
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.isRead = false,
    this.isDelivered = false,
    this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'],
      roomId: json['roomId'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      receiverId: json['receiverId'],
      receiverName: json['receiverName'],
      message: json['message'] ?? '',
      messageType: json['messageType'] ?? 'text',
      timestamp: DateTime.parse(json['timestamp']),
      imageUrl: json['imageUrl'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      isRead: json['isRead'] ?? false,
      isDelivered: json['isDelivered'] ?? false,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        "_id": id,
        "roomId": roomId,
        "senderId": senderId,
        "senderName": senderName,
        "receiverId": receiverId,
        "receiverName": receiverName,
        "message": message,
        "messageType": messageType,
        "timestamp": timestamp.toIso8601String(),
        "imageUrl": imageUrl,
        "latitude": latitude,
        "longitude": longitude,
        "isRead": isRead,
        "isDelivered": isDelivered,
        "readAt": readAt?.toIso8601String(),
      };
}

class ChatRoom {
  final String id;
  final String participant1Id;
  final String participant1Name;
  final String participant2Id;
  final String participant2Name;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ChatRoom({
    required this.id,
    required this.participant1Id,
    required this.participant1Name,
    required this.participant2Id,
    required this.participant2Name,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['_id'] ?? json['id'],
      participant1Id: json['participant1Id'],
      participant1Name: json['participant1Name'],
      participant2Id: json['participant2Id'],
      participant2Name: json['participant2Name'],
      lastMessage: json['lastMessage'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}
