class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? role;
  final String? address;
  final String? cnic;
  final bool isVerified;
  final String verificationStatus; // 'pending', 'approved', 'rejected'
  final String identityVerificationStatus; // 'not_submitted', 'pending', 'approved', 'rejected'
  final String emailVerificationStatus; // 'pending', 'verified'
  final String? rejectionReason;
  final DateTime? verificationDate;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role,
    this.address,
    this.cnic,
    this.isVerified = false,
    this.verificationStatus = 'pending',
    this.identityVerificationStatus = 'not_submitted',
    this.emailVerificationStatus = 'pending',
    this.rejectionReason,
    this.verificationDate,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? role,
    String? address,
    String? cnic,
    bool? isVerified,
    String? verificationStatus,
    String? identityVerificationStatus,
    String? emailVerificationStatus,
    String? rejectionReason,
    DateTime? verificationDate,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      address: address ?? this.address,
      cnic: cnic ?? this.cnic,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      identityVerificationStatus: identityVerificationStatus ?? this.identityVerificationStatus,
      emailVerificationStatus: emailVerificationStatus ?? this.emailVerificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      verificationDate: verificationDate ?? this.verificationDate,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    print('🔍 UserModel.fromJson() - Raw JSON: $json');
    final role = json['role'] ?? json['roles']?[0] ?? '';
    print('🔍 UserModel.fromJson() - Extracted role: "$role"');
    
    // Check both status and identityVerificationStatus for proper verification
    final status = json['status'] ?? 'pending';
    final identityStatus = json['identityVerificationStatus'] ?? 'not_submitted';
    final emailStatus = json['emailVerificationStatus'] ?? 'pending';
    
    // FIXED: Mark as verified if admin approved OR if already verified (permanent status)
    final isFullyVerified = (identityStatus == 'approved' || identityStatus == 'verified');
    
    // Normalize verification status - keep verified status permanent
    String normalizedIdentityStatus = identityStatus;
    if (identityStatus == 'approved' || identityStatus == 'verified') {
      normalizedIdentityStatus = 'verified';
    }
    
    String normalizedStatus = status;
    if (status == 'approved' || isFullyVerified) {
      normalizedStatus = 'approved';
    }
    
    print('🔍 UserModel.fromJson() - Status: "$status" -> "$normalizedStatus", Identity: "$identityStatus" -> "$normalizedIdentityStatus", Email: "$emailStatus", Fully Verified: $isFullyVerified');
    
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '', // Backend uses _id, handle both
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? json['number'] ?? '', // Backend sends 'number'
      avatarUrl: json['avatarUrl'] ?? json['profilePicture'] ?? '', // Backend sends 'profilePicture'
      role: role,
      address: json['address'] ?? '', // Backend sends 'address'
      cnic: json['cnic'] ?? json['cnicNumber'] ?? '',
      isVerified: isFullyVerified,
      verificationStatus: normalizedStatus,
      identityVerificationStatus: normalizedIdentityStatus,
      emailVerificationStatus: emailStatus,
      rejectionReason: json['rejectionReason'],
      verificationDate: json['verificationDate'] != null 
          ? DateTime.parse(json['verificationDate']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'role': role,
      'address': address,
      'cnic': cnic,
      'isVerified': isVerified,
      'verificationStatus': verificationStatus,
      'identityVerificationStatus': identityVerificationStatus,
      'emailVerificationStatus': emailVerificationStatus,
      'rejectionReason': rejectionReason,
      'verificationDate': verificationDate?.toIso8601String(),
    };
  }

  /// Check if user has a specific role
  bool hasRole(String roleToCheck) {
    print('🔍 UserModel.hasRole() - Current role: "$role", Checking for: "$roleToCheck"');
    final result = role?.toLowerCase() == roleToCheck.toLowerCase();
    print('✅ Role match result: $result');
    return result;
  }

  /// Get primary role for dashboard routing
  String get primaryRole {
    return role?.toLowerCase() ?? '';
  }

  /// Alias for isVerified to maintain consistency with dashboard code
  bool get isIdentityVerified => isVerified;

  /// Get identity verification status
  String get identityVerificationStatusValue => identityVerificationStatus;
}
