class RequestModel {
  final String id;
  final String requesterId;
  final String requesterName;
  final String title;
  final String description;
  final String foodType;
  final int quantity;
  final String quantityUnit;
  final DateTime neededBy;
  final String pickupAddress;
  final double latitude;
  final double longitude;
  final String status; // 'pending', 'approved', 'fulfilled', 'cancelled'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> images;
  final String? notes;
  final bool isUrgent;
  final String? fulfilledBy;
  final DateTime? fulfilledAt;
  final String? reason;

  RequestModel({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.title,
    required this.description,
    required this.foodType,
    required this.quantity,
    required this.quantityUnit,
    required this.neededBy,
    required this.pickupAddress,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.images = const [],
    this.notes,
    this.isUrgent = false,
    this.fulfilledBy,
    this.fulfilledAt,
    this.reason,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'] ?? json['_id'] ?? '',
      requesterId: json['requesterId'],
      requesterName: json['requesterName'],
      title: json['title'],
      description: json['description'],
      foodType: json['foodType'],
      quantity: json['quantity'],
      quantityUnit: json['quantityUnit'],
      neededBy: DateTime.parse(json['neededBy']),
      pickupAddress: json['pickupAddress'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      images: List<String>.from(json['images'] ?? []),
      notes: json['notes'],
      isUrgent: json['isUrgent'] ?? false,
      fulfilledBy: json['fulfilledBy'],
      fulfilledAt:
          json['fulfilledAt'] != null
              ? DateTime.parse(json['fulfilledAt'])
              : null,
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'title': title,
      'description': description,
      'foodType': foodType,
      'quantity': quantity,
      'quantityUnit': quantityUnit,
      'neededBy': neededBy.toIso8601String(),
      'pickupAddress': pickupAddress,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'images': images,
      'notes': notes,
      'isUrgent': isUrgent,
      'fulfilledBy': fulfilledBy,
      'fulfilledAt': fulfilledAt?.toIso8601String(),
      'reason': reason,
    };
  }

  RequestModel copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? title,
    String? description,
    String? foodType,
    int? quantity,
    String? quantityUnit,
    DateTime? neededBy,
    String? pickupAddress,
    double? latitude,
    double? longitude,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? images,
    String? notes,
    bool? isUrgent,
    String? fulfilledBy,
    DateTime? fulfilledAt,
    String? reason,
  }) {
    return RequestModel(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      title: title ?? this.title,
      description: description ?? this.description,
      foodType: foodType ?? this.foodType,
      quantity: quantity ?? this.quantity,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      neededBy: neededBy ?? this.neededBy,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      notes: notes ?? this.notes,
      isUrgent: isUrgent ?? this.isUrgent,
      fulfilledBy: fulfilledBy ?? this.fulfilledBy,
      fulfilledAt: fulfilledAt ?? this.fulfilledAt,
      reason: reason ?? this.reason,
    );
  }
}
