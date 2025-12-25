class VolunteerModel {
  final String id;
  final String userId;
  final String userName;
  final String email;
  final String? phone;
  final List<String> skills;
  final Map<String, dynamic> availability;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String status;
  final int totalHours;
  final int completedTasks;
  final double rating;
  final List<double> reviews;
  final DateTime createdAt;
  final DateTime updatedAt;

  VolunteerModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    this.phone,
    required this.skills,
    required this.availability,
    this.address,
    this.latitude,
    this.longitude,
    this.status = 'pending',
    this.totalHours = 0,
    this.completedTasks = 0,
    this.rating = 0.0,
    this.reviews = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory VolunteerModel.fromJson(Map<String, dynamic> json) {
    try {
      return VolunteerModel(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? 'Anonymous',
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString(),
        skills: List<String>.from(json['skills'] ?? []),
        availability: Map<String, dynamic>.from(json['availability'] ?? {}),
        address: json['address']?.toString(),
        latitude: json['location']?['coordinates']?[1]?.toDouble() ?? 
                 double.tryParse(json['latitude']?.toString() ?? '0.0'),
        longitude: json['location']?['coordinates']?[0]?.toDouble() ?? 
                  double.tryParse(json['longitude']?.toString() ?? '0.0'),
        status: json['status']?.toString() ?? 'pending',
        totalHours: int.tryParse(json['totalHours']?.toString() ?? '0') ?? 0,
        completedTasks: int.tryParse(json['completedTasks']?.toString() ?? '0') ?? 0,
        rating: double.tryParse(json['rating']?.toString() ?? '0.0') ?? 0.0,
        reviews: (json['reviews'] as List?)?.map((e) => double.tryParse(e.toString()) ?? 0.0).toList() ?? [],
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      print('Error parsing VolunteerModel: $e');
      return VolunteerModel(
        id: '',
        userId: '',
        userName: 'Anonymous',
        email: '',
        skills: [],
        availability: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'email': email,
        'phone': phone,
        'skills': skills,
        'availability': availability,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'totalHours': totalHours,
        'completedTasks': completedTasks,
        'rating': rating,
        'reviews': reviews,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  String get availabilityText {
    final days = availability['days'] as List?;
    final hours = availability['hours'] as Map?;
    
    if (days == null || days.isEmpty) return 'No availability set';
    
    String daysText = days.join(', ');
    if (hours != null && hours['start'] != null && hours['end'] != null) {
      daysText += ' (${hours['start']} - ${hours['end']})';
    }
    
    return daysText;
  }

  String get skillsText => skills.isEmpty ? 'No skills listed' : skills.join(', ');

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'pending':
        return 'Pending Approval';
      default:
        return status;
    }
  }
}

class VolunteerOpportunity {
  final String id;
  final String title;
  final String description;
  final String organizerId;
  final String organizerName;
  final List<String> requiredSkills;
  final DateTime startDate;
  final DateTime endDate;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int maxVolunteers;
  final int currentVolunteers;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  VolunteerOpportunity({
    required this.id,
    required this.title,
    required this.description,
    required this.organizerId,
    required this.organizerName,
    required this.requiredSkills,
    required this.startDate,
    required this.endDate,
    this.address,
    this.latitude,
    this.longitude,
    this.maxVolunteers = 10,
    this.currentVolunteers = 0,
    this.status = 'open',
    this.priority = 'medium',
    required this.createdAt,
    required this.updatedAt,
  });

  factory VolunteerOpportunity.fromJson(Map<String, dynamic> json) {
    try {
      return VolunteerOpportunity(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        organizerId: json['organizerId']?.toString() ?? '',
        organizerName: json['organizerName']?.toString() ?? 'Unknown',
        requiredSkills: List<String>.from(json['requiredSkills'] ?? []),
        startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now().add(Duration(days: 1)),
        address: json['address']?.toString(),
        latitude: json['location']?['coordinates']?[1]?.toDouble() ?? 
                 double.tryParse(json['latitude']?.toString() ?? '0.0'),
        longitude: json['location']?['coordinates']?[0]?.toDouble() ?? 
                  double.tryParse(json['longitude']?.toString() ?? '0.0'),
        maxVolunteers: int.tryParse(json['maxVolunteers']?.toString() ?? '10') ?? 10,
        currentVolunteers: int.tryParse(json['currentVolunteers']?.toString() ?? '0') ?? 0,
        status: json['status']?.toString() ?? 'open',
        priority: json['priority']?.toString() ?? 'medium',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      print('Error parsing VolunteerOpportunity: $e');
      return VolunteerOpportunity(
        id: '',
        title: 'Unknown Opportunity',
        description: '',
        organizerId: '',
        organizerName: 'Unknown',
        requiredSkills: [],
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'requiredSkills': requiredSkills,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'maxVolunteers': maxVolunteers,
      'currentVolunteers': currentVolunteers,
      'status': status,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  VolunteerOpportunity copyWith({
    String? id,
    String? title,
    String? description,
    String? organizerId,
    String? organizerName,
    List<String>? requiredSkills,
    DateTime? startDate,
    DateTime? endDate,
    String? address,
    double? latitude,
    double? longitude,
    int? maxVolunteers,
    int? currentVolunteers,
    String? status,
    String? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VolunteerOpportunity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      maxVolunteers: maxVolunteers ?? this.maxVolunteers,
      currentVolunteers: currentVolunteers ?? this.currentVolunteers,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isAvailable => currentVolunteers < maxVolunteers && status == 'open';
  
  String get spotsText => '$currentVolunteers/$maxVolunteers volunteers';
  
  String get priorityDisplay {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'High Priority';
      case 'medium':
        return 'Medium Priority';
      case 'low':
        return 'Low Priority';
      default:
        return priority;
    }
  }
}
