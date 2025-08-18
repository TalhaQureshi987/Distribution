class ReviewModel {
  final String id;
  final String reviewerId;
  final String reviewerName;
  final String reviewedUserId;
  final String reviewedUserName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? donationId;
  final String? requestId;

  ReviewModel({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewedUserId,
    required this.reviewedUserName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
    this.donationId,
    this.requestId,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? json['_id'] ?? '',
      reviewerId: json['reviewerId'],
      reviewerName: json['reviewerName'],
      reviewedUserId: json['reviewedUserId'],
      reviewedUserName: json['reviewedUserName'],
      rating: json['rating'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      donationId: json['donationId'],
      requestId: json['requestId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewedUserId': reviewedUserId,
      'reviewedUserName': reviewedUserName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'donationId': donationId,
      'requestId': requestId,
    };
  }
}
