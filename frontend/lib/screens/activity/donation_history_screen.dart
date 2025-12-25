import 'package:flutter/material.dart';
import '../../services/donation_service.dart';
import '../../models/donation_model.dart';

class DonationHistoryScreen extends StatefulWidget {
  @override
  _DonationHistoryScreenState createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  List<DonationModel> donations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDonationHistory();
  }

  Future<void> _loadDonationHistory() async {
    try {
      final result = await DonationService.getUserDonations();
      // setState(() {
      //   donations =
      //       (result['donations'] as List)
      //           .map(
      //             (donation) =>
      //                 DonationModel.fromJson(donation as Map<String, dynamic>),
      //           )
      //           .toList();
      //   isLoading = false;
      // });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load donation history: $e'),
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
      appBar: AppBar(title: Text('Donation History'), leading: BackButton()),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : donations.isEmpty
              ? Center(child: Text('No donations yet.'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: donations.length,
                itemBuilder: (context, index) {
                  final donation = donations[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: Icon(Icons.card_giftcard, color: Colors.brown),
                      title: Text(donation.title),
                      subtitle: Text(
                        'Date: ${_formatDate(donation.createdAt)}',
                      ),
                      trailing: Text(
                        donation.status,
                        style: TextStyle(
                          color:
                              donation.status == 'completed'
                                  ? Color(0xFF8B4513) // Brown theme color
                                  : Color(0xFFD2691E), // Brown-orange theme color
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
