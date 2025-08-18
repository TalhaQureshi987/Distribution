import 'package:flutter/material.dart';
import '../../services/volunteer_service.dart';

class VolunteerScreen extends StatefulWidget {
  @override
  State<VolunteerScreen> createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends State<VolunteerScreen> {
  final List<VolunteerOpportunity> _opportunities = [
    VolunteerOpportunity(
      icon: Icons.food_bank,
      title: 'Food Distribution',
      description: 'Help distribute food to those in need at local centers.',
      location: 'Community Center, Main Street',
      schedule: 'Every Saturday, 10am-2pm',
      requirements: 'Must be 18+, bring ID',
      imageAsset: 'assets/images/food_distribution.jpg',
      category: 'Food',
    ),
    VolunteerOpportunity(
      icon: Icons.clean_hands,
      title: 'Hygiene Kit Packing',
      description: 'Assemble hygiene kits for distribution to shelters.',
      location: 'Health Center, Oak Avenue',
      schedule: '1st Sunday monthly, 9am-1pm',
      requirements: 'All ages welcome',
      imageAsset: 'assets/images/hygiene_kits.jpg',
      category: 'Hygiene',
    ),
    VolunteerOpportunity(
      icon: Icons.school,
      title: 'Education Support',
      description: 'Tutor children in after-school programs.',
      location: 'Public Library, 2nd Floor',
      schedule: 'Weekdays, 4pm-6pm',
      requirements: 'Background check required',
      imageAsset: 'assets/images/education.jpg',
      category: 'Education',
    ),
  ];

  String _searchQuery = '';
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Food',
    'Hygiene',
    'Education',
    'Medical',
  ];
  final List<String> _volunteeredTitles = [];
  final Color _primaryColor = Color(0xFF8D6E63); // Brown 400
  final Color _secondaryColor = Color(0xFFD7CCC8); // Brown 100
  final Color _accentColor = Color(0xFF5D4037); // Brown 700
  final Color _backgroundColor = Colors.white;

  List<VolunteerOpportunity> get _filteredOpportunities {
    return _opportunities
        .where(
          (opp) =>
              (_selectedCategory == 'All' ||
                  opp.category == _selectedCategory) &&
              opp.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  void _showVolunteerDialog(VolunteerOpportunity opportunity) async {
    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: _backgroundColor,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(bottom: 16),
                        width: double.infinity,
                        child: Text(
                          'Join ${opportunity.title}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _accentColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: _primaryColor,
                                ),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: _primaryColor),
                                ),
                              ),
                              validator:
                                  (value) =>
                                      value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: phoneController,
                              decoration: InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: Icon(
                                  Icons.phone,
                                  color: _primaryColor,
                                ),
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: _primaryColor),
                                ),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value?.isEmpty ?? true) return 'Required';
                                if (!RegExp(r'^[0-9]{10}$').hasMatch(value!)) {
                                  return '10 digits required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: messageController,
                              decoration: InputDecoration(
                                labelText: 'Why volunteer? (Optional)',
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: _primaryColor),
                                ),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(color: _accentColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (_formKey.currentState!.validate()) {
                                      try {
                                        // Register as volunteer using backend API
                                        await VolunteerService.registerVolunteer(
                                          skills: [opportunity.category],
                                          availability: {
                                            'days': [
                                              'monday',
                                              'tuesday',
                                              'wednesday',
                                              'thursday',
                                              'friday',
                                            ],
                                            'hours': {
                                              'start': '09:00',
                                              'end': '17:00',
                                            },
                                          },
                                          address:
                                              'Default Address', // TODO: Get actual address
                                          latitude:
                                              0.0, // TODO: Get actual location
                                          longitude:
                                              0.0, // TODO: Get actual location
                                        );

                                        Navigator.pop(context);
                                        setState(
                                          () => _volunteeredTitles.add(
                                            opportunity.title,
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Successfully joined ${opportunity.title}!',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to join volunteer opportunity: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Submit'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Volunteer Opportunities',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _accentColor,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistoryDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              hintText: 'Search opportunities...',
              onChanged: (value) => setState(() => _searchQuery = value),
              backgroundColor: MaterialStateProperty.all(_secondaryColor),
              elevation: MaterialStateProperty.all(1),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder:
                  (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FilterChip(
                      label: Text(_categories[index]),
                      selected: _selectedCategory == _categories[index],
                      selectedColor: _primaryColor.withOpacity(0.5),
                      checkmarkColor: Colors.white,
                      onSelected:
                          (selected) => setState(
                            () =>
                                _selectedCategory =
                                    selected ? _categories[index] : 'All',
                          ),
                    ),
                  ),
            ),
          ),
          Expanded(
            child:
                _filteredOpportunities.isEmpty
                    ? Center(
                      child: Text(
                        'No matching opportunities',
                        style: TextStyle(color: _accentColor),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredOpportunities.length,
                      itemBuilder: (context, index) {
                        final opp = _filteredOpportunities[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          color: _secondaryColor.withOpacity(0.3),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _primaryColor.withOpacity(0.2),
                              child: Icon(opp.icon, color: _primaryColor),
                            ),
                            title: Text(
                              opp.title,
                              style: TextStyle(
                                color: _accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(opp.description),
                                const SizedBox(height: 4),
                                Text(
                                  opp.schedule ?? '',
                                  style: TextStyle(
                                    color: _accentColor.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: _primaryColor,
                            ),
                            onTap: () => _showVolunteerDialog(opp),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(
                    'Volunteer Today!',
                    style: TextStyle(color: _accentColor),
                  ),
                  content: Text(
                    'Make a difference in your community by volunteering your time and skills.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: TextStyle(color: _accentColor),
                      ),
                    ),
                  ],
                ),
          );
        },
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.volunteer_activism),
        label: const Text('Volunteer Now'),
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Your Volunteering',
              style: TextStyle(color: _accentColor),
            ),
            content:
                _volunteeredTitles.isEmpty
                    ? Text(
                      'No sign-ups yet',
                      style: TextStyle(color: _accentColor),
                    )
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final title in _volunteeredTitles)
                          ListTile(
                            leading: Icon(
                              Icons.check_circle,
                              color: _primaryColor,
                            ),
                            title: Text(title),
                          ),
                      ],
                    ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: _accentColor)),
              ),
            ],
          ),
    );
  }
}

class VolunteerOpportunity {
  final IconData icon;
  final String title;
  final String description;
  final String? location;
  final String? schedule;
  final String? requirements;
  final String? imageAsset;
  final String category;

  VolunteerOpportunity({
    required this.icon,
    required this.title,
    required this.description,
    this.location,
    this.schedule,
    this.requirements,
    this.imageAsset,
    required this.category,
  });
}
