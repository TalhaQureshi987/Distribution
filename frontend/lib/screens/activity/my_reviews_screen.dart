import 'package:flutter/material.dart';
import '../../services/review_service.dart';
import '../../models/review_model.dart';

class MyReviewsScreen extends StatefulWidget {
  @override
  _MyReviewsScreenState createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  List<ReviewModel> reviews = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final result = await ReviewService.getUserReviews();
      setState(() {
        reviews =
            (result['reviews'] as List)
                .map(
                  (review) =>
                      ReviewModel.fromJson(review as Map<String, dynamic>),
                )
                .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load reviews: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Reviews'), leading: BackButton()),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : reviews.isEmpty
              ? Center(child: Text('No reviews yet.'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                review.reviewedUserName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (starIndex) {
                                  return Icon(
                                    starIndex < review.rating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  );
                                }),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(review.comment),
                          SizedBox(height: 8),
                          Text(
                            _formatDate(review.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
