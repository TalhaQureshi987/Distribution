class DonationModel {
  final String id;
  final String donorId;
  final String donorName;
  final String title;
  final String description;
  final String foodType;
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
  final String? reservedBy;
  final DateTime? reservedAt;

  DonationModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.title,
    required this.description,
    required this.foodType,
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
    this.reservedBy,
    this.reservedAt,
  });

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    try {
      return DonationModel(
        id: json['id'] ?? json['_id'] ?? '',
        donorId: json['donorId'] ?? '',
        donorName: json['donorName'] ?? '',
        title: json['title'] ?? '',
        description: json['description']?.toString().trim() ?? '',
        foodType: json['foodType'] ?? '',
        quantity: (json['quantity'] ?? 1) as int,
        quantityUnit: json['quantityUnit'] ?? 'pieces',
        expiryDate: DateTime.parse(json['expiryDate']),
        pickupAddress: json['pickupAddress'] ?? '',
        latitude: (json['latitude'] ?? 0.0).toDouble(),
        longitude: (json['longitude'] ?? 0.0).toDouble(),
        status: json['status'] ?? 'available',
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
        images: List<String>.from(json['images'] ?? []),
        notes: json['notes'],
        isUrgent: json['isUrgent'] ?? false,
        reservedBy: json['reservedBy'],
        reservedAt: json['reservedAt'] != null ? DateTime.parse(json['reservedAt']) : null,
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
    };
  }

  DonationModel copyWith({
    String? id,
    String? donorId,
    String? donorName,
    String? title,
    String? description,
    String? foodType,
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
  }) {
    return DonationModel(
      id: id ?? this.id,
      donorId: donorId ?? this.donorId,
      donorName: donorName ?? this.donorName,
      title: title ?? this.title,
      description: description ?? this.description,
      foodType: foodType ?? this.foodType,
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
    );
  }

  @override
  String toString() {
    return 'DonationModel(${toJson()})';
  }
}