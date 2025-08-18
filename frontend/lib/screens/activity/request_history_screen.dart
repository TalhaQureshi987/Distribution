import 'package:flutter/material.dart';
import '../../services/request_service.dart';
import '../../models/request_model.dart';

class RequestHistoryScreen extends StatefulWidget {
  @override
  _RequestHistoryScreenState createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  List<RequestModel> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequestHistory();
  }

  Future<void> _loadRequestHistory() async {
    try {
      final result = await RequestService.getUserRequests();
      // setState(() {
      //   requests =
      //       (result['requests'] as List)
      //           .map(
      //             (request) =>
      //                 RequestModel.fromJson(request as Map<String, dynamic>),
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
            content: Text('Failed to load request history: $e'),
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
      appBar: AppBar(title: Text('Request History'), leading: BackButton()),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : requests.isEmpty
              ? Center(child: Text('No requests yet.'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: Icon(Icons.handshake, color: Colors.brown),
                      title: Text(request.title),
                      subtitle: Text('Date: ${_formatDate(request.createdAt)}'),
                      trailing: Text(
                        request.status,
                        style: TextStyle(
                          color:
                              request.status == 'completed'
                                  ? Colors.green
                                  : Colors.orange,
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
