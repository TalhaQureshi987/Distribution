class DonationModel {
  final String id;
  final String donorId;
  final String donorName;
  final String title;
  final String description;
  final String foodType;
  final String? foodName;
  final String? foodCategory;
  final int quantity;
  final String quantityUnit;
  final DateTime expiryDate;
  final String pickupAddress;
  final double latitude;
  final double longitude;
  final String status; // 'available', 'reserved', 'picked_up', 'expired'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> images;
  final String? notes;
  final bool isUrgent;
  final bool needsVolunteer; // Derived from deliveryOption == 'Volunteer Delivery'
  final String? reservedBy;
  final DateTime? reservedAt;
  final String deliveryOption; // 'Self delivery', 'Volunteer Delivery', 'Paid Delivery (Earn)'
  final String? assignedTo; // ID of assigned volunteer or delivery person
  final double? deliveryDistance; // Distance in kilometers
  final double? totalDeliveryPrice; // Full price based on distance
  final double? deliveryCommission; // 10% commission for platform
  final double? deliveryPayment; // 90% payment for delivery person

  DonationModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.title,
    required this.description,
    required this.foodType,
    this.foodName,
    this.foodCategory,
    required this.quantity,
    required this.quantityUnit,
    required this.expiryDate,
    required this.pickupAddress,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.images = const [],
    this.notes,
    this.isUrgent = false,
    this.needsVolunteer = false,
    this.reservedBy,
    this.reservedAt,
    required this.deliveryOption,
    this.assignedTo,
    this.deliveryDistance,
    this.totalDeliveryPrice,
    this.deliveryCommission,
    this.deliveryPayment,
  });

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    try {
      final deliveryOption = json['deliveryOption']?.toString();
      if (deliveryOption == null) {
        throw Exception('deliveryOption is required');
      }
      return DonationModel(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        donorId: _extractId(json['donorId']) ?? _extractId(json['userId']) ?? '',
        donorName: _extractName(json['donorId']) ?? _extractName(json['userId']) ?? json['donorName']?.toString() ?? json['userName']?.toString() ?? 'Anonymous',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString().trim() ?? '',
        foodType: json['foodType']?.toString() ?? '',
        foodName: json['foodName']?.toString(),
        foodCategory: json['foodCategory']?.toString(),
        quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
        quantityUnit: json['quantityUnit']?.toString() ?? 'pieces',
        expiryDate: DateTime.tryParse(json['expiryDate']?.toString() ?? '') ?? DateTime.now().add(Duration(days: 7)),
        pickupAddress: json['pickupAddress']?.toString() ?? '',
        latitude: double.tryParse(json['latitude']?.toString() ?? '0.0') ?? 0.0,
        longitude: double.tryParse(json['longitude']?.toString() ?? '0.0') ?? 0.0,
        status: json['status']?.toString() ?? 'available',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
        images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
        notes: json['notes']?.toString(),
        isUrgent: json['isUrgent'] == true || json['isUrgent']?.toString().toLowerCase() == 'true',
        needsVolunteer: deliveryOption == 'Volunteer Delivery',
        reservedBy: json['reservedBy']?.toString(),
        reservedAt: json['reservedAt'] != null ? DateTime.tryParse(json['reservedAt'].toString()) : null,
        deliveryOption: deliveryOption,
        assignedTo: json['assignedTo']?.toString(),
        deliveryDistance: double.tryParse(json['deliveryDistance']?.toString() ?? '0.0'),
        totalDeliveryPrice: double.tryParse(json['totalDeliveryPrice']?.toString() ?? '0.0'),
        deliveryCommission: double.tryParse(json['deliveryCommission']?.toString() ?? '0.0'),
        deliveryPayment: double.tryParse(json['deliveryPayment']?.toString() ?? '0.0'),
      );
    } catch (e) {
      throw Exception('Failed to parse DonationModel: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donorId': donorId,
      'donorName': donorName,
      'title': title,
      'description': description.trim(),
      'foodType': foodType,
      'foodName': foodName,
      'foodCategory': foodCategory,
      'quantity': quantity,
      'quantityUnit': quantityUnit,
      'expiryDate': expiryDate.toIso8601String(),
      'pickupAddress': pickupAddress,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'images': images,
      'notes': notes,
      'isUrgent': isUrgent,
      'reservedBy': reservedBy,
      'reservedAt': reservedAt?.toIso8601String(),
      'deliveryOption': deliveryOption,
      'needsVolunteer': needsVolunteer,
      'assignedTo': assignedTo,
      'deliveryDistance': deliveryDistance,
      'totalDeliveryPrice': totalDeliveryPrice,
      'deliveryCommission': deliveryCommission,
      'deliveryPayment': deliveryPayment,
    };
  }

  DonationModel copyWith({
    String? id,
    String? donorId,
    String? donorName,
    String? title,
    String? description,
    String? foodType,
    String? foodName,
    String? foodCategory,
    int? quantity,
    String? quantityUnit,
    DateTime? expiryDate,
    String? pickupAddress,
    double? latitude,
    double? longitude,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? images,
    String? notes,
    bool? isUrgent,
    String? reservedBy,
    DateTime? reservedAt,
    String? deliveryOption,
    String? assignedTo,
    bool? needsVolunteer,
    double? deliveryDistance,
    double? totalDeliveryPrice,
    double? deliveryCommission,
    double? deliveryPayment,
  }) {
    return DonationModel(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      donorName: donorName ?? this.donorName,
      title: title ?? this.title,
      description: description ?? this.description,
      foodType: foodType ?? this.foodType,
      foodName: foodName ?? this.foodName,
      foodCategory: foodCategory ?? this.foodCategory,
      quantity: quantity ?? this.quantity,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      expiryDate: expiryDate ?? this.expiryDate,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
      notes: notes ?? this.notes,
      isUrgent: isUrgent ?? this.isUrgent,
      reservedBy: reservedBy ?? this.reservedBy,
      reservedAt: reservedAt ?? this.reservedAt,
      deliveryOption: deliveryOption ?? this.deliveryOption,
      assignedTo: assignedTo ?? this.assignedTo,
      needsVolunteer: needsVolunteer ?? this.needsVolunteer,
      deliveryDistance: deliveryDistance ?? this.deliveryDistance,
      totalDeliveryPrice: totalDeliveryPrice ?? this.totalDeliveryPrice,
      deliveryCommission: deliveryCommission ?? this.deliveryCommission,
      deliveryPayment: deliveryPayment ?? this.deliveryPayment,
    );
  }

  @override
  String toString() {
    return 'DonationModel(${toJson()})';
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