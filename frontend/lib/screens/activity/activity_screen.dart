import 'package:flutter/material.dart';
import '../../services/activity_service.dart';
import '../../config/theme.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool loading = true;
  List<Map<String, dynamic>> activities = [];
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() => loading = true);
    try {
      final data = await ActivityService.getSimpleActivity();
      setState(() {
        activities = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Widget _buildFilters() {
    final filters = ['all', 'donation', 'request'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: filters.map((filter) {
          final selected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.toUpperCase()),
              selected: selected,
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() => selectedFilter = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredActivities = selectedFilter == 'all' 
        ? activities 
        : activities.where((activity) => activity['type'] == selectedFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Activity'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  )
                : filteredActivities.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No activity yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadActivity,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredActivities.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final activity = filteredActivities[index];
                            return _buildActivityCard(activity);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['type'] as String? ?? '';
    final title = activity['title'] as String? ?? '';
    final description = activity['description'] as String? ?? '';
    final date = DateTime.tryParse(activity['date'] as String? ?? '') ?? DateTime.now();
    final status = activity['status'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getTypeColor(type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getTypeIcon(type),
              color: _getTypeColor(type),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'donation':
        return Icons.volunteer_activism;
      case 'request':
        return Icons.handshake;
      default:
        return Icons.event_note;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'donation':
        return Color(0xFF8B4513); // Brown theme color
      case 'request':
        return Color(0xFFD2691E); // Brown-orange theme color
      default:
        return AppTheme.primaryColor;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'available':
        return Color(0xFF8B4513); // Brown theme color
      case 'completed':
      case 'fulfilled':
        return Color(0xFF2E8B57); // Sea green for completed
      case 'cancelled':
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
