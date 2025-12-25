class RequestModel {
  final String id;
  final String requesterId;
  final String requesterName;
  final String title;
  final String description;
  final String requestType;
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
  final bool needsVolunteer;
  final String? deliveryOption; // 'Self', 'Volunteer Delivery', 'Other'
  final String? reason;

  RequestModel({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.title,
    required this.description,
    required this.requestType,
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
    this.needsVolunteer = false,
    this.deliveryOption,
    this.reason,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    try {
      return RequestModel(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        requesterId: _extractId(json['requesterId']) ?? _extractId(json['userId']) ?? '',
        requesterName: _extractName(json['requesterId']) ?? _extractName(json['userId']) ?? json['requesterName']?.toString() ?? json['userName']?.toString() ?? 'Anonymous',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        requestType: json['requestType']?.toString() ?? '',
        foodType: json['foodType']?.toString() ?? '',
        quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
        quantityUnit: json['quantityUnit']?.toString() ?? 'pieces',
        neededBy: DateTime.tryParse(json['neededBy']?.toString() ?? '') ?? DateTime.now().add(Duration(days: 7)),
        pickupAddress: json['pickupAddress']?.toString() ?? '',
        latitude: double.tryParse(json['latitude']?.toString() ?? '0.0') ?? 0.0,
        longitude: double.tryParse(json['longitude']?.toString() ?? '0.0') ?? 0.0,
        status: json['status']?.toString() ?? 'pending',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
        images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
        notes: json['notes']?.toString(),
        isUrgent: json['isUrgent'] == true || json['isUrgent']?.toString().toLowerCase() == 'true',
        fulfilledBy: json['fulfilledBy']?.toString(),
        fulfilledAt: json['fulfilledAt'] != null ? DateTime.parse(json['fulfilledAt']) : null,
        needsVolunteer: json['needsVolunteer'] ?? json['deliveryOption'] == 'Volunteer Delivery',
        deliveryOption: json['deliveryOption'],
        reason: json['reason']?.toString(),
      );
    } catch (e) {
      throw Exception('Failed to parse RequestModel: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'title': title,
      'description': description,
      'requestType': requestType,
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
      'needsVolunteer': needsVolunteer,
      'reason': reason,
    };
  }

  RequestModel copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? title,
    String? description,
    String? requestType,
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
    String? deliveryOption,
    bool? needsVolunteer,
    String? reason,
  }) {
    return RequestModel(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      title: title ?? this.title,
      description: description ?? this.description,
      requestType: requestType ?? this.requestType,
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
      deliveryOption: deliveryOption ?? this.deliveryOption,
      needsVolunteer: needsVolunteer ?? this.needsVolunteer,
      reason: reason ?? this.reason,
    );
  }

  // Helper methods to extract ID and name from user objects
  static String? _extractId(dynamic userField) {
    if (userField == null) return null;
    if (userField is String) return userField;
    if (userField is Map<String, dynamic>) {
      return userField['_id']?.toString() ?? userField['id']?.toString();
    }
    return null;
  }

  static String? _extractName(dynamic userField) {
    if (userField == null) return null;
    if (userField is String) return null; // If it's just an ID string, no name
    if (userField is Map<String, dynamic>) {
      return userField['name']?.toString();
    }
    return null;
  }
}
