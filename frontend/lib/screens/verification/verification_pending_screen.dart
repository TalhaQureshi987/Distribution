import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/identity_verification_service.dart';
import '../../services/dashboard_router.dart';
import '../../config/theme.dart';
import 'document_upload_screen.dart';

class VerificationPendingScreen extends StatefulWidget {
  @override
  _VerificationPendingScreenState createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  Timer? _statusTimer;
  Map<String, dynamic>? _verificationStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
    _startStatusChecking();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusChecking() {
    _statusTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _loadVerificationStatus();
    });
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final response = await IdentityVerificationService.getVerificationStatus();
      
      setState(() {
        _verificationStatus = response;
        _loading = false;
      });
      
      if (response['verified'] == true) {
        // User verified, navigate to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardRouter.getHomeDashboard(),
          ),
        );
      } else if (response['verificationStatus'] == 'rejected') {
        // Show rejection reason and allow re-upload
        _showRejectionDialog(response['rejectionReason'] ?? 'Verification was rejected');
      }
      // If still pending, continue checking with timer
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showRejectionDialog(String rejectionReason) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Verification Rejected',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your identity verification has been rejected for the following reason:',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  rejectionReason,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Please upload new documents to continue with the verification process.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate back to document upload screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentUploadScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(
                'Upload New Documents',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard() {
    if (_verificationStatus == null) return SizedBox.shrink();

    final status = _verificationStatus!['status'] ?? 'unknown';
    
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusDescription;

    switch (status) {
      case 'documents_uploaded':
      case 'under_review':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusTitle = 'Under Review';
        statusDescription = 'Your documents are being reviewed by our team. This usually takes 24-48 hours.';
        break;
      case 'verified':
        statusColor = Colors.green;
        statusIcon = Icons.verified;
        statusTitle = 'Verified!';
        statusDescription = 'Your identity has been verified successfully. You now have full access.';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusTitle = 'Verification Rejected';
        statusDescription = _verificationStatus!['rejectionReason'] ?? 'Your verification was rejected. Please contact support.';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusTitle = 'Unknown Status';
        statusDescription = 'Please contact support for assistance.';
    }

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              statusIcon,
              size: 48,
              color: statusColor,
            ),
          ),
          SizedBox(height: 20),
          Text(
            statusTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            statusDescription,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.secondaryTextColor,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (_verificationStatus!['reviewedAt'] != null) ...[
            SizedBox(height: 16),
            Text(
              'Reviewed on: ${DateTime.parse(_verificationStatus!['reviewedAt']).toLocal().toString().split('.')[0]}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Verification Status'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading verification status...',
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(height: 20),
                  _buildStatusCard(),
                  SizedBox(height: 32),
                  
                  // Progress indicator
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildProgressStep('Email Verified', true),
                        _buildProgressStep('Documents Uploaded', true),
                        _buildProgressStep(
                          'Under Review', 
                          _verificationStatus!['status'] == 'under_review' ||
                          _verificationStatus!['status'] == 'verified' ||
                          _verificationStatus!['status'] == 'rejected'
                        ),
                        _buildProgressStep(
                          'Identity Verified', 
                          _verificationStatus!['status'] == 'verified'
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Action buttons
                  if (_verificationStatus!['status'] == 'rejected') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/document-upload',
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => DashboardRouter.getHomeDashboard()),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue to App',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Auto-refresh indicator
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Auto-refreshing every 30 seconds',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressStep(String title, bool completed) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: completed ? Colors.green : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: completed
                ? Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: completed ? AppTheme.primaryTextColor : AppTheme.secondaryTextColor,
              fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
